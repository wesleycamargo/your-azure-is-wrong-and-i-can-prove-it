[CmdletBinding()]
param (
    [Parameter()]
    [string]$WorkspaceDirectory

)

#--------------------------------
# Install PSRule.Rules.Azure
#--------------------------------

$modules = @('PSRule.Rules.Azure')
if (-not (Get-Module -ListAvailable -Name $modules)) {
    Write-Host "Installing PSRule.Rules.Azure module..." -ForegroundColor Green
    Install-Module -Name $modules -Scope CurrentUser -Force -ErrorAction Stop;
}
else {
    Write-Host "PSRule.Rules.Azure module is already installed." -ForegroundColor Green
}




Push-Location "$workspaceDirectory/src/vm-simple-windows"

$outputPath = "$WorkspaceDirectory/.psrule/outputs"
$outputFile = "$outputPath/results-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"

if (-not (Test-Path -Path $outputPath)) {
    New-Item -ItemType Directory -Path $outputPath | Out-Null
}

$psRuleParams = @{
    InputPath    = '.'
    Module       = $modules
    Format       = 'File'
    Option       = "$WorkspaceDirectory/.psrule/ps-rule.yaml"
    OutputFormat = 'Markdown'
    OutputPath   = $outputFile
}

Assert-PSRule @psRuleParams

Pop-Location