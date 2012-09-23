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
require "ostruct"
class Plugin
    def initialize
       puts "Initialized plugin"
    end


    def loadMetrics(envid)
       puts "Loading all metrics for env #{envid}"
    end

    def getMetrics

    end

    def getActions

    end
end

class PluginManager
     def initialize
        @pluginMap = Hash.new 
        @pluginContext = Hash.new
     end

     def load
         if File.exists?($PLUGINDIR) == true
             Dir.foreach($PLUGINDIR) do |file|
                 # Just look for files ending in .rb
                 if file =~ /.rb$/
                    puts "Loading plugin #{file}"
                    loadPlugin(ENV["HOME"] + "/plugins/" + file) 
                 end
             end
         end
     end

     def loadPlugin(pluginFile)
         begin 
             Kernel::load pluginFile 
             pluginClassName = File.basename(pluginFile, ".rb")
             puts "pluginClassName=#{pluginClassName}"
             cl = Object.const_get(pluginClassName)
             unless cl.kind_of? Class
                 raise TypeError, "`#{cl.inspect}` must be a Class"
             end
             @pluginMap[pluginClassName]= cl.send(:new)
         rescue LoadError
             puts "Failed to load plugin #{pluginFile}"
         end
     end

     def invoke(pluginClassName, method, envid)
         cl = @pluginMap[pluginClassName]
         cl.send(method.to_sym, envid)
     end

     def invoke0(pluginClassName, method)
         cl = @pluginMap[pluginClassName]
         cl.send(method.to_sym)
     end

     # Evaluate  an expression against an environment
     def evaluateExpr(pluginClassNameList, expression, envid)
         # Load the metrics for each plugin required and save the metrics
         # in a structure
         m = OpenStruct.new
         pluginClassNameList.each { |pluginClassName|
              if @pluginMap[pluginClassName] == nil
                  puts "No plugin found for #{pluginClassName}"
                  return false
              end
              # We maintain a per plugin cache of metric values and
              # only call the plugin every 60s
              if @pluginContext[pluginClassName] == nil
                  t = Hash.new
                  t["lastLoadTime"]  = Time.now
                  @pluginContext[pluginClassName] = t
                  reload = true
              else
                  t = @pluginContext[pluginClassName]
                  if Time.now - t["lastLoadTime"]  >  60
                      t["lastLoadTime"] = Time.now
                      reload = true
                  else
                      reload = false
                  end
              end
              if reload == true
                  metricList=invoke0(pluginClassName,"getMetrics")
                  if metricList == nil
                      next
                  end 
                  metricList.each { |metric|
                      value=invoke(pluginClassName,metric,envid)
                      t[metric] = value 
                  }
             end
             # Merge the metrics from multiple plugins into single structure
             t.each{ |k,v|
                # For now we only support integer valued metrics
                eval("m.#{k} = v.to_i")
             }
        }
        # The expression should refence the structure 'm' members to get the
        # values for the expression
        #puts "m=#{m}"
        #puts "Evaluating expression #{expression}"
        result = eval(expression)
        #puts "result=#{result}"
        return result
     end
end

