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
CF_INSTALL_LOC=/opt/cloudfoundry-server/vcap

if [ -f /mnt/context.sh ]; then
  . /mnt/context.sh
fi

# Not much  to install  as CloudFoundry is in template. However we will have 
# to set up configuration of CF.
setup() {

    # Copy self to allow it to be invoked later to add/remove IPs via ssh
    cp /mnt/context.sh $HOME/context.sh
    cp /mnt/cloudfoundry.sh $HOME/cloudfoundry.sh

    LOCAL_IP=`/sbin/ifconfig eth0 | grep 'inet addr:'| grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $1}'`
    MYHOSTNAME=`hostname`
    /etc/init.d/cloudfoundry-server stop
    sleep 10
    sed -e "s/127.0.0.1/$LOCAL_IP/; s/api.vcap.me/$MYHOSTNAME/" $CF_INSTALL_LOC/cloud_controller/config/cloud_controller.yml > $CF_INSTALL_LOC/cloud_controller/config/cloud_controller.yml.new
    mv $CF_INSTALL_LOC/cloud_controller/config/cloud_controller.yml $CF_INSTALL_LOC/cloud_controller/config/cloud_controller.yml.bak
    mv $CF_INSTALL_LOC/cloud_controller/config/cloud_controller.yml.new $CF_INSTALL_LOC/cloud_controller/config/cloud_controller.yml

    /etc/init.d/cloudfoundry-server start


    # Report that setup is complete
    wget http://$CARINA_IP/cgi-bin/updateappstatus.sh?vmid=$VMID\&envid=$ENVID\&status=MASTER_INIT_DONE 2> /dev/null
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


