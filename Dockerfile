FROM archlinux:latest

# Privileged systemd sandbox for trying shared_dir without touching the host.
RUN pacman -Syu --noconfirm --needed \
      bash \
      coreutils \
      findutils \
      util-linux \
      systemd \
      acl \
      inotify-tools \
      sudo \
      which \
    && pacman -Scc --noconfirm

# Services and mounts that are noisy or useless inside a container.
RUN systemctl mask \
      systemd-remount-fs.service \
      systemd-firstboot.service \
      dev-hugepages.mount \
      sys-fs-fuse-connections.mount \
      systemd-logind.service \
      getty.target \
      console-getty.service \
      systemd-udev-trigger.service \
      systemd-udevd.service \
      systemd-random-seed.service 2>/dev/null || true

WORKDIR /opt/shared_dir
COPY shared_dir /opt/shared_dir/shared_dir
RUN chmod +x /opt/shared_dir/shared_dir \
    && ln -sf /opt/shared_dir/shared_dir /usr/local/bin/shared_dir

STOPSIGNAL SIGRTMIN+3
CMD ["/usr/lib/systemd/systemd", "--system"]
