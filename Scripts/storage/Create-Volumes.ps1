<#
    Author:  Kristopher J Turner
    Updated:  2024-11-13

    .DESCRIPTION
    This PowerShell Script .

    .NOTES

#>

#Region Variables
# Define variables
$StoragePoolName = "SU1_Pool"          # Storage pool name
$VolumeBaseName = ""        # Base name for volumes
$FileSystem = "CSVFS_ReFS"             # File system type
$VolumeSize = 3TB                    # Size of each volume
$ResiliencySetting = "Mirror"          # Resiliency setting
$NumberOfVolumes = 2                   # Number of volumes to create
#EndRegion


#Region Create Storage Volumes
# Loop to create volumes
for ($i = 1; $i -le $NumberOfVolumes; $i++) {
    $VolumeName = "$VolumeBaseName$i"  # Append number to base name

    New-Volume -StoragePoolFriendlyName $StoragePoolName `
        -FriendlyName $VolumeName `
        -FileSystem $FileSystem `
        -Size $VolumeSize `
        -ResiliencySettingName $ResiliencySetting `
        -ProvisioningType Fixed

    Write-Output "Volume $VolumeName created successfully."
}

#EndRegion


<# Older way
#Region Create Storage Volumes
New-Volume -FriendlyName "UserStorage_01" -FileSystem CSVFS_ReFS -StoragePoolFriendlyName SU1_Pool -Size 2.5TB -ResiliencySettingName Mirror
New-Volume -FriendlyName "UserStorage_02" -FileSystem CSVFS_ReFS -StoragePoolFriendlyName SU1_Pool -Size 2.5TB -ResiliencySettingName Mirror
New-Volume -FriendlyName "UserStorage_03" -FileSystem CSVFS_ReFS -StoragePoolFriendlyName SU1_Pool -Size 2.5TB -ResiliencySettingName Mirror
New-Volume -FriendlyName "UserStorage_04" -FileSystem CSVFS_ReFS -StoragePoolFriendlyName SU1_Pool -Size 2.5TB -ResiliencySettingName Mirror
#EndRegion
#>