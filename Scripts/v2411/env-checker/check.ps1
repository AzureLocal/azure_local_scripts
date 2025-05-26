Install-Module -Name PowerShellGet -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name AzStackHci.EnvironmentChecker


$UserName = "USNC17LCMmngr"
$Password = "!QazXSw2#EdcVFr4"
$SecuredPassword = ConvertTo-SecureString $password -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential ($UserName, $SecuredPassword)



# Active Directory
$params = @{
    ADOUPath                   = 'OU=USNC17,OU=AzureLocal,DC=CORNERSTONEHCI,DC=COM'
    DomainFQDN                 = 'cornerstonehci.com'
    NamingPrefix               = "poc"
    ActiveDirectoryServer      = 'cornerstonehci.com'
    ActiveDirectoryCredentials = $Credentials
    ClusterName                = 'USNC17ACP-Clstr'
    PhysicalMachineNames       = "poc-01-n01, poc-01-n02"
}
Invoke-AzStackHciExternalActiveDirectoryValidation @params

# Connectivity Validator
Invoke-AzStackHciConnectivityValidation



# Network Validation
$allServers = "10.125.6.11" # you need to use IP for the connection
$userName = "<LOCALADMIN>"
$secPassWord = ConvertTo-SecureString "<LOCALADMINPASSWORD>" -AsPlainText -Force 
$hostCred = New-Object System.Management.Automation.PSCredential($userName, $secPassWord) 
[System.Management.Automation.Runspaces.PSSession[]] $allServerSessions = @() 
foreach ($currentServer in $allServers) { 
    $currentSession = Microsoft.PowerShell.Core\New-PSSession -ComputerName $currentServer -Credential $hostCred -ErrorAction Stop 
    $allServerSessions += $currentSession 
} 
$answerFilePath = "<ANSWERFILELOCATION>" # Like C:\MASLogs\Unattended-2024-07-18-20-44-48.json 
Invoke-AzStackHciNetworkValidation -DeployAnswerFile $answerFilePath -PSSession $allServerSessions -ProxyEnabled $false



Set-NetAdapterAdvancedProperty -Name "Embedded NIC 1" -DisplayName "VLAN ID" -DisplayValue "6"
Set-NetAdapterAdvancedProperty -Name "Embedded NIC 2" -DisplayName "VLAN ID" -DisplayValue "6"


#Import required module
import-module ActiveDirectory

#Input parameters
$ouPath ="OU=USNC17,OU=AzureLocal,DC=CORNERSTONEHCI,DC=COM"
$DeploymentUser="USNC17LCMmngr"

#Assign required permissions
$userSecurityIdentifier = Get-ADuser -Identity $Deploymentuser
$userSID = [System.Security.Principal.SecurityIdentifier] $userSecurityIdentifier.SID
$acl = Get-Acl -Path "AD:$ouPath"
$userIdentityReference = [System.Security.Principal.IdentityReference] $userSID
$adRight = [System.DirectoryServices.ActiveDirectoryRights]::CreateChild -bor [System.DirectoryServices.ActiveDirectoryRights]::DeleteChild
$genericAllRight = [System.DirectoryServices.ActiveDirectoryRights]::GenericAll
$readPropertyRight = [System.DirectoryServices.ActiveDirectoryRights]::ReadProperty
$type = [System.Security.AccessControl.AccessControlType]::Allow 
$inheritanceType = [System.DirectoryServices.ActiveDirectorySecurityInheritance]::All 
$allObjectType = [System.Guid]::Empty

#Set computers object GUID, this is a well-known ID
$computersObjectType = [System.Guid]::New('bf967a86-0de6-11d0-a285-00aa003049e2')

#Set msFVE-RecoveryInformation GUID,this is a well-known ID
$msfveRecoveryGuid = [System.Guid]::New('ea715d30-8f53-40d0-bd1e-6109186d782c')
$rule1 = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($userIdentityReference, $adRight, $type, $computersObjectType, $inheritanceType)
$rule2 = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($userIdentityReference, $readPropertyRight, $type, $allObjectType , $inheritanceType)
$rule3 = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($userIdentityReference, $genericAllRight, $type, $inheritanceType, $msfveRecoveryGuid)
$acl.AddAccessRule($rule1)
$acl.AddAccessRule($rule2)
$acl.AddAccessRule($rule3)
Set-Acl -Path "AD:$ouPath" -AclObject $acl



# Script to list AD user permissions on specified OU
# Requires ActiveDirectory module

param (
    [Parameter(Mandatory=$true)]
    [string]$UserName,
    [Parameter(Mandatory=$true)]
    [string]$OUDistinguishedName
)

Import-Module ActiveDirectory

# Get user SID
$user = Get-ADUser -Identity $UserName
$userSid = $user.SID

# Get specified OU
$ou = Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$OUDistinguishedName'"

# Initialize results array
$results = @()

if ($ou) {
    $acl = Get-Acl -Path "AD:$($ou.DistinguishedName)"
    
    foreach ($ace in $acl.Access) {
        if ($ace.IdentityReference -eq $userSid -or $ace.IdentityReference -eq $user.Name) {
            $results += [PSCustomObject]@{
                OU             = $ou.DistinguishedName
                Rights         = $ace.ActiveDirectoryRights
                AccessControlType = $ace.AccessControlType
                IsInherited    = $ace.IsInherited
            }
        }
    }
}

