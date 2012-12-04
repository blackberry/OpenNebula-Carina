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


class Helper
    def self.closeFds()
         keepers = [STDIN,STDOUT,STDERR]
         ObjectSpace.each_object(IO) do |io|
             if not io.closed? and not keepers.include?(io)
                 io.close()
             end
         end
    end
end

class EnvConfig
    attr_accessor :paramfile
    attr_accessor :name
    attr_accessor :type
    attr_accessor :endpoint

    def initialize(name, desc, endpoint, params, type)
        @endpoint= endpoint
        @name = name
        @desc = desc
        @paramfile = params
        @type = type
    end

    def insertindb(con,gid) 
        envid = -1
        sqlstr = "INSERT INTO #{$APPENVTABLE} (status, policy_status, name, svcid, groupid) values ('INIT', 'INIT', \'#{@name}\', \'#{$SVCID}\', \'#{gid}\')  "
        rs = con.query(sqlstr)
        rs = con.query("SELECT LAST_INSERT_ID();")
        rs.each_hash { |h|
             envid = h['LAST_INSERT_ID()']
             $Logger.debug "Created new env entry in DB for env #{@name} with id #{envid}"
        }
        return envid 
    end

    # Create an environment from a configuration. The 'job' parameter indicates
    # if the corresponding CREATE job for the environment already exists (which
    # will happen if the job is part of group environment) or if a new job must
    # be defined (for a non-group environment)
    def launch(job,con)
        if job != nil
            gid = $jobManager.findParentEnvIdForJob(job)
        else
            gid = -1
        end
        envid = insertindb(con,gid)
        if envid == "-1" 
            $Logger.error "Could not insert environment into DB"
            return envid, "-1"
        end
        childpid=Kernel.fork
        if childpid == nil
             if job != nil && job.dependstr != ""
                 execString = $SVCBIN  + " -n " + @name +  " -i " + envid + " -c " + @paramfile + " -f " + job.dependstr +  " -s;"
             else
                 execString = $SVCBIN  + " -n " + @name +  " -i " + envid + " -c " + @paramfile + " -s;"
             end
             Helper.closeFds()
             $stdout.reopen($ENVLOGFILE + ".#{envid}",'a+')
             $stderr.reopen($ENVLOGFILE + ".#{envid}",'a+')
             Process.setsid
             exec(execString)
             puts "Should not get here"
             exit
        end
        if job == nil
            jobid= $jobManager.register(childpid, envid, "CREATE", @name, "RUNNING", 0)
        else
            $jobManager.trigger(job,childpid,envid)
            jobid = job.jobid
        end
        return envid,jobid
    end

    def to_json(*a)
    {
      "endpoint"   => @endpoint,
      "name" => @name, 
      "desc" => @desc,
      "type" => @type
    }.to_json(*a)
    end
 
    def self.json_create(o)
        new(o["endpoint"]["string"], o["name"]["string"], o["desc"]["string"])
    end

end

