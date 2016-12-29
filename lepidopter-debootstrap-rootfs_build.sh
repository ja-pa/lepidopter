#!/bin/bash
set -xe

GIT_BUILD="$(git describe --tags)"
echo "LEPIDOPTER_BUILD=\"${GIT_BUILD}\"" > lepidopter-fh/etc/default/lepidopter
source lepidopter-fh/etc/default/lepidopter
source conf/lepidopter-image.conf

export distro=jessie
export LANG=C
export DEBIAN_FRONTEND=noninteractive 
export DEBCONF_NONINTERACTIVE_SEEN=true
export LC_ALL=C LANGUAGE=C LANG=C
export UPDATE_SELF=0 SKIP_BACKUP=1 SKIP_WARNING=1

ROOTDIR=$(mktemp -d)/rootfs
SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCH=armhf

# Add an apt repository with apt preferences
set_apt_sources() {
    SUITE="$1"
    PIN_PRIORITY="$2"
    COMPONENTS="main"
    cat <<EOF >> ${ROOTDIR}/etc/apt/sources.list
# Repository: $SUITE
deb $APT_MIRROR $SUITE $COMPONENTS
EOF
    if [ -n "$PIN_PRIORITY" ]
      then
        cat <<EOF > ${ROOTDIR}/etc/apt/preferences.d/${SUITE}.pref
Package: *
Pin: release n=$SUITE
Pin-Priority: $PIN_PRIORITY
EOF
    fi
}

# debootstrap first stage
debootstrap --arch=armhf --foreign ${DEB_RELEASE} ${ROOTDIR}
cp /usr/bin/qemu-arm-static ${ROOTDIR}/usr/bin/
cp /etc/resolv.conf ${ROOTDIR}/etc

# debootstrap second stage
chroot ${ROOTDIR} /debootstrap/debootstrap --second-stage

cat <<EOT > ${ROOTDIR}/etc/apt/sources.list
deb http://ftp.uk.debian.org/debian ${DEB_RELEASE} main contrib non-free
deb-src http://ftp.uk.debian.org/debian ${DEB_RELEASE} main contrib non-free
deb http://ftp.uk.debian.org/debian ${DEB_RELEASE}-updates main contrib non-free
deb-src http://ftp.uk.debian.org/debian ${DEB_RELEASE}-updates main contrib non-free
deb http://security.debian.org/debian-security ${DEB_RELEASE}/updates main contrib non-free
deb-src http://security.debian.org/debian-security ${DEB_RELEASE}/updates main contrib non-free
EOT

cat <<EOT > ${ROOTDIR}/etc/network/interfaces
# interfaces(5) file used by ifup(8) and ifdown(8)
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOT

# Update
chroot ${ROOTDIR} /usr/bin/apt-get update

# Create user
chroot ${ROOTDIR} /usr/sbin/adduser --disabled-password --gecos "" lepidopter

# Install packages
chroot ${ROOTDIR} /usr/bin/apt-get install -y sudo netbase ntp less openssh-server screen git-core binutils ca-certificates wget curl haveged lsb-release tcpdump localepurge fake-hwclock crda 

# Customize rootfs
echo "Add Debian ${DEB_RELEASE}-backports repository"
set_apt_sources ${DEB_RELEASE}-backports
echo "Add Debian stretch repository"
set_apt_sources stretch 100

# Create ooniprobe log directory
mkdir -p ${ROOTDIR}/var/log/ooni/

# Copy required scripts, cronjobs and config files to lepidopter
# Rsync Directory/file hieratchy to image
rsync -avp lepidopter-fh/ ${ROOTDIR}/

set +e #disable exit on error
# Install ooniprobe via setup script
chroot ${ROOTDIR} /setup-ooniprobe.sh
rm ${ROOTDIR}/setup-ooniprobe.sh

# OS configure script
chroot ${ROOTDIR} /configure.sh
rm ${ROOTDIR}/configure.sh

# Execute cleanup script
chroot ${ROOTDIR} /cleanup.sh
rm ${ROOTDIR}/cleanup.sh

# Remove SSH host keys and add regenerate_ssh_host_keys SYSV script
chroot ${ROOTDIR} /remove_ssh_host_keys.sh
rm ${ROOTDIR}/remove_ssh_host_keys.sh

# Remove motd file and create symlink for lepidopter dynamic MOTD
rm ${ROOTDIR}/etc/motd
chroot ${ROOTDIR} ln -s /var/run/motd /etc/motd

# Add (optional) pluggable transport support in tor config
cat conf/tor-pt.conf >> ${ROOTDIR}/etc/tor/torrc

# Remove unnecessary files
rm ${ROOTDIR}/usr/bin/qemu-arm-static
rm ${ROOTDIR}/etc/resolv.conf

cd ${ROOTDIR}/..
tar -cvpzf ${SCRIPTDIR}/images/lepidopter-${LEPIDOPTER_BUILD}-${ARCH}.tar.gz  --one-file-system .

#filesize
ls -h ${SCRIPTDIR}/images/lepidopter-${LEPIDOPTER_BUILD}-${ARCH}.tar.gz

echo "Customize script finished successfully."
exit 0
