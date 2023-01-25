FROM docker.io/archlinux:base-devel as base
LABEL maintainer="Sam <dev@samarthj.com>"
LABEL org.opencontainers.image.source="https://github.com/samarthj/arch-pkgbuild-action"

COPY ./ssh_config /home/builder/.ssh/config
COPY ./.makepkg.conf /home/builder/.makepkg.conf
COPY ./pacman.conf /etc/pacman.conf

RUN \
  useradd --uid 1000 --shell /usr/bin/false builder && \
  mkdir -pv \
  /home/builder/.ssh /home/builder/.config /home/builder/.cache /home/builder/.local/share \
  /home/builder/packages /home/builder/sources && \
  chown -R builder:builder /home/builder && \
  echo "builder ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers

RUN --mount=type=cache,target=/var/cache/pacman/pkg,sharing=locked \
  --mount=type=tmpfs,target=/tmp \
  pacman -Sy --noconfirm archlinux-keyring && \
  pacman-key --init && \
  pacman-key --populate archlinux && \
  pacman -Sy --needed --noconfirm \
  git openssl pacman-contrib namcap \
  fakechroot fakeroot
# RUN paccache -r && \
#   rm -rvf /var/cache/pacman/pkg/* /home/builder/packages/*

FROM base as build
RUN --mount=type=cache,target=/var/cache/pacman/pkg,from=base,sharing=locked \
  --mount=type=tmpfs,target=/tmp \
  pacman -Sy --needed --noconfirm \
  pacman-mirrorlist openssh openssl-1.1 \
  gzip gnupg glibc zstd
# RUN paccache -r && \
#   rm -rvf /var/cache/pacman/pkg/* /home/builder/packages/*

FROM base as paru
RUN  --mount=type=tmpfs,target=/tmp \
  --mount=type=cache,target=/var/cache/pacman/pkg,from=base,sharing=locked \
  pacman -Sy --needed --noconfirm rustup
# RUN paccache -r && \
#   rm -rvf /var/cache/pacman/pkg/* /home/builder/packages/*
USER builder
RUN --mount=type=tmpfs,target=/tmp \
  --mount=type=cache,target=/var/cache/pacman/pkg,from=base,sharing=locked \
  cd tmp && \
  rustup default nightly && \
  git clone https://aur.archlinux.org/paru.git && \
  cd paru && \
  makepkg -Ccf --noconfirm
# ls -la /home/builder/packages && \
# find ~/packages -type f -name paru-*.pkg.* -exec namcap {} \;

FROM build as final
COPY --from=paru /home/builder/packages/paru-*.pkg.* /tmp/
RUN \
  find /tmp -type f -name paru-*.pkg.* -exec pacman -U --noconfirm {} \; && \
  mkdir -pv /var/cache/pacman/pkg && \
  paccache -r && \
  rm -rvf /var/cache/pacman/pkg/* /home/builder/packages/* /tmp/* && \
  pacman-key --delete pacman@localhost

USER builder

ENV XDG_CACHE_HOME=/home/builder/.cache
ENV XDG_CONFIG_HOME=/home/builder/.config
ENV XDG_DATA_HOME=/home/builder/.local/share
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
