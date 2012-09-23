#!/bin/bash
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
