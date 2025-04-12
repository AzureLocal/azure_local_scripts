<#
    Author:  Kristopher J Turner
    Updated:  2024-11-13

    .DESCRIPTION
    This PowerShell Script will create the Active Directory OU and Groups needed for the Azure Local Cluster v2411.

    .NOTES
    This script is for any Azure Local Cluster that will be running the 2411 release. If you are planning on deploying the 22H2 release or earlier, please use the 22H2 script.
    This version will install the most recent PowerShell Module AsHCIADArtifactsPreCreationTool from the PowerShell Gallery.  This module will create the OU and Groups needed for the Azure Local Cluster.
    It will also create the KDS Root Key needed for the cluster.  This script will also install the RSAT-ADDS and RSAT-Clustering features needed to manage the cluster from a management server.

    Check for the current version of the AsHCIADArtifactsPreCreationTool module in the PowerShell Gallery before running this script.  If there is a newer version, please update the script with the new version number. 
    https://www.powershellgallery.com/packages/AsHciADArtifactsPreCreationTool
#>

#region Prepare Active Directory
$AsHCIOUName = "" #Enter OU Path to Azure Local Cluster Here
$DomainFQDN = $env:USERDNSDOMAIN
$UserName = ""  #Enter Deployment Account/LIfe Cycle Management Account Here.
$Password = "" #Enter Password Here for Deployment Account/Life Cycle Management Account
$SecuredPassword = ConvertTo-SecureString $password -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential ($UserName, $SecuredPassword)

#Install posh module for prestaging Active Directory
Install-PackageProvider -Name NuGet -Force

#Install the AsHciADArtifactsPreCreationTool module
Install-Module AsHciADArtifactsPreCreationTool -Repository PSGallery -Force

#add KDS Root Key
if (-not (Get-KdsRootKey)) {
    Add-KdsRootKey -EffectiveTime ((Get-Date).addhours(-10))
}

New-HciAdObjectsPreCreation -AzureStackLCMUserCredential $Credentials -AsHciOUName $AsHCIOUName