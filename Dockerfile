FROM ghcr.io/greyltc/archlinux-aur:paru
LABEL maintainer="Sam <dev@samarthj.com>"

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
  echo "builder ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers && \
  pacman -Syyu --needed --noconfirm \
  pacman-mirrorlist openssl openssh git gzip gnupg base-devel zstd

USER builder

ENV XDG_CACHE_HOME=/home/builder/.cache
ENV XDG_CONFIG_HOME=/home/builder/.config
ENV XDG_DATA_HOME=/home/builder/.local/share
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

COPY ./entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
