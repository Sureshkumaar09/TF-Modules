#!/usr/bin/env ruby
require 'json'
data = JSON.parse(STDIN.read)

#result = { "ip" => data.inspect() }
#STDOUT.write result.to_json


# https://documentation.global.cloud.sap/docs/servers/baremetal_config.html

timeout="10"
retry_num=180

network=JSON.parse(data['network'])
working_ipv4=""
working_mac=""
working_interface_found=false
for i in 0..retry_num do
    network.each do |n|
        system("nc -z -w #{timeout} #{n['fixed_ip_v4']} 22")
        if $?.exitstatus == 0 then
            working_ipv4=n['fixed_ip_v4']
            working_mac=n['mac']
            working_interface_found=true
            break
        end
    end
    if working_interface_found==true then
        break
    end 
end

result = { "ipv4" => working_ipv4, "mac" => working_mac }

STDOUT.write result.to_json
