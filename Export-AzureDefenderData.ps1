#Requires -Version 7.0
#Requires -Module Az.Accounts, Az.ResourceGraph, Az.Security

<#
.SYNOPSIS
    Exports Azure Defender for Cloud CSPM, Compliance, and Secure Score data to CSV files.

.DESCRIPTION
    This script captures comprehensive Azure Defender for Cloud security data including:
    - Secure Score metrics and controls
    - Cloud Security Posture Management (CSPM) data
    - Regulatory Compliance assessments
    - Security recommendations and controls
    
    Data is exported to CSV files with timestamps for tracking over time.

.PARAMETER SubscriptionId
    Specific Azure subscription ID to analyze. If not provided, all accessible subscriptions will be processed.

.PARAMETER OutputPath
    Directory path where CSV files will be saved. Defaults to .\Reports directory.

.PARAMETER IncludeCompliance
    Include regulatory compliance data in the export.

.PARAMETER IncludeRecommendations
    Include detailed security recommendations in the export.

.PARAMETER DateSuffix
    Add date suffix to output files for historical tracking.

.EXAMPLE
    .\Export-AzureDefenderData.ps1 -OutputPath "C:\Reports" -DateSuffix
    
.EXAMPLE
    .\Export-AzureDefenderData.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -IncludeCompliance -IncludeRecommendations

.NOTES
    Author: Azure Security Script
    Version: 1.0
    Requirements:
    - PowerShell 7.0+
    - Az.Accounts module
    - Az.ResourceGraph module
    - Az.Security module
    - Appropriate Azure permissions (Security Reader or higher)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\Reports",
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeCompliance,
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeRecommendations,
    
    [Parameter(Mandatory = $false)]
    [switch]$DateSuffix
)

# Global variables
$script:ErrorActionPreference = 'Stop'
$script:ProgressPreference = 'Continue'
$script:VerbosePreference = if ($PSBoundParameters['Verbose']) { 'Continue' } else { 'SilentlyContinue' }

# Initialize logging
$script:LogsPath = ".\Logs"
$script:LogFile = Join-Path $script:LogsPath "AzureDefenderExport_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$script:StartTime = Get-Date

#region Helper Functions

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Write to console with colors
    switch ($Level) {
        'Info' { Write-Host $logMessage -ForegroundColor White }
        'Warning' { Write-Host $logMessage -ForegroundColor Yellow }
        'Error' { Write-Host $logMessage -ForegroundColor Red }
        'Success' { Write-Host $logMessage -ForegroundColor Green }
    }
    
    # Write to log file (create directory if needed)
    try {
        $logDir = Split-Path $script:LogFile -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        Add-Content -Path $script:LogFile -Value $logMessage
    }
    catch {
        # If logging fails, continue without logging to avoid breaking the script
        Write-Warning "Failed to write to log file: $($_.Exception.Message)"
    }
}

