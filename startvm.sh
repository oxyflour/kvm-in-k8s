#!/bin/bash

# https://github.com/ennweb/docker-kvm/blob/master/startup.sh

# Create the kvm node (required --privileged)
if [ ! -e /dev/kvm ]; then
  set +e
  mknod /dev/kvm c 10 $(grep '\<kvm\>' /proc/misc | cut -f 1 -d' ')
  set -e
fi

IFACE=eth0
TAP_IFACE=tap0
IP=`ip addr show dev $IFACE | grep "inet " | awk '{print $2}' | cut -f1 -d/`
NAMESERVER=`grep nameserver /etc/resolv.conf | cut -f2 -d ' '`
NAMESERVERS=`echo ${NAMESERVER[*]} | sed "s/ /,/g"`
NETWORK_IP="${NETWORK_IP:-$(echo 172.$((RANDOM%(31-16+1)+16)).$((RANDOM%256)).$((RANDOM%(254-2+1)+2)))}"
NETWORK_SUB=`echo $NETWORK_IP | cut -f1,2,3 -d\.`
NETWORK_GW="${NETWORK_GW:-$(echo ${NETWORK_SUB}.1)}"
tunctl -t $TAP_IFACE
dnsmasq --user=root \
  --dhcp-range=$NETWORK_IP,$NETWORK_IP \
  --dhcp-option=option:router,$NETWORK_GW \
  --dhcp-option=option:dns-server,$NAMESERVERS
ifconfig $TAP_IFACE $NETWORK_GW up
iptables -t nat -A POSTROUTING -o $IFACE -j MASQUERADE
iptables -I FORWARD 1 -i $TAP_IFACE -j ACCEPT
iptables -I FORWARD 1 -o $TAP_IFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -t nat -A PREROUTING -p tcp -d $IP ! --dport `expr 5900 + $VNC_ID` -j DNAT --to-destination $NETWORK_IP
iptables -t nat -A PREROUTING -p udp -d $IP -j DNAT --to-destination $NETWORK_IP
iptables -t nat -A PREROUTING -p icmp -d $IP -j DNAT --to-destination $NETWORK_IP
FLAGS_NETWORK="-netdev tap,id=net0,ifname=tap0,vhost=on,script=no,downscript=no -device virtio-net-pci,netdev=net0"

mkdir /root/iso
cat > /root/iso/startup.bat << EOF
EOF
genisoimage -o /root/image.iso /root/iso

wget $QCOW2_URL -q -O /root/image.qcow2 && \
qemu-system-x86_64 \
  -enable-kvm \
  -drive file=/root/image.qcow2,format=qcow2,if=none,id=drive-virtio-disk0 \
  -device virtio-blk-pci,scsi=off,drive=drive-virtio-disk0,id=virtio-disk0 \
  $FLAGS_NETWORK \
  -cdrom /root/image.iso \
  -vnc 0.0.0.0:0
