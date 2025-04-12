<#
    Author:  Kristopher J Turner
    Updated:  2025-04-10

    .DESCRIPTION
    .

    .NOTES
    .

#>

<#
Step 1: Download and install the Dell APEX PowerShell module
Step 2: Verify Variables are correctly filled out
Step 3: Configure the APEX system with static IPs
Step 4: Configure Azure pre-requisites\
Step 5: Create the cluster config file (optional)
Step 6: Install HCI OS
Step 7: Import LDAP certs
Step 8: Register the nodes in Azure
Step 9: Deploy the cluster
Step 10: Monitor the cluster deployment using PowerShell in the monitoring folder.
Step 11: Windows Admin Center (optional)
#>


# Note:  Make sure that the ISO has been dismounted before continuing.

#Region Deploy Dell APEX PowerShell Module
Invoke-WebRequest -Uri https://github.com/dell/powershell-acp-azure/archive/refs/tags/1.1.0.zip -OutFile $env:UserProfile\Downloads\ACPPosh.zip
#expand and import
Expand-Archive -Path $env:UserProfile\Downloads\ACPPosh.zip -DestinationPath $env:UserProfile\Downloads\
#import modules in correct order
Import-Module $env:UserProfile\Downloads\powershell-acp-azure-1.1.0\APEXCP.Azure.API.Common
Import-Module $env:UserProfile\Downloads\powershell-acp-azure-1.1.0\APEXCP.Azure.API.SysBringup
Import-Module $env:UserProfile\Downloads\powershell-acp-azure-1.1.0\APEXCP.Azure.API.Certificate
Import-Module $env:UserProfile\Downloads\powershell-acp-azure-1.1.0\APEXCP.Azure.API
#Endregion Deploy Dell APEX PowerShell Module

#Region Variables
$AsHCIOUName = "" #OU name cant be same as cluster name in this release (day 1 validation)
$LCMUserName = ""
$LCMPassword = ""
$SecuredPassword = ConvertTo-SecureString $LCMPassword -AsPlainText -Force
$LCMCredentials = New-Object System.Management.Automation.PSCredential ($LCMUserName, $SecuredPassword)

$SecurityGroupName = "" #Security group name for the APEX system

$SubscriptionID = ""
$ResourceGroupName = ""
$Location = "EastUS"
$Cloud = "AzureCloud"

$StorageAccountName = " "
$ServicePrincipalName = "Azure Local Deployment"
$ResourceGroupName = ""
$Location = "eastus" #make sure location is lowercase as in 2308 was not able to deploy with "EastUS"
$KeyVaultName = ""

$ACPManagerIP = " "
$PrimaryNodeIP = " "

#Endregion Variables

#Region Discovery
# Get the list of all APEX systems in the environment
# If static IPs are used, this section can be skipped
$PrimaryNodeIP = "" #Primary node IP address
Get-AutoDiscoveryHosts -Server $PrimaryNodeIP
#Endregion Discovery


#Region Configure Static IPs
# This is a manual process.  Connect to the iDRAC and configure static IP (no VLANs)

#Primary Node (Node01)
#make sure you make this node primary if it's a secondary
bash /usr/share/mcp-bootstrap-utility/scripts/bootstrap/custom_node.sh -s primary -i 192.168.203.11 -m 255.255.255.0 -g 192.168.203.1

#Secondary node (Node02)
bash /usr/share/mcp-bootstrap-utility/scripts/bootstrap/custom_node.sh -s secondary -i 192.168.203.12 -m 255.255.255.0 -g 192.168.203.1
#Endregion Configure Static IPs

#Region Azure Pre-requisites

# Login to Azure
if (!(Get-InstalledModule -Name az.accounts -ErrorAction Ignore)) {
    Install-Module -Name Az.Accounts -Force
}
if (-not (Get-AzContext)) {
    Connect-AzAccount -UseDeviceAuthentication
}

$SubscriptionID = (Get-AzContext).subscription.id
# Install AZ module if not already installed
if (!(Get-InstalledModule -Name "az.resources" -ErrorAction Ignore)) {
    Install-Module -Name "az.resources" -Force
}

