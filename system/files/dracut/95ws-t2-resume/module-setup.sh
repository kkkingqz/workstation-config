#!/bin/bash
# dracut module ws-t2-resume (helpws suspend, Hibernate): in the initrd of a
# resume boot, the T2 stack (t2bce, in the initrd for the internal keyboard)
# off before systemd-hibernate-resume loads the image, and on again if the
# resume did not happen. Included by /etc/dracut.conf.d/ws-hibernate.conf.

# shellcheck disable=SC2154 # moddir, initdir, systemdsystemunitdir, SYSTEMCTL: set by dracut
check() {
    return 255                     # only when asked for (add_dracutmodules)
}

depends() {
    echo systemd resume
}

install() {
    inst_script /usr/local/sbin/ws-t2-detach /usr/sbin/ws-t2-detach
    inst_script "$moddir/ws-t2-resume.sh" /usr/sbin/ws-t2-resume
    inst_multiple blkid cat mkdir modprobe readlink rm rmmod sleep touch udevadm
    inst_simple "$moddir/ws-t2-resume.service" "$systemdsystemunitdir/ws-t2-resume.service"
    inst_simple "$moddir/ws-t2-resume-up.service" "$systemdsystemunitdir/ws-t2-resume-up.service"
    $SYSTEMCTL -q --root "$initdir" enable ws-t2-resume.service ws-t2-resume-up.service
}
