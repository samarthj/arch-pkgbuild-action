FROM archlinux:base-devel
LABEL maintainer="Sam <dev@samarthj.com>"

COPY ./ssh_config /home/builder/.ssh/config
COPY ./entrypoint.sh /entrypoint.sh

RUN \
  useradd --create-home builder --shell /usr/bin/false && \
  mkdir -pv /home/builder/.ssh && \
  touch /home/builder/.ssh/known_hosts && \
  chown -R builder:builder /home/builder && \
  echo "builder ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers

USER builder
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN \
  pacman-key --init && \
  pacman-key --populate archlinux && \
  pacman -Syu git --needed --noconfirm && \
  find / -name "*.pacnew" -exec rename .pacnew '' '{}' \;

ENTRYPOINT ["/entrypoint.sh"]
