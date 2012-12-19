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

if [ -f /mnt/context.sh ]; then
  . /mnt/context.sh
fi

echo "Starting HBase slave install HBASE_MASTER=" $HBASE_MASTER  >> /tmp/hbaseslavesh.log
#HBASE_MASTER=10.135.42.126

yes | apt-get install curl 
curl -s http://archive.cloudera.com/debian/archive.key | sudo apt-key add -

cat >> /etc/apt/sources.list.d/cloudera.list << EOF
deb http://archive.cloudera.com/debian maverick-cdh3 contrib
deb-src  http://archive.cloudera.com/debian maverick-cdh3 contrib
EOF

apt-get update
yes | apt-get install hadoop-0.20-datanode 
yes | apt-get install hadoop-hbase-regionserver 

cd /usr/local/share
wget http://$CARINA_IP/downloads/jdk-6u27-linux-x64.bin  
chmod +x ./jdk-6u27-linux-x64.bin
yes | ./jdk-6u27-linux-x64.bin

cat >> /etc/default/hadoop-hbase  << EOF
export JAVA_HOME=/usr/local/share/jdk1.6.0_27/
export PATH=$JAVA_HOME/bin:$PATH
EOF

mkdir -p /var/lib/hadoop-0.20/cache/hdfs/dfs/data
chgrp -R hdfs /var/lib/hadoop-0.20/cache/hdfs/
chown -R hdfs /var/lib/hadoop-0.20/cache/hdfs/

cd /usr/lib/hadoop-0.20/conf
mv core-site.xml core-site.xml.bak
mv hdfs-site.xml hdfs-site.xml.bak
wget $HBASE_MASTER/downloads/core-site.xml 
wget $HBASE_MASTER/downloads/hdfs-site.xml 
cd /usr/lib/hbase/conf
mv hbase-site.xml  hbase-site.xml.bak
wget $HBASE_MASTER/downloads/hbase-site.xml 


/etc/init.d/hadoop-0.20-datanode start
/etc/init.d/hadoop-hbase-regionserver start






