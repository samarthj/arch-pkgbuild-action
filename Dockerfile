FROM ghcr.io/samarthj/arch-pkgbuild-action:latest
LABEL maintainer="Sam <dev@samarthj.com>"
COPY ./entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
