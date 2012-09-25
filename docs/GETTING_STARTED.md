
The server components for opennebula-carina are installed in a management
VM that can be accessed from the OpenNebula front-end. The client component
(oneenv CLI) needs to be installed on the oZones proxy or OpenNebula server
to interact with the server components. The client needs some environment
variables that have to be setup to talk to the server. The configuration
file $HOME/config.rb defines the endpoints, templates and environment 
definitions which must be uploaded to the server before environments are
created.

## Client Setup ##

   Install rest-client ruby gem locally in your service account on the oZones
   or ONE server where you normally login to run ONE commands. If the admin
   has already installed it at the system level, this step is not necessary:

    gem install --install-dir ~/gems  /tmp/rest-client-1.6.7.gem

   There is an error in ~/gems/specifications/mime-types-1.18.gemspec
   that gets installed: Change
~~~
    s.date = %q{2012-03-21 00:00:00.000000000Z}
   to:
    s.date = %q{2012-03-21}
~~~


  Copy the 'oneenv' CLI in your local bin directory

  Set the following environment variables on the service account on the oZones 
  proxy or OpenNebula server where ONE commands are normally issued: 
~~~
    export GEM_HOME=/var/lib/gems/1.8
    export GEM_PATH=/var/lib/gems/1.8:/home/<svc>/gems
    export CARINA_IP=5.62.27.190
    export CARINA_PORT=4567  (this is service-specific port that points to the oneenvd)
    export CARINA_GS_PORT=4321
~~~

## Configuration ##

Create the config.rb containing the endpoint, template, and at least
one environment definition.  The following is a minimal example:

~~~
ENDPOINT = {
        'flm01' => {
                :proxy   => 'http://ring00a/flm01',
                :oneauth => 'flm01-oneenv2:XXXXXX'
                }
            }



TEMPLATE = {
         'example' => {
                :file       => '/home/oneenv2/vm/example.vm',
                :cpu        => 1,
                :memory     => 1024,
                :network_id => { 'flm01' => 21, 'hlx01' => 7},
                :image_id   => { 'flm01' => 63, 'hlx01' => 20 }
        }
}

ENVIRONMENT = {
         'tomcat' => {
                :type => "compute",
                :endpoint => "flm01",
                :description => "Load-balanced Tomcat cluster",
                :placement_policy  => "pack",
                :master_template   => "example",
                :master_context_script =>  "balance.sh",
                :master_setup_time => 30,
                :master_context_var => "BALANCE_PORT=8080",
                :slave_template    => "example",
                :slave_context_script => "tomcat.sh",
                :slave_context_var => "\"APP_PACKAGE=gwt-petstore.war, SLAVE_ID=%SLAVE_INDEX%\"",
                :num_slaves        => 2,
                :slavedata         => "8080",
                :adminuser         => "local",
                :app_url           => "http://%MASTER%:8080/gwt-petstore"
         }
}
~~~

The following explains the parameters:

* type: a string allowing to classify different types of environments

* endpoint: specifies the endpoint defined in the ENDPOINT section that
would be used to create the environment.

* description: string describing the environment

* placement_policy: specifies how VMs for the environment should be
placed on physical hypervisors. Allowable values are 'pack', 'stripe'
or 'load'. This is used to select the RANK value in OpenNebula. See
http://www.opennebula.org/documentation:archives:rel3.0:schg.

* master_template, slave_template: references the TEMPLATEs section to
define what template will be used in creating the master and slave VMs.

* master_setup_time: delay between creating the master VM and the slave
VMs in order to give time for master setup to complete

* master_context_var, slave_context_var: Context variables to be
passed to the VM contextualization scripts on the master and slave
respectively. For the slave context vars, there are two strings that
are dynamically substituted at run time: %MASTER% is substituted with
the IP address of the master and %SLAVE_INDEX% is substituted with the
index number assigned to the slave starting at 0,1,2...

* num_slaves: the initial number of slaves that will be started when the
environment is first created

* slavedata: This is an arbitrary parameter that is passed to slave

* adminuser: this is the user that exists in the slave VM that is used
as the account to ssh into to run commands

* app_url: this is used to define an app-specifc url that a user can
connect to see after the app has been successfully provisioned. The string
%MASTER% can be specified to resolve to the IP address of the master VM.

Upload the config.rb to the oneenvd server on the Carina management VM:

~~~
     oneenv --upload config.rb
~~~

