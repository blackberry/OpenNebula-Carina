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

# Install redis master on ubuntu
if [ -f /mnt/context.sh ]; then
  . /mnt/context.sh
fi

# Assume we have a pre-built package of binaries for redis 
REDIS_PACKAGE=redis2.6_build.tar

if [ -f $HOME/context.sh ]; then
    . $HOME/context.sh
else
     HOME=/home/$DEFUSER
fi


setup ()
{
    cd $HOME
    wget http://$CARINA_IP/downloads/$REDIS_PACKAGE.gz
    if [ $? -ne 0 ]; then
        wget http://$CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=MASTER_PKG_NOTFOUND 2> /dev/null
    fi
    gunzip $HOME/$REDIS_PACKAGE.gz
    tar xvf $HOME/$REDIS_PACKAGE 
    cd redis
    src/redis-server --daemonize yes --appendonly yes

    cp /mnt/context.sh /home/$DEFUSER/context.sh
    cp /mnt/redis.sh /home/$DEFUSER/redis.sh

    wget http://$CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=MASTER_INIT_DONE 2> /dev/null

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










