#!/bin/bash

HOME=/home/$DEFUSER

if [ -f /mnt/context.sh ]; then
  . /mnt/context.sh
fi

cd $HOME
cnt=0
while [ $cnt -le 10 ]; do
      wget --retry-connrefused http://$JENKINS_MASTER:8080/jnlpJars/slave.jar
      if [ -f $HOME/slave.jar ]; then
          break
      fi
      cnt = `expr $cnt + 1`
      echo "Jenkins master not ready..retrying"
      sleep 30
done

java -jar slave.jar -jnlpUrl http://$JENKINS_MASTER:8080/computer/jenkins-slave$SLAVE_ID/slave-agent.jnlp 2> /tmp/jenkins.slave.log &
if [ $? -eq 0 ]; then
   wget $CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=SLAVE_"$SLAVE_ID"_INIT_DONE 2> /dev/null
else
   wget $CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=SLAVE_"$SLAVE_ID"_INIT_FAIL 2> /dev/null

fi

