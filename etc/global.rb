SHAREDPOOLS = {
    'pool1' => {
        :zone => 'helix',
        :allocateable_cpus => '5',
        :allocateable_mem => '4096',
        :service_class => 'bronze'
     },

    'mm01' => {
        :zone => 'flame',
        :allocateable_cpus => '2',
        :allocateable_mem  => '2048',
        :service_class     => 'silver'
     },

    'pool3' => {
        :zone => 'flame',
        :allocateable_cpus => '100',
        :allocateable_mem  => '102400',
        :service_class     => 'gold'
     }

}

SERVICES = {
   'service1' => {
        :priority => 'silver',
        :maxcpus => '12',
        :maxmemory => '64000',
    },

   'service2' => {
        :priority => 'gold',
        :maxcpus => '12',
        :maxmemory => '64000',
    }
}