function Test-AzureConnection {
    Write-Log "Testing Azure connection..."
    
    try {
        $context = Get-AzContext
        if (-not $context) {
            Write-Log "No Azure context found. Please run Connect-AzAccount first." -Level Error
            return $false
        }
        
        Write-Log "Connected to Azure as: $($context.Account.Id)" -Level Success
        Write-Log "Current subscription: $($context.Subscription.Name) ($($context.Subscription.Id))" -Level Info
        return $true
    }
    catch {
        Write-Log "Failed to get Azure context: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Get-SafeFileName {
    param(
        [string]$BaseName,
        [string]$Extension = '.csv'
    )
    
    $timestamp = if ($DateSuffix) { "_$(Get-Date -Format 'yyyyMMdd_HHmmss')" } else { "" }
    return Join-Path $OutputPath "$BaseName$timestamp$Extension"
}

function Invoke-SafeQuery {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,
        
        [Parameter(Mandatory = $true)]
        [string]$DataTypeName,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxResults = 1000
    )
    
    try {
        Write-Log "Querying $DataTypeName data (max $MaxResults records)..." -Level Info
        $results = Search-AzGraph -Query $Query -First $MaxResults
        
        if ($results) {
            Write-Log "Retrieved $($results.Count) $DataTypeName records" -Level Success
            
            # Warn if we hit the maximum limit (there might be more data)
            if ($results.Count -eq $MaxResults) {
                Write-Log "Warning: Retrieved maximum limit of $MaxResults records. There may be additional data not included." -Level Warning
                Write-Log "Consider filtering your query or running for specific subscriptions to get complete data." -Level Warning
            }
        } else {
            Write-Log "No $DataTypeName records found" -Level Info
            $results = @()
        }
        
        return $results
    }
    catch {
        Write-Log "Failed to retrieve $DataTypeName data: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Export-ToCsv {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Data,
        
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $true)]
        [string]$DataType
    )
    
    try {
        if ($Data.Count -eq 0) {
            Write-Log "No $DataType data to export" -Level Warning
            return
        }
        
        # Ensure output directory exists
        $directory = Split-Path $FilePath -Parent
        if (-not (Test-Path $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        
        # Add progress reporting for large datasets  
        if ($Data.Count -gt 1000) {
            Write-Progress -Activity "Exporting $DataType" -Status "Processing $($Data.Count) records..." -PercentComplete 0
        }
        
        $Data | Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8
        
        if ($Data.Count -gt 1000) {
            Write-Progress -Activity "Exporting $DataType" -Completed
        }
        
        Write-Log "Exported $($Data.Count) $DataType records to: $FilePath" -Level Success
        
        # Validate the exported file
        if (Test-Path $FilePath) {
            $fileSize = (Get-Item $FilePath).Length
            Write-Log "File size: $([math]::Round($fileSize / 1KB, 2)) KB" -Level Info
        }
    }
    catch {
        Write-Log "Failed to export $DataType data: $($_.Exception.Message)" -Level Error
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error
        throw
    }
}

function Test-Prerequisites {
    Write-Log "Checking prerequisites..." -Level Info
    
    $issues = @()
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        $issues += "PowerShell 7.0 or higher is required. Current version: $($PSVersionTable.PSVersion)"
    }
    
    # Check required modules
    $requiredModules = @('Az.Accounts', 'Az.ResourceGraph', 'Az.Security')
    foreach ($module in $requiredModules) {
        try {
            $moduleInfo = Get-Module -Name $module -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
            if (-not $moduleInfo) {
                $issues += "Required module '$module' is not installed. Install with: Install-Module -Name $module"
            } else {
                Write-Log "Module $module version $($moduleInfo.Version) is available" -Level Info
            }
        }
        catch {
            $issues += "Failed to check module '$module': $($_.Exception.Message)"
        }
    }
    
    if ($issues.Count -gt 0) {
        Write-Log "Prerequisites check failed:" -Level Error
        foreach ($issue in $issues) {
            Write-Log "  - $issue" -Level Error
        }
        return $false
    }
    
    Write-Log "All prerequisites met" -Level Success
    return $true
}

#endregion

#region Azure Resource Graph Queries

