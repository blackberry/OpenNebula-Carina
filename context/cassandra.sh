#!/bin/bash 

#SLAVE_ID=0
#NUM_SLAVES=4
#MOUNTLIST="5.62.70.23:/vol/data{10-32}"

getmount() {
    BASE=`echo $MOUNTLIST | awk -F '{' '{print $1}'`
    if [ -z "${SLAVE_ID+x}"  ]; then
        TOKEN=0
        START=`echo $MOUNTLIST | awk -F '{' '{print $2}' | awk -F '}' '{print $1}' | awk -F '-' '{START=$1;LAST=$2; print START}'`
        export MOUNT=`echo $BASE$START`
    else
         #START=`echo $MOUNTLIST | awk -F '[' '{print $2}' | awk -F ']' '{print $1}' | awk -F '-' '{START=$1;END=$2; print START}'`
         START=`echo $MOUNTLIST | awk -F '{' '{print $2}' | awk -F '}' '{print $1}' | awk -F '-' '{START=$1;LAST=$2; print START}'`
         MOUNTINDEX=`expr $START + $SLAVE_ID + 1`
         export MOUNT=`echo $BASE$MOUNTINDEX`
     fi
}

calctoken() {
    if [ -z "${SLAVE_ID+x}"  ]; then
         export TOKEN=0
    else
         NUM_SLAVES=`expr $NUM_SLAVES + 1`
         SLAVE_ID=`expr $SLAVE_ID + 1`
         export TOKEN=`echo "$SLAVE_ID*(2^127)/$NUM_SLAVES" | bc`
    fi 
}

reportstatus() {
    if [ -z "${SLAVE_ID+x}"  ]; then
        wget $CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=MASTER_INIT_DONE 2> /dev/null
        cp /mnt/context.sh /home/$DEFUSER/context.sh
        cp /mnt/cassandra.sh /home/$DEFUSER/cassandra.sh
    else
       wget $CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=SLAVE_"$SLAVE_ID"_INIT_DONE 2> /dev/null
   fi
}


setupconfig() {
    if grep -q /var/lib/cassandra /etc/fstab; then
      sed -i "s#^.*\( /var/lib/cassandra.*\)\$#${MOUNT}\1#" /etc/fstab
    else
      echo $MOUNT /var/lib/cassandra nfs _netdev,hard,tcp,intr,rsize=32768,wsize=32768,nodev,nosuid 0 0 >> /etc/fstab
    fi
    mount /var/lib/cassandra
    chown cassandra /var/lib/cassandra
    chgrp cassandra /var/lib/cassandra


    if [ -f /etc/cassandra/cassandra.yaml ]; then
       sed -i "s/\(listen_address:\).*/\1 $IP/" /etc/cassandra/cassandra.yaml
       sed -i "s/\(rpc_address:\).*/\1 $IP/" /etc/cassandra/cassandra.yaml
       if [ -z "${SEEDS+x}"  ]; then
           sed -i "s/\(seeds:\).*/\1 $IP/" /etc/cassandra/cassandra.yaml
       else
           sed -i "s/\(seeds:\).*/\1 $SEEDS/" /etc/cassandra/cassandra.yaml
        fi
        sed -i "s/\(initial_token:\).*/\1 $TOKEN/" /etc/cassandra/cassandra.yaml
    fi
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

if [ -z "${MOUNTLIST+x}"  ]; then
    wget $CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=MASTER_INIT_FAIL:MOUNTLIST_MISSING 2> /dev/null
    exit
fi

if [[ $OPER == "" ]]; then
    getmount
    calctoken
    echo "MOUNT is $MOUNT"
    echo "TOKEN is $TOKEN"
    reportstatus
    setupconfig
fi


if [[ $OPER == "add" ]]; then
   TARGET_HOST=$2
   TARGET_PORT=$3
   echo "Re-calcluate tokens and update nodes"
fi

if [[ $OPER ==  "delete" ]]; then
   TARGET_HOST=$2
   TARGET_PORT=$3
   echo "Re-calcluate tokens and update nodes"
fi




