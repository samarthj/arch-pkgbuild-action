#!/bin/bash

set -euo pipefail

pkgbuild_root=$1
aur_username=$2
aur_email=$3
aur_ssh_private_key=$4
commit_message=$5
dry_run=${6:-true}

cd "$pkgbuild_root" || exit 1

if [ ! -f PKGBUILD ]; then
  echo "ERROR: Could not find the PKGBUILD at \"${pkgbuild_root}\""
  exit 1
fi

makepkg --printsrcinfo >.SRCINFO
pkgbase="$(sed -n -e 's/^pkgbase = //p' .SRCINFO)"

if [ "$dry_run" == "false" ]; then
  echo "$aur_ssh_private_key" >~/.ssh/aur

  git-config

  git init
  git remote add aur ssh://aur@aur.archlinux.org/"${pkgbase}".git
  git fetch aur master
  git pull --rebase aur master
fi

makepkg -csfC --noconfirm --needed
makepkg --printsrcinfo >.SRCINFO

mapfile -t pkgname < <(sed -n -e 's/^pkgname = //p' .SRCINFO)
pkgver="$(sed -n -e 's/^.*pkgver = //p' .SRCINFO)"
pkgrel="$(sed -n -e 's/^.*pkgrel = //p' .SRCINFO)"
arch="$(sed -n -e 's/^.*arch = //p' .SRCINFO)"

function git_config() {
  [ -z "$aur_username" ] &&
    echo "ERROR: In order to commit to AUR, please add your 'aur_username'" && exit 1
  git config user.name = "$aur_username"
  [ -z "$aur_email" ] &&
    echo "ERROR: In order to commit to AUR, please add your 'aur_email'" && exit 1
  git config user.email = "$aur_email"
  git config init.defaultbranch = "master"
}

if [ "$dry_run" == "false" ]; then

  if [ -z "$(git diff FETCH_HEAD --stat)" ]; then
    echo 'The pkg .SRCINFO has changed.'
    git add PKGBUILD .SRCINFO
    git commit \
      --message="${commit_message:-"updpkg: ${pkgname[*]} ${pkgver}-${pkgrel}"}"
    git push --set-upstream aur master
  else
    echo 'The pkg is un-changed.'
  fi
fi

for pkg in "${pkgname[@]}"; do
  echo "::set-output name=${pkg}::${pkgbuild_root}/${pkg}-${pkgver}-${pkgrel}-${arch}.pkg.tar.zst"
done