Update any VM templates to include the following context variables
and upload the VM file

~~~
CONTEXT        = [
  ENVID=%ENVID%,
  VMID=$VMID,
  CARINA_IP=%CARINA_IP%,
  SERVICE_NAME=%SERVICE_NAME%,
  DEFUSER=local,
  %APP_CONTEXT_VAR%,
  FILES        = "http://%CARINA_IP%/repo/%SERVICE_NAME%/context/authorized_keys http://ring00/repo/%SERVICE_NAME%/context/init.sh http://ring00/repo/%SERVICE_NAME%/context/network.sh  http://ring00/repo/%SERVICE_NAME%/context/%APP_CONTEXT_SCRIPT%",
.
.
]
~~~

These variables are resolved by the system. The authorized_keys file is
already generated in the controller VM and is used to ssh into master or
load-balancer VM without requiring password.  A service needs to provide
the contextualization scripts that will be invoked. A number of samples
are provided in the context subdirectory.

To upload the VM file do:
~~~
     oneenv --upload example.vm
~~~

Where example.vm is found in ~/vm/example.vm (i.e just put name not
full path)


## Adapting contextualization scripts ##

The contextualization scripts have to be adapted to report status of
deployment back to the onenvd controller. The status is reported by
invoking a cgi script running on the controller passing it information
that will update the database. The parameters for the call such as ENVID,
VMID, etc are passed to the contextualization script automatically. The
following are examples of reporting status from within a contextualization
script.


~~~
# This should be invoked after the network contextualization is completed.
wget $CARINA_IP/cgi-bin/updatevmstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&newip=$IP\&name=$HOSTNAME 2> /dev/null

# This is invoked on the master VM for an environment to indicate successful setup.
wget $CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=MASTER_INIT_DONE 2> /dev/null


# This is invoked on the master VM for an environment to indicate a failed setup
wget $CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=MASTER_INIT_FAIL 2> /dev/null

NOTE: The system looks for the status of MASTER_INIT_DONE or MASTER_INIT_FAIL to start deploying the slaves.

# This is invoked on the slave VM for an environment to indicate successful setup
wget $CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=SLAVE_"$SLAVE_ID"_INIT_DONE 2> /dev/null


# This is invoked on the slave VM for an environment to indicate failed setup
wget $CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=SLAVE_"$SLAVE_ID"_INIT_FAIL 2> /dev/null
~~~

The master contextualization script is invoked when the VM is
created, but also when the a new slave is added or removed from the
environment. This is done by ssh-ing into the master VM and running the
master contextualization script as follows:

~~~
    # To inform the master to add a new slave
     ssh -o StrictHostKeyChecking=no $ADMINUSER@$MASTERIP /home/$ADMINUSER/$MASTER_CONTEXT_SCRIPT add $SLAVEIP $SLAVEDATA

     # To inform the master to remove a slave
     ssh -o StrictHostKeyChecking=no $ADMINUSER@$MASTERIP /home/$ADMINUSER/$MASTER_CONTEXT_SCRIPT delete $LASTSLAVEIP $SLAVEDATA
~~~


The master contextualization script should be written to accept the 'add'
and 'remove' arguements. See the 'balance.sh' for an example of how this
is used to implement load-balancer integration.


## Elasticity Policy Specification ##

The environment definition in the config.rb can be extended with a policy
specification indicating how the number of slaves should auto-scale. This
can be achieved manually using the 'oneenv --scaleup <envid>' or 'oneenv
--scaledown <envid>' commands. The policy specification allows the system
to automate this process subject to various conditions.

### Time-Based Elasticity ###

Add the following hash to the environment specification to enforce
a time-based constraints on the number of VMs in an environment. The
'windows' parameter specifies a series of day-time restrictions and
the 'min' parameter specifies the number of VMs that should be running
(including the master VM) for the environment. The system will issue
'scaleup' or 'scaledown' requests until the number of VMs correspond to
the 'min' value.


