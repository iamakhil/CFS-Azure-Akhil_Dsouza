$RESOURCEGROUP = @{ Name= 'RG-SEA-NilavembuHerbs'; Location = 'southeastasia' }
New-AzResourceGroup @RESOURCEGROUP
$VNET = @{ Name = 'vnet-test-SEA-NilavembuHerbs001' ; ResourceGroupName = 'RG-SEA-NilavembuHerbs';Location='southeastasia';AddressPrefix='10.2.0.0/16'}
$VIRTUALNETWORK = New-AzVirtualNetwork @VNET
$SUBNET1 =@{Name='snet-test-websubnet';virtualNetwork=$VIRTUALNETWORK;AddressPrefix='10.2.1.0/24'}
$SUBNET2 =@{Name='snet-test-jumphost';virtualNetwork=$VIRTUALNETWORK;AddressPrefix='10.2.2.0/24'}
$WEBSUBNET = Add-AzVirtualNetworkSubnetConfig @SUBNET1
$JUMPSUBNET = Add-AzVirtualNetworkSubnetConfig @SUBNET2
$VIRTUALNETWORK | Set-AzVirtualNetwork
$WebNSGRule1=New-AzNetworkSecurityRuleConfig -name rule-webservers -Description "Allow httpRDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix 42.105.120.55 -SourcePortRange * -DestinationAddressPrefix 10.2.1.0/24 -DestinationPortRange 80,3389
$webNSG =New-AzNetworkSecurityGroup -ResourceGroupName $RESOURCEGROUP.Name -Location 'southeastasia' -Name "NSG-Allow_web" -SecurityRules $WebNSGRule1
New-AzAvailabilitySet -Location "southeastasia" -Name "avail-test-SEA001" -ResourceGroupName $RESOURCEGROUP.Name -Sku aligned -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 2

$publicipLB = @{Name = 'myPublicIPLB'; ResourceGroupName = $RESOURCEGROUP.name;Location = 'Southeast Asia'; Sku = 'basic'; AllocationMethod = 'static'}
New-AzPublicIpAddress @publicipLB
$publicIp = Get-AzPublicIpAddress -Name 'myPublicIPLB' -ResourceGroupName $RESOURCEGROUP.name
$feip = New-AzLoadBalancerFrontendIpConfig -Name 'myFrontEnd' -PublicIpAddress $publicIp
$bepool = New-AzLoadBalancerBackendAddressPoolConfig -Name 'webserverBackEndPool'
$probe = @{
    Name = 'myHealthProbe'
    Protocol = 'http'
    Port = '80'
    IntervalInSeconds = '360'
    ProbeCount = '5'
    RequestPath = '/'
}
$healthprobe = New-AzLoadBalancerProbeConfig @probe
$lbrule = @{
    Name = 'myHTTPRule'
    Protocol = 'tcp'
    FrontendPort = '80'
    BackendPort = '80'
    IdleTimeoutInMinutes = '15'
    FrontendIpConfiguration = $feip
    BackendAddressPool = $bePool
}
$rule = New-AzLoadBalancerRuleConfig @lbrule -LoadDistribution SourceIP -DisableOutboundSNA
$loadbalancer = @{
    ResourceGroupName = $RESOURCEGROUP.name
    Name = 'lb-SEA-webservers'
    Location = 'southeastasia'
    Sku = 'basic'
    FrontendIpConfiguration = $feip
    BackendAddressPool = $bePool
    LoadBalancingRule = $rule
    Probe = $healthprobe
}
New-AzLoadBalancer @loadbalancer

$slb = Get-AzLoadBalancer -Name "lb-SEA-webservers" -ResourceGroupName $RESOURCEGROUP.Name
$slb | Add-AzLoadBalancerInboundNatRuleConfig -Name "RDPNatRule" -FrontendIPConfiguration $slb.FrontendIpConfigurations[0] -Protocol "Tcp" -FrontendPort 8350 -BackendPort 3350 
$slb | Set-AzLoadBalancer

$inNAT = Get-AzLoadBalancerInboundNatRuleConfig -LoadBalancer $slb


$AvailabilitySet = Get-AzAvailabilitySet -ResourceGroupName $RESOURCEGROUP.Name -Name "avail-test-SEA001"
$lb = @{
    Name = 'lb-SEA-webservers'
    ResourceGroupName = $RESOURCEGROUP.name
}
$bepool = Get-AzLoadBalancer @lb  | Get-AzLoadBalancerBackendAddressPoolConfig

