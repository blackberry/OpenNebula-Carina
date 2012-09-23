#!/bin/bash
# This updates the IP address of the VM  assigned by dyamic DNS. This script
# will be invoked from CGI on the ONE master server and will be triggered via 
# wget from the contextualization script
LOGFILE=/tmp/updatevmstatus.log
echo "Content-type: text/html"
echo ""
echo ""
echo "Being called with query string" $QUERY_STRING >>  $LOGFILE
VMID=`echo "$QUERY_STRING" | grep -oE "(^|[?&])vmid=[0-9]+" | cut -f 2 -d "=" | head -n1`
ENVID=`echo "$QUERY_STRING" | grep -oE "(^|[?&])envid=[0-9]+" | cut -f 2 -d "=" | head -n1`
NEW_IP=`echo "$QUERY_STRING" | grep -oE "(^|[?&])newip=[^&]+" | sed "s/%20/ /g" | cut -f 2 -d "="`
HOSTNAME=`echo "$QUERY_STRING" | grep -oE "(^|[?&])name=[^&]+" | sed "s/%20/ /g" | cut -f 2 -d "="`
SERVICE_NAME=`echo "$QUERY_STRING" | grep -oE "(^|[?&])service=[^&]+" | sed "s/%20/ /g" | cut -f 2 -d "="`
echo "Updating VMID = " $VMID "Envid = " $ENVID "NEWIP = " $NEW_IP "HOSTNAME=" $HOSTNAME >> $LOGFILE

USER=root
DB_HOST=127.0.0.1
DB_PASS=
DB=opennebula

VMTABLE="vm_pool_ext"
APPENVTABLE="app_environment"
JOBSTABLE="jobs"


STATUS="NET_CONFIG_DONE"
mysql -u$USER -h$DB_HOST --password=$DB_PASS -e "UPDATE  $VMTABLE SET ipaddress='$NEW_IP',  hostname='$HOSTNAME', status='$STATUS'  WHERE vmid='$VMID'" $DB >> $LOGFILE

