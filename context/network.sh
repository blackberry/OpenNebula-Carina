#!/bin/bash

. /mnt/context.sh

cat >/etc/network/interfaces <<EOF
auto lo
iface lo inet loopback
EOF

ifconfig eth0 $IP netmask $NETMASK up
route add -net 0.0.0.0 gw $GATEWAY

hostname $HOSTNAME
hostname > /etc/hostname

echo "$IP $HOSTNAME" >> /etc/hosts

cat >/etc/resolv.conf <<EOF
search $DOMAIN
nameserver $NAMESERVERS
EOF

#Allow ssh traffic in
iptables -I INPUT -p tcp --dport 22 -j ACCEPT

wget $CARINA_IP/cgi-bin/updatevmstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&newip=$IP\&name=$HOSTNAME 2> /dev/null
