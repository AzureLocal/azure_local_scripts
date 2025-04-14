Install-Module -Name PowerShellGet -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name AzStackHci.EnvironmentChecker


# Connectivity Validator
Invoke-AzStackHciConnectivityValidation


# Active Directory
$params = @{
    ADOUPath                   = 'OU=Hci001,DC=contoso,DC=local'
    DomainFQDN                 = 'contoso.local'
    NamingPrefix               = "hci"
    ActiveDirectoryServer      = 'contoso.local'
    ActiveDirectoryCredentials = (Get-Credential -Message 'Active Directory Credentials')
    ClusterName                = 'S-Cluster'
    PhysicalMachineNames       = "node01, node02, node03, node04"
}
Invoke-AzStackHciExternalActiveDirectoryValidation @params


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