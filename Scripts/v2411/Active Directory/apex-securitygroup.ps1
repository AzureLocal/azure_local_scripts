<#
    Author:  Kristopher J Turner
    Updated:  2024-11-13

    .DESCRIPTION
    This PowerShell Script will  Creates the security group with suffix ACPManager to authenticate and authorize.

    .NOTES
    This script creates the security group with suffix ACPManager to authenticate and authorize.  Remember to update the variables with the correct values for your environment.
    Change the $user and $OUPath to match the values you used when you created the OU Name.  The $prefix is the prefix you used when you created the OU Name.
    The $group is the name of the security group you want to create.  The $user is the user you want to add to the security group.The $OUPath is the path to the OU you created in the Active Directory configuration script.
#>


$prefix = "" #Enter the prefix. Example clus01.
$group = $prefix + "-ACPManager"
$user = "" #management user name used when you previously created the OU Name
$OUPath = "" #OU created by previous new-hciadobjectprecreation script E

New-Adgroup -Name $group -GroupScope Global -GroupCategory Security -Path $OUPath -Description "Security group for ACP Manager"
Add-AdGroupMember -Identity $group -Members $user
