#!/bin/bash -x
PATH=$PATH:/usr/sbin/
HOME=/home
WWWDIR=/var/www/repo

if [ $# -ne 3 ]; then
   echo "Usage: `basename $0` service_name service_port zone"
   exit -1
fi
useradd -d $HOME/$1 -m $1
if [ $? -ne 0 ]; then
   echo "Failed to create user"
   exit -1
fi
mkdir $HOME/$1/logs $HOME/$1/work $HOME/$1/conf $HOME/$1/vm
chown $1 $HOME/$1/logs $HOME/$1/work $HOME/$1/conf $HOME/$1/vm
chgrp $1 $HOME/$1/logs $HOME/$1/work $HOME/$1/conf $HOME/$1/vm
cp /var/lib/one/opennebula-carina/etc/oneenv.conf.bak $HOME/$1/conf/oneenv.conf
sed -i "s/SERVICE_NAME=[A-Za-z0-9_]*/SERVICE_NAME=$1/" $HOME/$1/conf/oneenv.conf
sed -i "s/LOAD_VM_INFO=[a-z]*/LOAD_VM_INFO=false/" $HOME/$1/conf/oneenv.conf
sed -i "s/CARINA_PORT=[0-9]*/CARINA_PORT=$2/" $HOME/$1/conf/oneenv.conf
sed -i "s/ZONE=[A-Za-z]*/ZONE=$3/" $HOME/$1/conf/oneenv.conf
chown $1 $HOME/$1/conf/oneenv.conf
chgrp $1 $HOME/$1/conf/oneenv.conf
$ONE_LOCATION/opennebula-carina/misc/createschema.sh $1
mkdir $WWWDIR/$1
chown $1 $WWWDIR/$1
chgrp $1 $WWWDIR/$1
su $1 -c "mkdir $WWWDIR/$1/context"
su $1 -c "cp /var/lib/one/opennebula-carina/context/*  $WWWDIR/$1/context"
su $1 -c "cp /var/lib/one/opennebula-carina/etc/config.rb $HOME/$1/config.rb"
su $1 -c "cp /var/lib/one/opennebula-carina/templates/*  $HOME/$1/vm/"
su $1 -c "ssh-keygen -t rsa -N \"\" -f $HOME/$1/.ssh/id_rsa"
su $1 -c "cp $HOME/$1/.ssh/id_rsa.pub $WWWDIR/$1/context/authorized_keys"

