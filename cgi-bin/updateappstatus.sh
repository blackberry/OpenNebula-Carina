#!/bin/sh -x
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

# This CGI script updates the status of the app environment. It is called from
# the VM contextualization scripts via wget
LOGFILE=/tmp/updateappstatus.log
echo "Content-type: text/html"
echo ""
echo ""
echo "Being called with query string" $QUERY_STRING >>  $LOGFILE
VMID=`echo "$QUERY_STRING" | grep -oE "(^|[?&])vmid=[0-9]+" | cut -f 2 -d "=" | head -n1`
ENVID=`echo "$QUERY_STRING" | grep -oE "(^|[?&])envid=[0-9]+" | cut -f 2 -d "=" | head -n1`
STATUS=`echo "$QUERY_STRING" | grep -oE "(^|[?&])status=[^&]+" | sed "s/%20/ /g" | cut -f 2 -d "="`
SERVICE_NAME=`echo "$QUERY_STRING" | grep -oE "(^|[?&])service=[^&]+" | sed "s/%20/ /g" | cut -f 2 -d "="`
echo "Updating SERVICE = " $SERVICE_NAME "VMID = " $VMID "Envid = " $ENVID " STATUS = " $STATUS   >> $LOGFILE

USER=root
DB_HOST=127.0.0.1
DB_PASS=
DB=opennebula

VMTABLE="vm_pool_ext"
APPENVTABLE="app_environment"
JOBSTABLE="jobs"


mysql -u$USER -h$DB_HOST --password=$DB_PASS -e "UPDATE $APPENVTABLE SET status=\"$STATUS\" WHERE envid=$ENVID "  $DB 2>> $LOGFILE


mysql -u$USER -h$DB_HOST --password=$DB_PASS -e "UPDATE $VMTABLE SET status=\"$STATUS\" WHERE vmid=$VMID "  $DB 2>>  $LOGFILE

