#!/bin/bash 
# Install redis master on ubuntu

if [ -f /mnt/context.sh ]; then
  . /mnt/context.sh
fi

HOME=/home/$DEFUSER
REDIS_PACKAGE=redis2.6_build.tar

if [ -f $HOME/context.sh ]; then
    . $HOME/context.sh
fi


setup()
{
    cd $HOME
    wget $CARINA_IP/downloads/$REDIS_PACKAGE.gz
    if [ $? -ne 0 ]; then
        wget $CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=SLAVE_"$SLAVE_ID"_PKG_NOTFOUND 2> /dev/null
        exit
    fi

    gunzip $HOME/$REDIS_PACKAGE.gz
    tar xvf $HOME/$REDIS_PACKAGE 
    cd redis
    src/redis-server --daemonize yes --slaveof $REDIS_MASTER 6379
    
    if [ $? -eq 0 ]; then
        wget $CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=SLAVE_"$SLAVE_ID"_INIT_DONE 2> /dev/null
    else
        wget $CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=SLAVE_"$SLAVE_ID"_INIT_FAIL 2> /dev/null
    fi

}

if [[ $REDIS_MASTER == "" ]]; then
    wget $CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=SLAVE_"$SLAVE_ID"_CONFIG_FAIL 2> /dev/null
fi


setup