# Create a new resource group if it doesn't exist
if (-not(Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Ignore)) {
    New-AzResourceGroup -Name $ResourceGroupName -Location $location
}

#make sure resource providers are registered (most likely not needed)
<#
    $Providers="Microsoft.ResourceConnector","Microsoft.Authorization","Microsoft.AzureStackHCI","Microsoft.HybridCompute","Microsoft.GuestConfiguration"
    foreach ($Provider in $Providers){
        Register-AzResourceProvider -ProviderNamespace $Provider
        #wait for provider to finish registration
        do {
            $Status=Get-AzResourceProvider -ProviderNamespace $Provider
            Write-Output "Registration Status - $Provider : $(($status.RegistrationState -match 'Registered').Count)/$($Status.Count)"
            Start-Sleep 1
        } while (($status.RegistrationState -match "Registered").Count -ne ($Status.Count))
    }
#>

#Create Storage Account for witness

if (!(Get-InstalledModule -Name "az.storage"-ErrorAction Ignore)) {
    Install-Module -Name "az.storage" -Force
}

#create Storage Account
If (-not(Get-AzStorageAccountKey -Name $StorageAccountName -ResourceGroupName $ResourceGroupName -ErrorAction Ignore)) {
    New-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -SkuName Standard_LRS -Location $location -Kind StorageV2 -AccessTier Cool
}
$StorageAccountAccessKey = (Get-AzStorageAccountKey -Name $StorageAccountName -ResourceGroupName $ResourceGroupName | Select-Object -First 1).Value


#Create key vault
if (!(Get-InstalledModule -Name "az.keyvault"-ErrorAction Ignore)) {
    Install-Module -Name "az.keyvault" -Force
}
If (-not(Get-AzKeyVault -Name $KeyVaultName -ResourceGroupName $ResourceGroupName -ErrorAction Ignore)) {
    New-AzKeyVault -Name $KeyVaultName -ResourceGroupName $ResourceGroupName -Location $location
}
#configure key vault policy
$KeyVault = Get-AzKeyVault -VaultName $KeyVaultName
$KeyVault | Update-AzKeyVault -DisableRbacAuthorization $false
Set-AzKeyVaultAccessPolicy -VaultName $KeyVaultName -EnabledForDeployment -EnabledForTemplateDeployment -EnabledForDiskEncryption

#cleanup unknown (identity not found) Assignments
$Assignments = Get-AzRoleAssignment | Where-Object { $_.ObjectType.Equals("Unknown") }
$Assignments | Remove-AzRoleAssignment

#create service principal
#Create AzADServicePrincipal for Azure Stack HCI registration (if it does not exist)
#new rights! (https://www.dell.com/support/kbdoc/en-us/000219105/dell-apex-cloud-platform-application-does-not-have-sufficient-permissions-causes-cluster-deployment-validation-failed)
$SP = Get-AZADServicePrincipal -DisplayName $ServicePrincipalName
if (-not $SP) {
    $SP = New-AzADServicePrincipal -DisplayName $ServicePrincipalName -Role "Azure Stack HCI Administrator"
    #remove default cred
    Remove-AzADAppCredential -ApplicationId $SP.AppId
}


#Add other roles
New-AzRoleAssignment -RoleDefinitionName "Reader" -Scope /subscriptions/$SubscriptionID -ApplicationId $SP.AppId
New-AzRoleAssignment -RoleDefinitionName "Azure Resource Bridge Deployment Role" -Scope /subscriptions/$SubscriptionID -ApplicationId $SP.AppId
New-AzRoleAssignment -RoleDefinitionName "Key Vault Contributor" -Scope /subscriptions/$SubscriptionID/ResourceGroups/$ResourceGroupName -ApplicationId $SP.AppId
New-AzRoleAssignment -RoleDefinitionName "Key Vault Data Access Administrator" -Scope /subscriptions/$SubscriptionID/ResourceGroups/$ResourceGroupName -ApplicationId $SP.AppId
New-AzRoleAssignment -RoleDefinitionName "Key Vault Secrets Officer" -Scope /subscriptions/$SubscriptionID/ResourceGroups/$ResourceGroupName -ApplicationId $SP.AppId
New-AzRoleAssignment -RoleDefinitionName "Storage Account Contributor" -Scope /subscriptions/$SubscriptionID/ResourceGroups/$ResourceGroupName -ApplicationId $SP.AppId

