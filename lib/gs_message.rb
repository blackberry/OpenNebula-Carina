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
require 'rubygems'
require 'sinatra'
require 'json'


class JSONable
    def to_json(options= {})
        hash = {}
        self.instance_variables.each do |var|
            hash[var] = self.instance_variable_get var
        end
        hash.to_json
    end
    def from_json(string)
        JSON.load(string).each do |var, val|
            self.instance_variable_set var, val
        end
    end
end



# Sent from oneenvd -> oneenvd-gs announcing itself
class Register < JSONable
     attr_accessor :type
     attr_accessor :zone
     attr_accessor :service
     attr_accessor :host
     attr_accessor :port
     def initialize ( type, zone, service)
        @type = type
        @zone = zone
        @service = service
     end
end

# Sent from oneenvd-gs to oneenvd telling it what resources it has
class Initialize < JSONable
    attr_accessor :type
    attr_accessor :reqIds
    def initialize (type)
        @type = type
        @reqIds = Hash.new
    end
end

# Sent from oneenvd to oneenvd-gs requesting a resource capacity slice in
# order to create a VM
class Request  < JSONable
     attr_accessor :type
     attr_accessor :zone
     attr_accessor :submittime
     attr_accessor :vcpus
     attr_accessor :mem
     attr_accessor :env
     attr_accessor :envid
     attr_accessor :service
     attr_accessor :reqid
     attr_accessor :status
     attr_accessor :pool

    def initialize ( type, zone, service)
        @type = type
        @zone = zone
        @service = service
    end

end

# Sent from oneenvd to oneenvd-gs indicating a resource no longer used
class Release < JSONable
     attr_accessor :type
     attr_accessor :reqid
     def initialize( type, reqid)
         @type = type
         @reqid = reqid
     end
end

# Sent from ongeenvd-gs to oneenvd granting it access to capacity to start a VM
class Grant < JSONable
     attr_accessor :type
     attr_accessor :zone
     attr_accessor :service
     attr_accessor :vdc
     attr_accessor :vcpus
     attr_accessor :mem
     attr_accessor :envid
     attr_accessor :reqid

     def initialize ( type, zone, service, vdc, envid, reqid)
        @type = type
        @zone = zone
        @service = service
        @vdc = vdc
        @envid = envid
        @reqid = reqid
     end

end

# Sent from oneenvd-s to oneenvd telling it to return the capacity to be used
# by a higher class service
class Reclaim < JSONable
     attr_accessor :type
     attr_accessor :reqid
     attr_accessor :envid
     def initialize ( type, reqid, envid)
         @type = type
         @reqid = reqid
         @envid = envid
     end
end


# Initial startup message from oneenvd-gs indicating it is up and causing the oneenvds to
# register themselves
class Startup < JSONable
     attr_accessor :type
     def initialize(type)
         @type = type
     end
end


# Sent from oneenvd to oneenvd-gs cancelling any outstanding pending
# requests for an environment. This ensures outstanding requests are deleted 
# after the oneenvd removes the environment
class Cancel < JSONable
     attr_accessor :type
     attr_accessor :zone
     attr_accessor :service
     attr_accessor :envid

     def initialize(type, zone, service, envid)
         @type = type
         @zone = zone
         @service = service
         @envid = envid
     end
end
