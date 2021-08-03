# arch-pkgbuild-action

Build the specified PKGBUILD for archlinux

Note: The containerized build does not modify the permissions of the github workspace, since that breaks any following actions. Instead of playing around with and reverting permissions, the build works in an isolated environment and thus any additional environments that would otherwise end up in the normal github workspace need to be explicitly provided as in the example below.

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

## `custom_build_cmd`

**Optional** Used for specifying a custom build command in-case the standard command is undesirable. Default `makepkg --config /home/builder/.makepkg.conf -cfCs --needed --noconfirm`.

## Outputs

## `pkg<n>`

The location of the built package. The key name is an incrementing integer for each package in the PKGBUILD. If the package is a split package, then there will be multiple keys starting with "pkg0". For a single package, only 1 key will be present as "pkg0".

## `ver<n>`

The "$pkgver-$pkgrel" of the built package. The key name is an incrementing integer for each package in the PKGBUILD. If the package is a split package, then there will be multiple keys starting with "ver0". For a single package, only 1 key will be present as "ver0".

## Usage Example

```yaml
- name: Build
  id: build
  uses: samarthj/arch-pkgbuild-action@v1
  with:
    pkgbuild_root: path/to/pkgbuild_folder
    aur_username: Your Name
    aur_email: email@example.com
    aur_ssh_private_key: ${{ secrets.AUR_SSH_PRIVATE_KEY }}
    dry_run: false
    custom_build_cmd:
      - makepkg
      - --config
      - /home/builder/.makepkg.conf
      - -cfCs
      - --needed
      - --noconfirm

    # example for specifying paths for builds like golang, that require custom locations for their paths.
    GOPATH: /home/builder/.local/share/go
    GOCACHE: /home/builder/.cache/go
```
