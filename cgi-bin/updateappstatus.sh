#!/bin/sh -x
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

