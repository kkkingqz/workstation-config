#!/bin/sh
# Initrd, before systemd-hibernate-resume: when the resume device holds a
# hibernation image, take the T2 stack off (ws-t2-detach down). t2bce cannot
# stop the T2 for the restored kernel: it would keep its queues in memory
# the image overwrites. ws-t2-resume-up.service brings it back if the
# resume does not happen.
set -u

say() { echo "ws-t2-resume: $*"; }

resume="" offset=""
for arg in $(cat /proc/cmdline); do
    case "$arg" in
        resume=*) resume="${arg#resume=}" ;;
        resume_offset=*) offset="${arg#resume_offset=}" ;;
        noresume) exit 0 ;;
    esac
done
case "$resume" in
    UUID=*) dev="/dev/disk/by-uuid/${resume#UUID=}" ;;
    PARTUUID=*) dev="/dev/disk/by-partuuid/${resume#PARTUUID=}" ;;
    /dev/*) dev="$resume" ;;
    *) exit 0 ;;
esac

i=0
while [ ! -b "$dev" ] && [ $i -lt 100 ]; do
    sleep 0.1
    i=$((i + 1))
done
[ -b "$dev" ] || { say "no $dev"; exit 0; }

if [ -n "$offset" ]; then
    type="$(blkid -p -O $((offset * 4096)) -s TYPE -o value "$dev")"
else
    type="$(blkid -p -s TYPE -o value "$dev")"
fi
case "$type" in
    swsuspend|s1suspend|s2suspend|ulsuspend) ;;
    *) exit 0 ;;
esac

say "hibernation image on $dev: T2 stack off"
# No late load by udev; ws-t2-detach up loads it explicitly.
mkdir -p /etc/modprobe.d
echo "blacklist t2bce_core" >/etc/modprobe.d/ws-t2-resume.conf
udevadm settle -t 10
/usr/sbin/ws-t2-detach down
touch /run/ws-t2-detached
