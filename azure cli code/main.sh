#!/bin/bash

az group create -l southeastasia -n RG-SEA-NilavembuHerbs

az network vnet create \
  --name vnet-SEA-VNET1 \
  --resource-group RG-SEA-NilavembuHerbs \
  --address-prefixes 10.1.0.0/16

az network nsg create -g RG-SEA-NilavembuHerbs -n NSG-webservers

az network nsg rule create -g RG-SEA-NilavembuHerbs --nsg-name NSG-webservers -n NsgRule1 --priority 1000 \
    --source-address-prefixes 122.187.99.198 --source-port-ranges '*' \
    --destination-address-prefixes 10.1.1.0/24 --destination-port-ranges 80 3389 --access Allow \
    --protocol Tcp --description "Allow from specific IP address ranges on 80 and 3389."

az network vnet subnet create -g RG-SEA-NilavembuHerbs --vnet-name vnet-SEA-VNET1 -n snet-SEA-webservers \
  --address-prefixes 10.1.1.0/24 --network-security-group NSG-webservers

az network vnet subnet create -g RG-SEA-NilavembuHerbs --vnet-name vnet-SEA-VNET1 -n snet-SEA-jumpservers \
  --address-prefixes 10.1.2.0/24

az network nic create \
--resource-group RG-SEA-NilavembuHerbs \
--name NicwebVM1 \
--vnet-name vnet-SEA-VNET1 \
--subnet snet-SEA-webservers

az network nic create \
--resource-group RG-SEA-NilavembuHerbs \
--name NicwebVM2 \
--vnet-name vnet-SEA-VNET1 \
--subnet snet-SEA-webservers

az vm availability-set create -n avail-SEA-webservers -g RG-SEA-NilavembuHerbs --platform-fault-domain-count 2 --platform-update-domain-count 2

az vm create \
--resource-group RG-SEA-NilavembuHerbs \
--name vm-SEA-web1 \
--location southeastasia \
--availability-set avail-SEA-webservers \
--size Standard_DS1_v2 \
--nics NicwebVM1 \
--image win2019datacenter \
--private-ip-address 10.1.1.4 \
--admin-username vmuser

az vm create \
--resource-group RG-SEA-NilavembuHerbs \
--name vm-SEA-web2 \
--location southeastasia \
--availability-set avail-SEA-webservers \
--size Standard_DS1_v2 \
--nics NicwebVM2 \
--image win2019datacenter \
--private-ip-address 10.1.1.5 \
--admin-username vmuser

az network public-ip create \
    --resource-group RG-SEA-NilavembuHerbs \
    --name LBPublicIP \
    --location southeastasia \
    --sku Basic


az network lb create \
    --resource-group RG-SEA-NilavembuHerbs \
    --name LoadBalancer-SEA-webservers \
    --location southeastasia \
    --sku Basic \
    --public-ip-address LBmyPublicIP \
    --frontend-ip-name myFrontEnd \
    --backend-pool-name myBackEndPool

az network lb probe create \
    --resource-group RG-SEA-NilavembuHerbs \
    --lb-name LoadBalancer-SEA-webservers \
    --name myHealthProbe \
    --protocol tcp \
    --port 80   

az network lb rule create \
    --resource-group RG-SEA-NilavembuHerbs \
    --lb-name LoadBalancer-SEA-webservers \
    --name myHTTPRule \
    --protocol tcp \
    --frontend-port 80 \
    --backend-port 80 \
    --frontend-ip-name myFrontEnd \
    --backend-pool-name myBackEndPool \
    --probe-name myHealthProbe \
    --disable-outbound-snat true \
    --idle-timeout 15 

az network nic ip-config address-pool add \
     --address-pool myBackendPool \
     --ip-config-name ipconfig1 \
     --nic-name NicwebVM1 \
     --resource-group RG-SEA-NilavembuHerbs \
     --lb-name LoadBalancer-SEA-webservers

az network nic ip-config address-pool add \
     --address-pool myBackendPool \
     --ip-config-name ipconfig1 \
     --nic-name NicwebVM2 \
     --resource-group RG-SEA-NilavembuHerbs \
     --lb-name LoadBalancer-SEA-webservers

az vm extension set \
--publisher Microsoft.Compute \
--version 1.8 \
--name CustomScriptExtension \
--vm-name vm-SEA-web2 \
--resource-group RG-SEA-NilavembuHerbs \
--settings '{"commandToExecute":"powershell Add-WindowsFeature Web-Server"}'

az vm extension set \
--publisher Microsoft.Compute \
--version 1.8 \
--name CustomScriptExtension \
--vm-name vm-SEA-web1 \
--resource-group RG-SEA-NilavembuHerbs \
--settings '{"commandToExecute":"powershell Add-WindowsFeature Web-Server"}'

az network nic create \
--resource-group RG-SEA-NilavembuHerbs \
--name NicjumpVM1 \
--vnet-name vnet-SEA-VNET1 \
--subnet snet-SEA-jumpservers

az network public-ip create \
    --resource-group RG-SEA-NilavembuHerbs \
    --name jumpVMPublicIP \
    --location southeastasia \
    --allocation-method static \
    --sku Basic


az vm create \
--resource-group RG-SEA-NilavembuHerbs \
--name vm-SEA-jump1 \
--location southeastasia \
--size Standard_DS1_v2 \
--image win2019datacenter \
--public-ip-address jumpVMPublicIP \
--vnet-name vnet-SEA-VNET1 \
--subnet snet-SEA-jumpservers \
--admin-username vmuser

