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

LOGFILE=/tmp/hbasemaster.log

if [ -f /mnt/context.sh ]; then
  . /mnt/context.sh
  HOME=/home/$DEFUSER
else
   . $HOME/context.sh
fi



setupmaster () {
    echo "Starting HBase master install "  >>  $LOGFILE
    wget $CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=APP_INSTALL_START 2> /dev/null

    yes | apt-get install curl 
    curl -s http://archive.cloudera.com/debian/archive.key | sudo apt-key add -

    # Install Java
    cd /usr/local/share
    wget $CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=JDK_INSTALL_START 2> /dev/null
    wget $CARINA_IP/downloads/jdk-6u27-linux-x64.bin  
    chmod +x ./jdk-6u27-linux-x64.bin
    yes | ./jdk-6u27-linux-x64.bin

cat >> /etc/apt/sources.list.d/cloudera.list << EOF
deb http://archive.cloudera.com/debian maverick-cdh3 contrib
deb-src  http://archive.cloudera.com/debian maverick-cdh3 contrib
EOF

    wget $CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=HBASE_INSTALL_START 2> /dev/null
    apt-get update
    yes | apt-get install hadoop-0.20-namenode 
    yes | apt-get install hadoop-0.20-datanode 
    yes | apt-get install hadoop-0.20-secondarynamenode 
    yes | apt-get install hadoop-hbase-master
    yes | apt-get install hadoop-hbase-regionserver 


cat >> /etc/default/hadoop-hbase  << EOF
export JAVA_HOME=/usr/local/share/jdk1.6.0_27/
export PATH=$JAVA_HOME/bin:$PATH
EOF

    wget $CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=HBASE_CONFIG_START 2> /dev/null
    mkdir -p /var/lib/hadoop-0.20/cache/hadoop/dfs/name
    cd /var/lib
    chgrp -R hadoop hadoop-0.20
    cd /var/lib/hadoop-0.20/cache/hadoop/
    chown -R hdfs  dfs

    mkdir -p /var/lib/hadoop-0.20/cache/hdfs/dfs/data
    chgrp -R hdfs /var/lib/hadoop-0.20/cache/hdfs/
    chown -R hdfs /var/lib/hadoop-0.20/cache/hdfs/


    mkdir -p /var/lib/hadoop-0.20/cache/hdfs/dfs/namesecondary
    cd /var/lib/hadoop-0.20/cache
    chown -R hdfs hdfs
    chgrp -R hdfs hdfs



cd $HADOOP_CONF
mv core-site.xml core-site.xml.bak
mv hdfs-site.xml hdfs-site.xml.bak
wget $CARINA_IP/downloads/core-site.xml 
wget $CARINA_IP/downloads/hdfs-site.xml 
sed -i -e "s/%HBASE_MASTER_NAME/$MASTER/g" core-site.xml 

cd $HBASE_CONF
mv hbase-site.xml  hbase-site.xml.bak
wget $CARINA_IP/downloads/hbase-site.xml 
sed -i -e "s/%HBASE_MASTER_NAME/$MASTER/g" hbase-site.xml 

# To allow slaves to download my config files (assume web server installed)
DOWNLOAD_DIR=/var/www/downloads
mkdir -p $DOWNLOAD_DIR 
ln -s $HADOOP_CONF/core-site.xml  $DOWNLOAD_DIR/core-site.xml
ln -s $HADOOP_CONF/hdfs-site.xml  $DOWNLOAD_DIR/hdfs-site.xml
ln -s $HBASE_CONF/hbase-site.xml  $DOWNLOAD_DIR/hbase-site.xml


echo $MASTER > /usr/lib/hadoop-0.20/conf/masters
echo $MASTER > /usr/lib/hadoop-0.20/conf/slaves
echo $MASTER > /usr/lib/hbase/conf/regionservers

# Have to make slaves file writeable by default VM admin ($DEFUSER)
# so slaves can be added at run time
chmod 0666 /usr/lib/hadoop-0.20/conf/slaves
chmod 0666 /usr/lib/hbase/conf/regionservers


wget $CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=HBASE_DBFORMAT_START 2> /dev/null
# Format the namenode
/bin/su hdfs -c "echo Y | /usr/lib/hadoop/bin/hadoop namenode -format"

# Bring up the HDFS layer
wget $CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=HADOOP_SVCS_START 2> /dev/null
/usr/lib/zookeeper/bin/zkServer.sh start
/etc/init.d/hadoop-0.20-datanode start
/etc/init.d/hadoop-0.20-namenode start
/etc/init.d/hadoop-0.20-secondarynamenode start

# A little delay to make sure HDFS comes up ok
sleep 30
# Set up directories/permissiosn for HBase 
/bin/su hdfs -c "/usr/lib/hadoop/bin/hadoop fs -mkdir /hbase"
/bin/su hdfs -c "/usr/lib/hadoop/bin/hadoop fs -chown hbase /hbase"
wget $CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=HBASE_SVCS_START 2> /dev/null

/etc/init.d/hadoop-hbase-regionserver start
/etc/init.d/hadoop-hbase-master start

# Copy self to allow it to be invoked later to add/remove IPs via ssh
cp /mnt/context.sh /home/$DEFUSER/context.sh
cp /mnt/hbasemaster.sh /home/$DEFUSER/hbasemaster.sh

wget $CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=MASTER_INIT_DONE 2> /dev/null



}

add_slave() {
   echo $SLAVE_IP >> $HADOOP_CONF/slaves
   echo $SLAVE_IP >> $HBASE_CONF/regionservers
}

delete_slave() {
   echo "Delete slave"
   # Tell HDFS to exclude the node
   echo $1 >> $HADOOP_CONF/excludes
   hadoop dfsadmin -refershNodes
   # Wait for node to be decomissioned
   cnt=10
   while [ $cnt -ge 0 ]; do
       STATUS=`hadoop dfsadmin -report | grep  -A 1 $1 | grep Status | awk '{print $4}'`
       if [[ $STATUS != "Decomissioned" ]]; then
           echo "Waiting for node to be decomissioned"
           sleep 30
       else
           break
       fi
       cnt=`expr $cnt - 1`
   done
   # Remove the slave from the  excludes, slaves and regionservers file
   grep -Ev "$1" $HADOOP_CONF/excludes > $HADOOP_CONF/excludes.new
   mv $HADOOP_CONF/excludes.new $HADOOP_CONF/excludes
   grep -Ev "$1" $HADOOP_CONF/slaves > $HADOOP_CONF/slaves.new
   mv $HADOOP_CONF/slaves.new  $HADOOP_CONF/slaves
   grep -Ev "$1" $HBASE_CONF/regionservers > $HBASE_CONF/regionservers.new
   mv $HBASE_CONF/regionservers.new  $HBASE_CONF/regionservers
   # Refersh the nodes
   hadoop dfsadmin -refershNodes
    
}


MASTER=`hostname`
HADOOP_CONF=/usr/lib/hadoop-0.20/conf
HBASE_CONF=/usr/lib/hbase/conf
OPER=$1

if [[ $OPER == "init" || $OPER == "" ]]; then
   setupmaster
fi


if [[ $OPER == "add" ]]; then
   SLAVE_IP=$2
   add_slave
fi

if [[ $OPER ==  "delete" ]]; then
   SLAVE_IP=$3
   delete_slave
fi





