## Unreleased

## v2.6 (2023-01-25)

### Feat

- default to cleaning up srcs after makepkg
- reduced image size by another ~90M
- installation tweaks
- add ability to use git releases for py pkgs
- add ability to skip aur setup completely
- overhaul image build

### Fix

- try dumping it via sudo and logging the file permissions
- **bug**:  the output env var is called output
- setting the state parameters
- :wastebasket: update `::set-output` references
- python pkg logic switch
- pacman-key init before archlinux-keyring
- **bug**: depends parsing was broken
- **bug**: uninstall pkg if trying a reinstall

### Refactor

- remove the unneeded build_python switch

## v2.5 (2022-12-05)

### Feat

- skip gpg checks in case of broken keys
- try installing pkg that was just built

### Fix

- broken paru due to openssl upgrade
- do a full init cycle for keys on base img
- issues with aur repo git init
- remove the provided targets for multi pkgbuilds

## v2.4 (2022-01-28)

### Fix

- git config globalized
- **aur**: :bug: pkgrel should be reset on a pkgver increase

## v2.3 (2022-01-04)

## v2.2 (2021-09-23)

### Feat

- add mirrorlist rating and setup

### Fix

- install paru packages as non root
- update trust for keys
- try explicitly deleting the lsign key

### Refactor

- moving around run commands

## v2.1 (2021-08-31)

### Feat

- add an option to install optional dependencies

### Refactor

- installs into a single command

## v2.0.1 (2021-08-20)

### Feat

- update package sources
- make image daily 1 hour before builds start

### Fix

- reinit pacman with mirrors and key

## v2 (2021-08-14)

### Feat

- add ability to override python pkg name
- :sparkles: add support for python packages
- use a pre-built image with paru support

### Fix

- typo missing &&
- repository label
- update PAT for image push
- filename references are being for multiarch
- only soft reset on diff after  rebase
- remove explicit makepkg override inplace of  selective user override
- removing custom srcdest.
- updpkgsums command-not-found
- updpkgsums for python
- typo on the ver<n> output

### Refactor

- :wrench: add default pacman.conf
- add src and pkg dests to makepkg.conf

## v1.1 (2021-08-02)

### Fix

- move icon and label under branding

## v1 (2021-08-02)

### Feat

- add custom build cmd option

### Fix

- :bug: a multitude of issues
- :bug: RUN command order
- :bug: workdir is discouraged.
