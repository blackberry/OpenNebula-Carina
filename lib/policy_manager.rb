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

class PolicyManager

    def initialize(envManager, pluginManager, lock)
        @envManager = envManager
        @pluginManager = pluginManager
        @lock = lock
        @elasticityCounter = Hash.new
        @recreateCounter = Hash.new
        @failoverCounter = Hash.new
        @failbackCounter = Hash.new
    end

    private
    def evalloadpolicy(env,policy)

        # This handles the load-based policy. We compute the average cpu load
        # across all VMs in the environment and then evaluate the scaleup/down
        # expressions
        $Logger.debug "PM: Calculating VM cpu usage of environment"
         vms = env.getVMList()
         numVms = 0
         totCpu = 0
         vms.each { |vm|
             totCpu = totCpu + vm.cpu.to_i
             numVms = numVms + 1
         }
         if numVms == 0
             envAvgCpu = 0
         else
             envAvgCpu = totCpu / numVms 
         end
         $Logger.info "PM: Average cpu is #{envAvgCpu}"
         env.metrics = "avgcpu[#{envAvgCpu}]"

         if policy[:scaleup_expr] == nil || policy[:scaledown_expr] == nil 
             $Logger.info "PM: No scaleup and scaledown expression for policy #{env.envid}"
             return 
         end
         avgcpu = envAvgCpu
         if policy[:metric_plugins] != nil
             scaleup_result = @pluginManager.evaluateExpr( policy[:metric_plugins], policy[:scaleup_expr], env.envid)
             scaledown_result = @pluginManager.evaluateExpr( policy[:metric_plugins], policy[:scaledown_expr], env.envid)
         else
             scaleup_result=eval(policy[:scaleup_expr])
             scaledown_result=eval(policy[:scaledown_expr])
         end
         if scaleup_result == true && scaledown_result == true
             env.info = "POLICY_STATUS: Scale up and down expressions both true. Check policy definition."
             $Logger.error "PM: Scale up and scale down expressions both true. Possible error in policy configuration for #{env.envid}"
             return 
         end

         action = "none"
         @elasticityCounter[env.envid] = "0" if @elasticityCounter[env.envid] == nil

         if numVms < policy[:min].to_i  
             scaleup_result = true
             scaledown_result = false
         end
         if numVms > policy[:max].to_i 
            scaledown_result = true
            scaleup_result = false
         end
                   
         if scaleup_result == true && numVms < policy[:max] 
             action = "scaleup"
             newval = @elasticityCounter[env.envid].to_i + 1
             @elasticityCounter[env.envid] = newval.to_s
             env.info= "POLICY_STATUS: Scale up counter incremented to #{@elasticityCounter[env.envid]}"
             $Logger.debug "PM: Incrementing threshold @counter to create VM counter=#{@elasticityCounter[env.envid]}"
         end

         if scaledown_result == true && numVms > policy[:min] 
              action = "scaledown"
              newval = @elasticityCounter[env.envid].to_i + 1
              @elasticityCounter[env.envid] = newval.to_s
              env.info = "POLICY_STATUS: Scale down @elasticityCounter incremented to #{@elasticityCounter[env.envid]}"
              $Logger.debug "PM: Incrementing threshold @elasticityCounter to destroy VM @elasticityCounter=#{@elasticityCounter[env.envid]}"
         end

         if action == "none"
              @elasticityCounter[env.envid] = "0"   
              $Logger.debug "PM: Resetting threshold count " 
         elsif @elasticityCounter[env.envid].to_i > policy[:period].to_i
              if policy[:mode] == 'auto'
                  $Logger.info "PM: Triggering action " + action + " on environment #{env.envid} " 
                   priority=0
                   priority = policy[:priority] if policy[:priority] != nil
                   if action == "scaleup"
                        env.scaleup(false, priority)
                   else
                        env.scaledown(false, nil)
                   end
               else
                   env.info = "POLICY_STATUS: Recommend action #{action}"
                   $Logger.info "PM: Recommend action #{action} on environment #{env.envid}" 
               end
               @elasticityCounter[env.envid] = "0"   
          else
               $Logger.debug "PM: No action taken for env " + env.envid.to_s
          end
    end

    # Evaluate time expression to determine whether to auto-scale up or down
    # This allows the setting of policies for environments where the workload
    # is predictable (day/night, weekday/weekends,etc). 
    private
    def evaltimepolicy(env, policy)
       $Logger.debug "In evaltimepolicy for env #{env.envid}"
       windows = policy[:windows]
       if windows == nil
           puts "No time windows specified"
           return
       end
       now = Time.now
       windows.keys.each { |w|
           spec = policy[:windows][w][:spec]
           ws = TimeWindow.new(spec) 
           if ws.include?(now)
               #If we are in the time window than either increase or decrease
               #the number of instances to match the minimum
               size = env.getVMList.size
               if size  <  policy[:windows][w][:min]
                   $Logger.info "Scaling up #{env.envid} to meet minimum"
                   env.info = "POLICY_STATUS: Scaling up to meet minimum #{policy[:windows][w][:min]} for time window #{w}"
                   priority=0
                   if policy[:priority] != nil
                       priority = policy[:priority]
                   end
                   # Don't trigger another scaleup if we have
                   # already made enough  requests to the global scheduler
                   if $useGlobalScheduler == true 
                       if size + env.gsOutStandingReqs <= policy[:windows][w][:min]
                           env.scaleup(false, priority)
                       end
                   else
                        env.scaleup(false, priority)
                   end
               else
                   if size > policy[:windows][w][:min]
                      $Logger.info "Scaling down #{env.envid} to meet minimum"
                      env.info = "POLICY_STATUS: Scaling down to meet minimum #{policy[:windows][w][:min]} for time window #{w}"
                      env.scaledown(true, nil)
                   else
                      $Logger.info "Env #{env.envid} is at desired size in time window #{w}"
                   end
               end
               # Ignore other windows as we assume non-overlapping windows configured in policy
               return
           end
       }
    end

    private
    def evalelasticitypolicy(env, policy)
        if policy == nil
            $Logger.debug "PM: No elasticity policy for env #{env.envid}"
            return 
        end
        if policy[:mode]  == nil
            $Logger.debug "PM: Policy mode is not defined or unknown for #{env.envid}"
            return 
        end

        if policy[:mode] == 'manual'
            $Logger.debug "PM: Policy is in manual mode for  #{env.envid}"
            return 
        end

        # Don't apply elasticity policies to environments which are
        if env.policy_status != "ACTIVE" 
            $Logger.debug "PM: Elasticity policies not applied to PASSIVE or FAILED env  #{env.envid}"
            return
        end
        if policy[:mode] == 'time-based'
            evaltimepolicy(env,policy)
        end
        if policy[:mode] == 'auto'
            evalloadpolicy(env, policy)
        end
    end

    private
    def failoverEnv(env, policy)
        env.policy_status = "FAILED" 
        env.info="AVAIL_POLICY_STATUS: Declaring environment as FAILED and triggering failover"
        @envManager.updateEnvPolicyStatusInDb(env)
        #Find the corresponding passive environment in same failover group
        group = policy[:failover_group]
        envs = @envManager.getEnvs()
        envs.each { |e|
            if e.envid != env.envid && e.name != nil && ENVIRONMENT[e.name][:availability_policy] != nil
                egroup = ENVIRONMENT[e.name][:availability_policy][:failover_group]
                erole = ENVIRONMENT[e.name][:availability_policy][:failover_role]
                next if egroup == nil || erole == nil
                # Mark this environment as ACTIVE so that elasticity policies can be applied
                if egroup == group && erole == "passive"
                     e.policy_status = "ACTIVE"
                     e.info = "AVAIL_POLICY_STATUS: Making environment ACTIVE due to failover of primary environment #{env.envid}"
                     @envManager.updateEnvPolicyStatusInDb(e)
                     return
                end
            end
        }
        env.info="AVAIL_POLICY_STATUS: Environment declared in FAILED state but no environment to failover to"
    end

    private
    def failbackEnv(env, policy)
        env.policy_status = "ACTIVE" 
        env.info="AVAIL_POLICY_STATUS: Failing back environment to ACTIVE status"
        @envManager.updateEnvPolicyStatusInDb(env)
        #Find the corresponding passive environment in same failover group
        group = policy[:failover_group]
        envs = @envManager.getEnvs()
        envs.each { |e|
            if e.envid != env.envid && e.name != nil && ENVIRONMENT[e.name][:availability_policy] != nil
                egroup = ENVIRONMENT[e.name][:availability_policy][:failover_group]
                erole = ENVIRONMENT[e.name][:availability_policy][:failover_role]
                next if egroup == nil || erole == nil
                # Mark this environment as ACTIVE so that elasticity policies can be applied
                if egroup == group && erole == "passive"
                     e.policy_status = "PASSIVE"
                     e.info = "AVAIL_POLICY_STATUS: Making environment PASSIVE after failing back to primary enviornment #{env.envid}"
                     @envManager.updateEnvPolicyStatusInDb(e)
                     return
                end
            end
        }
        env.info "AVAIL_POLICY_STATUS: Environment delcared as ACTIVE but failover environment missing"
    end


    private
    def evalavailabilitypolicy(env, policy)
        if policy == nil
            $Logger.debug "PM: No availabilty policy for env #{env.envid}"
            return
        end
        # Calculate counters for the environment
        nummissing=0
        numunknown=0
        numfailed=0
        numvms = 0
        targetvm = nil
        vmList = env.getVMList()
        mastervmfailed=false
        vmList.each { |vm|
             if vm.envid == env.envid
                 numvms += 1
                 nummissing += 1 if vm.status == "MISSING"
                 numunknown += 1 if vm.status == "UNKNOWN"
                 numfailed += 1    if vm.status == "FAILED"
                 targetvm = vm if vm.status == "MISSING" || vm.status == "UNKNOWN" || vm.status == "FAILED"
                 mastervmfailed = true if vm.vmid == env.mastervmid && (vm.status== "MISSING"  || vm.status == "UNKNOWN" || vm.status == "FAILED")
             end
        }
        # Make sure to restart master first before any slaves
        targetvm == env.mastervmid if mastervmfailed == true
        # Check if we should be re-creating any VMs 
        if policy[:recreate_expr] != nil
            recreate_result = eval(policy[:recreate_expr])
            @recreateCounter[env.envid] = "0" if @recreateCounter[env.envid] == nil
            if recreate_result == true
                newval = @recreateCounter[env.envid].to_i + 1
                @recreateCounter[env.envid] = newval.to_s
                if newval > policy[:period]
                    if $jobManager.isJobRunning(env.envid) == false
                        env.info = "AVAIL_POLICY_STATUS: Recreating VM #{targetvm.vmid}"
                        env.recreateVM(targetvm)
                        @recreateCounter[env.envid] = "0"
                    end
                else
                    env.info = "AVAIL_POLICY_STATUS: Detected missing VM counter=#{@recreateCounter[env.envid]} period=#{policy[:period]}"
                end
            end
         end
         # Determine if the entire environment should be considered as failed 
         if policy[:failover_expr] != nil  && env.policy_status == "ACTIVE"
             if policy[:failover_role] == "active" 
                failover_result = eval(policy[:failover_expr])
                @failoverCounter[env.envid] = "0" if @failoverCounter[env.envid] == nil
                if failover_result == true 
                    newval = @failoverCounter[env.envid].to_i + 1
                    @failoverCounter[env.envid] = newval.to_s
                    if newval > policy[:period] 
                        failoverEnv(env, policy)
                        @failoverCounter[env.envid] = "0"
                    else
                        env.info = "AVAIL_POLICY_STATUS: Failover condition is true counter=#{@failoverCounter[env.envid]} period=#{policy[:period]}"
                    end
                end
             end
         end

         # Determine if the entire environment should failed back 
         if policy[:failback_expr] != nil  && policy[:failover_role] == "active" && env.policy_status == "FAILED"
             failback_result = eval(policy[:failback_expr])
             @failbackCounter[env.envid] = "0" if @failbackCounter[env.envid] == nil
             if failback_result == true 
                 newval = @failbackCounter[env.envid].to_i + 1
                 @failbackCounter[env.envid] = newval.to_s
                 if newval > policy[:period] 
                     failbackEnv(env, policy)
                     @failbackCounter[env.envid] = "0"
                 else
                     env.info = "AVAIL_POLICY_STATUS: Failback condition is true counter=#{@failbackCounter[env.envid]} period=#{policy[:period]}"
                 end
             end
         end

         # After a failback we want to check for PASSIVE environments
         # which were scaled up before and scale them back down
         if policy[:failover_role] == "passive"  && 
               env.policy_status == "PASSIVE" && env.hasgsToken() == true && 
               $jobManager.isJobRunning(env.envid) == false
               env.scaledown(true,nil)
         end
    end

    private 
    def validatePolicy(env)
        # Environment not found in config.rb so no policy exists
        if ENVIRONMENT[env.name] == nil
            env.info = "POLICY_STATUS: Environment #{env.name} not found" 
            return false
        end
        policy = ENVIRONMENT[env.name][:availability_policy]
        if policy != nil
             if policy[:failover_expr] != nil  && (policy[:failover_role] == nil || policy[:failover_group] == nil)
                 $Logger.debug " Bad availabilty policy #{env.envid}"
                 env.info = "POLICY_STATUS: Incorrect availabilty policy configuration" 
                 return false 
             end
        end
        return true
    end
 
    # Main loop for thread  evaluating policies on running environments. Each environment
    # is evaluated against the policy that is specified for it and decision is made
    # to scale it up / down / recreate VMs based on various conditions.
    public
    def run ()
       configrbfile = ENV["HOME"] + "/config.rb"
       require configrbfile
       lastMtime = File.mtime(configrbfile)
       loop do
           @lock.synchronize {
               newMtime = File.mtime(configrbfile)
               if newMtime != lastMtime
                   $Logger.info "PM: Reloading config.rb "
                   $configList.load() 
                   lastMtime = newMtime
               end
               $Logger.info "PM: Loading environments and usage data"
               @envManager.loadAll()
               @envManager.loadVMInfo()
               envs = @envManager.getEnvs()
               if envs == nil
                  $Logger.info "PM: No environments loaded"
               else 
                  envs.each { |env|
                      $Logger.debug "PM: Checking against policy for env #{env.envid} with name = #{env.name}"
                      if validatePolicy(env) == false
                          next
                      end
                      epolicy = ENVIRONMENT[env.name][:elasticity_policy]
                      apolicy = ENVIRONMENT[env.name][:availability_policy]
                      # Don't apply any policy until environment is READY (
                      # creation of initial cluster has succeeded)
                      if env.policy_status == "INIT"
puts "Policy status still in INIT state for #{env.envid}"
                         next
                      end
                      if env.policy_status == "READY"
                          # Put into ACTIVE or PASSIVE state
                          env.policy_status = "ACTIVE"
                          if apolicy != nil && apolicy[:failover_role] != nil 
                              env.policy_status = "PASSIVE" if apolicy[:failover_role] == "passive" 
                          end
                          $envManager.updateEnvPolicyStatusInDb(env)
                      end
                   
                      evalavailabilitypolicy(env,apolicy)
                      evalelasticitypolicy(env,epolicy)
                  }
                  # Schedule based on local priority if global scheduler not 
                  # enabled
                  if $useGlobalScheduler == false
                       $jobManager.schedule()
                  end
               end 
           }
           sleep 60
        end
        $Logger.error "Exiting run loop..shouldn't get here"
     end
end
