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
class DataStore
     attr_accessor :name
     attr_accessor :storeid
     attr_accessor :type
     attr_accessor :endpoint
     attr_accessor :size
     attr_accessor :mountpoint
     attr_accessor :imageid
     attr_accessor :status
     attr_accessor :vmid
     attr_accessor :envid
     attr_accessor :metainfo

     def initialize(name,type,endpoint, size)
         @name = name
         @type = type
         @endpoint = endpoint
         @size = size
         @status = "FREE"
         @indb = false
         @storeid = -1
         @envid = -1
         @vmid  = -1
     end
end

class DataStoreManager
     def initialize(con)
         @dsList = Array.new
         @con = con
     end

     def load()
        # Create the objects
        DATASTORE.each_key do |d|
           ds = DataStore.new("#{d}", DATASTORE[d][:type], DATASTORE[d][:endpoint, DATASTORE[d][:size])) 
          @dsList.push(ds) 
        end
 
        # Load all the existing datastores from the DB and reconcile
        rs = "select  storeid, name, status, envid, vmid, metainfo from #{$DSTORETABLE}"
        rs.each_hash { |ds|
            match = @dsList.select{ |d| d.name == ds['name'] }         
            if match == nil  || match[0] == nil
                # Delete the DS from the DB as it is no longer in config.rb
            end

            matchds = match[0]
            matchds.storeid = ds['storeid']
            matchds.status = ds['status']
            matchds.envid = ds['envid']
            matchds.vmid = ds['vmid']
            matchds.metainfo = ds['metainfo']
            matchds.indb = true
        }
        # Put any new datastores into the DB
        @dsList.each { |d|
            if d.indb == false
                sqlstr = "INSERT INTO #{$DSTORETABLE} (name, status,envid, vmid,metainfo,svcid) VALUES('#{d.name}', '#{d.status}', '#{d.envid}', '#{d.vmid}', '#{d.metainfo}', '#{$SVCID}');" 
              rs = @con.query(sqlstr)
              rs = @con.query("select LAST_INSERT_ID();")
              rs.each_hash { |h|
                d.storeid = h['LAST_INSERT_ID()']
                puts "insertindb for datastore #{d.name} #{d.storeid}"
              }
            end
         }
     end

     def allocate(size, type, mode) 
         match = @dsList.select{ |d| d.status == "FREE" && d.type == type && d.size >= size}
         if match == nil || match[0] = nil
             $Logger.error "Unable to find matching datastore for request"
              return nil
         end
         d = match[0]
         d.status = "ALLOCATED"
         return d
     end

     def update(id, envid, vmid, metinfo)

     end

     def release(id)

     end

     def list()

     end

     def query(metainfo)

     end

     def setmetainfo(id, info)

     end
end
