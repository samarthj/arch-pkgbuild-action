FROM docker.io/archlinux:base-devel as base
LABEL maintainer="Sam <dev@samarthj.com>"
LABEL org.opencontainers.image.source="https://github.com/samarthj/arch-pkgbuild-action"

COPY ./ssh_config /home/builder/.ssh/config
COPY ./.makepkg.conf /home/builder/.makepkg.conf
COPY ./pacman.conf /etc/pacman.conf

RUN \
  --mount=type=tmpfs,target=/tmp \
  useradd --uid 1000 --shell /usr/bin/false builder && \
  mkdir -pv \
  /home/builder/.ssh /home/builder/.config /home/builder/.cache /home/builder/.local/share \
  /home/builder/packages /home/builder/sources /home/builder/srcpackages && \
  chown -R builder:builder /home/builder && \
  echo "builder ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers

RUN \
  --mount=type=cache,target=/var/cache/pacman/pkg,sharing=locked \
  --mount=type=tmpfs,target=/tmp \
  pacman-key --init && \
  pacman-key --populate archlinux && \
  pacman -Sy --noconfirm archlinux-keyring

FROM base as build
RUN \
  --mount=type=cache,target=/var/cache/pacman/pkg,source=/var/cache/pacman/pkg,from=base \
  --mount=type=tmpfs,target=/tmp \
  pacman -Sy --needed --noconfirm \
  git openssl pacman-contrib \
  fakechroot fakeroot \
  pacman-mirrorlist openssh openssl-1.1 \
  gzip gnupg glibc zstd

FROM docker.io/alpine as git
RUN apk add git

FROM git as fetch
WORKDIR /repo
RUN git clone https://aur.archlinux.org/paru.git

FROM base as paru
USER builder
COPY --chown=builder:builder --from=fetch /repo/paru /repo/paru
RUN  --mount=type=tmpfs,target=/tmp \
  --mount=type=cache,target=/var/cache/pacman/pkg,source=/var/cache/pacman/pkg,from=base \
  --mount=type=cache,target=/home/builder/.rustup,uid=1000,gid=1000 \
  --mount=type=cache,target=/home/builder/.cargo,uid=1000,gid=1000 \
  sudo pacman -Sy --needed --noconfirm rustup && \
  rustup set profile minimal && \
  rustup default stable && \
  cd /repo/paru && makepkg -Ccsf --noconfirm

FROM build as final
COPY --chown=builder:builder --from=paru /home/builder/packages/paru-*.pkg.* /tmp/
RUN \
  find /tmp -type f -name paru-*.pkg.* -exec pacman -U --noconfirm {} \; && \
  mkdir -pv /var/cache/pacman/pkg && \
  paccache -r && \
  rm -rvf /var/cache/pacman/pkg/* /home/builder/packages/* /home/builder/sources/* \
  /home/builder/srcpackages/* /tmp/* && \
  pacman-key --delete pacman@localhost

USER builder

ENV XDG_CACHE_HOME=/home/builder/.cache
ENV XDG_CONFIG_HOME=/home/builder/.config
ENV XDG_DATA_HOME=/home/builder/.local/share
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
