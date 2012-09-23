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

# Not much  to install  as CloudFoundry is in template. However we will have to set 
# up configuration of CF.
HOME=/home/rimadmin
CF_INSTALL_LOC=/opt/cloudfoundry-server/vcap

if [ -f /mnt/context.sh ]; then
  . /mnt/context.sh
fi

echo "CloudFoundry DEA install"
# The CF template starts everyting by default
/etc/init.d/cloudfoundry-server stop
sleep 10
sed -e "s/mbus: http:\/\/127.0.0.1:4222/mbus: http:\/\/$CLOUDFOUNDRY_CONTROLLER:4222/" $CF_INSTALL_LOC/dea/config/dea.yml > $CF_INSTALL_LOC/dea/config/dea.yml.new
mv $CF_INSTALL_LOC/dea/config/dea.yml $CF_INSTALL_LOC/dea/config/dea.yml.bak
mv $CF_INSTALL_LOC/dea/config/dea.yml.new $CF_INSTALL_LOC/dea/config/dea.yml
/etc/init.d/cloudfoundry-server-dea start
