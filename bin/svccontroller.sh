#!/bin/bash -x
# -------------------------------------------------------------------------- #
# Copyright 2002-2012, Research In Motion Limited                            #
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

getsvcid() {
  ID=`mysql -u$USER -h$HOST --password=$PASS -e "select svcid from $SVCTABLE where name='$1'" $DB | awk 'NR>1{print $1}'`
  echo $ID
}

getvmip() {
   if [[ $USE_DDNS == "FALSE" ]]; then
     IP=`onecmd -e $ENDPOINT onevm show $1  | grep IP | tr '=' ' ' | tr  ',' ' ' | awk 'END {print $2}'`
     echo $IP
     return
   fi

   cnt=0
   while [ $cnt -le 5 ]; do
       IP=`mysql -u$USER -h$HOST --password=$PASS -e "select * from $VMTABLE where vmid=$1" $DB | grep $1 | awk '{print $4}'`
       if [[ $IP != "NULL" ]]; then
          echo $IP
          return
       else
          sleep 30
       fi
       cnt=`expr $cnt + 1`
   done
   return 
}

waitvmstarted() {
    while true; do
       CMDOUT=`onecmd -e $ENDPOINT onevm show  $1 | grep STATE | awk '{print $3}'` 
       STATE1=`echo $CMDOUT | awk '{print $1}'` 
       STATE2=`echo $CMDOUT | awk '{print $2}'` 
       if [[ $STATE1 == "FAILED" ]]; then
           CMDOUT=`onecmd -e $ENDPOINT onevm show  $1 | grep MESSAGE | cut -d'=' -f2 | sed "s/\"//g"`

           updateappenvdb $2 $1  "$3_CREATE_FAIL:$CMDOUT"
           echo "VM $1 is in FAILED state ..aborting"
           exit -1 
       fi
       if [[ $STATE2 == "RUNNING" ]]; then
           echo "VM $1 is RUNNING ..return"
           return 0
       fi
       echo "VM $1 state is $STATE1 $STATE2 . Retrying...."
       sleep 30
    done
}

waitmasterappinit() {
    while true; do
        STATUS=`mysql -u$USER -h$HOST --password=$PASS -e "SELECT status from $APPENVTABLE where envid=$1" $DB`
        STATUS=`echo $STATUS | awk '{print $2}'`
        if [[ $STATUS == "MASTER_INIT_DONE" ]]; then
           echo "Master VM for Env $1 is initialized ..return"
           return 0
        fi
        if [[ $STATUS == "MASTER_INIT_FAIL" ]]; then
           echo "Master VM for Env $1 failed initialization ..Check the contextualization log files on the VM ..aborting"
           exit -1
        fi
        echo "Env $1 not initialized . Retrying...."
        sleep 30
    done
}

insertvmpooldb() {
    mysql -u$USER -h$HOST --password=$PASS -e "INSERT INTO  $VMTABLE (vmid,envid,status, svcid)  VALUES('$1', '$2', '$3', '$SVCID') "  $DB

}

updateappenvdb() {
    mysql -u$USER -h$HOST --password=$PASS -e "UPDATE  $APPENVTABLE SET mastervmid=$2 , status=\"$3\" WHERE envid=$1" $DB

}

updateappenvpolicystatusdb() {
    mysql -u$USER -h$HOST --password=$PASS -e "UPDATE  $APPENVTABLE SET policy_status=\"$2\" WHERE envid=$1" $DB
}

updateappurl() {
    mysql -u$USER -h$HOST --password=$PASS -e "UPDATE  $APPENVTABLE SET app_url=\"$2\" WHERE envid=$1" $DB
}

getnextslaveindex() {
     COUNT=`mysql -u$USER -h$HOST --password=$PASS -e "select * from $VMTABLE where envid=$1" $DB | wc -l`
     COUNT=`expr $COUNT - 2`
     echo $COUNT
}

getlastslavevm()  {
     LASTVM=`mysql -u$USER -h$HOST --password=$PASS   -e "select vmid,ipaddress from $VMTABLE where envid=$1 ORDER BY vmid DESC  LIMIT 1" $DB | awk 'NR>1 {print $0}' `
     echo $LASTVM
}

