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

class VMStatus  < Plugin
    def initialize
        @nummissing=0
        @numunknown=0
        @numfailed=0
        @numvms = 0
        @lastCheckTime = Hash.new
    end

    def getVMStatus(envid)
        now= Time.now
        elapsedTime=0
        if @lastCheckTime[envid] != nil
             elaspedTime = now - @lastCheckTime[envid]
             return if elapsedTime < 30
        end
        @lastCheckTime[envid]=now
       
        env = $envManager.getEnv(envid)
        vmList = env.getVMList()
        mastervmfailed=false
        vmList.each { |vm|
            @numvms += 1
            @nummissing += 1 if vm.status == "MISSING"
            @numunknown += 1 if vm.status == "UNKNOWN"
            @numfailed += 1    if vm.status == "FAILED"
         }
    end

    def numvms(envid)
        getVMStatus(envid)
        return @numvms
    end

    def nummissing(envid)
        getVMStatus(envid)
puts "nummissing=#{@nummissing}"
        return @nummissing
    end

    def numunknown(envid)
        getVMStatus(envid)
        return @numunknown
    end

    def numfailed(envid)
        getVMStatus(envid)
        return @numfailed
    end
 

    def getMetrics
       return ['numvms', 'nummissing', 'numunknown', 'numfailed']
    end

    def getMetrics
       return ['numvms', 'nummissing', 'numunknown', 'numfailed']
    end
end
