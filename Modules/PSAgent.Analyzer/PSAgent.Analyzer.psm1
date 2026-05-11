function Get-PSAScriptAnalysis {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    $tokens = $null
    $errors = $null

    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $Path,
        [ref]$tokens,
        [ref]$errors
    )

    # Functions
    $functions = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
    }, $true)

    # Parameters
    $parameters = @()

    if ($ast.ParamBlock) {

        foreach ($param in $ast.ParamBlock.Parameters) {

            $parameters += $param.Name.VariablePath.UserPath
        }
    }

    # Import-Module statements
    $imports = $ast.FindAll({
        param($node)

        $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -eq 'Import-Module'

    }, $true)

    $importedModules = foreach ($import in $imports) {

        if ($import.CommandElements.Count -ge 2) {
            $import.CommandElements[1].Value
        }
    }

    # Find commands used
    $commands = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst]
    }, $true)

    $commandNames = foreach ($command in $commands) {

        $commandName = $command.GetCommandName()

        if ($commandName) {
            $commandName
        }
    }

    # Basic file info
    $file = Get-Item $Path

    # Return structured result
    [PSCustomObject]@{
        ScriptName       = $file.Name
        FullPath         = $file.FullName
        LastModified     = $file.LastWriteTime
        FileSizeKB       = [math]::Round($file.Length / 1KB, 2)

        Functions        = $functions.Name
        FunctionCount    = $functions.Count

        Parameters       = $parameters
        ParameterCount   = $parameters.Count

        ImportedModules  = $importedModules | Sort-Object -Unique

        CommandsUsed     = $commandNames | Sort-Object -Unique
        CommandCount     = ($commandNames | Sort-Object -Unique).Count

        ParseErrors      = $errors.Message
        ParseErrorCount  = $errors.Count
    }
}

function Invoke-PSAgentScan {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RootPath
    )

    if (-not (Test-Path $RootPath)) {
        throw "Folder not found: $RootPath"
    }

    $scripts = Get-ChildItem -Path $RootPath -Filter *.ps1 -Recurse

    $results = foreach ($script in $scripts) {

        try {

            Write-Host "[SCAN] $($script.FullName)" -ForegroundColor Cyan

            Get-PSAScriptAnalysis -Path $script.FullName

        }
        catch {

            Write-Warning "Failed to scan $($script.FullName)"
            Write-Warning $_
        }
    }

    return $results
}

Export-ModuleMember -Function Get-PSAScriptAnalysis
Export-ModuleMember -Function Invoke-PSAgentScan