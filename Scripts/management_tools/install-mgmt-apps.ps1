<#
    Author:  Kristopher J Turner
    Updated:  2025-4-1

    .DESCRIPTION
    .

    .NOTES
    .
#>

winget install -e --id Microsoft.VisualStudioCode --scope machine
winget install -e --id Microsoft.PowerShell --scope machine
winget install -e --id Git.Git --scope machine
winget install -e --id Microsoft.AzureCLI --scope machine
winget install -e --id GitHub.GitHubDesktop --scope machine
winget install -e --id PuTTY.PuTTY --scope machine
winget install -e --id Kubernetes.kubectl --scope machine
winget install -e --id WinSCP.WinSCP --scope machine
winget install -e --id Helm.Helm --scope machine

Install-Module -Name Az -Scope CurrentUser -AllowClobber -Force
Import-Module Az
