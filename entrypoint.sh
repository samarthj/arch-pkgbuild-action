#!/usr/bin/env bash

set -euo pipefail

dry_run=${INPUT_DRY_RUN:-'true'}
custom_build_cmd=${INPUT_CUSTOM_BUILD_CMD:-''}

HOME=/home/builder

echo "::group::Setting up pacman"
uname -m
# sudo pacman-key --delete pacman@localhost
sudo pacman-key --init
sudo pacman-key --populate archlinux
sudo pacman -Syy
# paru -S rate-mirrors --noconfirm --skipreview
# export TMPFILE="$(mktemp)"
# sudo true
# rate-mirrors --save=$TMPFILE arch --max-delay=21600 &&
#   sudo mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist-backup &&
#   sudo mv $TMPFILE /etc/pacman.d/mirrorlist
echo "::endgroup::"

echo "::group::Chown repo and move to \"${INPUT_PKGBUILD_ROOT}\""
pkgbuild_path="$GITHUB_WORKSPACE/$INPUT_PKGBUILD_ROOT/PKGBUILD"
if [ ! -f "$pkgbuild_path" ]; then
  echo "ERROR: Could not find the PKGBUILD at \"${INPUT_PKGBUILD_ROOT}\""
  exit 1
fi
git config --global --add safe.directory "$GITHUB_WORKSPACE/$INPUT_PKGBUILD_ROOT"
sudo chmod -R a=rwX "$GITHUB_WORKSPACE/$INPUT_PKGBUILD_ROOT/"
cd "$GITHUB_WORKSPACE/$INPUT_PKGBUILD_ROOT/" || exit 1

echo "::endgroup::"

echo "::group::Init .SRCINFO"
makepkg --printsrcinfo >.SRCINFO
cat .SRCINFO
pkgbase="$(sed -n -e 's/^pkgbase = //p' .SRCINFO)"
echo "::endgroup::"

