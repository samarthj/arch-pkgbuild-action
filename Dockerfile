FROM archlinux:base-devel
LABEL maintainer="Sam <dev@samarthj.com>"

RUN \
  pacman-key --init && \
  pacman-key --populate archlinux && \
  pacman -Syu git --needed --noconfirm && \
  find / -name "*.pacnew" -exec rename .pacnew '' '{}' \; \
  useradd --create-home builder --shell /usr/bin/false && \
  mkdir -p /home/builder/work && \
  mkdir -p /home/builder/packages && \
  mkdir -pv /home/builder/.ssh && \
  touch /home/builder/.ssh/known_hosts && \
  chown -R builder:builder /home/builder && \
  echo "builder ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers

COPY ./entrypoint.sh /entrypoint.sh

USER builder

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
COPY ./makepkg.conf /home/builder/.makepkg.conf
COPY ./ssh_config /home/builder/.ssh/config

WORKDIR /home/builder/work
ENTRYPOINT ["/entrypoint.sh"]