getmastervmip() {
    MASTERID=`mysql -u$USER -h$HOST --password=$PASS -e "SELECT mastervmid from $APPENVTABLE WHERE envid=$1" $DB`
    MASTERID=`echo $MASTERID | awk '{print $2}'`
    MASTERIP=$(getvmip $MASTERID)
    echo $MASTERIP
}

getmastervm() {
    MASTERID=`mysql -u$USER -h$HOST --password=$PASS -e "SELECT mastervmid from $APPENVTABLE WHERE envid=$1" $DB`
    MASTERID=`echo $MASTERID | awk '{print $2}'`
    MASTERIP=$(getvmip $MASTERID)
    echo $MASTERID " " $MASTERIP
}


getallenvvmids() {
    IDLIST=`mysql -u$USER -h$HOST --password=$PASS  -e "select vmid from $VMTABLE where envid=$1" $DB | awk 'NR> 1 {print $1}' `
    echo $IDLIST
}

getallenvvmips() {
    IPLIST=`mysql -u$USER -h$HOST --password=$PASS  -e "select ipaddress from $VMTABLE where envid=$1" $DB | awk 'NR> 1 {print $1}' `

    echo $IPLIST
}

getvmipfromdb() {
    VMIP=`mysql -u$USER -h$HOST --password=$PASS  -e "select ipaddress from $VMTABLE where vmid=$1" $DB | awk 'NR> 1 {print $1}' `
    echo $VMIP
}


deleteenvvm() {
    mysql -u$USER -h$HOST --password=$PASS -e "DELETE from $VMTABLE where envid=$1" $DB

    mysql -u$USER -h$HOST --password=$PASS -e "DELETE from $APPENVTABLE where envid=$1" $DB
}

deletevm() {
    mysql -u$USER -h$HOST --password=$PASS -e "DELETE from $VMTABLE where vmid=$1" $DB
}


checknumeric() {
   if [[ $1 == ?(+|-)+([0-9]) ]]; then
       echo 0
   else
       echo 1
   fi
}

# Adds on sections to Vm template before creating the VM
insertvmtemplatevars() {
    if  [ -n "${PLACEMENT_POLICY+x}" ]; then
        if  [[ $PLACEMENT_POLICY == "pack" ]]; then
            echo "RANK=RUNNING_VMS" >> $1
        fi
        if  [[ $PLACEMENT_POLICY == "stripe" ]]; then
            echo "RANK=\"-RUNNING_VMS\"" >> $1
        fi
        if  [[ $PLACEMENT_POLICY == "load" ]]; then
            echo "RANK=FREECPU" >> $1
        fi
    fi
}

createmaster() {
    ENVID=$1
    # Add the environments dependency to MASTER_CONTEXT_VAR
    if [ -n "${ENVDEP+x}" ]; then
        MASTER_CONTEXT_VAR=`echo $MASTER_CONTEXT_VAR $ENVDEP`
    fi
    MASTER_CONTEXT_VAR=`echo $MASTER_CONTEXT_VAR | sed -e "s/%NUM_SLAVES%/$NUM_SLAVES/g;"`

    # Check if  master template is there
    if [ ! -f $MASTER_TEMPLATE ]; then
        updateappenvdb $ENVID "-1"  "MASTER_CREATE_FAIL: Template $MASTER_TEMPLATE not found"
        echo "ABORT"
        return 1
    fi

    # Create the master 
    sed -e "s/%ENVID%/$ENVID/g; s/%SERVICE_NAME%/$SERVICE_NAME/g; s/%CARINA_IP%/$CARINA_IP/g; s/%NAME%/$MASTER_VM_NAME/g; s/%NETWORK_ID%/$MASTER_NETWORK_ID/g; s/%IMAGE_ID%/$MASTER_IMAGE_ID/g; s/%CPU%/$MASTER_NUM_CPUS/g; s/%MEMORY%/$MASTER_MEMORY/g; s/%MASTER_SERVICE_PORT%/$MASTER_SERVICE_PORT/g; s/%APP_CONTEXT_SCRIPT%/$MASTER_CONTEXT_SCRIPT/g; s/%APP_CONTEXT_VAR%/$MASTER_CONTEXT_VAR/g " $MASTER_TEMPLATE > $MASTER_TEMPLATE.tmp.$$

    insertvmtemplatevars $MASTER_TEMPLATE.tmp.$$

    CMDOUT=`onecmd -e $ENDPOINT onevm create $MASTER_TEMPLATE.tmp.$$`
    MASTERID=`echo $CMDOUT | awk '{print $2}'`
    RES=$(checknumeric $MASTERID)
    if  [ $RES -eq 1 ]; then
        updateappenvdb $ENVID "-1"  "MASTER_CREATE_FAIL:$CMDOUT"
        echo "ABORT"
        return 1
    fi
    echo $MASTERID
    return 0
}



