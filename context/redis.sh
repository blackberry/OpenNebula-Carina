#!/bin/bash 
# Install redis master on ubuntu
if [ -f /mnt/context.sh ]; then
  . /mnt/context.sh
fi

REDIS_PACKAGE=redis2.6_build.tar

if [ -f $HOME/context.sh ]; then
    . $HOME/context.sh
else
     HOME=/home/$DEFUSER
fi


setup ()
{
    cd $HOME
    wget $CARINA_IP/downloads/$REDIS_PACKAGE.gz
    if [ $? -ne 0 ]; then
        wget $CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=MASTER_PKG_NOTFOUND 2> /dev/null
    fi
    gunzip $HOME/$REDIS_PACKAGE.gz
    tar xvf $HOME/$REDIS_PACKAGE 
    cd redis
    src/redis-server --daemonize yes --appendonly yes

    cp /mnt/context.sh /home/$DEFUSER/context.sh
    cp /mnt/redis.sh /home/$DEFUSER/redis.sh

    wget $CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=MASTER_INIT_DONE 2> /dev/null

}

OPER=$1

if [[ $OPER == "init" || $OPER == "" ]]; then
    setup
fi


if [[ $OPER == "add" ]]; then
   TARGET_HOST=$2
fi

if [[ $OPER == "delete" ]]; then
   TARGET_HOST=$2
fi










