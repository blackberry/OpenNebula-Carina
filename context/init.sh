#!/bin/bash

HOME=/home/$DEFUSER



cd $HOME

/mnt/network.sh

# Only run this once per VM
if [ -f $HOME/.runonce ]; then
   exit
fi
touch $HOME/.runonce

echo "init.sh being invoked" >> /tmp/init.sh.log
if [ -f /mnt/context.sh ]; then
  . /mnt/context.sh
fi

if [ -f /mnt/authorized_keys ]; then
    mkdir -p /home/$DEFUSER/.ssh
    cp /mnt/authorized_keys /home/$DEFUSER/.ssh/
    chmod 0700 /home/$DEFUSER/.ssh/authorized_keys 
    chown $DEFUSER /home/$DEFUSER/.ssh/authorized_keys 
    chgrp $DEFUSER /home/$DEFUSER/.ssh/authorized_keys 
fi

# Turn off tomcat and postgress which are on by default in Ubuntu template
if [ -f /etc/init.d/tomcat6 ]; then
    /etc/init.d/tomcat6 stop
fi
if [ -f /etc/init.d/postgresql ]; then
   /etc/init.d/postgresql stop
fi


# Look for other file with .sh and execute them (exeept for init.sh and network.sh)
FILES=`ls /mnt/*.sh | grep -v -E '(init.sh|network.sh|context.sh)'`
for f in $FILES; do
    echo "Executing file " $f >> /tmp/init.sh.log
    $f
done





