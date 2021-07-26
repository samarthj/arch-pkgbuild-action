# arch-pkgbuild-action

Build the specified PKGBUILD for archlinux

## Inputs

## `pkgbuild_root`

**Required** The relative location of PKGBUILD root.

## `aur_username`

**Optional** Username for the AUR maintainer (used for commit).

## `aur_email`

**Optional** Email for the AUR maintainer (used for commit).

## `aur_ssh_private_key`

**Optional** Private key with access to AUR package.

## `commit_message`

**Optional** Commit message for the AUR package. Default `upgpkg: <pkgname> <pkgver>-<pkgrel>`

## `dry_run`

**Optional** Used for testing the action. To do a full commit, set this to false. Default `true`.

## Outputs

## `n`

The location of the built package. The key name is an incrementing integer for each package in the PKGBUILD. If the package is a split package, then there will be multiple keys starting with "0". For a single package, only 1 key will be present as "0".
