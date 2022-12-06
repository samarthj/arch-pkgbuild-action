FROM ghcr.io/greyltc/archlinux-aur:paru
LABEL maintainer="Sam <dev@samarthj.com>"
LABEL org.opencontainers.image.source="https://github.com/samarthj/arch-pkgbuild-action"

COPY ./ssh_config /home/builder/.ssh/config
COPY ./.makepkg.conf /home/builder/.makepkg.conf
COPY ./pacman.conf /etc/pacman.conf

RUN \
  useradd builder --shell /usr/bin/false && \
  mkdir -pv /home/builder/.ssh && \
  mkdir -pv /home/builder/.config && \
  mkdir -pv /home/builder/.cache && \
  mkdir -pv /home/builder/.local/share && \
  mkdir -pv /home/builder/packages && \
  mkdir -pv /home/builder/sources && \
  chown -R builder:builder /home/builder && \
  echo "builder ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers

RUN \
  pacman -Sy --noconfirm archlinux-keyring && \
  pacman-key --init && pacman-key --populate archlinux && \
  pacman -Syu --needed --noconfirm --asexplicit \
  pacman-mirrorlist openssl openssl-1.1 openssh git gzip gnupg glibc base-devel zstd pacman-contrib && \
  paccache -r && \
  rm -rvf /var/cache/pacman/pkg/* /home/builder/packages/* && \
  pacman-key --delete pacman@localhost

USER builder

ENV XDG_CACHE_HOME=/home/builder/.cache
ENV XDG_CONFIG_HOME=/home/builder/.config
ENV XDG_DATA_HOME=/home/builder/.local/share
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