createnv () {
    # Add it to to the DB and get an the enviroment id
    ENVID=$1
    echo "Environment ID: " $ENVID
 
    # Need some value for context vars so that the substitution in the 
    # template doesn't leave a dangling ',' which onevm create doesn't like
    if [ -z "$MASTER_CONTEXT_VAR" ]; then
        MASTER_CONTEXT_VAR="MASTER=true"
    fi
    if [ -z "$SLAVE_CONTEXT_VAR" ]; then
        SLAVE_CONTEXT_VAR="SLAVE=true"
    fi

    MASTERID=$(createmaster $ENVID)
    if [[ $MASTERID -eq "ABORT" ]]; then
         echo "Fatal error when creating master. Check template, account or quotoa"
         exit -1
    fi
  
    echo "Master is " $MASTERID

    insertvmpooldb $MASTERID $ENVID "VM_CREATE"
 
    updateappenvdb $ENVID $MASTERID "MASTER_CREATE"

    # Wait for master to start
    waitvmstarted $MASTERID $ENVID "MASTER"

    # Get the IP address of the master 
    MASTERIP=$(getvmip $MASTERID)
    echo "Master's IP address is " $MASTERIP

    # Delay to allow application to be setup on the master 
    if [ -n "${MASTER_SETUP_TIME+x}" ]; then
       echo "Waiting for application deployment on master"
       sleep $MASTER_SETUP_TIME
    fi

    waitmasterappinit $ENVID

    # Check if  slave template is there
    if [ ! -f $SLAVE_TEMPLATE ]; then
        updateappenvdb $ENVID "-1"  "SLAVE_CREATE_FAIL: Template $SLAVE_TEMPLATE not found"
        exit -1
    fi

    # Create the slaves
    SLAVELIST=""
    for (( i=0; i < $NUM_SLAVES; i++))
    do
       # Add the environments dependency to SLAVE_CONTEXT_VAR
       if [ -n "${ENVDEP+x}" ]; then
           SLAVE_CONTEXT_VAR=`echo $SLAVE_CONTEXT_VAR $ENVDEP`
       fi
       # Do some variable transform 
       SLAVE_CONTEXT_VAR_T=`echo $SLAVE_CONTEXT_VAR | sed -e "s/%MASTER%/$MASTERIP/g; s/%SLAVE_INDEX%/$i/g; s/%NUM_SLAVES%/$NUM_SLAVES/g;"` 

       sed -e "s/%MASTER%/$MASTERIP/g; s/%SERVICE_NAME%/$SERVICE_NAME/g; s/%CARINA_IP%/$CARINA_IP/g; s/%NAME%/$SLAVE_VM_NAME/g; s/%NETWORK_ID%/$SLAVE_NETWORK_ID/g; s/%IMAGE_ID%/$SLAVE_IMAGE_ID/g; s/%CPU%/$SLAVE_NUM_CPUS/g; s/%MEMORY%/$SLAVE_MEMORY/g; s/%ENVID%/$ENVID/g; s/%APP_PACKAGE%/$APP_PACKAGE/g;  s/%APP_CONTEXT_SCRIPT%/$SLAVE_CONTEXT_SCRIPT/g; s/%APP_CONTEXT_VAR%/$SLAVE_CONTEXT_VAR_T/g;" $SLAVE_TEMPLATE > $SLAVE_TEMPLATE.tmp.$$

       insertvmtemplatevars $SLAVE_TEMPLATE.tmp.$$

       CMDOUT=`onecmd -e $ENDPOINT onevm create $SLAVE_TEMPLATE.tmp.$$`
       SLAVEID=`echo $CMDOUT | awk '{print $2}'`
       RES=$(checknumeric $SLAVEID)
       if  [ $RES -eq 1 ]; then
            echo "Error encountered creating slave VM. Check template"
            updateappenvdb $ENVID "-1"  "SLAVE_CREATE_FAIL:$CMDOUT"
            exit -1
       fi
  
       insertvmpooldb $SLAVEID $ENVID "VM_CREATE"
       SLAVELIST=`echo $SLAVELIST  $SLAVEID`
    done
    echo "SLAVELIST is " $SLAVELIST


    for slave in $SLAVELIST
    do 
        # Wait for slaves to start
        waitvmstarted  $slave $ENVID "SLAVE"
        # Get IP address of the slave servers 
        SLAVEIP=$(getvmip $slave)
        # Tell the master IP address of slave 
        yes | ssh -o StrictHostKeyChecking=no $ADMINUSER@$MASTERIP /home/$ADMINUSER/$MASTER_CONTEXT_SCRIPT add $SLAVEIP $SLAVEDATA
    done

    if [ -n "${APP_URL+x}" ]; then
       URL=`echo $APP_URL | sed -e "s/%MASTER%/$MASTERIP/g"` 
       updateappurl $ENVID $URL
    fi

    #Final update indicating we have succesfully completed
    updateappenvpolicystatusdb $ENVID "READY"

    rm $MASTER_TEMPLATE.tmp.$$
    if [ -f  $SLAVE_TEMPLATE.tmp.$$ ]; then
        rm $SLAVE_TEMPLATE.tmp.$$
    fi
    exit 0
}


