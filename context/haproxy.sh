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

# For now we only support a single backend but in future this could be passed as
# context var
BACKEND=webfarm

check_last_status()
{
   if [ $? -ne 0 ]; then
       wget http://$CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=MASTER_INIT_FAIL 2> /dev/null
       exit -1
   fi
}

setup () {
   # Download and install the haproxy binary. Not needed if its already installed in image
   cd /usr/sbin
   wget http://$CARINA_IP/downloads/haproxy
   check_last_status
   chmod +x haproxy
   mkdir -p /usr/share/haproxy
   touch /var/run/haproxy-private.pid

   # Get a skeleton configuration file
   mkdir /etc/haproxy
   cd /etc/haproxy
   wget http://$CARINA_IP/downloads/haproxy.cfg
   sed -i "s/%BALANCE_PORT%/$BALANCE_PORT/g" /etc/haproxy/haproxy.cfg
   check_last_status
   # So non-root user can update this
   chmod 777 /etc/haproxy/haproxy.cfg

   # Add to sudoers so we can execute remotely when adding/removing nodes
   # without requiring password
   echo "%admin ALL=(ALL) NOPASSWD:/home/$DEFUSER/haproxyctl/haproxyctl" >> /etc/sudoers

   # Install the haproxyctl tool gotten from https://github.com/flores/haproxyctl.git
   cd /home/$DEFUSER
   wget http://$CARINA_IP/downloads/haproxyctl.tar
   check_last_status
   tar xvf /home/$DEFUSER/haproxyctl.tar
 
   # Start the haproxy - have to run as root
   /home/$DEFUSER/haproxyctl/haproxyctl start | grep -v error
   check_last_status

   # Copy self to allow it to be invoked later to add/remove IPs via ssh
   cp /mnt/context.sh /home/$DEFUSER/context.sh
   cp /mnt/haproxy.sh /home/$DEFUSER/haproxy.sh

   # Report that setup is complete
   wget http://$CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=MASTER_INIT_DONE 2> /dev/null
}


add_ip() 
{
    # Check if IP is already in the server pool and just enable it again
    grep $TARGET_HOST /etc/haproxy/haproxy.cfg
    if [ $? -eq 0 ]; then
        sudo /home/$DEFUSER/haproxyctl/haproxyctl enable server $BACKEND/$TARGET_HOST
    else 
        # Assume  the cfg has single backend with  'server' list at the end so just 
        # append new IP to it
        echo "server $TARGET_HOST $TARGET_HOST:$TARGET_PORT cookie $TARGET_HOST check inter 2000 rise 2 fall 5" >> /etc/haproxy/haproxy.cfg
        # Reload the configuration
        sudo /home/$DEFUSER/haproxyctl/haproxyctl reload
    fi
}

delete_ip () 
{
     # Just disable the IP instead of actually removing it from the cfg. If in the
     # future we add that IP back again, just renable it
     sudo /home/$DEFUSER/haproxyctl/haproxyctl disable server $BACKEND/$TARGET_HOST

}

show_ip ()
{
     sudo /home/$DEFUSER/haproxyctl/haproxyctl show stat 
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
