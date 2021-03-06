
This document describes the process to setup of the Carina Environment 
Manager for an OpenNebula installation. It is assumed you have OpenNebula
installed and configured and can startup individual VMs in it and execute contextualization scripts within the VMs [1]. Carina can be installed
on a bare VM containing only the OS or it can be installed from a VM
applicance that pre-installs all the dependencies.  For additional background on
requirements and  Carina architecture see the blog entry at http://blog.opennebula.org/?p=3509.

This management VM should ideally be created in a management VDC in 
environments where different services will be running in their own virtual
networks.  The network on which the management VM runs must be accessible 
from the  networks on which service VMs will be created.  Specifically 
service VMs 
will need to be able to connect to the management VM on port 80/http and the 
management VM must be able to connect to the service VMs on port 22/ssh.

The management VM contains the Carina software that can be installed as described in the
sections below. The service VMs do not require any Carina-specific software installed, but
must be able to use a tool like 'wget' to report status to the Carina management VM.
The serice VMs should be configured to support OpenNebula contextualization scripts so 
that  when Carina launches the VM using OpenNebual it can pass scripts and parameters that
will setup up middleware/applications on the service VM. Examples of how to setup 
contextualiztion scripts for various middleware packages are provided under the '/context'
directory. These should be seen as starting points for integrating applications to make
use of Carina services.

Carina communicates with OpenNebula using the 'onecmd' wrapper which allows for interactions
with multiple OpenNebula endpoints which can be either the oZones proxy or individual
instances of OpenNebula server. The 'onecmd' wrapper generates the '.one_auth' file containing
the authentication information required to issue commands such as 'onevm' to each endpoint by setting the ONE_XMLRPC variable appropriately. 
The endpoint information is retreived from the config.rb for each service (see the sample config.rb). 

The Carina management VM will require setting up an OS user account ('carina') under which
the Carina global scheduler , oneenvd-gs,  and the system oneenvd run. In general a separate OS
account should be setup on the Carina management VM for each user or service which has its
own credentials to talk to the OpenNebula server. A copy of oneenvd will run for each service 
under that OS account and manage environments on behalf of that service. Separate config.rb files
are maintained for each service. The accounts on the Carina management VM should mirror
those on the server where users normally invoke the 'onevm' command to create and manage VMs.



RAW INSTALL
===========

The following are notes for setting up the Carina Environment Manager in a 
base Ubuntu VM. 

A. Create an Ubuntu VM on the management VDC and setup mysql and apache on 
   the node.

  * apt-get install apache2
  * apt-get install mysql-server
  * apt-get install mysql-client
  * apt-get install libmysqlclient-dev 

B. Install OpenNebula client commands on this node (including ruby dependencies) in /var/lib/one. 

   * apt-get install ruby
   * apt-get install ruby-dev
   * apt-get install rubygems
   * mkdir /var/lib/one
   * chown -R carina /var/lib/one
   * chgrp -R carina /var/lib/one
   * In openenbula directory ./install.sh -c -d /var/lib/one (run as carina)
   * export ONE_AUTH=/home/carina/.one_auth
   * export ONE_LOCATION=/var/lib/one
   * Copy onecmd into /var/lib/one/bin

NOTE: All testing so far has been with OpenNebula 3.0 and OpenNebula 3.6

C. Setup ruby dependencies for oneenvd

   * sudo gem install sinatra
   * sudo gem install mysql
   * sudo gem install json
   * sudo gem install rest-client
   * sudo gem install redis

D. Untar/unzip the opennebula-carina package in /var/lib/one

E. Create schema in MySQL

  * /var/lib/one/opennebula-carina/misc/createschema.sh 

F. Setup CGI bin for Apache

  * In /etc/apache2/apache2.conf

~~~
ScriptAlias /cgi-bin/ "/usr/lib/cgi-bin/"

<Directory "/usr/lib/cgi-bin">
    AllowOverride None
    Options None
    Order allow,deny
    Allow from all
