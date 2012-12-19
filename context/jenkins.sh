#!/bin/bash
# -------------------------------------------------------------------------- #
# Copyright 2011-2012, Research In Motion (rim.com)                          #
#                                                                            #
# Licensed under the Apache License, Version 2.0 (the "License"); you may    #
# not use this file except in compliance with the License. You may obtain    #
# a copy of the License at                                                   #
#                                                                            #
# http://www.apache.org/licenses/LICENSE-2.0                                 #
#                                                                            #
# Unless required by applicable law or agreed to in writing, software        #
# distributed under the License is distributed on an "AS IS" BASIS,          #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
# See the License for the specific language governing permissions and        #
# limitations under the License.                                             #
#--------------------------------------------------------------------------- #

HOME=/home/$DEFUSER

setup() {
     wget http://$CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=APP_INSTALL_START 2> /dev/null
    if [ -f /etc/redhat-release ]; then
        wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins-ci.org/redhat/jenkins.repo
        rpm --import http://pkg.jenkins-ci.org/redhat/jenkins-ci.org.key
        yum install jenkins
    else
        wget -q -O - http://pkg.jenkins-ci.org/debian/jenkins-ci.org.key | sudo apt-key add -
        sh -c 'echo deb http://pkg.jenkins-ci.org/debian binary/ > /etc/apt/sources.list.d/jenkins.list'
        yes | apt-get update
        yes | apt-get install jenkins
    fi
    # Check if install successful (just check if init script present for jenkins
    if [ ! -f  /etc/init.d/jenkins ]; then
       echo "Installation failed ..aborting"
       wget http://$CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=MASTER_INIT_FAIL 2> /dev/null
       exit -1
    fi
  
    wget http://$CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=APP_INSTALL_DONE 2> /dev/null
    /etc/init.d/jenkins stop
    cd /var/lib/jenkins
    wget http://$CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=APP_CONFIG_START 2> /dev/null
    wget http://$CARINA_IP/downloads/jenkins.config.xml
    mv jenkins.config.xml config.xml
    wget http://$CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=APP_CONFIG_DONE 2> /dev/null
    cd $HOME
    wget http://$CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=APP_SVC_START 2> /dev/null
    /etc/init.d/jenkins start

    # Copy self to allow it to be invoked later to add/remove IPs via ssh
    cp /mnt/context.sh /home/$DEFUSER/context.sh
    cp /mnt/jenkins.sh /home/$DEFUSER/jenkins.sh

    # Report that setup is complete
    wget http://$CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=MASTER_INIT_DONE 2> /dev/null


}


#During initial VM creation /mnt will exist
if [ -f /mnt/context.sh ]; then
  . /mnt/context.sh
fi

# Post creation operations will use this
if [ -f /home/$DEFUSER/context.sh ]; then
    . /home/$DEFUSER/context.sh
fi

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