class EnvConfigs
     def initialize(con)
        @configList=Array.new
        @con = con
     end

     def add(c)
         @configList.push(c)
     end

     def getDBConnection()
         return @con
     end


     # Check that the authinfo for the end-points is for the OS
     # account that this oneenvd is running against
     def validate(file)
         Kernel::load file
         ENDPOINT.each_key do |k|
             auth = ENDPOINT[k][:oneauth]
             # auth is of the form 'flm01-oneenv1:passwd'  and we just want 'oneenv1' to match against OS
             # account we are running under 
             name = auth.split(":",2).first
             name = name.split("-",2).last
             if name != ENV["USER"]
                 $Logger.error "User attempting to upload invalid config.rb with user name of #{name} instead of #{ENV["USER"]}  for this service"
                 return false
             end
         end

         return true
     end
 
     def load()
         Kernel::load ENV["HOME"] + "/config.rb"

         @configList.clear

         ENVIRONMENT.each_key do |k|
            c= EnvConfig.new("#{k}", ENVIRONMENT[k][:description], ENVIRONMENT[k][:endpoint], $WORKDIR + "/envconfig.#{k}", ENVIRONMENT[k][:type])
            @configList.push(c)
            if ENVIRONMENT[k][:type] == "group"
                next
            end
        
            f=File.open($WORKDIR + "/envconfig.#{k}","w+")
            ENVIRONMENT[k].each_pair do |n,v|
                name = "#{n}"
                name = name.upcase
                value = "#{v}"
                if name == "MASTER_TEMPLATE" || name == "SLAVE_TEMPLATE" || name == "ELASTICITY_POLICY" || name == "AVAILABILITY_POLICY" || name == "DESCRIPTION"
                   next
                end
                f.write( name + "=" + value + "\n")
            end
            endpoint=ENVIRONMENT[k][:endpoint]
            template=ENVIRONMENT[k][:master_template]
            f.write("MASTER_TEMPLATE=" + "#{TEMPLATE[template][:file]}\n")
            f.write("MASTER_NUM_CPUS=" + "#{TEMPLATE[template][:cpu]}\n")
            f.write("MASTER_MEMORY=" + "#{TEMPLATE[template][:memory]}\n")
            f.write("MASTER_IMAGE_ID=" + "#{TEMPLATE[template][:image_id][endpoint]}\n")
            f.write("MASTER_NETWORK_ID=" + "#{TEMPLATE[template][:network_id][endpoint]}\n")
            f.write("MASTER_VM_NAME=" + "#{k}-m\n")

            template=ENVIRONMENT[k][:slave_template]
            f.write("SLAVE_TEMPLATE=" + "#{TEMPLATE[template][:file]}\n")
            f.write("SLAVE_NUM_CPUS=" + "#{TEMPLATE[template][:cpu]}\n")
            f.write("SLAVE_MEMORY=" + "#{TEMPLATE[template][:memory]}\n")
            f.write("SLAVE_IMAGE_ID=" + "#{TEMPLATE[template][:image_id][endpoint]}\n")
            f.write("SLAVE_NETWORK_ID=" + "#{TEMPLATE[template][:network_id][endpoint]}\n")
            f.write("SLAVE_VM_NAME=" + "#{k}-s\n")
            f.close

         end
     end

     def getbyname(name)
        @configList.each do |config|
            if config.name == name
                return config
            end
        end
        return nil
     end

     def get(i)
         return @configList[i]
     end

     def getList
         @configList
     end

     # Store the config.rb in DB for replication
     def insertindb 
         file = File.open(ENV["HOME"]+ "/config.rb") 
         content = file.read
         stmt = @con.prepare "UPDATE #{$SVCTABLE} SET config=?  WHERE svcid='#{$SVCID}';"
         rs = stmt.execute content 
         stmt.close
     end
end

class VM
    attr_accessor :cpu
    attr_accessor :mem
    attr_accessor :vmid
    attr_accessor :hostname
    attr_accessor :status
    attr_accessor :ipaddress
    attr_accessor :envid
    def initialize(vmid, hostname, ip, status, envid)
        @vmid=vmid
        @hostname = hostname
        @ip = ipaddress
        @status = status
        @envid = envid
        @cpu = -1
        @mem = 0
    end
    def to_json(*a)
     {
      "vmid"   => @vmid,
      "envid"   => @envid,
      "hostname"   => @hostname,
      "ipaddress" => @ipaddress,
      "status" => @status,
      "cpu" => @cpu
     }.to_json(*a)
    end
end