function Get-SecureScoreData {
    Write-Log "Collecting Secure Score data..."
    
    $query = @"
SecurityResources
| where type == 'microsoft.security/securescores'
| extend percentageScore = properties.score.percentage,
         currentScore = properties.score.current,
         maxScore = properties.score.max,
         weight = properties.weight
| project tenantId, subscriptionId, percentageScore, currentScore, maxScore, weight, 
          resourceGroup, name, id, tags, properties
"@
    
    try {
        $results = Search-AzGraph -Query $query -First 1000
        Write-Log "Retrieved $($results.Count) secure score records" -Level Success
        return $results
    }
    catch {
        Write-Log "Failed to retrieve secure score data: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Get-SecureScoreControls {
    Write-Log "Collecting Secure Score Controls data..."
    
    $query = @"
SecurityResources
| where type == 'microsoft.security/securescores/securescorecontrols'
| extend controlName = name,
         displayName = properties.displayName,
         maxScore = properties.maxScore,
         currentScore = properties.currentScore,
         percentage = properties.percentage,
         weight = properties.weight,
         healthyResourceCount = properties.healthyResourceCount,
         unhealthyResourceCount = properties.unhealthyResourceCount,
         notApplicableResourceCount = properties.notApplicableResourceCount
| project tenantId, subscriptionId, controlName, displayName, maxScore, currentScore, 
          percentage, weight, healthyResourceCount, unhealthyResourceCount, 
          notApplicableResourceCount, id, properties
"@
    
    try {
        $results = Search-AzGraph -Query $query -First 1000
        Write-Log "Retrieved $($results.Count) secure score control records" -Level Success
        return $results
    }
    catch {
        Write-Log "Failed to retrieve secure score controls: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Get-SecurityAssessments {
    Write-Log "Collecting Security Assessments data..."
    
    $query = @"
SecurityResources
| where type == 'microsoft.security/assessments'
| extend assessmentName = properties.displayName,
         severity = properties.metadata.severity,
         assessmentType = properties.metadata.assessmentType,
         category = properties.metadata.categories,
         status = properties.status.code,
         statusCause = properties.status.cause,
         statusDescription = properties.status.description,
         resourceType = properties.resourceDetails.id,
         implementationEffort = properties.metadata.implementationEffort,
         userImpact = properties.metadata.userImpact,
         threats = properties.metadata.threats
| project tenantId, subscriptionId, resourceGroup, assessmentName, severity, assessmentType,
          category, status, statusCause, statusDescription, resourceType, 
          implementationEffort, userImpact, threats, id, name, properties
"@
    
    return Invoke-SafeQuery -Query $query -DataTypeName "security assessment" -MaxResults 1000
}

function Get-SecurityRecommendations {
    Write-Log "Collecting Security Recommendations data..."
    
    $query = @"
SecurityResources
| where type == 'microsoft.security/assessments'
| where properties.status.code == 'Unhealthy'
| extend recommendationName = properties.displayName,
         severity = properties.metadata.severity,
         category = properties.metadata.categories,
         description = properties.metadata.description,
         remediationDescription = properties.metadata.remediationDescription,
         policyDefinitionId = properties.metadata.policyDefinitionId,
         implementationEffort = properties.metadata.implementationEffort,
         userImpact = properties.metadata.userImpact,
         threats = properties.metadata.threats,
         resourceId = properties.resourceDetails.id,
         resourceType = split(properties.resourceDetails.id, '/')[6],
         resourceName = split(properties.resourceDetails.id, '/')[-1]
| project tenantId, subscriptionId, resourceGroup, recommendationName, severity, category,
          description, remediationDescription, policyDefinitionId, implementationEffort,
          userImpact, threats, resourceId, resourceType, resourceName, id, properties
"@
    
    return Invoke-SafeQuery -Query $query -DataTypeName "security recommendation" -MaxResults 1000
}

function Get-RegulatoryComplianceStandards {
    Write-Log "Collecting Regulatory Compliance Standards data..."
    
    $query = @"
SecurityResources
| where type == 'microsoft.security/regulatorycompliancestandards'
| extend complianceStandard = name,
         state = properties.state,
         passedControls = properties.passedControls,
         failedControls = properties.failedControls,
         skippedControls = properties.skippedControls,
         unsupportedControls = properties.unsupportedControls
| project tenantId, subscriptionId, complianceStandard, state, passedControls, 
          failedControls, skippedControls, unsupportedControls, id, properties
"@
    
    try {
        $results = Search-AzGraph -Query $query -First 1000
        Write-Log "Retrieved $($results.Count) regulatory compliance standard records" -Level Success
        return $results
    }
    catch {
        Write-Log "Failed to retrieve regulatory compliance standards: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Get-RegulatoryComplianceAssessments {
    Write-Log "Collecting Regulatory Compliance Assessments data..."
    
    $query = @"
SecurityResources
| where type == 'microsoft.security/regulatorycompliancestandards/regulatorycompliancecontrols/regulatorycomplianceassessments'
| extend assessmentName = properties.description,
         complianceStandard = extract(@'/regulatoryComplianceStandards/(.+)/regulatoryComplianceControls',1,id),
         complianceControl = extract(@'/regulatoryComplianceControls/(.+)/regulatoryComplianceAssessments',1,id),
         skippedResources = properties.skippedResources,
         passedResources = properties.passedResources,
         failedResources = properties.failedResources,
         state = properties.state
| project tenantId, subscriptionId, id, complianceStandard, complianceControl, 
          assessmentName, state, skippedResources, passedResources, failedResources, properties
"@
    
    return Invoke-SafeQuery -Query $query -DataTypeName "regulatory compliance assessment" -MaxResults 1000
}

function Get-RegulatoryComplianceControls {
    Write-Log "Collecting Regulatory Compliance Controls data..."
    
    $query = @"
SecurityResources
| where type == 'microsoft.security/regulatorycompliancestandards/regulatorycompliancecontrols'
| extend complianceStandard = extract(@'/regulatoryComplianceStandards/(.+)/regulatoryComplianceControls',1,id),
         controlName = name,
         description = properties.description,
         state = properties.state,
         passedAssessments = properties.passedAssessments,
         failedAssessments = properties.failedAssessments,
         skippedAssessments = properties.skippedAssessments
| project tenantId, subscriptionId, complianceStandard, controlName, description, state,
          passedAssessments, failedAssessments, skippedAssessments, id, properties
"@
    
    return Invoke-SafeQuery -Query $query -DataTypeName "regulatory compliance control" -MaxResults 1000
}

#endregion

#region Main Functions

function Initialize-Script {
    Write-Log "=== Azure Defender for Cloud Data Export Started ===" -Level Info
    Write-Log "Script Parameters:" -Level Info
    Write-Log "  - SubscriptionId: $($SubscriptionId -or 'All accessible subscriptions')" -Level Info
    Write-Log "  - OutputPath: $OutputPath" -Level Info
    Write-Log "  - IncludeCompliance: $IncludeCompliance" -Level Info
    Write-Log "  - IncludeRecommendations: $IncludeRecommendations" -Level Info
    Write-Log "  - DateSuffix: $DateSuffix" -Level Info
    
    # Check prerequisites
    if (-not (Test-Prerequisites)) {
        throw "Prerequisites check failed. Please resolve the issues above and try again."
    }
    
    # Test Azure connection
    if (-not (Test-AzureConnection)) {
        throw "Azure connection test failed. Please run 'Connect-AzAccount' first."
    }
    
    # Set subscription context if specified
    if ($SubscriptionId) {
        try {
            Write-Log "Setting subscription context to: $SubscriptionId" -Level Info
            $context = Set-AzContext -SubscriptionId $SubscriptionId
            Write-Log "Set context to subscription: $($context.Subscription.Name) ($SubscriptionId)" -Level Success
        }
        catch {
            Write-Log "Failed to set subscription context: $($_.Exception.Message)" -Level Error
            throw "Unable to set subscription context. Please verify the subscription ID and your permissions."
        }
    }
    
    # Ensure output directory exists and is writable
    try {
        if (-not (Test-Path $OutputPath)) {
            New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
            Write-Log "Created output directory: $OutputPath" -Level Info
        }
        
        # Test write access
        $testFile = Join-Path $OutputPath "test_write.tmp"
        "test" | Out-File -FilePath $testFile -Force
        Remove-Item -Path $testFile -Force
        Write-Log "Output directory is writable: $OutputPath" -Level Success
    }
    catch {
        Write-Log "Failed to create or write to output directory: $($_.Exception.Message)" -Level Error
        throw "Unable to create or write to output directory: $OutputPath"
    }
    
    # Ensure logs directory exists
    try {
        if (-not (Test-Path $script:LogsPath)) {
            New-Item -ItemType Directory -Path $script:LogsPath -Force | Out-Null
            Write-Log "Created logs directory: $($script:LogsPath)" -Level Info
        }
    }
    catch {
        Write-Log "Failed to create logs directory: $($_.Exception.Message)" -Level Warning
        # Continue execution even if logs directory creation fails
    }
    
    # Log system information
    Write-Log "PowerShell version: $($PSVersionTable.PSVersion)" -Level Info
    Write-Log "OS: $($PSVersionTable.OS)" -Level Info
    Write-Log "Current user: $env:USERNAME" -Level Info
}

function Export-SecureScoreData {
    Write-Log "Starting Secure Score data export..." -Level Info
    
    try {
        # Get secure score data
        $secureScores = Get-SecureScoreData
        $fileName = Get-SafeFileName -BaseName "SecureScores"
        Export-ToCsv -Data $secureScores -FilePath $fileName -DataType "Secure Score"
        
        # Get secure score controls
        $secureScoreControls = Get-SecureScoreControls
        $fileName = Get-SafeFileName -BaseName "SecureScoreControls"
        Export-ToCsv -Data $secureScoreControls -FilePath $fileName -DataType "Secure Score Controls"
        
        Write-Log "Secure Score data export completed" -Level Success
    }
    catch {
        Write-Log "Failed to export Secure Score data: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Export-CSPMData {
    Write-Log "Starting CSPM data export..." -Level Info
    
    try {
        # Get security assessments
        $assessments = Get-SecurityAssessments
        $fileName = Get-SafeFileName -BaseName "SecurityAssessments"
        Export-ToCsv -Data $assessments -FilePath $fileName -DataType "Security Assessments"
        
        # Get security recommendations if requested
        if ($IncludeRecommendations) {
            $recommendations = Get-SecurityRecommendations
            $fileName = Get-SafeFileName -BaseName "SecurityRecommendations"
            Export-ToCsv -Data $recommendations -FilePath $fileName -DataType "Security Recommendations"
        }
        
        Write-Log "CSPM data export completed" -Level Success
    }
    catch {
        Write-Log "Failed to export CSPM data: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Export-ComplianceData {
    Write-Log "Starting Compliance data export..." -Level Info
    
    try {
        # Get regulatory compliance standards
        $complianceStandards = Get-RegulatoryComplianceStandards
        $fileName = Get-SafeFileName -BaseName "ComplianceStandards"
        Export-ToCsv -Data $complianceStandards -FilePath $fileName -DataType "Compliance Standards"
        
        # Get regulatory compliance controls
        $complianceControls = Get-RegulatoryComplianceControls
        $fileName = Get-SafeFileName -BaseName "ComplianceControls"
        Export-ToCsv -Data $complianceControls -FilePath $fileName -DataType "Compliance Controls"
        
        # Get regulatory compliance assessments
        $complianceAssessments = Get-RegulatoryComplianceAssessments
        $fileName = Get-SafeFileName -BaseName "ComplianceAssessments"
        Export-ToCsv -Data $complianceAssessments -FilePath $fileName -DataType "Compliance Assessments"
        
        Write-Log "Compliance data export completed" -Level Success
    }
    catch {
        Write-Log "Failed to export Compliance data: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Invoke-MainExport {
    try {
        Initialize-Script
        
        # Always export secure score data
        Export-SecureScoreData
        
        # Always export CSPM data (includes assessments and optionally recommendations)
        Export-CSPMData
        
        # Export compliance data if requested
        if ($IncludeCompliance) {
            Export-ComplianceData
        }
        
        # Generate summary report
        Generate-SummaryReport
        
        $duration = (Get-Date) - $script:StartTime
        Write-Log "=== Export completed successfully in $($duration.TotalMinutes.ToString('F2')) minutes ===" -Level Success
    }
    catch {
        Write-Log "Export failed: $($_.Exception.Message)" -Level Error
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error
        throw
    }
}

function Generate-SummaryReport {
    Write-Log "Generating summary report..." -Level Info
    
    try {
        $summary = @()
        
        # Get current context
        $context = Get-AzContext
        
        $summary += [PSCustomObject]@{
            ReportDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            TenantId = $context.Tenant.Id
            SubscriptionId = $context.Subscription.Id
            SubscriptionName = $context.Subscription.Name
            OutputPath = $OutputPath
            IncludeCompliance = $IncludeCompliance
            IncludeRecommendations = $IncludeRecommendations
            ScriptVersion = "1.0"
        }
        
        $fileName = Get-SafeFileName -BaseName "ExportSummary"
        Export-ToCsv -Data $summary -FilePath $fileName -DataType "Export Summary"
        
        Write-Log "Summary report generated successfully" -Level Success
    }
    catch {
        Write-Log "Failed to generate summary report: $($_.Exception.Message)" -Level Warning
    }
}

#endregion

# Script execution
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-MainExport
}