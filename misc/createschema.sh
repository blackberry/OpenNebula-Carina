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

. ../etc/system.conf
USER=root
HOST=$DB_HOST
PASS=$DB_PASS
DB=opennebula
SVCTABLE="service"
VMTABLE="vm_pool_ext"
APPENVTABLE="app_environment"
JOBSTABLE="jobs"
DSTORETABLE="datastore"

if [ $# -eq 1 ]; then
     mysql -u$USER -h$HOST --password=$PASS -e "INSERT INTO $SVCTABLE (name) VALUES('$1')" $DB
     exit
fi

mysql -u$USER -h$HOST --password=$PASS -e "CREATE DATABASE if not exists opennebula"

mysql -u$USER -h$HOST --password=$PASS  -e "DROP TABLE IF EXISTS $VMTABLE" $DB
mysql -u$USER -h$HOST --password=$PASS  -e "CREATE TABLE $VMTABLE (vmid INT , PRIMARY KEY(vmid), envid INT, svcid INT, ipaddress VARCHAR(16), hostname VARCHAR(32),status VARCHAR(256))" $DB


mysql -u$USER -h$HOST --password=$PASS  -e "DROP TABLE IF EXISTS $APPENVTABLE" $DB
mysql -u$USER -h$HOST --password=$PASS  -e "CREATE TABLE $APPENVTABLE (envid INT AUTO_INCREMENT, PRIMARY KEY(envid), svcid INT, name VARCHAR(32), type INT, create_time TIMESTAMP, update_time TIMESTAMP,  master_template VARCHAR(16), slave_template VARCHAR(16), mastervmid INT, app_url VARCHAR(256), service_class VARCHAR(16), status VARCHAR(256), groupid INT, policy_status VARCHAR(256) )" $DB


mysql -u$USER -h$HOST --password=$PASS  -e "DROP TABLE IF EXISTS $JOBSTABLE" $DB
mysql -u$USER -h$HOST --password=$PASS  -e "CREATE TABLE $JOBSTABLE (jobid INT AUTO_INCREMENT, PRIMARY KEY(jobid), svcid INT, name VARCHAR(32), dependstr VARCHAR(256), type VARCHAR(16), envid INT, pid INT, predjobid INT, groupid INT, groupname VARCHAR(32), status VARCHAR(16), exitstatus INT, submit TIMESTAMP, start TIMESTAMP, end TIMESTAMP)" $DB

mysql -u$USER -h$HOST --password=$PASS  -e "DROP TABLE IF EXISTS $DSTORETABLE" $DB
mysql -u$USER -h$HOST --password=$PASS  -e "CREATE TABLE $DSTORETABLE (storeid INT AUTO_INCREMENT, PRIMARY KEY(storeid), name VARCHAR(32), status VARCHAR(16), envid INT, vmid INT, metainfo VARCHAR(256))" $DB

mysql -u$USER -h$HOST --password=$PASS  -e "DROP TABLE IF EXISTS $SVCTABLE" $DB

mysql -u$USER -h$HOST --password=$PASS  -e "CREATE TABLE $SVCTABLE (svcid INT AUTO_INCREMENT, PRIMARY KEY(svcid), name VARCHAR(32), config MEDIUMTEXT)" $DB