class Env
     attr_accessor :envid
     attr_accessor :name
     attr_accessor :url
     attr_accessor :metrics
     attr_accessor :status
     attr_accessor :policy_status
     attr_accessor :info
     attr_accessor :gsOutStandingReqs
     attr_accessor :mastervmid
     attr_accessor :groupid

     def initialize(envid, name, status, url, policy_status)
        @envid=envid
        @name=name
        @status=status
        @policy_status=policy_status
        @url=url
        @vms = Array.new
        @metrics=''
        @gsTokens=Array.new
        @gsOutStandingReqs = 0
        @info=''
        @mastervmid=0
        @groupid=nil
     end

     def addvm(vm)
        @vms.push(vm)
     end

     def resetVMs()
         @vms = Array.new
     end

     def getVMList()
         return @vms
     end

     def addgsToken(token)
         # Check for same token existing
         matches=@gsTokens.select{|t| t == token}
         if matches != nil && matches[0] != nil
             $Logger.error "Attempt to add duplicate token #{token} for environment #{@envid}"
             return
         end
         @gsTokens.push(token)
         @gsOutStandingReqs -= 1
         if  @gsOutStandingReqs < 0
             @gsOutStandingReqs = 0
         end
     end

     def removegsToken
         return @gsTokens.shift
     end

     def hasgsToken
         if @gsTokens.size > 0
            return true
         else
            return false
         end
     end
   
     # Add another  VM to the environment. If 'now' is false, then a job
     # will be created which will get scheduled (either locally through the
     # job_manager or through global scheduler). Otherwise the scaleup job
     # is launched immediately.
     def scaleup(now, priority)
        if now == false 
           # Job will be examined and run by scheduler later
           jid = $jobManager.register(-1, @envid, "SCALEUP", @name, "READY", priority)
           # Make a request to the global scheduler for capacity
           if $useGlobalScheduler == true
               template=ENVIRONMENT[@name][:slave_template]
               if template == nil
                   $Logger.error "scaleup: unable to find slave template for env #{@name} envid #{@envid}"
                   return
               end
               # Put a cap on number of requests sent to global scheduler
               # NOTE: For time based policy the throttling is done in 
               # elastic_maanger/evaltimepolicy()
               if ENVIRONMENT[@name][:elasticity_policy] != nil &&
                  ENVIRONMENT[@name][:elasticity_policy][:max] != nil 
                   maxVMs = ENVIRONMENT[@name][:elasticity_policy][:max] 
               else
                   maxVMs=16
               end
               if @vms.size + @gsOutStandingReqs > maxVMs
                   $Logger.info "scaleup: Too many outstanding requests to global schduler #{@name} envid #{@envid}  outstanding #{@gsOutStandingReqs}"
                   return "Too many scale up requests outstanding"
               end
            
               vcpus = TEMPLATE[template][:cpu]
               mem   = TEMPLATE[template][:memory]
               $gsProxy.request(@envid, @name, vcpus, mem, ENVIRONMENT[@name][:endpoint])
               @gsOutStandingReqs += 1
           end
           return jid
        end
        paramfile = $WORKDIR +  "/envconfig." + @name
        execString = $SVCBIN +  " -c " + paramfile + " -u " + @envid
        childpid=Kernel.fork
        if childpid == nil
           Helper.closeFds()
           $stdout.reopen($ENVLOGFILE + ".#{@envid}",'a+')
           $stderr.reopen($ENVLOGFILE + ".#{@envid}",'a+')
           exec(execString)
        end
        jid = $jobManager.register(childpid, @envid, "SCALEUP", @name, "RUNNING", priority)
        return jid 
     end

     # Reduce the number of VMs in the environment
     def scaledown(now, gstoken)
        paramfile = $WORKDIR + "/envconfig." + @name
        execString = $SVCBIN + " -c " + paramfile + " -d " + @envid
        childpid=Kernel.fork
        if childpid == nil
           Helper.closeFds()
           $stdout.reopen($ENVLOGFILE + ".#{@envid}" ,'a+')
           $stderr.reopen($ENVLOGFILE + ".#{@envid}",'a+')
           exec(execString)
        end
        if $useGlobalScheduler == true
            # Global scheduler specifices specific token/reqid to remove
            # Otherwise when we are scaling down we remove any one of the
            # requests
            if gstoken != nil
               @gsTokens.delete(gstoken)
               $gsProxy.release(gstoken)
            else
               $gsProxy.release(removegsToken())
            end
        end
        jid = $jobManager.register(childpid, @envid, "SCALEDOWN", @name, "RUNNING", 0)
        return jid 
     end

     # Remove the environment
     def remove()
        # Remove any previously running creation job
        $jobManager.cancel(@envid)
        if $useGlobalScheduler == true
            # Release the requests we have gotten for the environment
            token = removegsToken()
            while token != nil do
                $gsProxy.release(token)
                token = removegsToken()
            end 
            # This will cancel any outstanding requests that are pending
            $gsProxy.cancel(@envid)
        end
        paramfile = $WORKDIR + "/envconfig." + @name
        execString = $SVCBIN +  " -c " + paramfile + " -r "  + @envid
        childpid=Kernel.fork
        if childpid == nil
           Helper.closeFds()
           $stdout.reopen($ENVLOGFILE + ".#{@envid}",'a+')
           $stderr.reopen($ENVLOGFILE + ".#{@envid}",'a+')
           exec(execString)
        end
        jid = $jobManager.register(childpid, @envid, "REMOVE", @name, "RUNNING", 0)
        return jid 
     end

 
     # Recreate a specific VM from the environment. This is called when we
     # detect that the VM has disappeared from ONE
     def recreateVM(vm)
         # Call the service controller to delete the VM and update the master
         paramfile = $WORKDIR + "/envconfig." + @name
         execString = $SVCBIN + " -c " + paramfile +  " -v " + vm.vmid + " -x " + @envid 
         childpid=Kernel.fork
         if childpid == nil
             $stdout.reopen($ENVLOGFILE + ".#{@envid}" ,'a+')
             $stderr.reopen($ENVLOGFILE + ".#{@envid}",'a+')
             exec(execString)
         end
         jid = $jobManager.register(childpid, @envid, "RECREATE", @name, "RUNNING", 0)
         return jid 
     end
   
     def to_json(*a)
     {
      "envid"   => @envid,
      "name" => @name, 
      "status" => @status,
      "policy_status" => @policy_status,
      "url" => @url,
      "numVMs" => @vms.size,
      "metrics" => @metrics,
      "gsTokens" => @gsTokens,
      "gsOutStandingReqs" => @gsOutStandingReqs,
      "info" => @info,
      "groupid" => @groupid,
     }.to_json(*a)
     end