# Output results
if ($results.Count -eq 0) {
    Write-Output "No specific OU permissions found for user: $UserName on OU: $OUDistinguishedName"
} else {
    $results | Format-Table -AutoSize
}


$ports = @(49152..49160)
$ports | ForEach-Object { Test-NetConnection -ComputerName cornerstonehci.com -Port $_ -InformationLevel Detailed }

$ports = @(53, 88, 123, 135, 137, 138, 139, 389, 445, 464, 636, 3268, 3269, 5722, 5985, 9389, 443, 49443)
$ports | ForEach-Object { Test-NetConnection -ComputerName cornerstonehci.com -Port $_ -InformationLevel Detailed }




# Define your target domain controller (hostname or IP)
$domainController = "USIS04DC-P04.cornerstonehci.com"

# Define required AD ports for Azure Stack HCI / Azure Local
$requiredPorts = @(
    53,      # DNS
    88,      # Kerberos
    123,     # NTP (optional but recommended for time sync)
    135,     # RPC Endpoint Mapper
    137,138,139, # NetBIOS
    389,     # LDAP
    445,     # SMB
    464,     # Kerberos password change
    636,     # LDAPS
    3268,    # Global Catalog
    3269,    # Global Catalog over SSL
    5722,    # DFSR (optional, if used)
    5985,    # WinRM HTTP (used during some remote automation)
    9389,    # AD Web Services (required for AD PowerShell)
    443,     # HTTPS (Arc / Azure APIs)
    49443    # Azure Edge (Azure Local / Arc extensions)
)

# Include dynamic RPC port range (49152–65535) if needed
$rpcDynamicPorts = 49152..65535

# Combine ports to test
$portsToTest = $requiredPorts + $rpcDynamicPorts

# Optional: log file for results
$logFile = "ADPortTestResults.txt"
Remove-Item $logFile -ErrorAction SilentlyContinue

# Run test for each port
$results = foreach ($port in $portsToTest) {
    $test = Test-NetConnection -ComputerName $domainController -Port $port -InformationLevel Quiet
    [PSCustomObject]@{
        Port    = $port
        Status  = if ($test) { "Open" } else { "Closed" }
    }
}

# Output summary
$results | Format-Table -AutoSize
$results | Out-File $logFile

Write-Host "Port test completed. Results saved to: $logFile" -ForegroundColor Green


param (
    [string]$DomainController = "USIS04DC-P04.cornerstonehci.com"
)

# Ports to test for TCP and UDP
$tcpPorts = @(
    53,      # DNS
    88,      # Kerberos
    123,     # NTP (often UDP, included for completeness)
    135,     # RPC Endpoint Mapper
    137,138,139, # NetBIOS
    389,     # LDAP
    445,     # SMB
    464,     # Kerberos password change
    636,     # LDAPS
    3268,    # Global Catalog
    3269,    # Global Catalog SSL
    5722,    # DFSR
    5985,    # WinRM HTTP
    9389,    # AD Web Services
    443,     # HTTPS (Azure Local, Arc)
    49443    # Azure Edge Device Management
)

$udpPorts = @(
    53,      # DNS
    88,      # Kerberos
    123,     # NTP
    137,138  # NetBIOS
)

# Function to test UDP port
function Test-UDPPort {
    param (
        [string]$ComputerName,
        [int]$Port
    )
    try {
        $udpClient = New-Object System.Net.Sockets.UdpClient
        $udpClient.Client.ReceiveTimeout = 2000
        $endpoint = New-Object System.Net.IPEndPoint ([System.Net.Dns]::GetHostAddresses($ComputerName)[0], $Port)
        $udpClient.Connect($endpoint)
        $sendBytes = [System.Text.Encoding]::ASCII.GetBytes("Ping")
        $udpClient.Send($sendBytes, $sendBytes.Length) | Out-Null
        # Note: No reliable way to know if port received packet unless service replies
        $udpClient.Close()
        return "Sent"
    } catch {
        return "Failed"
    }
}

# Results array
$results = @()

Write-Host "`nTesting TCP ports..." -ForegroundColor Cyan
foreach ($port in $tcpPorts) {
    $tcpResult = Test-NetConnection -ComputerName $DomainController -Port $port -InformationLevel Quiet
    $status = if ($tcpResult) { "Open" } else { "Closed" }
    $results += [PSCustomObject]@{
        Protocol = "TCP"
        Port     = $port
        Status   = $status
    }
    Write-Host "TCP $port:`t$status"
}

Write-Host "`nTesting UDP ports..." -ForegroundColor Cyan
foreach ($port in $udpPorts) {
    $udpStatus = Test-UDPPort -ComputerName $DomainController -Port $port
    $status = if ($udpStatus -eq "Sent") { "Sent (UDP likely open)" } else { "Failed" }
    $results += [PSCustomObject]@{
        Protocol = "UDP"
        Port     = $port
        Status   = $status
    }
    Write-Host "UDP $port:`t$status"
}

# Optional: save to CSV
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$results | Export-Csv -NoTypeInformation -Path "AD_Port_Test_$timestamp.csv"

Write-Host "`n✅ Test complete. Results saved to AD_Port_Test_$timestamp.csv" -ForegroundColor Green
