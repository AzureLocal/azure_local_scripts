<#
    Author:  Kristopher J Turner
    Updated:  2025-4-1

    .DESCRIPTION
    .

    .NOTES
    .
#>

# Define the features to install
$features = @(
    "GPMC",                                   # Group Policy Management Console
    "RSAT-Clustering",                        # Failover Cluster Tools
    "RSAT-Hyper-V-Tools",                     # Hyper-V Management Tools
    "RSAT-ADDS",                              # Active Directory Domain Services and Lightweight Directory Tools
    "RSAT-ADCS",                              # Active Directory Certificate Services Tools
    "RSAT-DHCP",                              # DHCP Server Tools
    "RSAT-DNS-Server"                         # DNS Server Tools
)

# Iterate over the features and install them
foreach ($feature in $features) {
    Write-Host "Installing feature: $feature..." -ForegroundColor Green
    Install-WindowsFeature -Name $feature -IncludeManagementTools -ErrorAction Stop
    if ($?) {
        Write-Host "$feature installed successfully." -ForegroundColor Cyan
    } else {
        Write-Host "Failed to install $feature." -ForegroundColor Red
    }
}

Write-Host "All features installation completed." -ForegroundColor Green