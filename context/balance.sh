#!/bin/bash

setup () {
   cd /usr/sbin
   wget $CARINA_IP/downloads/balance
   chmod +x balance
   mkdir -m 01777 /var/run/balance
   /bin/su -c "balance -b $LOCAL_IP $BALANCE_PORT" $DEFUSER
   # Copy self to allow it to be invoked later to add/remove IPs via ssh
   cp /mnt/context.sh /home/$DEFUSER/context.sh
   cp /mnt/balance.sh /home/$DEFUSER/balance.sh
   # Report that setup is complete
   wget $CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=MASTER_INIT_DONE 2> /dev/null
}


add_ip() 
{

/usr/sbin/balance -b $LOCAL_IP $BALANCE_PORT  -c "create $TARGET_HOST $TARGET_PORT" 
/usr/sbin/balance -b $LOCAL_IP $BALANCE_PORT  -c "show"  > /tmp/balance.out
CHAN=`cat /tmp/balance.out | grep $TARGET_HOST | awk '{print $3}'`
/usr/sbin/balance -b $LOCAL_IP $BALANCE_PORT  -c "enable $CHAN"
}

delete_ip () 
{

/usr/sbin/balance -b $LOCAL_IP $BALANCE_PORT  -c "show"  > /tmp/balance.out
CHAN=`cat /tmp/balance.out | grep $TARGET_HOST | awk '{print $3}'`
/usr/sbin/balance -b $LOCAL_IP $BALANCE_PORT  -c "disable $CHAN"

}

show_ip ()
{
/usr/sbin/balance -b $LOCAL_IP -c show $BALANCE_PORT 
}

# During initial VM creation /mnt will exist
if [ -f /mnt/context.sh ]; then
  . /mnt/context.sh
fi

# Post creation operations will use this
if [ -f $HOME/context.sh ]; then
    . $HOME/context.sh
fi

OPER=$1

LOCAL_IP=`/sbin/ifconfig eth0 | grep 'inet addr:'| grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $1}'`

if [[ $OPER == "init" || $OPER == "" ]]; then
    setup
fi


if [[ $OPER == "add" ]]; then
   TARGET_HOST=$2
   TARGET_PORT=$3
   add_ip
fi

if [[ $OPER ==  "delete" ]]; then
   TARGET_HOST=$2
   TARGET_PORT=$3
   delete_ip
fi

if [[ $OPER == "show" ]]; then
   show_ip
fi
