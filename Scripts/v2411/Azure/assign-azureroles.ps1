<#
The following roles should be assigned at the subscription level to the user who deploys the cluster:
● Azure Stack HCI Administrator
● Reader
● Azure Resource Bridge Deployment Role

The following roles must be added to the resource group that you use for the deployment. You can assign these roles using either PowerShell commands or Azure portal:
● Key vault data access administrator
● Key vault secrets officer
● Key vault contributor
● Storage account contributor

Add the following built-in roles directly to the resource provider "Microsoft.AzureStackHCI":
● Azure Connected Machine Resource Manager

Registers the following providers:
● Microsoft.HybridCompute
● Microsoft.GuestConfiguration
● Microsoft.HybridConnectivity
● Microsoft.AzureStackHCI
#>

#Region Declare Variables
$SubscriptionID = "" #Enter your subscription ID
$Tenant = "" #Enter your tenant ID
$ResourceGroup = "" #Enter your resource group name 
$servicePrincipalName = "Azure Local Deployment" #Enter your service principal name created earlier. Example: Azure Local Deployment

#EndRegion

Connect-AzAccount -SubscriptionId $SubscriptionID -TenantId $Tenant -DeviceCode

#Region Register the providers
az provider register --namespace 'Microsoft.HybridCompute'
az provider register --namespace 'Microsoft.GuestConfiguration'
az provider register --namespace 'Microsoft.HybridConnectivity'
az provider register --namespace 'Microsoft.AzureStackHCI'
#EndRegion

#Region Get Object ID from Service Principal Name
# Retrieve the Object ID and store it in a variable
$objectId = (Get-AzADServicePrincipal -DisplayName $servicePrincipalName).Id
# Output the Object ID
Write-Output "The Object ID is: $objectId"
#EndRegion


#Region Assign the roles to the Service Principal
az role assignment create --assignee-object-id $objectID --role "Azure Stack HCI Administrator" --scope "/subscriptions/$SubscriptionID"
az role assignment create --assignee-object-id $objectID --role "Reader" --scope "/subscriptions/$SubscriptionID"
az role assignment create --assignee-object-id $objectID --role "Azure Resource Bridge Deployment Role" --scope "/subscriptions/$SubscriptionID"
az role assignment create --assignee-object-id $objectID --role "Key Vault Data Access Administrator" --scope "/subscriptions/$SubscriptionID/resourceGroups/$ResourceGroup"
az role assignment create --assignee-object-id $objectID --role "Key Vault Secrets Officer" --scope "/subscriptions/$SubscriptionID/resourceGroups/$ResourceGroup"
az role assignment create --assignee-object-id $objectID --role "Key Vault Contributor" --scope "/subscriptions/$SubscriptionID/resourceGroups/$ResourceGroup"
az role assignment create --assignee-object-id $objectID --role "Storage Account Contributor" --scope "/subscriptions/$SubscriptionID/resourceGroups/$ResourceGroup"
#EndRegion

#Region Assign Resource Provider
$roleDefinitionName = "Azure Connected Machine Resource Manager"
$resourceProviderName = "Microsoft.AzureStackHCI Resource Provider"
$RPobjectId = (Get-AzADServicePrincipal -DisplayName $resourceProviderName).Id

# Get the role definition
$roleDefinition = Get-AzRoleDefinition -Name $roleDefinitionName

# Assign the role to the resource provider
New-AzRoleAssignment -ObjectId $RPobjectId -RoleDefinitionId $roleDefinition.Id -Scope "/subscriptions/$SubscriptionID"

Write-Output "Role assignment completed successfully."
#EndRegion


# New-AzRoleAssignment -RoleDefinitionName "Azure Connected Machine Resource Manager" -Scope /subscriptions/$SubscriptionID/ResourceGroups/$ResourceGroupName -ApplicationId $RP.AppId
New-AzRoleAssignment -ObjectId $RPobjectId -RoleDefinitionId $roleDefinition.Id -Scope "/subscriptions/$SubscriptionID/ResourceGroups/$ResourceGroupName"