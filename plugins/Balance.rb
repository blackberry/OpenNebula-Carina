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

class Balance < Plugin
    def initialize
        @lastCheckTime = Time.now - 60
        @netTxRate = 0
        @netRxRate = 0
        @connRate = 0
        @totalConn = 0
        @lastCount = 0
        @lastTotalCount = 0
        @lastSent = 0
        @lastRecv = 0
    end

    def netTxRate(envid)
       getBalanceInfo(envid)
       return @netTxRate
    end

    def netRxRate(envid)
       getBalanceInfo(envid)
       return @netRxRate
    end

    def connectRate(envid)
       getBalanceInfo(envid)
       return @connRate 
    end

    def numConnections(envid)
       getBalanceInfo(envid)
       return @totalConn 
    end
  
    def getBalanceInfo(envid)
         now = Time.now
         elapsedTime = now - @lastCheckTime 
         if elapsedTime < 120.0 
             return
         end
         @lastCheckTime = now
         env = $envManager.getEnv(envid)
         vmList = env.getVMList()
         # Find the IP address of the master VM
         masterip=""
         vmList.each { |vm|
             if env.mastervmid == vm.vmid
                 masterip = vm.ipaddress
                 break
             end
         }
         defuser = "rimadmin"
         cmd = "ssh -o StrictHostKeyChecking=no #{defuser}@#{masterip} /home/#{defuser}/balance.sh show"
         validoutput = false
         IO.popen(cmd)  { |f|
             count = totalc = sent = rcv = 0
             loop do
                 if f.eof
                     break
                 end
                 v = f.readline
                 # Throw away header line
                 if v.index("GRP") != nil
                     validoutput=true
                     next
                 end
                 nv = v.split
                 count += nv[6].to_i
                 totalc += nv[7].to_i
                 sent += nv[9].to_i
                 rcv += nv[10].to_i
             end
             if validoutput == true
                 @netTxRate = (sent - @lastSent) / elapsedTime
                 @netRxRate = (rcv - @lastRecv) / elapsedTime
                 @connRate = (totalc - @lastTotalCount) / elapsedTime
                 @totalConn = count
                 @lastSent = sent
                 @lastRecv = rcv 
                 @lastTotalCount = totalc
                 puts "netTxRate=#{@netTxRate} netRxRate=#{@netRxRate} totalConn=#{@totalConn} connRate=#{@connRate}"
              else
                 puts "Balance plugin: Invalid output from popen"
              end
         }
    end

    def getMetrics
       return ['numConnections','connectRate','netTxRate', 'netRxRate']
    end
end
