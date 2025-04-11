<#
    Author:  Kristopher J Turner
    Updated:  2024-11-13

    .DESCRIPTION
    This PowerShell Script .

    .NOTES

https://learn.microsoft.com/en-us/azure-stack/hci/manage/create-storage-path?tabs=azurecli#delete-a-storage-path
#>

<#
#Region Variables
$storagepathname="<Storage path name>"
$path="<Path on the disk to cluster shared volume>"
$subscription="<Subscription ID>"
$resource_group="<Resource group name>"
$customLocName="<Custom location of your Azure Local>"
$customLocationID="/subscriptions/<Subscription ID>/resourceGroups/$resource_group/providers/Microsoft.ExtendedLocation/customLocations/$customLocName"
$location="<Azure region where the system is deployed>"


#region Login to Azure
az login --use-device-code
#az account --subscription ""
#endregion

#Region Create Storage Path
az stack-hci-vm storagepath create --resource-group $resource_group --custom-location $customLocationID --name $storagepathname --path $path
#EndRegion

#>