if [ "${INPUT_SETUP_AUR:-'true'}" == "true" ]; then
  echo "::group::Setup AUR ssh"
  echo "store aur ssh config"
  ssh-keyscan -v -t "rsa,dsa,ecdsa,ed25519" aur.archlinux.org >>/home/builder/.ssh/known_hosts
  echo "$INPUT_AUR_SSH_PRIVATE_KEY" >/home/builder/.ssh/aur
  chmod -vR 600 /home/builder/.ssh/*
  ssh-keygen -vy -f /home/builder/.ssh/aur >/home/builder/.ssh/aur.pub
  # ls -la /home/builder/.ssh/
  echo "check ssh key"
  ssh -i /home/builder/.ssh/aur aur@aur.archlinux.org help
  echo "::endgroup::"

  echo "::group::Setup AUR git-repo"
  [ -z "$INPUT_AUR_USERNAME" ] &&
    echo "ERROR: In order to commit to AUR, please add your 'INPUT_AUR_USERNAME'" && exit 1
  echo "save git global config"
  git config --global user.name "$INPUT_AUR_USERNAME"
  [ -z "$INPUT_AUR_EMAIL" ] &&
    echo "ERROR: In order to commit to AUR, please add your 'INPUT_AUR_EMAIL'" && exit 1
  git config --global user.email "$INPUT_AUR_EMAIL"
  git config --global init.defaultbranch "master"
  echo "init git repo at $(pwd)"
  git init -b master .
  echo "add ssh://aur@aur.archlinux.org/${pkgbase}.git as a remote"
  git remote add aur "ssh://aur@aur.archlinux.org/${pkgbase}.git"
  git fetch aur master
  echo "commit current working tree"
  git add -A
  git commit --message="wip"
  echo "pull --rebase the remote"
  git branch --set-upstream-to=aur/master master
  git pull --rebase --strategy recursive --strategy-option=theirs --allow-unrelated-histories --no-commit --no-edit aur master
  if [ -z "$(git diff FETCH_HEAD --stat)" ]; then
    echo 'The pkg is same as upstream. The rebase should have automatically dropped the "wip" commit.'
  else
    echo 'The pkg is different from upstream. Will do a soft reset and commit later.'
    git reset --soft HEAD~1
    git fetch aur master
    git diff FETCH_HEAD
  fi
  echo "::endgroup::"
fi

echo "::group::Install dependencies ${makedepends[*]}"
makepkg --printsrcinfo >.SRCINFO
mapfile -t makedepends < <(sed -n -e 's/^\tmakedepends = //p' .SRCINFO)
mapfile -t checkdepends < <(sed -n -e 's/^\tcheckdepends = //p' .SRCINFO)
mapfile -t depends < <(sed -n -e 's/^\tdepends = //p' .SRCINFO)
mapfile -t provides < <(sed -n -e 's/^\tprovides = //p' .SRCINFO)
for target in "${provides[@]}"; do
  for i in "${!depends[@]}"; do
    if [[ ${depends[i]} == "$target" ]]; then
      unset 'depends[i]'
    fi
  done
done
echo "Including makedepends: ${makedepends[*]}"
echo "Including checkdepends: ${checkdepends[*]}"
echo "Including depends: ${depends[*]}"
if [ "${INPUT_INSTALL_OPTDEPENDS:-'false'}" == "true" ]; then
  mapfile -t optdepends < <(grep 'optdepends = ' .SRCINFO | cut -d':' -f1 | cut -d' ' -f3)
  echo "Including optdepends: ${optdepends[*]}"
  cmd="paru -Sy ${makedepends[*]} ${checkdepends[*]} ${depends[*]} ${optdepends[*]} --noconfirm --needed --skipreview --batchinstall --sudoloop --removemake"
else
  cmd="paru -Sy ${makedepends[*]} ${checkdepends[*]} ${depends[*]} --noconfirm --needed --skipreview --batchinstall --sudoloop --removemake"
fi
echo "Install cmd: '$cmd'"
$cmd || true
echo "::endgroup::"

echo "::group::Version check"
current_pkgver="$(sed -n -e 's/^.*pkgver = //p' .SRCINFO)"
strip_prefix="${pkgbase#python-}"
strip_suffix="${strip_prefix%-git}"
strip_suffix="${strip_suffix%-bin}"
py_pkgname="${INPUT_PYTHON_PKG_NAME:-$strip_suffix}"
if [[ (${INPUT_IS_PYTHON_PKG:-'false'} == "true" && -n ${py_pkgname}) || ($pkgbase =~ "^python-" && -n $py_pkgname) ]]; then
  echo "Using python package ${py_pkgname}"
  py_pkgprerelease="$(curl -fSsL "https://pypi.org/rss/project/${py_pkgname}/releases.xml" | grep -oP '<title>.*$' | grep -vi 'PyPI' | head -n1 | sed -re 's|^.*>(.*)<.*$|\1|g')"
  echo "Latest release - ${py_pkgprerelease}"
  py_pkgrelease="$(curl -fSsL "https://pypi.org/rss/project/${py_pkgname}/releases.xml" | grep -oP '<title>.*$' | grep -vi 'PyPI' | grep -vE 'a|b|rc|dev' | head -n1 | sed -re 's|^.*>(.*)<.*$|\1|g')"
  echo "Latest release (excluding pre-releases) - ${py_pkgrelease}"
  if [ "${INPUT_USE_PYPI_PRERELEASE_VERSION:-'false'}" == "true" ]; then
    echo "Updated PKGBUILD with pkgver=${py_pkgprerelease}"
    sed -i "s|^pkgver=.*$|pkgver=${py_pkgprerelease}|" PKGBUILD
    if [ "$current_pkgver" != "${py_pkgprerelease}" ]; then
      sed -i "s|^pkgrel=.*$|pkgrel=1|" PKGBUILD
    fi
  elif [ "${INPUT_USE_PYPI_RELEASE_VERSION:-'false'}" == "true" ]; then
    echo "Updated PKGBUILD with pkgver=${py_pkgrelease}"
    sed -i "s|^pkgver=.*$|pkgver=${py_pkgrelease}|" PKGBUILD
    if [ "$current_pkgver" != "${py_pkgrelease}" ]; then
      sed -i "s|^pkgrel=.*$|pkgrel=1|" PKGBUILD
    fi
  fi
elif [ "${INPUT_IS_PYTHON_PKG:-'false'}" == "true" ]; then
  echo "Expecting python package but the name ($py_pkgname) does not begin with 'python-*' and/ not provided as an input. Ignoring pypi check..."
fi
if [ "${INPUT_USE_GIT_RELEASE_VERSION:-'false'}" == "true" ]; then
  git_repo="${INPUT_GITHUB_PKG_REPOSITORY:-$(sed -n -e 's/^\turl = https:\/\/github\.com\///p' .SRCINFO)}"
  echo "Github repo: ${git_repo} release check..."
  git_release="$(curl -fsSL "https://api.github.com/repos/${git_repo}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')"
  if [ -n "${git_release}" ]; then
    echo "Using git release: ${git_release} for repo: ${git_repo}"
    sed -i "s|^pkgver=.*$|pkgver=${git_release}|" PKGBUILD
    if [ "$current_pkgver" != "${git_release}" ]; then
      sed -i "s|^pkgrel=.*$|pkgrel=1|" PKGBUILD
    fi
  else
    echo "Unable to find the latest release for ${git_repo}. Ignoring git release check..."
  fi
fi
echo "::endgroup::"

echo "::group::Build package(s) ${pkgname[*]}"

mapfile -t pkgname < <(sed -n -e 's/^pkgname = //p' .SRCINFO)
validpgpkeys="$(sed -n -e 's/^.*validpgpkeys = //p' .SRCINFO)"
[ -z "$validpgpkeys" ] || gpg --recv-keys "$validpgpkeys"
updpkgsums
if [ -n "$custom_build_cmd" ]; then
  ${custom_build_cmd}
else
  makepkg -f --cleanbuild --clean --needed --syncdeps --noconfirm --rmdeps --asdeps
fi
echo "::endgroup::"

echo "::group::Updated .SRCINFO"
makepkg --printsrcinfo >.SRCINFO
cat .SRCINFO
pkgver="$(sed -n -e 's/^.*pkgver = //p' .SRCINFO)"
pkgrel="$(sed -n -e 's/^.*pkgrel = //p' .SRCINFO)"
echo "::endgroup::"

echo "::group::Test install package"
for ((i = 0; i < ${#pkgname[@]}; i++)); do
  pkg=${pkgname[$i]}
  echo "Package: ${pkg}"
  ver="${pkg}-${pkgver}-${pkgrel}"
  pkg_archive="$(sudo find /home/builder/packages -type f -name "${ver}-"*".pkg"*)"
  provider="${pkg%-git}"
  provider="${provider%-bin}"
  echo "Checking: if ${provider} already exists"
  if pacman -T "${provider}"; then
    echo "Removing: if ${provider} already exists"
    sudo pacman -Rcus --noconfirm "${provider}"
  fi
  sudo pacman -U --noconfirm "$pkg_archive"
done
echo "::endgroup::"

if [ "${INPUT_SETUP_AUR:-'true'}" == "true" ]; then
  echo "::group::Publish PKGBUILD to AUR"
  if [ -z "$(git diff FETCH_HEAD --stat)" ]; then
    echo 'The pkg is un-changed.'
  else
    echo 'The pkg .SRCINFO has changed.'
    git add -A
    git status
    commit_msg="${INPUT_COMMIT_MESSAGE:-"updpkg: ${pkgname[*]} ${pkgver}-${pkgrel}"}"
    echo "Committing with message: ${commit_msg}"
    git commit --message="${commit_msg}"
    git status
    if [ "$dry_run" == "false" ]; then
      git push --set-upstream aur master
    fi
  fi
  echo "cleanup the git directory and ssh key"
  rm -rf .git /home/builder/.ssh/aur*
  echo "::endgroup::"
fi

echo "::group::Setting artifact locations"
for ((i = 0; i < ${#pkgname[@]}; i++)); do
  echo "Package: ${pkgname[$i]}"
  ver="${pkgname[$i]}-${pkgver}-${pkgrel}"
  pkg_archive="$(sudo find /home/builder/packages -type f -name "${ver}-"*".pkg"*)"
  echo "Package Archve: ${pkg_archive}"
  filename="${pkg_archive##*/}"
  echo "::set-output name=pkg${i}::${filename}"
  echo "::set-output name=ver${i}::${ver}"
  sudo mv "$pkg_archive" "${GITHUB_WORKSPACE}"
done
echo "::endgroup::"
