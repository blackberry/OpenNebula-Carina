#!/bin/bash -x
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

cd /var/lib/one
mv opennebula-carina  opennebula-carina.old
tar xvf $1
mv ./opennebula-carina/oneenv.conf ./opennebula-carina/oneenv.conf.bak
cp ./opennebula-carina.old/global.rb  ./opennebula-carina/global.rb
SVCLIST="oneenv oneenv1 oneenv2"
PIDLIST=`ps aux | grep oneenvd | awk '{print $2}'`
for pid in $PIDLIST
do
    echo "Killing $pid"
    kill $pid
done
/bin/su - oneenv -c "/var/lib/one/opennebula-carina/misc/start-oneenvd-gs.sh"
for svc in $SVCLIST
do
    /bin/su - $svc -c "/var/lib/one/opennebula-carina/misc/start-oneenvd.sh"
done