~~~
  :elasticity_policy   => {
                           :mode => 'time-based',
                           :windows =>  {
                              'morn' => {:spec => 'Mon-Fri 0900-1300', :min => 6},
                              'aft' => {:spec => 'Mon-Fri 1300-1700', :min => 4},
                              'night' => {:spec => 'Mon-Fri 0000-0859 1700-2359', :min => 2},
                          }

~~~

### Load-Based Elasticity ###

Add the following to the environment specification to support auto-scaling
based on load conditions of the VM. Currently only the cpu metric
is supported.  The 'period' parameter indicates how many periods the
condition has to be true before an action is triggered. The system
evalutes the condition every 60 seconds. The 'priority' parameter reflects
the relative priority of the environment within a service class (NOTE:
This is ignored for now).

~~~
       :elasticity_policy   => {
                                      :mode => 'auto',
                                      :min => 2,
                                      :max => 4,
                                      :priority => 10,
                                      :period => 3,
                                      :scaleup_expr   => 'avgcpu > 50',
                                      :scaledown_expr => 'avgcpu < 20'
                                      },
~~~


## Application Storage & Stateful Applications ##

In order to deal with applications that must persist state independent
of the VM lifecyle, the service can make use of storage mounts from
NAS filers that are attached to the VM during the contextualization
process. Another approach is to use persistent disk images which are
attached to the VM when it is created.


The following describes how to handle NFS mounts through contextualization
using the Cassandra NoSQL database as an example. The environment
definition should have a list of mount points specified in the MOUNTLIST
variable that is passed to both the master and slave. The mounts are
expected to be in some regular form with suffix ending in a number i.e
172.30.53.23:/vol/data1, 172.30.53.23:/vol/data2, etc. The extra back
slashes are necessary to handle various shell escapes as the  mount list
variable is ultimately passed to the context script. The context script
will also recieve a SLAVE_ID (starting from 0) and NUM_SLAVES variable.


~~~
  'cassandra-flm01' => {
                .
                .
                :master_template   => "cassandra",
                :master_context_script =>  "cassandra.sh",
                :master_context_var => "\"MOUNTLIST=172.30.53.23:\\/vol\\/data{1-6},\"",
                .
                .
                :slave_template    => "cassandra",
                :slave_context_script => "cassandra.sh",
                :slave_context_var       => "\"SLAVE_ID=%SLAVE_INDEX%, NUM_SLAVES=%NUM_SLAVES%, SEEDS=%MASTER%, MOUNTLIST=172.30.53.23:\\/vol\\/data{1-6},\"",
         },
~~~


In the contextualization script the following method can be used to
extract the context variable and determine the MOUNT for a given VM in
the environment:


~~~
getmount() {
    BASE=`echo $MOUNTLIST | awk -F '{' '{print $1}'`
    if [ -z "${SLAVE_ID+x}"  ]; then
        START=`echo $MOUNTLIST | awk -F '{' '{print $2}' | awk -F '}' '{print $1}' | awk -F '-' '{START=$1;LAST=$2; print START}'`
        export MOUNT=`echo $BASE$START`
    else
         START=`echo $MOUNTLIST | awk -F '{' '{print $2}' | awk -F '}' '{print $1}' | awk -F '-' '{START=$1;LAST=$2; print START}'`
         MOUNTINDEX=`expr $START + $SLAVE_ID + 1`
         export MOUNT=`echo $BASE$MOUNTINDEX`
     fi
}
~~~


## Environment Groups ##

It is possible to define a composite environment which is composed of
multiple sub-environments with dependencies in between them. The following
is a (contrived) example of an environment group that can be specified:

~~~
ENVIRONMENT = {
     .
     .
    'analytics' => {
                :type => "group",
                :description => "BI Analytics environment with Hbase data store and Tomcat cluster for processing and a Jenkins build environment",
                :members => [ 'hbase' , 'tomcat', 'apache' ],
                :dependencies => { 'tomcat' => ['hbase', 'jenkins'],
                                   'jenkins' => ['hbase'] }
        },
     .
}
~~~



* type: must be set to "group"

* members: This lists the other environments that are members of this
group. The definitions for the other environments must exist within the
environment section. Note that the order in the members list specifies
the order in which the environments are created for the group.

* dependencies: This specifices the information dependencies between
the environments. This is expressed as a string of APP_URLs that are
passed from the dependant environment to the depending environment. In
the above example, the 'hbase' environment is created first. Its
APP_URL is obtained and then passed to the 'jenkins' environments
contextualization scripts (both master and slave contextualization). The
form of the context variable is "<environment name>_URL=value" e.g
HBASE_URL="http://192.168.23.121:60010".

The context script is expected to check for that variable and setup any
configuration to point the environment to its dependency. If multiple
environments are in the dependency list, then the APP_URLS for all the
dependents will be passed as separate context variables. In the above
example, the 'tomcat' environment's contextualization should expect
variables HBASE_URL and JENKINS_URL to be set.

When the group is created, each sub-environment is assigned its own 
environment id. The first environment (the parent) id is assigned to the
group id of all subsequent environments within the group. When removing
the environments, the default is to remove each sub-environment individually.
Alternatively the entire group may be removed by using a '-' in front of the
environment id when removing i.e 'oneenv --remove -55' to remove all 
environments in the group with the parent environment id being '55'.

NOTE: When defining environments with dependencies do not use any
characters other than [a-z][a-Z][0-9]_ in the name as other characters
create problems with the context variables in OpenNebula (i.e OpenNebula
will fail to create the VM)

## Availability Policies ##

The environment definition in config.rb can be extended to include
policies that relate to managing the availability of an environment.
Specifically the following use cases are considered:

*  Automatically recreate VMs that are deleted (for whatever reason) -
Automatically delete and recreate VMs that go into an 'UNKNOWN' state
  typically caused by hypervisor failures
*  Automatically recreate VMs in "FAILED" state caused by (hopefully)
transient
  errors in deployment
*  Active-Passive environments for DR - Active-Active environments for
redundancy and load-balancing

The following gives example of two environments which form an
active-passive pair and where the active environment is set to recreate
VMs with faults.


~~~
           'tomcat_ha_active' => {
                       .
                       .
                       :availability_policy => {
                             :period => 3,
                             :recreate_expr => "nummissing > 0 || numunknown > 0 || numfailed > 0"
                             :failover_role => "active"
                             :failover_group => "tomcat-ha",
                             :failover_expr => "(numunknown + nummissing + numfail)/numvms > 0.50",
                             :failback_expr => "numunknown == 0",
                       },
           }

           'tomcat_ha_passive' => {
                       .
                       .
                        :availability_policy => {
                               :period => 3,
                               :failover_role => "passive"
                               :failover_group => "tomcat-ha",
                         },
                         :elasticity_policy   => {
                             :mode => 'time-based',
                             :windows =>  {
                                       'all'  =>   {:spec => 'Mon-Fri 0000-2359', :min => 4},
                              }},
                          :num_slaves   => 0,

                         .
           }

~~~


* period: Availability policies are evaluated every 60s. The period
is the number of times an expression has to be true before the action
(recreate, failover, or failback) is taken.

*  recreate_expr: This expression is evaluated to determine if VMs should
be recreated. The variables 'nummissing', 'numunknown', 'numfailed' and
'numvms' hold the counters for the number of VMs in the environment that
are in various states.These variables can be combined in any way in a
Ruby expression.

*  failover_role:  This can be one of 'active' or 'passive'

* failover_group: This identifies environments that are in the same
failover group. The name must be unique for each pair of environments
which form a failover pair.

*  failover_expr: This expression is evaluated to determine if an
environment is no longer functioning and it must be failed over. The
variables 'nummissing', 'numunknown', 'numfailed' and 'numvms' hold
the counters for the number of VMs in the environment that are in
various states.These variables can be combined in any way in a Ruby
expression. When the 'failover_expr' expression is true for 'period'
intervals,the environment is marked as FAILED. The passive environment
in the same failover_group is made ACTIVE (if it isn't already)  and
elasticity policies can be used to have that environment scale out to
take over the load.

NOTE: A passive environment can be created with 0 slaves so that only
the load-balancer/master exists initially.

*  failback_expr: This expression is evaluated to determine when an
environment should be considered ACTIVE again after being put into the
FAILED state. The same variables can be used as in the failover_expr. When
the 'failback_expr' is true for  'period' intervals, the environment
is marked as 'ACTIVE'. The corresponding passive environment is reset
into the PASSIVE state. Any VMs for the PASSIVE environment that were
created by elasticity polices will be shutdown.


## Command Summary ##

### oneenv --upload config.rb ###
Uploads the local config.rb to the Carina management VM.
Example:

~~~
oneenv1@ring00b:~$ oneenv --upload config.rb
OK
~~~

### oneenv --upload [filename] ###
Uploads a VM template file referenced from config.rb to the Carina management VM. Any VM template file that is referenced by an environment must be uploaded prior to attempting to create the environment. The file must reside in $HOME/vm directory.
Example:

~~~
oneenv1@ring00b:~$ ls ~/vm/default.vm
/home/oneenv1/vm/default.vm
oneenv1@ring00b:~$ oneenv --upload default.vm
OK
~~~


### oneenv --create [configname] ###
This creates a new environment based on the configuration given. The 
configuration must be in the config.rb uploaded to the Carina server. The environment id is assigned and a job is launched to step through the workflow
of creating a cluster. 
Example:

~~~
oneenv1@ring00b:~$ oneenv --create tomcat-hlx02
{"envid":"18", "jobid":"51"}
~~~

### oneenv --envs ###
Displays the list of environments that are in the system for a service.
Example:
~~~
oneenv1@ring00b:~$ oneenv --envs
ID            NAME VMS P_STATUS          D_STATUS APP_URL
--            ---- --- --------          -------- -------
16  e-tomcat-flm01   2   active  slave__init_done http://172.30.53.34:8080/gwt-petstore
15 cassandra-flm01   3   active slave_1_init_done http://172.30.53.30:8080/
14    tomcat-flm01   3   active  slave__init_done http://172.30.53.37:8080/gwt-petstore
18    tomcat-hlx02   2   active  slave__init_done http://5.62.70.33:8080/gwt-petstore
~~~


### oneenv --scaleup [envid] ###
This manually scales up the environment, identified by the envid, by starting up another slave VM. While a scaleup operation is running another scale up or
scale down operation is not permitted.
Example:

~~~
oneenv1@ring00b:~$ oneenv --scaleup 18
{"jobid":"52"}
~~~

### oneenv --scaledown [envid] ###
This manually scales down the environment, identified by the envid, by shutting down one slave VM. While a scaledown operation is running another scale up or
scale down operation is not permitted.
Example:

~~~
oneenv1@ring00b:~$ oneenv --scaledown 18
{"jobid":"53"}
~~~


### oneenv --remove [envid] ###
This removes an environment. All VMs within the environment are deleted and the
environment is removed from the database.
Example:

~~~
oneenv1@ring00b:~$ oneenv --remove 18
{"jobid":"54"}
~~~

###  oneenv --envvms [envid] ###

This displays all the VMs for a given environment identified by envid.
Example:

~~~
oneenv1@ring00b:~$ oneenv --envvms 14
VMID ENVID       HOSTNAME       IPADDR           STATUS CPU
----  ----       --------       ------           ------ ---
1604    14 tomcat-flm01-m 172.30.53.37 master_init_done 0
1605    14 tomcat-flm01-s 172.30.53.38 slave__init_done 0
1606    14 tomcat-flm01-s 172.30.53.39 slave__init_done 0
~~~


### oneenv --jobs ###

This will display all the jobs for the service. Jobs are launched for each operation like create, scaleup, scaledown, remove operation that is run. You can track the status of these jobs through this command. The job list is stored in the database and can form an event log of all the provisioning activities for an environment.

oneenv1@ring00b:~$ oneenv --jobs

~~~
ID ENVID     CONFIG_NAME      TYPE                    SUBMIT_TIME STATUS
-- -----     -----------      ----                    ----------- ------
48    17    tomcat-hlx02    CREATE Mon Sep 17 14:41:29 -0400 2012 DONE
49    17    tomcat-hlx02   SCALEUP Mon Sep 17 14:44:13 -0400 2012 DONE
50    17    tomcat-hlx02    REMOVE Tue Sep 25 11:18:53 -0400 2012 DONE
51    18    tomcat-hlx02    CREATE Tue Sep 25 11:19:02 -0400 2012 DONE
52    18    tomcat-hlx02   SCALEUP Tue Sep 25 11:29:52 -0400 2012 DONE
53    18    tomcat-hlx02 SCALEDOWN Tue Sep 25 11:33:57 -0400 2012 DONE
54    18    tomcat-hlx02    REMOVE Tue Sep 25 11:52:15 -0400 2012 DONE
~~~


### oneenv --vms ###
Displays all the VMs across different environments for the service.
Example:

~~~
oneenv1@ring00b:~$ oneenv --vms
VMID ENVID          HOSTNAME       IPADDR STATUS CPU
----  ----          --------       ------ ------ ---
1971    16  e-tomcat-flm01-m 172.30.53.34   runn 2
1972    16  e-tomcat-flm01-s 172.30.53.40   runn 0
1872    15 cassandra-flm01-s 172.30.53.33   runn 2
1870    15 cassandra-flm01-m 172.30.53.30   runn 0
1871    15 cassandra-flm01-s 172.30.53.31   runn 0
1604    14    tomcat-flm01-m 172.30.53.37   runn 0
1605    14    tomcat-flm01-s 172.30.53.38   runn 0
1606    14    tomcat-flm01-s 172.30.53.39   runn 2
~~~

### oneenv --configs ###

oneenv1@ring00b:~$ oneenv --configs
This displays the list of environment configurations (as defined in config.rb) that are know by the server. This is useful to check if the config.rb that was uploaded was processed properly.
Example:

~~~
           NAME    TYPE ENDPOINT DESCRIPTION
           ----    ----  ------- -----------
tomcat-tw-flm01 compute    flm01 "Load-balanced Tomcat cluster"
cassandra-flm01    data    flm01 "Cassandra NoSQL Database"
 tomcat_hlx02_p compute    hlx02 "Load-balanced Tomcat cluster"
   tomcat-hlx02 compute    hlx02 "Load-balanced Tomcat cluster"
 tomcat_flm01_a compute    flm01 "Load-balanced Tomcat cluster"
 tomcat_ha_pair   group        - "HA Active-Passive pair of Tomcat cluster
 e-tomcat-flm01 compute    flm01 "Load-balanced Tomcat cluster"
   tomcat-flm01 compute    flm01 "Load-balanced Tomcat cluster"
~~~


### oneenv --services ###

This displays a list of all the services that are defined in the system. This iinformation is reported by the Carina scheduler.
Example:

~~~
oneenv1@ring00b:~$ oneenv --services
   NAME PRIORITY_CLASS MEM(ALLOC/MAX) VCPUS(ALLOC/MAX) CLIENT
   ---- -------------- --------------  --------------- ------
oneenv1         silver     512/128000             1/12 5.62.27.190:4567
oneenv2           gold        0/64000             0/12 5.62.27.190:4577
   arch         silver        0/64000             0/12 NONE
   gist           gold        0/64000             0/12 NONE
 oneenv         silver        0/64000             0/12 5.62.27.190:4557
~~~

### oneenv --pools ###
This displays all the resource pools that are managed by the Carina scheduler. When environments are scaled up/down, resources are allocated from the pools 
based on the service class of the environment requesting and the availability
of resources within pools of that class.
Example:

~~~
oneenv1@ring00b:~$ oneenv --pools
 NAME  ZONE PRIORITY_CLASS MEM_TOT MEM_AVAIL VCPUS_TOT VCPUS_AVAIL
 ----  ---- -------------- ------- --------- --------- -----------
flm01 flame           gold   10248      9736        10 9
hlx02 helix         silver    4096      4096         5 5
~~~


### oneenv --requests ###
This displays all the requests from different services that are sent to the Carina scheduler when environments are scaled up/down.
Example:

~~~
oneenv1@ring00b:~$ oneenv --requests
ID ENVID SERVICE  MEM  VCPUS    STATUS POOL
--  ---- ------- ---- ------    ------ ----
 4    14 oneenv1  512      1 ALLOCATED flm01
 7    19 oneenv1  512      1      PEND hlx02
~~~


### oneenv --json ###
For any informational commands the --json argument can be give to return 
the full datastructures. This can be useful for troubleshooting purposes
to display extra information that is not normally displayed.
Example:

~~~
oneenv1@ring00b:~$ oneenv --envs --json
[
  {
    "gsOutStandingReqs": 0,
    "envid": "16",
    "gsTokens": [

    ],
    "numVMs": 2,
    "metrics": "avgcpu[0]",
    "policy_status": "ACTIVE",
    "url": "http://172.30.53.34:8080/gwt-petstore",
    "info": "POLICY_STATUS: Scale down @elasticityCounter incremented to 4",
    "status": "SLAVE__INIT_DONE",
    "name": "e-tomcat-flm01"
  },
  {
    "gsOutStandingReqs": 0,
    "envid": "15",
    "gsTokens": [

    ],
    "numVMs": 3,
    "metrics": "",
    "policy_status": "ACTIVE",
    "url": "http://172.30.53.30:8080/",
    "info": "",
    "status": "SLAVE_1_INIT_DONE",
    "name": "cassandra-flm01"
  },
  {
    "gsOutStandingReqs": 0,
    "envid": "14",
    "gsTokens": [
      "4"
    ],
    "numVMs": 3,
    "metrics": "",
    "policy_status": "ACTIVE",
    "url": "http://172.30.53.37:8080/gwt-petstore",
    "info": "",
    "status": "SLAVE__INIT_DONE",
    "name": "tomcat-flm01"
  }
]
~~~

