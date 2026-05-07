[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$WorkspaceDirectory,

    [Parameter()]
    [string]$SourcePath = 'src/vm-simple-windows',

    [Parameter()]
    [string]$OutputPath = 'reports',

    [Parameter()]
    [ValidateSet('Sarif', 'Json', 'Yaml', 'Csv', 'NUnit3', 'JUnit', 'Markdown')]
    [string]$OutputFormat = 'Sarif'
)

$ErrorActionPreference = 'Stop'

#--------------------------------
# Install PSRule.Rules.Azure
#--------------------------------
$requiredModules = @('PSRule.Rules.Azure')
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing $module module..." -ForegroundColor Green
        Install-Module -Name $module -Scope CurrentUser -Force -ErrorAction Stop
    }
    else {
        Write-Host "$module module is already installed." -ForegroundColor Green
    }
}

$extensionMap = @{
    Sarif  = 'sarif'
    Json   = 'json'
    Yaml   = 'yaml'
    Csv    = 'csv'
    NUnit3 = 'xml'
    JUnit  = 'xml'
    Markdown = 'md'
}
$resolvedOutputPath = [System.IO.Path]::IsPathRooted($OutputPath) ? $OutputPath : "$WorkspaceDirectory/$OutputPath"
$outputFile = "$resolvedOutputPath/ps-rule-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').$($extensionMap[$OutputFormat])"

if (-not (Test-Path -Path $resolvedOutputPath)) {
    New-Item -ItemType Directory -Path $resolvedOutputPath | Out-Null
}

Push-Location "$WorkspaceDirectory/$SourcePath"
try {
    $psRuleParams = @{
        InputPath    = '.'
        Module       = $requiredModules
        Format       = 'File'
        Option       = "$WorkspaceDirectory/.psrule/ps-rule.yaml"
        OutputFormat = $OutputFormat
        OutputPath   = $outputFile
    }

    Assert-PSRule @psRuleParams
}
finally {
    Pop-Location
}