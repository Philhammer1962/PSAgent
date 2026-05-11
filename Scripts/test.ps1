param(
    [string]$ComputerName
)

Import-Module Posh-SSH

function Get-TestData {

    Get-Service
}

Get-TestData