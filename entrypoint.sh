#!/bin/bash

set -euo pipefail

pkgbuild_root=${INPUT_PKGBUILD_ROOT}
aur_username=${INPUT_AUR_USERNAME}
aur_email=${INPUT_AUR_EMAIL}
aur_ssh_private_key=${INPUT_AUR_SSH_PRIVATE_KEY}
commit_message=${INPUT_COMMIT_MESSAGE}
dry_run=${INPUT_DRY_RUN:-true}

HOME=/home/builder

echo "::group::Setting up pacman"
uname -m
sudo sed -i 's|#ParallelDownloads|ParallelDownloads|g' /etc/pacman.conf
sudo pacman-key --init
sudo pacman-key --populate archlinux
echo "::endgroup::"

echo "::group::Chown repo and move to \"${pkgbuild_root}\""
pkgbuild_path="$GITHUB_WORKSPACE/$pkgbuild_root/PKGBUILD"
if [ ! -f "$pkgbuild_path" ]; then
  echo "ERROR: Could not find the PKGBUILD at \"${pkgbuild_root}\""
  exit 1
fi
sudo chmod -R a=rwX "$GITHUB_WORKSPACE/$pkgbuild_root/"
cd "$GITHUB_WORKSPACE/$pkgbuild_root/" || exit 1

echo "::endgroup::"

echo "::group::Init .SRCINFO"
makepkg --printsrcinfo >.SRCINFO
cat .SRCINFO
pkgbase="$(sed -n -e 's/^pkgbase = //p' .SRCINFO)"
echo "::endgroup::"

echo "::group::Setup AUR ssh"
echo "store aur ssh config"
ssh-keyscan -v -t "rsa,dsa,ecdsa,ed25519" aur.archlinux.org >>/home/builder/.ssh/known_hosts
echo "$aur_ssh_private_key" >/home/builder/.ssh/aur
chmod -vR 600 /home/builder/.ssh/*
ssh-keygen -vy -f /home/builder/.ssh/aur >/home/builder/.ssh/aur.pub
ls -la /home/builder/.ssh/
eval "$(ssh-agent -s)"
ssh-add /home/builder/.ssh/aur
echo "check ssh key"
ssh -i /home/builder/.ssh/aur aur@aur.archlinux.org help
echo "::endgroup::"

echo "::group::Setup AUR git-repo"
echo "init git repo"
git init -b wip .
[ -z "$aur_username" ] &&
  echo "ERROR: In order to commit to AUR, please add your 'aur_username'" && exit 1
echo "save git local config"
git config --local user.name "$aur_username"
[ -z "$aur_email" ] &&
  echo "ERROR: In order to commit to AUR, please add your 'aur_email'" && exit 1
git config --local user.email "$aur_email"
git config --local init.defaultbranch "master"
echo "add ssh://aur@aur.archlinux.org/${pkgbase}.git as a remote"
git remote add -f aur "ssh://aur@aur.archlinux.org/${pkgbase}.git"
echo "commit current working tree"
git add -A
git commit --message="wip"
echo "pull rebase the remote"
git checkout master
echo "merge the current worktree with 'recursive:theirs' strategy"
git merge --strategy recursive --strategy-option=theirs --allow-unrelated-histories --no-commit wip
mapfile -t makedepends < <(sed -n -e 's/^.*makedepends = //p' .SRCINFO)
echo "::endgroup::"

echo "::group::Install make dependencies ${makedepends[*]}"
sudo pacman -Syyu "${makedepends[@]}" --needed --noconfirm
mapfile -t pkgname < <(sed -n -e 's/^pkgname = //p' .SRCINFO)
echo "::endgroup::"

echo "::group::Build package(s) ${pkgname[*]}"
mkdir "/home/builder/packages"
echo "PKGDEST=/home/builder/packages" >>/home/builder/.makepkg.conf
validpgpkeys="$(sed -n -e 's/^.*validpgpkeys = //p' .SRCINFO)"
[ -z "$validpgpkeys" ] || gpg --recv-keys "$validpgpkeys"
makepkg --config /home/builder/.makepkg.conf -cfCs --needed --noconfirm
echo "::endgroup::"

echo "::group::Updated .SRCINFO"
makepkg --printsrcinfo >.SRCINFO
cat .SRCINFO
pkgver="$(sed -n -e 's/^.*pkgver = //p' .SRCINFO)"
pkgrel="$(sed -n -e 's/^.*pkgrel = //p' .SRCINFO)"
arch="$(sed -n -e 's/^.*arch = //p' .SRCINFO)"
echo "::endgroup::"

echo "::group::Publish PKGBUILD to AUR"
if [ -z "$(git diff FETCH_HEAD --stat)" ]; then
  echo 'The pkg is un-changed.'
else
  echo 'The pkg .SRCINFO has changed.'
  git status
  git add .
  git status
  git commit \
    --message="${commit_message:-"updpkg: ${pkgname[*]} ${pkgver}-${pkgrel}"}"
  if [ "$dry_run" == "false" ]; then
    git push --set-upstream aur master
  fi
fi
echo "cleanup the git directory"
rm -rf .git
echo "::endgroup::"

echo "::group::Setting artifact locations"
for ((i = 0; i < ${#pkgname[@]}; i++)); do
  echo "${pkgname[@]}"
  ver="${pkgname[$i]}-${pkgver}-${pkgrel}"
  echo "::set-output name=pkg${i}::${ver}-${arch}.pkg.tar.zst"
  echo "::set-output name=ver${i}::${ver}"
  sudo mv "/home/builder/packages/${ver}-${arch}.pkg.tar.zst" "${GITHUB_WORKSPACE}"
done
echo "::endgroup::"