# Create 1 slave and add it to master
flexup () {
    #Get the master IP for this app env
    MASTERINFO=$(getmastervm $1)
    MASTERID=`echo $MASTERINFO | awk '{print $1}'`
    MASTERIP=`echo $MASTERINFO | awk '{print $2}'`
    echo "Environment master's IP address is " $MASTERIP

    echo "Flexing up application id $1"

    SLAVE_INDEX=$(getnextslaveindex $1)
    if [ -z "$SLAVE_CONTEXT_VAR" ]; then
        SLAVE_CONTEXT_VAR="SLAVE=true"
    fi

    if [ -n "${ENVDEP+x}" ]; then
        SLAVE_CONTEXT_VAR=`echo $SLAVE_CONTEXT_VAR $ENVDEP`
    fi

    SLAVE_CONTEXT_VAR_T=`echo $SLAVE_CONTEXT_VAR | sed -e "s/%MASTER%/$MASTERIP/g; s/%SLAVE_INDEX%/$SLAVE_INDEX/g; s/%NUM_SLAVES%/$SLAVE_INDEX/g;"` 
    sed -e "s/%MASTER%/$MASTERIP/g; s/%SERVICE_NAME%/$SERVICE_NAME/g; s/%CARINA_IP%/$CARINA_IP/g; s/%NAME%/$SLAVE_VM_NAME/g; s/%NETWORK_ID%/$SLAVE_NETWORK_ID/g; s/%IMAGE_ID%/$SLAVE_IMAGE_ID/g; s/%CPU%/$SLAVE_NUM_CPUS/g; s/%MEMORY%/$SLAVE_MEMORY/g; s/%ENVID%/$1/g; s/%APP_PACKAGE%/$APP_PACKAGE/g;  s/%APP_CONTEXT_SCRIPT%/$SLAVE_CONTEXT_SCRIPT/g; s/%APP_CONTEXT_VAR%/$SLAVE_CONTEXT_VAR_T/g;" $SLAVE_TEMPLATE > $SLAVE_TEMPLATE.tmp.$$

    insertvmtemplatevars $SLAVE_TEMPLATE.tmp.$$

    CMDOUT=`onecmd -e $ENDPOINT onevm create $SLAVE_TEMPLATE.tmp.$$`
    SLAVEID=`echo $CMDOUT | awk '{print $2}'`
    RES=$(checknumeric $SLAVEID)
    if  [ $RES -eq 1 ]; then
        echo "Error encountered creating slave VM. Check template"
        updateappenvdb $1 $MASTERID  "SLAVE_CREATE_FAIL:$CMDOUT"
        exit -1
    fi
    echo "Created new slave for $1 with VM ID $SLAVEID"
    # Add entry to DB
    insertvmpooldb $SLAVEID $1 "VM_CREATE"

    # Wait for slaves to start
    waitvmstarted  $SLAVEID $1 "SLAVE"
    # Get IP address of the slave servers 
    SLAVEIP=$(getvmip $SLAVEID)
    # Tell the master IP address of slave 
    yes | ssh -o StrictHostKeyChecking=no $ADMINUSER@$MASTERIP /home/$ADMINUSER/$MASTER_CONTEXT_SCRIPT add $SLAVEIP $SLAVEDATA
    if [ $? -eq 0 ]; then
        updateappenvdb $1 $MASTERID  "SLAVE_SCALEUP_SUCCESS"
    else
        updateappenvdb $1 $MASTERID  "SLAVE_SCALEUP_FAIL: ssh to master failed"
    fi

    rm $SLAVE_TEMPLATE.tmp.$$
}