$nic = New-AzNetworkInterface -Name nic-webserver1 -LoadBalancerInboundNatRuleId $inNAT.Id -PrivateIpAddress "10.2.1.5" -ResourceGroupName $RESOURCEGROUP.Name -Location 'Southeast Asia' -LoadBalancerBackendAddressPoolId $bepool.Id  -SubnetId $VIRTUALNETWORK.Subnets[0].Id -NetworkSecurityGroupId $webNSG.Id 
$cred = Get-Credential
$vmConfig = New-AzVMConfig -VMName "vm-test-SEA-webserver1" -VMSize "Standard_DS1_v2" -AvailabilitySetId $AvailabilitySet.Id | Set-AzVMOperatingSystem -Windows -ComputerName "webserver1" -Credential $cred | Set-AzVMSourceImage -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer"-Skus "2016-Datacenter" -Version "latest"| Add-AzVMNetworkInterface -Id $nic.Id
New-AzVM -ResourceGroupName $RESOURCEGROUP.Name -Location 'Southeast Asia' -VM $vmConfig
$nic2 = New-AzNetworkInterface -Name nic-webserver2 -PrivateIpAddress "10.2.1.6" -ResourceGroupName $RESOURCEGROUP.Name -Location 'Southeast Asia'-LoadBalancerBackendAddressPoolId $bepool.Id -SubnetId $VIRTUALNETWORK.Subnets[0].Id -NetworkSecurityGroupId $webNSG.Id
$vmConfig2 = New-AzVMConfig -VMName "vm-test-SEA-webserver2" -VMSize "Standard_DS1_v2" -AvailabilitySetId $AvailabilitySet.Id | Set-AzVMOperatingSystem -Windows -ComputerName "webserver2" -Credential $cred | Set-AzVMSourceImage -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer"-Skus "2016-Datacenter" -Version "latest"| Add-AzVMNetworkInterface -Id $nic2.Id
New-AzVM -ResourceGroupName $RESOURCEGROUP.Name -Location 'Southeast Asia' -VM $vmConfig2


$JUMPNSGRule1=New-AzNetworkSecurityRuleConfig -name rule-JUMPservers -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix "internet" -SourcePortRange * -DestinationAddressPrefix 10.2.2.0/24 -DestinationPortRange 3389
$JUMPNSG =New-AzNetworkSecurityGroup -ResourceGroupName $RESOURCEGROUP.Name -Location 'southeastasia' -Name "NSG-Allow_RDP" -SecurityRules $JUMPNSGRule1

New-AzVm `
    -ResourceGroupName $RESOURCEGROUP.name `
    -Name "vm-jumpserver" `
    -Location "Southeast Asia" `
    -VirtualNetworkName "vnet-test-SEA-NilavembuHerbs001" `
    -SubnetName "snet-test-jumphost" `
    -SecurityGroupName "NSG-Allow_RDP" `
    -OpenPorts 3389 `
    -Image Win2016Datacenter

New-AzRecoveryServicesVault `
    -Name 'backup-SEA-VM' `
    -ResourceGroupName $RESOURCEGROUP.Name `
    -Location 'southeastasia' 

$vault1 = Get-AzRecoveryServicesVault -Name 'backup-SEA-VM'    

Get-AzRecoveryServicesVault -Name 'backup-SEA-VM' | Set-AzRecoveryServicesVaultContext
$retpol = Get-AzRecoveryServicesBackupRetentionPolicyObject -WorkloadType "AzureVM"
$schPol = Get-AzRecoveryServicesBackupSchedulePolicyObject -WorkloadType "AzureVM"
New-AzRecoveryServicesBackupProtectionPolicy -Name "Policy1-vm" -WorkloadType "AzureVM" -SchedulePolicy $schPol -RetentionPolicy $retpol

$pol = Get-AzRecoveryServicesBackupProtectionPolicy -Name "Policy1-vm"

Enable-AzRecoveryServicesBackupProtection `
    -Policy $pol `
    -Name "vm-test-SEA-webserver1" `
    -ResourceGroupName $RESOURCEGROUP.name 

Enable-AzRecoveryServicesBackupProtection `
    -Policy $pol `
    -Name "vm-test-SEA-webserver2" `
    -ResourceGroupName $RESOURCEGROUP.name 

$receiver= New-AzActionGroupReceiver -Name "vmadmin" -EmailAddress "dsouzaakhil@outlook.com"
$actiongroup= Set-AzActionGroup -Name "Notify-admin" -ShortName "vmadmingroup" -ResourceGroupName $RESOURCEGROUP.name -Receiver $receiver
$actiongroupid= New-AzActionGroup -ActionGroupId $actiongroup.Id
$condition = New-AzMetricAlertRuleV2Criteria -MetricName "Percentage CPU" -MetricNamespace "Microsoft.Compute/virtualMachines" -TimeAggregation Maximum -Operator GreaterThan -Threshold 80


$targetid1= (Get-AzVM -name "vm-test-SEA-webserver1" -resourcegroup $RESOURCEGROUP.name).Id
$targetid2= (Get-AzVM -name "vm-test-SEA-webserver2" -resourcegroup $RESOURCEGROUP.name).Id

Add-AzMetricAlertRuleV2 -Name "metricrule" -ResourceGroupName $RESOURCEGROUP.Name -WindowSize 0:5 -Frequency 0:5 `
-TargetResourceScope $targetid1,$targetid2 `
-TargetResourceType "Microsoft.Compute/virtualMachines" -TargetResourceRegion "southeastasia" `
-Description "Warning" -Severity 3 -ActionGroup $actiongroupid -Condition $condition

