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
class Job
     attr_accessor :pid
     attr_accessor :envid
     attr_accessor :jobid
     attr_accessor :status
     attr_accessor :predjobid
     attr_accessor :name
     attr_accessor :groupname
     attr_accessor :groupid
     attr_accessor :dependstr
     attr_accessor :exitstatus
     attr_accessor :startTime
     attr_accessor :endTime
     attr_accessor :submitTime
     attr_accessor :type
     attr_accessor :priority

     def initialize(pid, envid, type, status)
         @name = ""
         @jobid = -1
         @predjobid = ""
         @pid=pid
         @envid=envid
         @type = type
         @submitTime=Time.now
         @startTime=0
         @endTime =0
         @status = status
         @groupname = ""
         @dependstr = ""
         @priority = 0
     end
 
     def start
         @startTime = Time.now
         @status = "RUNNING"
     end

     def done
         @endTime = Time.now
         @status = "DONE"
     end

     def fail 
         @endTime = Time.now
         @status = "FAIL"
     end

     def abort
         @endTime = Time.now
         @status = "ABORT"
     end

     def to_json(*a)
     {
      "jobid"   => @jobid,
      "name"    => @name,
      "pid"     => @pid,
      "envid"   => @envid,
      "type"    => @type,
      "predjob" => @predjobid,
      "group"     => @group,
      "groupid"   => @groupid,
      "submit"  => @submitTime,
      "start"   => @startTime,
      "end"     => @endTime,
      "dependstr"     => @dependstr,
      "status"  => @status,
      "priority"  => @priority
    }.to_json(*a)
    end
end


