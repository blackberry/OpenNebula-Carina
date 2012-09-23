#!/bin/sh

if [ -f /mnt/context.sh ]; then
  . /mnt/context.sh
fi

if [ ! -f /etc/init.d/tomcat6 ]; then
   yes | apt-get install tomcat6
fi

/etc/init.d/tomcat6 stop

CATALINA_HOME=/var/lib/tomcat6
cd $CATALINA_HOME/webapps
wget $CARINA_IP/downloads/$APP_PACKAGE

/etc/init.d/tomcat6 start

wget $CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=SLAVE_"$SLAVE_ID"_INIT_DONE 2> /dev/null