az vm open-port --port 3389 --resource-group RG-SEA-NilavembuHerbs --name vm-SEA-jump1

az network lb inbound-nat-rule create -g RG-SEA-NilavembuHerbs --lb-name LoadBalancer-SEA-webservers -n MyNatRule \
    --protocol Tcp --frontend-port 8050 --backend-port 3389

az network nic ip-config inbound-nat-rule add -g RG-SEA-NilavembuHerbs --nic-name NicwebVM1 --inbound-nat-rule MyNatRule --lb-name LoadBalancer-SEA-webservers --ip-config-name ipconfig1



az backup vault create --resource-group RG-SEA-NilavembuHerbs \
    --name backup-webservers\
    --location southeastasia

az backup vault backup-properties set \
    --name backup-webservers \
    --resource-group RG-SEA-NilavembuHerbs \
    --backup-storage-redundancy "LocallyRedundant"


az backup protection enable-for-vm \
    --resource-group RG-SEA-NilavembuHerbs \
    --vault-name backup-webservers \
    --vm vm-SEA-web1 \
    --policy-name DefaultPolicy

az backup protection enable-for-vm \
    --resource-group RG-SEA-NilavembuHerbs \
    --vault-name backup-webservers \
    --vm vm-SEA-web2 \
    --policy-name DefaultPolicy


az monitor action-group create --name vmadmin --resource-group RG-SEA-NilavembuHerbs --action email akhil dsouzaakhil@outlook.com --short-name vmadm

az monitor metrics alert create -n alert1 -g RG-SEA-NilavembuHerbs --scopes "/subscriptions/4208f520-b385-4898-a89b-cf2de22f4a29/resourceGroups/RG-SEA-NilavembuHerbs/providers/Microsoft.Compute/virtualMachines/vm-SEA-web1" \
    --condition "max Percentage CPU > 80" --window-size 5m --evaluation-frequency 1m \
    --action "/subscriptions/4208f520-b385-4898-a89b-cf2de22f4a29/resourceGroups/RG-SEA-NilavembuHerbs/providers/Microsoft.Insights/actionGroups/vmadmin" \
    --description "High CPU" 



az group create -l eastus -n RG-eastus-NilavembuHerbs


az network vnet create \
  --name vnet-EUS-VNET1 \
  --resource-group RG-eastus-NilavembuHerbs \
  --address-prefixes 10.2.0.0/16

az network vnet subnet create -g RG-eastus-NilavembuHerbs --vnet-name vnet-EUS-VNET1 -n snet-EUS-servers \
  --address-prefixes 10.2.1.0/24

az network public-ip create \
    --resource-group RG-eastus-NilavembuHerbs \
    --name server11PublicIP \
    --location eastus \
    --sku Basic

az vm create \
--resource-group RG-eastus-NilavembuHerbs \
--name vm-EUS-server11 \
--location eastus \
--size Standard_DS1_v2 \
--image win2019datacenter \
--public-ip-address server11PublicIP \
--vnet-name vnet-EUS-VNET1 \
--subnet snet-EUS-servers \
--admin-username vmuser


az network vnet peering create -g RG-eastus-NilavembuHerbs -n EUStoSEA --vnet-name vnet-EUS-VNET1 \
    --remote-vnet /subscriptions/4208f520-b385-4898-a89b-cf2de22f4a29/resourceGroups/RG-SEA-NilavembuHerbs/providers/Microsoft.Network/virtualNetworks/vnet-SEA-VNET1 --allow-vnet-access

az network vnet peering create -g RG-SEA-NilavembuHerbs -n SEAtoEUS --vnet-name vnet-SEA-VNET1 \
    --remote-vnet /subscriptions/4208f520-b385-4898-a89b-cf2de22f4a29/resourceGroups/RG-eastus-NilavembuHerbs/providers/Microsoft.Network/virtualNetworks/vnet-EUS-VNET1 --allow-vnet-access


az storage account create -n stgnh0112 -g RG-eastus-NilavembuHerbs --kind StorageV2 -l eastus --sku Standard_ZRS

az storage account generate-sas --account-key 1vyRhfXBuT4/znMMiP6IkbqT2PIctfco0tDLfPKIf2zLItUqrFsJZtQPkqWju+KFpkOP8w6ceHX5G7RtuOJotg== --account-name stgnh0112 --expiry 2022-01-01 --permissions acuw --resource-types co --services bfqt

az storage share-rm create \
    --resource-group RG-eastus-NilavembuHerbs \
    --storage-account stgnh0112 \
    --name salesfile \
    --access-tier "TransactionOptimized" \
    --quota 1 

az storage account create -n stgnh01123 -g RG-SEA-NilavembuHerbs --kind StorageV2 -l southeastasia --sku Standard_GRS

az ad user create --display-name vmadmin --password admin@123 --user-principal-name vmadmin@dszakhiloutlook.onmicrosoft.com
az ad user create --display-name backupadmin --password admin@123 --user-principal-name backupadmin@dszakhiloutlook.onmicrosoft.com

az role assignment create --role "Virtual Machine Administrator Login" --assignee "vmadmin@dszakhiloutlook.onmicrosoft.com" --scope /subscriptions/4208f520-b385-4898-a89b-cf2de22f4a29

az role assignment create --role "Backup Contributor" --assignee "backupadmin@dszakhiloutlook.onmicrosoft.com" --resource-group RG-eastus-NilavembuHerbs


