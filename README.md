# arch-pkgbuild-action

Build the specified PKGBUILD for archlinux

Note: The containerized build does not modify the permissions of the github workspace, since that breaks any following actions. Instead of playing around with and reverting permissions, the build works in an isolated environment and thus any additional environments that would otherwise end up in the normal github workspace need to be explicitly provided as in the example below.

## Inputs

## `pkgbuild_root`

**Required** The relative location of PKGBUILD root.

## `aur_username`

**Required** Username for the AUR maintainer (used for commit).

## `aur_email`

**Required** Email for the AUR maintainer (used for commit).

## `aur_ssh_private_key`

**Required** Private key with access to AUR package.

## `commit_message`

**Optional** Commit message for the AUR package. Default `upgpkg: <pkgname> <pkgver>-<pkgrel>`

## `dry_run`

**Optional** Used for testing the action. To do a full commit, set this to false. Default `true`.

## `is_python_pkg`

**Optional** Whether this is a python format package. Based on the PKGBUILD documentations these should be prefixed with "python-", and this action needs that to be true, else the pypi version check is simply ignored. On its own changes no behaviour without the pypi flags. Default `false`.

## `use_pypi_release_version`

**Optional** Whether to upgrade a python package using the latest release on pypi. Requires "is_python_pkg" to be true. It uses the pypi rss feed to read the latest release. Default `false`.

## `use_pypi_prerelease_version`

**Optional** Whether to upgrade a python package using the latest release (including prereleases - a, b, rc & dev) on pypi. Requires "is_python_pkg" to be true. Overrides the "use_pypi_release_version" regardless of value. It uses the pypi rss feed to read the latest release. Default `false`.

## `custom_build_cmd`

**Optional** Used for specifying a custom build command in-case the standard command is undesirable. The normal command used is `makepkg --config /home/builder/.makepkg.conf -cfC --needed --nodeps --noconfirm`. Note: --nodeps is used since all dependencies are installed before a build is attempted.

## Outputs

## `pkg<n>`

The location of the built package. The key name is an incrementing integer for each package in the PKGBUILD. If the package is a split package, then there will be multiple keys starting with "pkg0". For a single package, only 1 key will be present as "pkg0".

## `ver<n>`

The "<pkgver>-<pkgrel>" of the built package. The key name is an incrementing integer for each package in the PKGBUILD. If the package is a split package, then there will be multiple keys starting with "ver0". For a single package, only 1 key will be present as "ver0".

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
    custom_build_cmd: makepkg --config /home/builder/.makepkg.conf -cfC --needed --nodeps --noconfirm

    # example for specifying paths for builds like golang, that require custom locations for their paths. Basically just add like normal envs you would anywhere else.
  env:
    GOPATH: /home/builder/.local/share/go
    GOCACHE: /home/builder/.cache/go
```