$RESOURCEGROUPEUS = @{ Name= 'RG-EastUS-NilavembuHerbs'; Location = 'eastus' }
New-AzResourceGroup @RESOURCEGROUPEUS

$VNETEUS = @{ Name = 'vnet-test-EUS-NilavembuHerbs001' ; ResourceGroupName = $RESOURCEGROUPEUS.name ;Location='eastus';AddressPrefix='10.3.0.0/16'}
$VIRTUALNETWORKEUS = New-AzVirtualNetwork @VNETEUS
$SUBNETEUS1 =@{Name='snet-test-serversubnet';virtualNetwork=$VIRTUALNETWORKEUS;AddressPrefix='10.3.1.0/24'}
$SUBNETEUS2 =@{Name='snet-test-jumphost';virtualNetwork=$VIRTUALNETWORKEUS;AddressPrefix='10.3.2.0/24'}
$serverSUBNETEUS = Add-AzVirtualNetworkSubnetConfig @SUBNETEUS1
$JUMPSUBNETEUS = Add-AzVirtualNetworkSubnetConfig @SUBNETEUS2
$VIRTUALNETWORKEUS | Set-AzVirtualNetwork

$VNET1 = Get-AzVirtualNetwork -Name "vnet-test-SEA-NilavembuHerbs001" -ResourceGroupName $RESOURCEGROUP.name
$VNET2 = Get-AzVirtualNetwork -Name "vnet-test-EUS-NilavembuHerbs001" -ResourceGroupName $RESOURCEGROUPEUS.name

Add-AzVirtualNetworkPeering -Name "SEA-ESUpeering" -VirtualNetwork $VNET1 -RemoteVirtualNetworkId $VNET2.Id
Add-AzVirtualNetworkPeering -Name "EUS-SEApeering" -VirtualNetwork $VNET2 -RemoteVirtualNetworkId $VNET1.Id


$publicipserver11 = @{Name = 'myPublicIPserver11'; ResourceGroupName = $RESOURCEGROUPEUS.name;Location = 'East US'; Sku = 'basic'; AllocationMethod = 'static'}
New-AzPublicIpAddress @publicipserver11
$publicIpserver11 = Get-AzPublicIpAddress -Name 'myPublicIPserver11' -ResourceGroupName $RESOURCEGROUPEUS.name

$server11NSGRule1=New-AzNetworkSecurityRuleConfig -name rule-server11 -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix "internet" -SourcePortRange * -DestinationAddressPrefix 10.3.1.0/24 -DestinationPortRange 3389
$server11NSG =New-AzNetworkSecurityGroup -ResourceGroupName $RESOURCEGROUP.Name -Location 'eastus' -Name "NSG-Allow_RDP_server11" -SecurityRules $server11NSGRule1


New-AzVm `
    -ResourceGroupName $RESOURCEGROUPEUS.name `
    -Name "vm-server11" `
    -Location "eastus" `
    -VirtualNetworkName "vnet-test-EUS-NilavembuHerbs001" `
    -SubnetName "snet-test-serversubnet" `
    -SecurityGroupName "NSG-Allow_RDP_server11" `
    -OpenPorts 3389 `
    -PublicIpAddressName $publicipserver11.Name
    -Image Win2016Datacenter


New-AzStorageAccount -ResourceGroupName $RESOURCEGROUPEUS.name`
    -Name 'strgnh0123' `
    -Location 'eastus' `
    -SkuName Standard_ZRS `
    -Kind StorageV2

$context = (Get-AzStorageAccount -ResourceGroupName $RESOURCEGROUPEUS.name` -AccountName 'strgnh0123').context

New-AzStorageAccountSASToken -Context $context -Service Blob,File,Table,Queue -ResourceType Service,Container,Object -Permission "racwdlup" 

New-AzStorageSyncGroup


New-AzRmStorageShare `
        -ResourceGroupName $RESOURCEGROUPEUS.name `
        -StorageAccountName 'strgnh0123' `
        -Name 'salesfile' `
        -AccessTier TransactionOptimized `
        -QuotaGiB 1024

New-AzStorageAccount -ResourceGroupName $RESOURCEGROUP.name`
    -Name 'strgnh01234' `
    -Location 'southeastasia' `
    -SkuName Standard_GRS `
    -Kind StorageV2

New-AzADUser -DisplayName "vmadmin" -UserPrincipalName "vmadmin@dszakhiloutlook.onmicrosoft.com" -MailNickname "vmadmin"
New-AzADUser -DisplayName "backadmin" -UserPrincipalName "backupadmin@dszakhiloutlook.onmicrosoft.com" -MailNickname "backupadmin"


New-AzRoleAssignment -SignInName vmadmin@dszakhiloutlook.onmicrosoft.com `
-RoleDefinitionName "Virtual Machine Administrator Login" `
-Scope "/subscriptions/4208f520-b385-4898-a89b-cf2de22f4a29"

New-AzRoleAssignment -SignInName backupadmin@dszakhiloutlook.onmicrosoft.com `
-RoleDefinitionName "Backup Contributor" `
-ResourceGroupName RG-EastUS-NilavembuHerbs
