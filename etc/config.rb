ENDPOINT = {
	'mm01' => {
		:proxy   => 'http://localhost:2633/RPC2',
		:oneauth => "oneadmin:oneadmin"
		}
	}


TEMPLATE = {
	'sles11' => {
		:file       => "~/vm/sles11.vm",
		:cpu        => 1,
		:memory     => 1048,
		:network_id => { 'ccn01' => 4, 'mm01' => 0 },
		:image_id   => { 'ccn01' => 9, 'mm01' => 13 }
	},

	'centos6-medium' => {
		:file       => "~/vm/centos6.vm",
		:cpu        => 1,
		:memory     => 1048,
		:network_id => { 'ccn01' => 4 , 'mm01' => 0},
		:image_id   => { 'ccn01' => 10, 'mm01' => 11  }
	},

	'centos6-small' => {
		:file       => "~/vm/centos6.vm",
		:cpu        => 1,
		:memory     => 512,
		:network_id => { 'ccn01' => 4, 'mm01' => 0 },
		:image_id   => { 'ccn01' => 10, 'mm01' => 11 }
        },

	'ubuntu1104-small' => {
		:file       => "~/vm/ubuntu1104.vm",
		:cpu        => 1,
		:memory     => 512,
		:network_id => { 'ccn01' => 4, 'mm01' => 0 },
		:image_id   => { 'ccn01' => 1, 'mm01' => 1 }
	},

	'ubuntu1104-medium' => {
		:file       => "~/vm/ubuntu1104.vm",
		:cpu        => 1,
		:memory     => 1048,
		:network_id => { 'ccn01' => 4, 'mm01' => 0 },
		:image_id   => { 'ccn01' => 1, 'mm01' => 1 }
	},

	'ubuntu1104-large' => {
		:file       => "~/vm/ubuntu1104.vm",
		:cpu        => 1,
		:memory     => 2048,
		:network_id => { 'ccn01' => 4, 'mm01' => 0 },
		:image_id   => { 'ccn01' => 1, 'mm01' => 1 }
	}
}


