<#
    Author:  Kristopher J Turner
    Updated:  2023-11-13

    .DESCRIPTION
    This PowerShell Script will monitor the deployment of 23H2.

    .NOTES
    This script is for any Azure Stack HCI Cluster that will be running the 23H2. This will monitor the cloud deployment of 23H2.
#>


# Before domain join
#Create new password credentials
$Servers = "", "" #Enter Server Names Example: "Server1", "Server2"
$UserName = "Administrator"
$Password = "" #Enter Local Admin Password
$SecuredPassword = ConvertTo-SecureString $password -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential ($UserName, $SecuredPassword)

#configure trusted hosts to be able to communicate with servers (not secure)
$TrustedHosts = @()
$TrustedHosts += $Servers
Set-Item WSMan:\localhost\Client\TrustedHosts -Value $($TrustedHosts -join ',') -Force

Invoke-Command -ComputerName $Servers[0] -ScriptBlock {
    ([xml](Get-Content C:\ecestore\efb61d70-47ed-8f44-5d63-bed6adc0fb0f\086a22e3-ef1a-7b3a-dc9d-f407953b0f84)) | Select-Xml -XPath "//Action/Steps/Step" | ForEach-Object { $_.Node } | Select-Object FullStepIndex, Status, Name, StartTimeUtc, EndTimeUtc, @{Name = "Duration"; Expression = { new-timespan -Start $_.StartTimeUtc -End $_.EndTimeUtc } } | Format-Table -AutoSize
} -Credential $Credentials

# Monitor the deployment process with automatic refresh every 2 minutes

while ($true) {
    Invoke-Command -ComputerName $Servers[0] -ScriptBlock {
        ([xml](Get-Content C:\ecestore\efb61d70-47ed-8f44-5d63-bed6adc0fb0f\086a22e3-ef1a-7b3a-dc9d-f407953b0f84)) |
        Select-Xml -XPath "//Action/Steps/Step" |
        ForEach-Object { $_.Node } |
        Select-Object FullStepIndex, Status, Name, StartTimeUtc, EndTimeUtc,
            @{Name = "Duration"; Expression = { new-timespan -Start $_.StartTimeUtc -End $_.EndTimeUtc } } |
        Format-Table -AutoSize
    } -Credential $Credentials
    Start-Sleep -Seconds 120
}


#after domain join
#Create new password credentials
$Servers = "", "" #Enter Server Names Example: "Server1", "Server2"
$UserName = "" #Enter Deployment Account
$Password = "" #Enter Account Password
$SecuredPassword = ConvertTo-SecureString $password -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential ($UserName, $SecuredPassword)



Invoke-Command -ComputerName $Servers[0] -ScriptBlock {
         ([xml](Get-Content C:\ecestore\efb61d70-47ed-8f44-5d63-bed6adc0fb0f\086a22e3-ef1a-7b3a-dc9d-f407953b0f84)) | Select-Xml -XPath "//Action/Steps/Step" | ForEach-Object { $_.Node } | Select-Object FullStepIndex, Status, Name, StartTimeUtc, EndTimeUtc, @{Name = "Duration"; Expression = { new-timespan -Start $_.StartTimeUtc -End $_.EndTimeUtc } } | Format-Table -AutoSize
}

# Monitor the deployment process with automatic refresh every 2 minutes

while ($true) {
    Invoke-Command -ComputerName $Servers[0] -ScriptBlock {
        ([xml](Get-Content C:\ecestore\efb61d70-47ed-8f44-5d63-bed6adc0fb0f\086a22e3-ef1a-7b3a-dc9d-f407953b0f84)) | 
        Select-Xml -XPath "//Action/Steps/Step" | 
        ForEach-Object { $_.Node } | 
        Select-Object FullStepIndex, Status, Name, StartTimeUtc, EndTimeUtc, 
            @{Name = "Duration"; Expression = { new-timespan -Start $_.StartTimeUtc -End $_.EndTimeUtc } } | 
        Format-Table -AutoSize
    } -Credential $Credentials
    Start-Sleep -Seconds 120
}
