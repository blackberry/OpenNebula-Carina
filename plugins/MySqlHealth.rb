# -------------------------------------------------------------------------- #
# Copyright 2011-2012, Research In Motion Limited                            #
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
#
# This plugin checks the health of MySQL instances in an environment. It 
# assumes all VMs in the envrionment will run MySQL server and uses the
# 'mysqladmin ping' command to check

class MySqlHealth < Plugin
    def initialize
    end

    # Returns 1 if MySQL is alive on all VMs in an environment or 0 if any VM has a failed mysql

    def mysqlHealth(envid)
         now = Time.now
         env = $envManager.getEnv(envid)
         vmList = env.getVMList()
         vmList.each { |vm|
             cmd = "ssh carina@#{vm.ipaddress}  mysqladmin ping"
             lineread = false
             IO.popen(cmd)  { |f|
                 if f.eof
                     if !lineread
                         $Logger.debug "MySqlHealthPlugin: mysqld is not alive - no output from mysqladmin ping"
                         vm.status = "SICK"
                         return 0
                     end
                     break
                 end
                 v = f.readline
                 puts "MySqlHealthPlugin: Processing line: #{v}"
                 lineread=true
                 if !v.include? 'is alive'
                     $Logger.debug "MySqlHealthPlugin: mysqld is not alive"
                     vm.status = "SICK"
                     return 0
                 end
             }
         }
         $Logger.debug "MySqlHealthPlugin: mysqld is  alive"
         return 1
    end

    def getMetrics
       return ['mysqlHealth']
    end
end