class JobManager
     def initialize(con)
         @jobList = Array.new
         @numJobs = 0
         @con = con
     end
   
     # This method takes a 'group' configuration and creates a sequence of
     # environment creation jobs that are queued up. 
     def queuejobs(group, parentjobid, members)
         parent = parentjobid
         puts "queuejobs: members " + members.to_s
         members.each { |m| 
             puts "queuejobs: evaluating memeber " + m
             # Create a job for each remaining memmber
             if ENVIRONMENT[m] == nil
                $Logger.error "Dependency  not found " + m
             else
                puts "queuejobs: creating new job for " + m
                j = Job.new(-1,-1,"CREATE", "PENDING")
                j.name = m
                j.predjobid = parent
                j.groupid = parentjobid
                j.groupname  = group
                self.insertInDb(j)
                self.updateInDb(j)
                @jobList[@numJobs]=j
                @numJobs = @numJobs + 1
                parent = j.jobid
             end
         }
     end

     def load()
        $Logger.debug "Loading jobs from db"
        # Get all PENDING and RUNNING jobs as well as CREATE jobs that are less
        # than 6 hours in order to resolve dependencies on finished jobs
        rs = @con.query("select * FROM #{$JOBSTABLE} WHERE (svcid = #{$SVCID}) AND (status IN ('RUNNING', 'PENDING') OR ((type IN ('CREATE')) && (submit >  DATE_SUB(NOW(), INTERVAL 6 HOUR)))) ")
        rs.each_hash { |h|
            j = Job.new(h['pid'], h['envid'], h['type'], h['status'])
            j.jobid = h['jobid']
            j.name = h['name']
            j.predjobid = h['predjobid']
            j.startTime = h['start']
            j.endTime = h['end']
            j.groupname = h['groupname']
            j.groupid = h['groupid']
            j.dependstr = h['dependstr']
            j.submitTime = h['submit']
            j.startTime = h['start']
            j.endTime = h['end']
            @jobList[@numJobs]=j
            @numJobs += 1 
        }
     end

     def insertInDb(job)
         sqlstr = "INSERT INTO #{$JOBSTABLE} (pid, envid, type,  status, name, submit, svcid) VALUES('#{job.pid}', '#{job.envid}', '#{job.type}', '#{job.status}', '#{job.name}', '#{job.submitTime}', '#{$SVCID}');"
         puts " insertInDb sqlstr is #{sqlstr}"
         rs = @con.query(sqlstr)
         rs = @con.query("select LAST_INSERT_ID();")
         rs.each_hash { |h|
             job.jobid = h['LAST_INSERT_ID()']
             puts "insertInDb for job #{job.name} #{job.jobid}"
         }
     end

     def updateInDb(job)
         rs = @con.query("UPDATE #{$JOBSTABLE}  SET  pid='#{job.pid}', envid='#{job.envid}', status='#{job.status}', dependstr='#{job.dependstr}', predjobid='#{job.predjobid}', groupid='#{job.groupid}', groupname='#{job.groupname}',  exitstatus='#{job.exitstatus}', start='#{job.startTime}', end='#{job.endTime}' WHERE jobid='#{job.jobid}';")

     end


     # Cancel jobs for a given environment. Normally should only have
     # one job outstanding.
     def cancel(envid)
        @jobList.each { |job|
            if job.envid == envid && job.status == "RUNNING"
                begin
                    Process.kill('TERM', job.pid.to_i)
                rescue Errno::ESRCH
                    reportDone(job.pid, -1)
                end
            end
        }
     end

     # This is called to register a new process (pid) that was started
     # with the Job Manager. A new job is created in the database if a job
     # of the given type was not already created.
     def register(pid, envid, type, name, state, priority)
         matches=@jobList.select{|j| j.envid == envid && j.type  == type && j.status == "READY" }
         if matches == nil || matches[0] == nil
             j = Job.new(pid,envid,type, state)
             j.name = name
             j.priority = priority
             @jobList[@numJobs]=j
             @numJobs = @numJobs + 1
             self.insertInDb(j)
             return j.jobid
         else
             matches[0].pid = pid
             matches[0].status = state
             matches[0].priority = priority
             self.updateInDb(matches[0])
             return matches[0].jobid
         end
     end


     # This is called when a PENDING job is started. The job already
     # exists in the database and needs to be updated.
     def trigger(job, pid, envid)
         job.pid = pid
         job.envid = envid
         job.start
         self.updateInDb(job)
     end

     # Determine if there is a job running for an environment. This is to
     # prevent operations on an environment from interfering with each other
     def isJobRunning(envid)
        @jobList.each { |job|
            if job.envid == envid && job.status == "RUNNING"
                return true
            end
        }
        return false
     end

     # This sets the dependency string for a job. The dependencies look up
     # the APPURL of any previous environments that were created
     def resolveDependencies(job)
         config = job.groupname
         if config == nil
             return 
         end
         if ENVIRONMENT[config] == nil || ENVIRONMENT[config][:type] != "group"
             $Logger.error "Internal error: configuration doesn't exist or of wrong type for job #{job.jobid}"
             return 
         end
         if ENVIRONMENT[config][:dependencies] == nil
             $Logger.info "No dependencies in configuration for job #{job.jobid}"
             return 
         end
         if ENVIRONMENT[config][:dependencies][job.name] == nil
             $Logger.info "No dependencies for job #{job.jobid}"
             return 
         end
         jobdeps = ENVIRONMENT[config][:dependencies][job.name]
         depStr = ""
         jobdeps.each { |d|
             # Find the job in the same group as this job with the given
             # depedency name
             $Logger.debug "Resolving dependency for #{d} for job #{job.jobid}"
             matches=@jobList.select{|j| j.groupid == job.groupid && j.name == d }
             if matches == nil || matches[0] == nil
                 $Logger.error "Matching dependency #{d} not found for job #{job.jobid}" 
                 next 
             end
             # Get the app URL of the dependent environment
             e = $envManager.loadEnv(matches[0].envid)
             if e == nil
                 $Logger.error "Could not find environment with id #{matches[0].envid}"
                  next 
             end
 
             $Logger.debug "Resolved dependency for #{matches[0].name} to #{e.url} for job #{job.jobid}"
             if e.url != nil
                 depStr = depStr + "," + matches[0].name.upcase + "_URL=" + "\"" + e.url + "\"" 
             end

         }
         job.dependstr = depStr.gsub('/','\/').gsub('"','\"')
         job.dependstr = "\"" + job.dependstr + "\""
         self.updateInDb(job)
         $Logger.info "Dependency string for job #{job.jobid} with env #{job.envid} is #{job.dependstr}"
     end

     # If a job fails, check if the job belongs to a group and abort
     # all dependent jobs so that the system doesn't try to launch
     # creation jobs
     def abortDependentJobs(job)
         if job.groupid == nil
             # Job not part of a group so nothing to do
             return
         end
         @jobList.each { |j|
              if j.status == "PENDING" && job.groupid == j.groupid
                  j.abort
                  self.updateInDb(j)
              end
         }

     end

    
     # When the process corresponding to a job is completed, we update the
     # status and trigger any dependent jobs
     def reportDone(pid,exitstatus)
        @jobList.each { |job|
            if job.pid == pid
                job.exitstatus = exitstatus
                if job.exitstatus != 0
                    job.fail
                    self.updateInDb(job)
                    abortDependentJobs(job)
                    return
                end
                job.done
                self.updateInDb(job)
                # Now look for other jobs that are waiting for this
                match = @jobList.select{|j| j.predjobid == job.jobid  && j.status == "PENDING" }
                if match != nil && match[0] != nil
                    # Launch the next job
		    config = $configList.getbyname(match[0].name)
                    if config == nil
                        $Logger.error "Configuration #{match[0].name} in depdendent job #{job.jobid} not found" 
                    else
                        self.resolveDependencies(match[0])
                        envid,jobid = config.launch(match[0], @con)
                        $Logger.info "Launched dependent configurtion with envid #{envid} jobid #{jobid}"
                    end
                end
                return
            end
        }
     end

     def getJobList
         return @jobList
     end

     # This will schedule SCALEUP jobs so that those for applications with
     # higher priority will be run first
     def schedule
        # Look for all SCALEUP jobs in READY state
        match = @jobList.select{|j| j.status == "READY" && j.type == "SCALEUP"}
        if match == nil || match[0] == nil
            return
        end
        # Sort them by priority
        match.sort! { |a,b| a.priority <=> b.priority}
        # Launch the highest priority jobs up to a limit (say 5)
        e = $envManager.getEnv(match[0].envid)
        if e == nil
            $Logger.error "In schedule: Environment with id #{match[0].envid} not found"
            return
        end
        e.scaleup(true, match[0].priority)
     end

     # Let the Global Scheduler determine which env jobs to run
     def scheduleglobal(envid, token)
         match = @jobList.select{|j| j.status == "READY" && j.type == "SCALEUP" && j.envid == envid}
         if match == nil || match[0] == nil
            $Logger.error "No SCALEUP job corresponding to env #{envid}"
            return
         end
         e = $envManager.getEnv(envid)
         if e == nil 
            $Logger.error "Unable to find environment for id #{envid}"
            return
         end
         e.addgsToken(token)
         e.scaleup(true, match[0].priority)
     end


     def checkEnvDbStatus(job)
          e=$envManager.loadEnv(job.envid)
          if e == nil
              return false     
          end
          if e.policy_status == "READY" || e.policy_status == "ACTIVE"
              return true
          else
              return false
          end
     end

     # Called periodically to check the status of processes. Normally
     # get informed of process dying via SIGCHLD handler, but if oneenvd
     # is restarted can loose parent-child relationship
     def checkJobs()
        @jobList.each { |job|
            if job.status == "RUNNING"
                begin
                    Process.kill(0, job.pid.to_i)
                rescue Errno::ESRCH
                    # Process is gone, check the DB if the job completed
                    # based on the state of the environment
                    if checkEnvDbStatus(job) == true
                        reportDone(job.pid, 0)
                    else
                        reportDone(job.pid, -1)
                    end
                end
            end
        }
     end
 
     # Return the envid that corresponds to the envid of the parent job
     # within a group
     def findParentEnvIdForJob(job)
         @jobList.each { |j|
              if job.groupid == j.jobid
                  return j.envid
              end 
         }
         return -1
     end

     def run(lock)
         loop do
             lock.synchronize {
                 checkJobs()
             }
             sleep 60
         end
     end
end