#add RP rights
$RP = Get-AZADServicePrincipal -DisplayName "Microsoft.AzureStackHCI Resource Provider"
New-AzRoleAssignment -RoleDefinitionName "Azure Connected Machine Resource Manager" -Scope /subscriptions/$SubscriptionID/ResourceGroups/$ResourceGroupName -ApplicationId $RP.AppId

#Create new SPN password
$credential = New-Object -TypeName "Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.MicrosoftGraphPasswordCredential" -Property @{
    "KeyID"       = (new-guid).Guid ;
    "EndDateTime" = [DateTime]::UtcNow.AddYears(1)
}
$Creds = New-AzADAppCredential -PasswordCredentials $credential -ApplicationID $SP.AppID
$SPNSecret = $Creds.SecretText
$SPAppID = $SP.AppID

#>

#output variables
Write-Host -ForegroundColor Cyan @"
#Variables to copy
`$SubscriptionID=`"$SubscriptionID`"
`$SPAppID=`"$SPAppID`"
`$SPNSecret=`"$SPNSecret`"
`$ResourceGroupName=`"$ResourceGroupName`"
`$StorageAccountName=`"$StorageAccountName`"
`$StorageAccountAccessKey=`"$StorageAccountAccessKey`"
`$Location=`"$Location`"
`$KeyVaultName=`"$KeyVaultName`"
"@ 

#EndRegion Azure Pre-requisites

#Region Create Cluster Config
# This section will be skipped for now.  The cluster config is created in the APEX system and exported to a file.
# This file will be used to deploy the cluster. However, this is in place for documentation purposes.
$SPAppID = ""
$SPNSecret = ""
$StorageAccountAccessKey = ""

#Region Config

