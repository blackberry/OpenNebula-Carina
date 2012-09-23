Introduction
------------

The Carina Environment Manager is a component to handle the 
deployment of interconnected multi-VM application services on top of the 
OpenNebula IaaS platform. It supports the automated creation and run-time 
scaling of multi-VM application environments according to policies.  It 
leverages the OpenNebula contextualization framework to setup clusters of VMs 
in a master-slave configuration or a set of workers with an IP load-balancer 
in front. Policies can be defined to control how VMs are added or removed 
based on manual, time of day, or application load-based triggers.

The system will ensure that an appropriate number of VMs are started even
in the presence of hypervisor or data center failures to meet application
service requirements.  Environments can be aggregated so that multi-tier 
services consisting of web, app, caching, database clusters can be 
interconnected and deployed as unit. A variety of  sample integrations with 
distributed middleware and tools like Tomcat, CloudFoundry, Jenkins, HBase 
are provided.

For service developers, an IaaS platform and layered tools like this can help
turn their applications from static, manually configured systems that take 
weeks or months to deploy and change into dynamic and adaptive systems. 
Infrastructure becomes just another set of APIs that you use in developing 
your service so that the infrastructure will scale as your service 
workload evolves.

Key Features
------------

* Automated deployement of clustered services (load-balanced worker pool or master-slave deployment pattern)
* Automated deployment of multiple inter-dependent clusters 
* Integration with Balance software load-balancer with open hooks to support other load-balancers
* Auto-recreate VMs that disappear, fail or go into unknown state due to hypervisior or transient network/storage issues
* Auto-scaling of environments based on time of day or day of week
* Auto-scaling of environments based on load (cpu by default with support for custom metric plugins)
* Prioritization of services and resource pools into 'gold','silver','bronze' classes.  
* Preemption and reclaim of resources from lower classes when higher priority classes required them
* Active-Active and Active-Passive DR support where environments in surviving data centers are scaled up in response to datacenter outages 
* Centralized management and failover of the oneenv controller

Usage
-----
`
Usage: oneenv [options]
    -c, --create STRING              Create environment from configuration
    -r, --remove STRING              Remove environment and delete VMs
    -u, --scaleup STRING             Scale up environment by adding VM
    -d, --scaledown STRING           Scale down environment by removing VM
    -U, --upload  STRING             Upload config.rb, vm template or plugin to server
    -D, --download  STRING           Download log file from server
    -J, --jobs                       List all jobs
    -v, --vms                        List all VMs
    -k, --envvms STRING              List all VMs for environment
    -S, --services                   List all services managed by Global Scheduler
    -R, --requests                   List all requests in Global Scheduler
    -P, --pools                      List all pools in Global Scheduler
    -j, --json                       Display verbose JSON output
    -o, --configs                    List all environment configs
    -e, --envs                       List all environments
`