# Remove 1 slave and inform master
flexdown () {
    echo "Flexing down application id $1"
    #Get the master IP for this app env
    MASTERINFO=$(getmastervm $1)
    MASTERID=`echo $MASTERINFO | awk '{print $1}'`
    echo "Environment Master's id  is " $MASTERID

    LASTSLAVE=$(getlastslavevm $1)
    LASTSLAVEID=`echo $LASTSLAVE | awk '{print $1}'`
    if [[ $LASTSLAVEID == $MASTERID ]]; then
        echo "No slaves for this environment" 
        return
    fi
    MASTERIP=`echo $MASTERINFO | awk '{print $2}'`
    LASTSLAVEIP=`echo $LASTSLAVE | awk '{print $2}'`
    
    # Tell the environment master to remove the slave
    echo "Telling master VM to remove slave IP $LASTSLAVEIP"
    yes | ssh -o StrictHostKeyChecking=no $ADMINUSER@$MASTERIP /home/$ADMINUSER/$MASTER_CONTEXT_SCRIPT delete $LASTSLAVEIP $SLAVEDATA

    # Wait for the slave to drain
    echo "Waiting for slave to complete existing requests"
    sleep 30

    # Shutdown the slave VM. Dont delete because we could restart it in a flexup
    LASTSLAVEID=`echo $LASTSLAVE | awk '{print $1}'`
    echo "Shutting down (deleting) last slave $LASTSLAVEID"
    onecmd -e $ENDPOINT onevm shutdown $LASTSLAVEID
    onecmd -e $ENDPOINT onevm delete $LASTSLAVEID

    # Mark status in DB
    deletevm $LASTSLAVEID
    
}


removenv () {
    echo "Remove environment $1 "
    # Get all VMIDs for an environment
    VMIDS=$(getallenvvmids $1)

    # Shut down all the VMs
    for vm in $VMIDS
    do
       echo "Shutting down VM $vm"
       onevm shutdown $vm
    done

    # Delete the VMs
    for vm in $VMIDS
    do
       echo "Deleting  VM $vm"
       onecmd -e $ENDPOINT onevm delete $vm
    done
  
    # Remove the app envrionment and VM entries
    deleteenvvm $1
}