$Config = @"
{
  "witness": {
    "type": "CLOUD",
    "account_name": " ",
    "access_key": " "
  },
  "network": {
    "infrastructure_network": [
      {
        "subnet_mask": "255.255.255.0",
        "vlan_id": 0,
        "gateway": "192.168.203.1",
        "ip_pools": [
          {
            "starting_address": "192.168.203.20",
            "ending_address": "192.168.203.29"
          }
        ]
      }
    ],
    "host_network": {
      "storage_switch_topology": "SWITCHLESS",
      "intents": [
        {
          "name": "Compute-Management",
          "traffic_type": [
            "Compute",
            "Management"
          ],
          "adapter": [
            "Embedded NIC 1",
            "Embedded NIC 2"
          ],
          "override_virtual_switch_configuration": true,
          "virtual_switch_configuration_overrides": {
            "enable_iov": true,
            "load_balancing_algorithm": "HyperVPort"
          },
          "override_qos_policy": false,
          "qos_policy_overrides": {
            "priority_value8021_action_cluster": "",
            "priority_value8021_action_smb": "",
            "bandwidth_percentage_smb": ""
          },
          "override_adapter_property": true,
          "adapter_property_overrides": {
            "jumbo_packet": "9014",
            "network_direct": "",
            "network_direct_technology": ""
          }
        },
        {
          "name": "Storage",
          "traffic_type": [
            "Storage"
          ],
          "adapter": [
            "Embedded NIC 3",
            "Embedded NIC 4"
          ],
          "override_virtual_switch_configuration": true,
          "virtual_switch_configuration_overrides": {
            "enable_iov": true,
            "load_balancing_algorithm": "HyperVPort"
          },
          "override_qos_policy": true,
          "qos_policy_overrides": {
            "priority_value8021_action_cluster": "7",
            "priority_value8021_action_smb": "3",
            "bandwidth_percentage_smb": "50"
          },
          "override_adapter_property": true,
          "adapter_property_overrides": {
            "jumbo_packet": "9014",
            "network_direct": "ENABLED",
            "network_direct_technology": "IWARP"
          }
        }
      ],
      "enable_storage_auto_ip": true,
      "storage_networks": [
        {
          "network_adapter_name": "Embedded NIC 3",
          "vlan_id": 711
        },
        {
          "network_adapter_name": "Embedded NIC 4",
          "vlan_id": 712
        }
      ]
    }
  },
  "global": {
    "storage": {
      "configuration_mode": "INFRA_ONLY"
    },
    "dns_server": [
      "10.250.1.36",
      "10.250.1.37"
    ],
    "eu_location": false,
    "episodic_data_upload": true,
    "streaming_data_client": true,
    "cluster": {
      "name": " "
    }
  },
  "hosts": [
    {
      "serial_number": " ",
      "rack": {
        "name": "",
        "position": ""
      },
      "hostname": " ",
      "account": {
        "type": "admin",
        "username": "administrator",
        "password": " "
      },
      "management_network_ip": "192.168.203.12"
    },
    {
      "serial_number": " ",
      "rack": {
        "name": "",
        "position": ""
      },
      "hostname": " ",
      "account": {
        "type": "admin",
        "username": "administrator",
        "password": " "
      },
      "management_network_ip": "192.168.203.11"
    }
  ],
  "ad_domain": {
    "domain_name": " ",
    "ou_path": " ",
    "accounts": [
      {
        "type": "MANAGEMENT",
        "username": " ",
        "password": " "
      }
    ]
  },
  "ldaps": {
    "fqdn": " ",
    "port": 636
  },
  "kerberos": {
    "kdc": [
      " "
    ],
    "admin_server": " "
  },
  "azure_portal": {
    "cloud": "AZURE_CLOUD",
    "subscription_id": " ",
    "resource_group": " ",
    "service_principal": {
      "application_id": " ",
      "application_secret": " "
    },
    "custom_location": " ",
    "key_vault_name": " "
  },
  "cloud_platform_manager": {
    "hostname": "apxcpm-01",
    "ip": "192.168.203.10",
    "accounts": [
      {
        "type": "ROOT",
        "username": "root",
        "password": " "
      },
      {
        "type": "MANAGEMENT",
        "username": "mystic",
        "password": " "
      },
      {
        "type": "SERVICE",
        "username": "service",
        "password": " "
      }
    ]
  },
  "azure_proxy_server": {},
  "version": "10.2411",
  "wac": {}
}
"@

$Config | Out-File $env:USERPROFILE\Downloads\Config.json

#Endregion Config

#Endregion Create Cluster Config


#Region Install HCI OS

Start-SystemBringup -Server $PrimaryNodeIP -Mode OS_PROVISION -Conf $env:USERPROFILE\Downloads\Config.json

# Track the installation using PowerShell.  We cal also track it from the APEX Deployment Portal.
Get-BringupProgressStatus -CloudPlatformManagerIP $ACPManagerIP -PrimaryHostIP $PrimaryNodeIP -Mode OS_PROVISION

#Endregion Install HCI OS

#Region Import LDAP certs

Initialize-LDAPsCertificate -Server $ACPManagerIP -Cert <path_to_cert_file_content>

# https://www.dell.com/support/kbdoc/en-us/000215552

#Endregion Import LDAP certs

#Region Register Nodes In Azure

Start-SystemBringup -Server $ACPManagerIP -Mode LTP_REGISTRATION -Conf $env:USERPROFILE\Downloads\Config.json

# Monitor progress
Get-BringupProgressStatus -CloudPlatformManagerIP $ACPManagerIP -Mode LTP_REGISTRATION

#endregion Register Nodes In Azure


#region Deploy Cluster
Start-SystemBringup -Server $ACPManagerIP -Mode CLUSTER_DEPLOYMENT -Conf $env:USERPROFILE\Downloads\Config.json

# Monitor
Get-BringupProgressStatus -CloudPlatformManagerIP $ACPManagerIP -Mode CLUSTER_DEPLOYMENT

#endregion Deploy Cluster

# Monitor the cluster deployment using PowerShell in the monitoring folder.


# Windows Admin Center
# https://www.dell.com/support/kbdoc/en-us/000275807?lang=en