[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$SubscriptionId,

    [Parameter(Mandatory)]
    [string]$WorkspaceDirectory,

    [Parameter()]
    [string]$OutputPath = 'reports',

    [Parameter()]
    [switch]$ConnectToAzure
)

$ErrorActionPreference = 'Stop'

#--------------------------------
# Install PSRule.Rules.Azure
#--------------------------------

$requiredModules = @('PSRule.Rules.Azure', 'Az.Accounts', 'Az.Resources')
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Verbose "Installing $module module..."
        Install-Module -Name $module -Scope CurrentUser -Force -ErrorAction Stop
    }
    else {
        Write-Verbose "$module module is already installed."
    }
}

#--------------------------------
# Connect and set context
#--------------------------------

if ($ConnectToAzure.IsPresent) {
    Write-Verbose 'Connecting to Azure...'
    Connect-AzAccount -ErrorAction Stop
}

Write-Verbose "Setting subscription context: $SubscriptionId"
Set-AzContext -Subscription $SubscriptionId -ErrorAction Stop

#--------------------------------
# Export policy assignments
#--------------------------------

$resolvedOutputPath = [System.IO.Path]::IsPathRooted($OutputPath) ? $OutputPath : "$WorkspaceDirectory/$OutputPath"

if (-not (Test-Path -Path $resolvedOutputPath)) {
    New-Item -ItemType Directory -Path $resolvedOutputPath | Out-Null
}

Write-Verbose "Exporting policy assignments to: $resolvedOutputPath"
Export-AzPolicyAssignmentData -OutputPath $resolvedOutputPath

#--------------------------------
# Convert assignments to rules
#--------------------------------

$assignmentFile = Get-ChildItem -Path $resolvedOutputPath -Filter '*.assignment.json' |
    Sort-Object -Property LastWriteTime -Descending |
    Select-Object -First 1

if (-not $assignmentFile) {
    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
        [System.IO.FileNotFoundException]::new("No *.assignment.json file found in '$resolvedOutputPath'. Ensure Export-AzPolicyAssignmentData succeeded."),
        'AssignmentFileNotFound',
        [System.Management.Automation.ErrorCategory]::ObjectNotFound,
        $resolvedOutputPath
    )
    $PSCmdlet.ThrowTerminatingError($errorRecord)
}

Write-Verbose "Converting assignments to rules from: $($assignmentFile.FullName)"
Export-AzPolicyAssignmentRuleData -AssignmentFile $assignmentFile.FullName -OutputPath $resolvedOutputPath

#--------------------------------
# Copy rules to .psrule/ for PSRule pickup
#--------------------------------

$psRuleDir = "$WorkspaceDirectory/.psrule"
$ruleFile = Get-ChildItem -Path $resolvedOutputPath -Filter '*.Rule.jsonc' |
    Sort-Object -Property LastWriteTime -Descending |
    Select-Object -First 1

if ($ruleFile) {
    $destination = Join-Path -Path $psRuleDir -ChildPath $ruleFile.Name
    Write-Verbose "Copying '$($ruleFile.Name)' to '$psRuleDir'"
    Copy-Item -Path $ruleFile.FullName -Destination $destination -Force
    Write-Host "Policy rules ready: $destination" -ForegroundColor Green
}
else {
    Write-Warning "No *.Rule.jsonc file was generated in '$resolvedOutputPath'. No policies may have been exported."
}