</Directory>
~~~


   *  cp /var/lib/one/opennebula-carina/cgi-bin/* /usr/lib/cgi-bin
   *  Change DB_HOST/DB_PASS variable in scripts to reflect mysql host/password 


G. Set up and install Redis VMs

   * Download and build redis from http://redis.io (version 2.6)
   * Create 2 VMs to act as master and slave and install redis - Alternatively for testing you can just run redis on Carina management VM.
   * Start the redis server
         redis-server --daemonize yes --appendonly yes (on master)
         redis-server --daemonize yes --slaveof  <masterip> 6379 (on slave)

H. Create an OS account "carina"  on the management VM that will run the 
   global scheduler. Ensure that the accounts profile is set up with
   the correct PATH and ONE environment variables so that ONE commands work.

   * sudo useradd -d /home/carina -m carina
   * /bin/su carina
   * mkdir $HOME/logs $HOME/work $HOME/conf $HOME/vm
   * cp /var/lib/one/opennebula-carina/etc/oneenv.conf to $HOME/conf/oneenv.conf
   * Set LOAD_VM_INFO=true (see comments in the file)
   *  mv /var/lib/one/opennebula-carina/etc/oneenv.conf  /var/lib/one/opennebula-carina/etc/oneenv.conf.bak
   * /var/lib/one/opennebula-carina/misc/createschema.sh  carina
   * cp /var/lib/one/opennebula-carina/etc/config.rb $HOME/config.rb
    (edit the config.rb to set the appropriate endpoints and templates)
   * Edit the global.rb to reflect the resource pools and services that will be in the system
   * /var/lib/one/opennebula-carina/misc/start-oneenvd-gs.sh (start the global scheduler)
   * /var/lib/one/opennebula-carina/misc/start-oneenvd.sh (start the oneenvd)


NOTE: The oneenvd in this OS account is only used to collect the VM status/load
information.

I. Each service that will use the system should have an OS account on the
management VM. This account will be used to run the oneenvd that can be 
accessed from the corresponding account on the OpenNebula server. The following
describes the steps:

   * sudo useradd -d /home/svc -m svc
   * /bin/su svc
   * mkdir $HOME/logs $HOME/work $HOME/conf $HOME/vm
   * cp /var/lib/one/opennebula-carina/etc/oneenv.conf.bak to $HOME/conf/oneenv.conf
   * Change the CARINA_PORT to be unique for each service and set the CARINA_IP to point to Carina VM. 
   * Set the SERVICE_NAME parameter to reflect the service
   * Set LOAD_VM_INFO=false 
   * Set the ZONE parameter to reflect the which zone this oneenvd manages. Zonemust match the 'zone' parameter of a shared pool defined in global.rb.
   * cp /var/lib/one/opennebula-carina/etc/config.rb $HOME/config.rb
   *  Generate ssh keys for each service and copy into /var/www/repo/<service>/context (these will be copied into the service's VM and then later used when doing a passwordless ssh into the VM)

~~~
         ssh-keygen -t rsa
         cp $HOME/.ssh/id_rsa.pub /var/www/repo/<service>/context/authorized_keys
~~~

   *  /var/lib/one/opennebula-carina/misc/createschema.sh svc

The above steps can be automated by executing 'misc/addsvc.sh service_name service_port zone'. The following steps are manual:

   * Setup /var/www/downloads to hold common packages/binaries that are required by sample the contextualization scripts (optional)
   * Edit the service's config.rb to set the appropriate service-specific endpoints. Before a service can use the system to upload their own config.rb, the admin must setup an endpoint which matches the username/password that the service will use. 
   * Add the service to /var/lib/one/opennebula-carina/etc/global.rb 
   * /var/lib/one/opennebula-carina/misc/start-oneenvd.sh (start the oneenvd for that service)

VM APPLIANCE INSTALL
====================

A VM applicance is provided with all the dependencies already installed and
steps 1-8 described above completed. After bringing up the VM from the 
template do the following:

* Login to the VM with default username/password: carina/carina
* Refresh the /var/lib/one/opennebula-carina with the latest version from
  Github
*  mv /var/lib/one/opennebula-carina/etc/oneenv.conf  /var/lib/one/opennebula-carina/etc/oneenv.conf.bak
* Edit /home/carina/conf/oneenv.conf to set the CARINA_IP parameter to 
  the IP address of the VM (NOTE: In current appliance the oneenv.conf still refers to CONTROLLER_IP, ONEENVD_PORT, ONEENVD_GS_PORT. Change these to CARINA_IP, CARINA_PORT, and CARINA_GS_PORT respectively)
* Edit /var/lib/one/opennebula-carina/etc/system.conf to set DB_HOST and 
  GS_REDIS_IP to the IP address of the VM (or 127.0.0.1)
* sudo to root and Start up the Redis server if its not running:
         redis-server --daemonize yes --appendonly yes 
* The appliance is installed with OpenNebula 3.6 by default. If you are
  running older version of OpenNebula, install the appropriate client CLIs.
  Built binaries for OpenNebula 3.0 are provided in the /home/carina/dist
* Edit the /var/lib/one/opennebula-carina/etc/global.rb with the resource 
  pools/service specific to your environment
* Create per-service accounts as required as described in step (I) above
* Start up scheduler daemon /var/lib/one/opennebula-carina/misc/start-oneenvd-gs.sh (start the oneenvd for that service)
* Start up per-service oneenvd daemon /var/lib/one/opennebula-carina/misc/start-oneenvd.sh (do this for each service account)


[1] In OpenNebula 3.6, you may have to modify your system datastore transport manager (eg. $ONE_LOCATION/var/remotes/tm/qcow2/context) to set execute permissions on context scripts.
