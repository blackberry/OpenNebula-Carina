#!/usr/bin/env ruby
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

class GSchedProxy 
     def initialize
        @redisip  = ENV["GS_REDIS_IP"]
        @redisport  = ENV["GS_REDIS_PORT"]
        @redisout = Redis.new(:host => @redisip, :port => $redisport) 
     end

     def register()
         r = Register.new("REGISTER", $zone, $service) 
         r.port = $port
         r.host = UDPSocket.open {|s| s.connect("64.233.187.99", 1); s.addr.last}
         reg = r.to_json
         @redisout.publish("svc", reg)
     end


     def request(envid, envname, vcpus, mem, pool)
         r = Request.new("ALLOCATE", $zone, $service)
         r.mem = mem
         r.vcpus = vcpus
         r.envid = envid
         r.env = envname
         r.pool =  pool
         req = r.to_json
         @redisout.publish("svc", req)
     end

     def release(token)
         if token == nil
             return
         end
         r = Release.new("RELEASE", token)
         rel = r.to_json
         @redisout.publish("svc", rel)
     end

     def cancel(envid)
         c = Cancel.new("CANCEL", $zone, $service, envid)
         can = c.to_json
         @redisout.publish("svc", can)
     end


     # Process either a GRANT or RECLAIM message from the GS
     def processmsg(channel, msg)
         $Logger.debug "Processing message #{msg} on channel #{channel}"
         if channel == "glob-sched"
              if msg.include? "STARTUP"
                  # This delay is to allow the global scheduler to enter its
                  # subscribe loop after it has sent out the STARTUP message
                  sleep 2
                  register()
              end
         end
         if msg.include? "GRANT" 
             g = Grant.new("","","","","","")
             g.from_json(msg)
             $jobManager.scheduleglobal(g.envid, g.reqid)
         end 
         if msg.include? "INITIALIZE" 
             g = Initialize.new("")
             g.from_json(msg)
             $envManager.restoreReqIds(g.reqIds) 
         end
         if msg.include? "RECLAIM" 
              r = Reclaim.new("","","")
              r.from_json(msg)
              e = $envManager.getEnv(r.envid)
              e.scaledown(true, r.reqid)
         end
     end

     def run(lock)
         redis = Redis.new(:host => ENV["GS_REDIS_IP"], :port => ENV["GS_REDIS_PORT"]) 
         channel = $service + "-" + $zone
         # Each oneenvd susbscribes on its own service-specific channel plus a 
         # channel the GS uses to indicate when it is starting up
         redis.subscribe(channel,"glob-sched") do |on|
              on.message do |channel, msg|
                  lock.synchronize {
                      processmsg(channel, msg)
                  }
            end
        end
     end
end

