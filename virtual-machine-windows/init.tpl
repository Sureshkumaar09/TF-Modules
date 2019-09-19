#<powershell>
#THIS SCRIPT IS FOR CHANGING MTU SIZE ON WINDOWS 2008 VMS FROM 1500 TO 9000 TO ENABLE JUMBO FRAME.
#THIS IS ESSENTIAL FOR A WORKING WINRM CONNECTION IN CONVERED CLOUD FOR THE PUBLIC WIN 2008 VM IMAGE.
#ALSO A PLUS LOCAL ADMINISTRATOR USER CALLED OPSADMIN IS ADDED TO THE NODES.

#1 STEP - JUMBO PACKET ENABLED AND MTU CHANGE
Write-Output "Enable Jumbo Packet and change MTU"
#param([string]$Mode = $(throw "Please specify enable, disable, or verify"),
# [string]$IPAddress = $(Read-Host -prompt "Enter the Static IP of the NIC to work with"))

$Mode = "enable"
$IPAddress = (get-WmiObject Win32_NetworkAdapterConfiguration|Where {$_.Ipaddress.length -gt 1}).ipaddress[0] 

Function VerifyJumboFrames ($IpAddress,$AdapterName,$CurrentJumboPacket)
 {
 Write-Host -foregroundcolor yellow $IpAddress on $AdapterName currently has a MTU size of $CurrentJumboPacket
 }
 
Function EnableJumboFrames ($IpAddress,$AdapterName,$CurrentJumboPacket,$AdapterProperties)
 {
 $EnableRegJumboPacket = 9014
 $EnableCmdJumboPacket = "mtu=8950"
 Write-Host -foregroundcolor yellow $IpAddress on $AdapterName currently has a MTU size of $CurrentJumboPacket
 Write-Host -foregroundcolor cyan Modifying netsh MTU Settings...
 netsh interface ipv4 set subinterface $AdapterName $EnableCmdJumboPacket store=persistent
 Write-Host -foregroundcolor cyan Modifying Registry MTU Settings...
 Set-ItemProperty $AdapterProperties.PSPath -name "*JumboPacket" -value $EnableRegJumboPacket
 Write-Host -foregroundcolor red Enable Completed - Reboot is Required.
 }
 
Function DisableJumboFrames ($IpAddress,$AdapterName,$CurrentJumboPacket,$AdapterProperties)
 {
 $DisableRegJumboPacket = 1514
 $DisableCmdJumboPacket = "mtu=1500"
 Write-Host -foregroundcolor yellow $IpAddress on $AdapterName currently has a MTU size of $CurrentJumboPacket
 Write-Host -foregroundcolor cyan Modifying Registry MTU Settings...
 Set-ItemProperty $AdapterProperties.PSPath -name "*JumboPacket" -value $DisableRegJumboPacket
 Write-Host -foregroundcolor cyan Modifying netsh MTU Settings...
 netsh interface ipv4 set subinterface $AdapterName $DisableCmdJumboPacket store=persistent
 Write-Host -foregroundcolor red Disable Completed - Reboot is Required.
 }
 
 $FindInterfaceIndex = gwmi win32_networkAdapterConfiguration |where {$_.IPAddress -eq $IpAddress}
 $FindInterfaceGUID = gwmi win32_networkAdapter |where {$_.Index -eq $FindInterfaceIndex.Index}
 $GUID = $FindInterfaceGUID.GUID
 $FindAdapterName = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Network\{4D36E972-E325-11CE-BFC1-08002BE10318}\$GUID\Connection"
 $AdapterName = $FindAdapterName.Name
 ## Legacy Code v1.0 $FindAdapterProperties = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}\*\' |where {$_.NetCfgInstanceID -eq $guid}
 $FindAdapterProperties = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}\0*\' |where {$_.NetCfgInstanceID -eq $guid}
 $AdapterProperties = Get-ItemProperty $FindAdapterProperties.PSPath
 $CurrentJumboPacket = $AdapterProperties."*JumboPacket"
 
if ($Mode -eq "enable")
 {
 EnableJumboFrames $IpAddress $AdapterName $CurrentJumboPacket $AdapterProperties
 }
 elseif ($Mode -eq "disable")
 {
 DisableJumboFrames $IpAddress $AdapterName $CurrentJumboPacket $AdapterProperties
 }
 elseif ($Mode -eq "verify")
 {
 VerifyJumboFrames $IpAddress $AdapterName $CurrentJumboPacket
 }
 
#2 STEP - DNS SERVER SET
Write-Output "Set DNS server"
netsh dnsclient set dnsservers name="$AdapterName" source=static address="${primary_name_server}" validate=no
netsh interface ip add dns name="$AdapterName" addr="${secondary_name_server}" index=2
#</powershell>
