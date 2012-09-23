#!/bin/sh
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