end

class EnvManager
     def initialize(con)
         @envList = Array.new
         # List of all VMs across envioronments created by this oneenvd
         @vmList = Array.new   
         @numEnvs = 0
         @con = con
         @lastUsageLoad = Time.now
     end
 
     def getEnvs()
         $Logger.debug "EnvManager: returing envList with size " + @numEnvs.to_s + " " + @envList.size().to_s
         return @envList
     end

     def getVMs()
         return @vmList
     end


     # In order to avoid multipe oneenvds calling ONE to get the VM load
     # of all the VMs independently, we let one of them do it and save
     # results into a file which others read to look at their VMs
     def createVMLoadFile()
         if File.exists?($TMPVMLOADFILE) 
             lastMtime = File.mtime($TMPVMLOADFILE)
         else
             lastMtime = Time.now - 60
         end
         diff = Time.now - lastMtime
         if diff >  60.0
            tmpfile = File.new($TMPVMLOADFILE + ".new" ,File::CREAT|File::TRUNC|File::RDWR, 0644)
            IO.popen("onecmd -a onevm list") { |f|
                 loop do
                    v =  f.readline
                    tmpfile.write(v) 
                    if f.eof 
                        tmpfile.close()
                        break
                     end
                 end
            }
            File.rename($TMPVMLOADFILE + ".new", $TMPVMLOADFILE)
         end
     end

     def mapONEVMStatus(status)
         if status == "unkn"
             return "UNKNOWN"
         elsif status == "fail"
             return "FAILED"
         else 
             return status
         end
     end


     def loadVMInfo()
        $Logger.debug "Loading cpu usage of all VMS"

        # This oneenvd is reponsible for creating the VM file
        if $vmInfoLoader == true 
            createVMLoadFile()
        end
        if File.exists?($TMPVMLOADFILE) == false
           $Logger.error "File containing VM load info doesn't exist. Cant load VM usage data"
           return
        end
        if File.size($TMPVMLOADFILE) == 0
           $Logger.error "File containing VM load is empty. Cant load VM usage data"
           return
        end
        age = Time.now - File.mtime($TMPVMLOADFILE)
        # If the file is not being updated for some reason we don't want to use
        if age > 120.0
           $Logger.error "The information file #{$TMPVMLOADFILE} is too old to use"
           return
        end
      
        # Mark all VMs as MISSING and update status later if we find in ONE
        # Availability manager will recreate MISSING VMs
        @vmList.each { |vm|
           vm.status = "MISSING"
        }
        File.open($TMPVMLOADFILE,'r') { |f|
             loop do
                 if f.eof 
                    $Logger.debug "EOF reached in VM usage file"
                    break
                 end
                 v =  f.readline
                 if v.index("|") != nil || v.index("ID") != nil
                    next
                 end
                 nv  = v.split 
                 vmid = nv[0]
                 status = nv[4]
                 cpu = nv[5]
                 mem = nv[6]
                 match = @vmList.select{|vm| vm.vmid == vmid}
                 if match != nil && match[0] != nil
                     $Logger.debug "Updating " + match[0].vmid + " cpu usage to " + cpu
                      match[0].cpu = cpu
                      match[0].mem =  mem
                      match[0].status = mapONEVMStatus(status)
                      vm = match[0]
                      $Logger.debug "Updated value of #{vm.vmid} cpu is #{vm.cpu}" 
                 else
                      #puts "Does not match " 
                 end
           end
        }
        $Logger.debug "finished loading usage of all VMS"
     end

     def loadAll()
        $Logger.debug "Load all of the environments"
        rs = @con.query("SELECT envid,name, create_time, mastervmid, status, app_url, policy_status,groupid from #{$APPENVTABLE} where svcid=#{$SVCID}") 
        newEnvList = Array.new
        newNumEnvs = 0
        rs.each_hash{|h| 
           $Logger.debug "Processing environment " + h['envid']
           match = @envList.select{ |e1| e1.envid == h['envid'] }
           if match == nil || match[0] == nil
               e = Env.new( h['envid'], h['name'], h['status'], h['app_url'], h['policy_status'])
               e.mastervmid = h['mastervmid']
               e.groupid = h['groupid']
           else
               e = match[0]
               e.name = h['name']
               e.status = h['status']
               e.policy_status = h['policy_status']
               e.url = h['app_url']
               e.groupid = h['groupid']
           end
           e.mastervmid = h['mastervmid']
           newEnvList[newNumEnvs] = e
           newNumEnvs += 1
        }
        @envList = newEnvList
        @numEnvs = newNumEnvs

        # Get the VMs for each environment
        newVmList = Array.new
        @envList.each { |env|
             $Logger.debug  'Getting VMs for env ' + env.envid()
             # Retrieve all the VMs that are in the DB and update them 
             env.resetVMs()
             qs = "SELECT vmid,ipaddress,hostname,status  from #{$VMTABLE} where envid="+ env.envid()
             rs = @con.query(qs)
             rs.each_hash{ |vm|
                 match = @vmList.select{ |v1| v1.vmid == vm['vmid'] }
                 if match == nil || match[0] == nil
                     # New VM that wasn't there before
                     v = VM.new(vm['vmid'],vm['hostname'],vm['ipaddress'],vm['status'],env.envid)
                 else
                     v = match[0]
                     v.hostname = vm['hostname']
                     v.ipaddress = vm['ipaddress']
                     v.status = vm['status']
                 end
                 env.addvm(v)
                 newVmList.push(v)
             }
        }
        @vmList = newVmList
        $Logger.debug "Return from loading all the environments"
     end

     def loadEnv(envid)
        rs = @con.query("SELECT envid,name, create_time, mastervmid, status, app_url, policy_status,groupid from #{$APPENVTABLE} where envid=" + envid) 
        rs.each_hash{|h| 
           e = Env.new( h['envid'], h['name'], h['status'], h['app_url'], h['policy_status'])
           e.mastervmid = h['mastervmid']
           e.groupid = h['groupid']
           return e
        }
        return nil
     end
 
     def loadEnvVMs(envid)
         env = self.loadEnv(envid)
         if env == nil
             return nil
         end
         $Logger.debug 'Getting VMs for env #{envid}'
         qs = "select vmid,ipaddress,hostname,status  from #{$VMTABLE} where envid="+ env.envid()
         rs = @con.query(qs)
         rs.each_hash{ |vm|
             match = @vmList.select{ |v1| v1.vmid == vm['vmid'] }
             if match == nil || match[0] == nil
                v = VM.new(vm['vmid'],vm['hostname'],vm['ipaddress'],vm['status'], envid)
             else
                v = match[0]
             end
             env.addvm(v)
         }
         return env
     end
 
     def getConfigId(envid)
         e = self.loadEnv(envid)
         return e.name.split(":",2).last
     end

     def getConfigName(envid)
         e = self.loadEnv(envid)
         return e.name
     end

     def getEnv(envid)
         e = @envList.select{|e| e.envid == envid}
         if e == nil
             return nil
         end
         return(e[0])
     end

     # For scaleup requests we maintain list of ids / tokesn from
     # global scheduler for each VM that was scaled up. 
     def restoreReqIds(reqIdHash)
         reqIdHash.each { |reqId,envId|
              env = self.getEnv(envId)           
              if env == nil
                 $Logger.error "Unknown envid #{envId} returned by GS during synchronization.Should not happen. Forcing cancel of the environment." 
                 $gsProxy.cancel(envId)
                 next
              end
              env.addgsToken(reqId) 
         }
     end

     # Used for updating status for failover by the policy manager
     def updateEnvPolicyStatusInDb(env)
         rs = @con.query("UPDATE #{$APPENVTABLE}  SET policy_status='#{env.policy_status}' WHERE envid='#{env.envid}';")
     end
 
     def getServiceId(svcname)
        qs="SELECT svcid from #{$SVCTABLE} WHERE name='#{svcname}';"
        rs = @con.query(qs) 
        # Should only be one
        rs.each_hash{|h| 
            return h['svcid']
        }
        return nil
     end

     # Remove an env or env group. If 'gid' is negative all environments 
     # with the same
     #  gid' as well as a parent environment with an envid or 'gid'
     def removeEnv(gid)
        # If id 
        removegroup=false
        if gid[0].chr == "-" 
           gid.slice!(0)
           removegroup = true
        end
        parent = getEnv(gid)
        if parent  == nil
            return -1,"Environment not found"
        end
        jidList=""
        if removegroup == true
            @envList.each { |e| 
                if e.groupid == gid
                   jid = e.remove()
                   jidList = jidList + "," + jid
                end
            }
        end 
        # Now remove the parent env
        jid=parent.remove()
        jidList = jid + jidList
        return 0, jidList 
    end

end