recreateenvvm() {
    VMID=$1
    ENVID=$2
    MASTERINFO=$(getmastervm $ENVID)
    MASTERID=`echo $MASTERINFO | awk '{print $1}'`
    MASTERIP=`echo $MASTERINFO | awk '{print $2}'`
    # If the VM still exists delete it and inform master. Note that the 
    # onecmd will work if VM is in unknown state but not if its already 
    # deleted
    onecmd -e $ENDPOINT onevm shutdown $VMID
    onecmd -e $ENDPOINT onevm delete $VMID
    deletevm $VMID       
    # If the VM to be removed is master, we recreate it and tell it about
    if [[ $VMID == $MASTERID ]]; then
        if [ -z "$MASTER_CONTEXT_VAR" ]; then
            MASTER_CONTEXT_VAR="MASTER=true"
        fi
        MASTERID=$(createmaster $ENVID)
        if [[ $MASTERID -eq "ABORT" ]]; then
            echo "Fatal error when recreating master. Check template, account or quotoa"
            exit -1
        fi
        echo "New Master is " $MASTERID
        insertvmpooldb $MASTERID $ENVID "VM_CREATE"
        updateappenvdb $ENVID $MASTERID "MASTER_CREATE"

        # Wait for master to start
        waitvmstarted $MASTERID $ENVID "MASTER"

        # Get the IP address of the master
        MASTERIP=$(getvmip $MASTERID)
        echo "New Master's IP address is " $MASTERIP
        # Delay to allow application to be setup on the master 
        if [ -n "${MASTER_SETUP_TIME+x}" ]; then
            echo "Waiting for application deployment on new master"
            sleep $MASTER_SETUP_TIME
        fi

        waitmasterappinit $ENVID

        # Now tell master to re-add its slaves
        VMIPLIST=$(getallenvvmips $ENVID)
        for ip in $VMIPLIST
        do
            if [[ $ip != $MASTERIP ]]; then
                yes | ssh -o StrictHostKeyChecking=no $ADMINUSER@$MASTERIP /home/$ADMINUSER/$MASTER_CONTEXT_SCRIPT add $ip $SLAVEDATA
            fi
        done
        # Update URL if new master was created
        if [ -n "${APP_URL+x}" ]; then
            URL=`echo $APP_URL | sed -e "s/%MASTER%/$MASTERIP/g"` 
            updateappurl $ENVID $URL
        fi
    else
        VMIP=$(getvmipfromdb $VMID)
        echo "Telling master VM to remove old slave IP $VMIP"
        yes | ssh -o StrictHostKeyChecking=no $ADMINUSER@$MASTERIP /home/$ADMINUSER/$MASTER_CONTEXT_SCRIPT delete $VMIP $SLAVEDATA
        # Re-add a new VM by flexing up
        flexup $ENVID
    fi
}
if [ -f ../etc/system.conf ]; then
   . ../etc/system.conf
fi

if [ -f ../etc/oneenv.conf ]; then
   . ../etc/oneenv.conf
else
   . $HOME/conf/oneenv.conf
fi
USER=root
HOST=$DB_HOST
PASS=$DB_PASS
DB=opennebula
VMTABLE="vm_pool_ext"
APPENVTABLE="app_environment"
JOBSTABLE="jobs"
SVCTABLE="service"
SVCID=$(getsvcid $SERVICE_NAME)
RES=$(checknumeric $SVCID)
if  [ $RES -eq 1 ]; then
    echo "Service name is not in DB"
    exit -1
fi

while getopts "e:f:n:i:c:u:d:r:v:x:s" opt; do
    case $opt in
       e)
          echo "Setting endpoint"
          ENDPOINT=$OPTARG 
          ;;
       c)
          echo "Reading configuration"
          . $OPTARG 
         ;;
       n)
          NAME=$OPTARG
         ;;
       i)
          ENVID=$OPTARG
         ;;
       f)
          ENVDEP=$OPTARG
         ;;
       v)
          VMID=$OPTARG
         ;;
       s)
          echo "### Creating app environment  ###"
          createnv $ENVID
         ;;
       u)
          echo "###  Flexing up environment ###"
          flexup $OPTARG
         ;;
       d)
          echo "###  Flexing down environment ###"
          flexdown $OPTARG
         ;;
       r)
          echo "### Removing an environment ###"
          removenv $OPTARG
         ;;
       x)
          echo "### Recreating VM in environment ###"
          recreateenvvm $VMID $OPTARG
         ;;
     esac
done 