ENVIRONMENT = {


	'tomcat' => {
                :type => "compute",
                :endpoint => "mm01",
                :description => "Load-balanced Tomcat cluster",
		:master_template   => "ubuntu1104-small",
                :master_context_script =>  "balance.sh",
		:master_setup_time => 30,
                :master_context_var => "BALANCE_PORT=8080",
		:slave_template    => "ubuntu1104-small",
                :slave_context_script => "tomcat.sh",
                :slave_context_var => "APP_PACKAGE=gwt-petstore.war",
                :placement_policy  => "pack",
                :num_slaves        => 2,
                :slavedata         => "8080",
                :adminuser         => "rimadmin",
                :app_url           => "http://%MASTER%:8080/gwt-petstore"
	 },


        'tomcat-ha' => {
                :type => "compute",
                :endpoint => "mm01",
                :description => "Load-balanced Tomcat cluster",
                :master_template   => "ubuntu1104-small",
                :master_context_script =>  "balance.sh",
                :master_setup_time => 30,
                :master_context_var => "BALANCE_PORT=8080",
                :slave_template    => "ubuntu1104-small",
                :slave_context_script => "tomcat.sh",
                :slave_context_var => "APP_PACKAGE=gwt-petstore.war",
                :placement_policy  => "pack",
                :availability_policy => {
                                         :period => 3,
                                         :recreate_expr => "nummissing > 0"
                                       },
                :num_slaves        => 2,
                :slavedata         => "8080",
                :adminuser         => "rimadmin",
                :app_url           => "http://%MASTER%:8080/gwt-petstore"
         },


      'tomcat_ha_active' => {
                :type => "compute",
                :endpoint => "mm01",
                :description => "Primary Load-balanced Tomcat cluster",
                :master_template   => "ubuntu1104-small",
                :master_context_script =>  "balance.sh",
                :master_setup_time => 30,
                :master_context_var => "BALANCE_PORT=8080",
                :slave_template    => "ubuntu1104-small",
                :slave_context_script => "tomcat.sh",
                :slave_context_var => "APP_PACKAGE=gwt-petstore.war",
                :placement_policy  => "pack",
                :availability_policy => {
                                         :period => 3,
                                         :recreate_expr => "nummissing > 0",
                                         :failover_expr => "numunknown/numvms > 0.50",
                                         :failback_expr => "numunknown == 0",
                                         :failover_group => "tomcat-ha",
                                         :failover_role => "active"
                                       },
                :num_slaves        => 2,
                :slavedata         => "8080",
                :adminuser         => "rimadmin",
                :app_url           => "http://%MASTER%:8080/gwt-petstore"
         },

      'tomcat_ha_passive' => {
                :type => "compute",
                :endpoint => "mm01",
                :description => "Failover Load-balanced Tomcat cluster",
                :master_template   => "ubuntu1104-small",
                :master_context_script =>  "balance.sh",
                :master_setup_time => 30,
                :master_context_var => "BALANCE_PORT=8080",
                :slave_template    => "ubuntu1104-small",
                :slave_context_script => "tomcat.sh",
                :slave_context_var => "APP_PACKAGE=gwt-petstore.war",
                :placement_policy  => "pack",
                :availability_policy => {
                                         :period => 3,
                                         :failover_group => "tomcat-ha",
                                         :failover_role => "passive"
                                       },
                :elasticity_policy   => {
                         :mode => 'time-based',
                         :windows =>  {
                         'all'  =>   {:spec => 'Mon-Fri 0000-2359', :min => 4},
                                      }},
                :num_slaves        => 0,
                :slavedata         => "8080",
                :adminuser         => "rimadmin",
                :app_url           => "http://%MASTER%:8080/gwt-petstore"
         },



      'tomcat-el' => {
                :type => "compute",
                :endpoint => "mm01",
                :description => "Load-balanced Tomcat cluster",
                :master_template   => "ubuntu1104-small",
                :master_context_script =>  "balance.sh",
                :master_setup_time => 30,
                :master_context_var => "BALANCE_PORT=8080",
                :slave_template    => "ubuntu1104-small",
                :slave_context_script => "tomcat.sh",
                :slave_context_var => "APP_PACKAGE=gwt-petstore.war",
                :num_slaves        => 2,
                :slavedata         => "8080",
              
                :elasticity_policy   => {
                                      :mode => 'auto',
                                      :min => 2,
                                      :max => 4,
                                      :priority => 1,
                                      :metric => 'avgcpu',
                                      :period => 3,
                                      :scaleup_expr   => 'avgcpu > 5',
                                      :scaledown_expr => 'avgcpu < 2'
                                      },
                :adminuser         => "rimadmin",
                :app_url           => "http://%MASTER%:8080/gwt-petstore"
         },


        'tomcat-el-plugin' => {
                :type => "compute",
                :endpoint => "mm01",
                :description => "Load-balanced Tomcat cluster",
                :master_template   => "ubuntu1104-small",
                :master_context_script =>  "balance.sh",
                :master_setup_time => 30,
                :master_context_var => "BALANCE_PORT=8080",
                :slave_template    => "ubuntu1104-small",
                :slave_context_script => "tomcat.sh",
                :slave_context_var => "APP_PACKAGE=gwt-petstore.war",
                :num_slaves        => 2,
                :slavedata         => "8080",
                :elasticity_policy   => {
                                      :mode => 'auto',
                                      :min => 2,
                                      :max => 4,
                                      :priority => 1,
                                      :metric_plugins => ['MemSize', 'Balance'],
                                      :period => 3,
                                      :scaleup_expr   => "m.numConnections > 20 && (m.netTxRate + m.netRxRate) >  30 ",
                                      :scaledown_expr => "(m.numConnections < 10) && m.avgMemSize > 512 "
                                      },
                :adminuser         => "rimadmin",
                :app_url           => "http://%MASTER%:8080/gwt-petstore"
         },



       'tomcat-tw' => {
                :type => "compute",
                :endpoint => "mm01",
                :description => "Load-balanced Tomcat cluster",
                :master_template   => "ubuntu1104-small",
                :master_context_script =>  "balance.sh",
                :master_setup_time => 30,
                :master_context_var => "BALANCE_PORT=8080",
                :slave_template    => "ubuntu1104-small",
                :slave_context_script => "tomcat.sh",
                :slave_context_var => "APP_PACKAGE=gwt-petstore.war",
                :num_slaves        => 2,
                :slavedata         => "8080",
                :elasticity_policy   => {
                                      :mode => 'time-based',
				      :windows =>  {
                                           'morn'  =>   {:spec => 'Mon-Fri 0900-1300', :min => 4},
                                           'aft'  =>   {:spec => 'Mon-Fri 1300-1700', :min => 3},
                                           'night'  => {:spec => 'Mon-Fri 0000-0859 1700-2359', :min => 2},
                                      }},
                :adminuser         => "rimadmin",
                :app_url           => "http://%MASTER%:8080/gwt-petstore"
         },


	'jenkins' => {
                :type => "compute",
                :description => "Jenkins CI Build Tool Cluster",
                :endpoint => "mm01",
		:master_template   => "ubuntu1104-medium",
                :master_context_script =>  "jenkins.sh",
                :master_context_var => "FOO=bar",
		:master_setup_time => 30,
		:slave_template    => "ubuntu1104-small",
                :slave_context_script => "jenkinsslave.sh",
                :slave_context_var       => "\"JENKINS_MASTER=%MASTER%, SLAVE_ID=%SLAVE_INDEX%\"",
                :num_slaves        => 2,
                :adminuser         => "rimadmin",
                :app_url           => "http://%MASTER%:8080/"
	 },

	'hbase' => {
                :type => "data",
                :description => "Hbase NoSQL Cluster Database",
                :endpoint => "mm01",
		:master_template   => "ubuntu1104-medium",
                :master_context_script =>  "hbasemaster.sh",
		:master_setup_time => 180,
		:slave_template    => "ubuntu1104-medium",
                :slave_context_script => "hbaseslave.sh",
                :slave_context_var       => "\"HBASE_MASTER=%MASTER%, SLAVE_ID=%SLAVE_INDEX%\"",
                :num_slaves        => 2,
                :adminuser         => "rimadmin",
                :app_url           => "http://%MASTER%:60010/"
	 },


        'redis' => {
                :type => "data",
                :description => "Redis Master-Slave Key-Value Store",
                :endpoint => "mm01",
                :master_template   => "ubuntu1104-small",
                :master_context_script =>  "redis.sh",
                :master_setup_time => 60,
                :slave_template    => "ubuntu1104-small",
                :slave_context_script => "redisslave.sh",
                :slave_context_var       => "\"REDIS_MASTER=%MASTER%, SLAVE_ID=%SLAVE_INDEX%\"",
                :num_slaves        => 1,
                :adminuser         => "rimadmin",
                :app_url           => "http://%MASTER%:6379/"
         },


        'cassandra' => {
                :type => "data",
                :description => "Cassandra NoSQL database",
                :endpoint => "mm01",
                :master_template   => "ubuntu1104-small",
                :master_context_script =>  "cassandra.sh",
                :master_context_var => "\"MOUNTLIST=172.30.53.23:\\/vol\\/data{1-6},\"",
                :master_setup_time => 60,
                :slave_template    => "ubuntu1104-small",
                :slave_context_script => "cassandra.sh",
		:slave_context_var       => "\"SLAVE_ID=%SLAVE_INDEX%, NUM_SLAVES=%NUM_SLAVES%, SEEDS=%MASTER%, MOUNTLIST=172.30.53.23:\\/vol\\/data{1-6},\"",
                :num_slaves        => 2,
                :adminuser         => "rimadmin",
                :app_url           => "http://%MASTER%:8080/"
         },


	'l7gateway' => {
                :type => "network",
                :description => "Load-balanced L7 Web Service Gateway Cluster",
                :endpoint => "mm01",
		:master_template   => "ubuntu1104-small",
                :master_context_script =>  "balance.sh",
		:master_setup_time => 30,
                :master_context_var => "BALANCE_PORT=8080,",
		:slave_template    => "centos6-medium",
                :slave_context_script => "l7gateway.sh",
                :slave_context_var       => "\"CLUSTER_HOST=%MASTER%, MEMBER_ID=%SLAVE_INDEX%,\"",
                :num_slaves        => 1,
                :adminuser         => "rimadmin",
                :app_url           => "http://%MASTER%/"
        },

        'analytics' => {
                :type => "group",
                :description => "BI Analytics environment with Hbase data store and Tomcat cluster for processing",
                :members => [ 'hbase' , 'jenkins', 'tomcat' ],
                :dependencies => { 'tomcat' => ['hbase', 'jenkins'],
				   'jenkins' => ['hbase'] }
        },

       'tomcat_ha' => {
                :type => "group",
                :description => "Tomcat Active-Passive cluster configuration",
                :members => [ 'tomcat_ha_active' , 'tomcat_ha_passive' ],
                :dependencies => { 'tomcat_ha_passive' => ['tomcat_ha_active']}
        },

}
