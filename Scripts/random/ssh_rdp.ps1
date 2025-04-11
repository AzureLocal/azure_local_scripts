<#
    Author:  Kristopher J Turner
    Updated:  2023-11-13

    .DESCRIPTION
    This PowerShell Script will connect to an Azure Arc VM RDP via SSH.

    .NOTES
    .
#>

$ResourceGroup = "" #Resource Group Name
$VMName = "" #VM Name
$localLogin = "" #Local Admin Account

az login --use-device-code

az ssh arc --resource-group $ResourceGroup --name $VMName --local-user $localLogin --rdp