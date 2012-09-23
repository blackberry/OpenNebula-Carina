#!/bin/bash
# This is network contextualization script for ONE environments which 
# have to work with DHCP assigned IP addresses rather than letting ONE
# manage the IP addresses

if [ -f /mnt/context.sh ]; then
  . /mnt/context.sh
fi

# On CentOS6 network interface coming up as eth1 instead of eth0
ifconfig eth0 > /dev/null
if [ $? -eq 0 ]; then
   ETH=eth0
else
   ETH=eth1 
fi


#Set the hostname locally  and in DDNS
if [ -f /etc/redhat-release ]; then
     # For CentOS/RHEL
     echo "Setting hostname $TARGET_HOSTNAME on RHEL/CENTOS " >> /tmp/dhcpnetwork.sh.log
     sed -ri "s/localhost.localdomain/$TARGET_HOSTNAME/g" /etc/sysconfig/network
     hostname $TARGET_HOST_NAME

     mv /etc/sysconfig/network-scripts/ifcfg-$ETH /etc/sysconfig/network-scripts/ifcfg-$ETH.orig
     HWADDR=`ifconfig $ETH | awk '/HWaddr/ {print $5}'`
     echo "DEVICE=$ETH" >> /etc/sysconfig/network-scripts/ifcfg-$ETH
     echo "HWADDR=$HWADDR" >> /etc/sysconfig/network-scripts/ifcfg-$ETH
     echo "ONBOOT=\"yes\"" >> /etc/sysconfig/network-scripts/ifcfg-$ETH
     echo "BOOTPROTO=dhcp" >> /etc/sysconfig/network-scripts/ifcfg-$ETH
     echo "NM_CONTROLLED=\"no\"" >> /etc/sysconfig/network-scripts/ifcfg-$ETH
     echo "DHCP_HOSTNAME=$TARGET_HOSTNAME" >> /etc/sysconfig/network-scripts/ifcfg-$ETH
     service network restart
     hostname $TARGET_HOST_NAME
     HOSTNAME=`hostname`
     echo "Hostname is  " $HOSTNAME >> /tmp/dhcpnetwork.sh.log
else 
    if  [ -f /etc/HOSTNAME ]; then
        # SUSE
        mv /etc/HOSTNAME /etc/HOSTNAME.orig
        echo $TARGET_HOSTNAME > /etc/HOSTNAME
        service network restart

    else
        # Ubuntu
        mv /etc/hostname /etc/hostname.orig
        echo $TARGET_HOSTNAME > /etc/hostname
        /etc/init.d/hostname restart

        if [ -f /etc/dhcp3 ]; then
            DHCP_DIR=dhcp3
        else
            DHCP_DIR=dhcp
        fi

        cat /etc/$DHCP_DIR/dhclient.conf | sed -e "s/<hostname>/$TARGET_HOSTNAME/g" > /tmp/dhclient.conf

        mv /etc/$DHCP_DIR/dhclient.conf /etc/$DHCP_DIR/dhclient.conf.bak
        mv /tmp/dhclient.conf /etc/$DHCP_DIR/dhclient.conf 
        /etc/init.d/networking restart
     fi
fi

#Get the DHCP address and update on master
NEW_IP=`ifconfig "$ETH" | grep 'inet addr:'| grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $1}'`
if [ -z "$NEW_IP" ]; then
    echo "Trying to start DHCP client " >> /tmp/dhcpnetwork.sh.log
    /sbin/dhclient -v $ETH 
    sleep 5
    NEW_IP=`ifconfig "$ETH" | grep 'inet addr:'| grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $1}'`
fi

echo "Updating ONE DB: ENVID=" $ENVID "VMID=" $VMID " OLDIP=" $IP_PUBLIC " NEWIP=" $NEW_IP >> /tmp/dhcpnetwork.sh.log

wget $CARINA_IP/cgi-bin/updatevmstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&newip=$NEW_IP\&name=$TARGET_HOSTNAME 2> /dev/null

