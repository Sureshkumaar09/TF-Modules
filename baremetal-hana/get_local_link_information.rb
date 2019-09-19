#!/usr/bin/env ruby
require 'json'
data = JSON.parse(STDIN.read)

# https://documentation.global.cloud.sap/docs/servers/baremetal_config.html

#file = File.open("/tmp/tf_debug.txt", "w")
#file.puts data.inspect()
#file.close()

bm_ports=JSON.parse(data['bm_ports'])
host_id=data['host_id']

local_link_information=Array.new()
bm_ports.each do |port|
    if port['device_id'].eql?(host_id) then
        port['binding'].each do |binding|
            binding_profile = JSON.parse(binding['profile'])
            binding_profile['local_link_information'].each do |info|
                local_link_information.push(info)
            end       
        end
    end
end

#terraform not supporting return of array, so have to use .to_json to change it to string, then parse it back to array/jason
# https://github.com/terraform-providers/terraform-provider-external/issues/2
result = { "local_link_information" => local_link_information.to_json() }

STDOUT.write result.to_json
