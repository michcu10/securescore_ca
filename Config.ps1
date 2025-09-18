# Azure Defender for Cloud Export Configuration
# This file contains default settings that can be customized

# Output Settings
$DefaultOutputPath = ".\Reports"
$DefaultDateFormat = "yyyyMMdd_HHmmss"
$DefaultFileEncoding = "UTF8"

# Query Settings (Azure Resource Graph has a max limit of 1000 per query)
$MaxQueryResults = @{
    SecureScores = 1000
    SecureScoreControls = 1000
    SecurityAssessments = 1000  # Uses pagination for larger datasets
    SecurityRecommendations = 1000  # Uses pagination for larger datasets
    ComplianceStandards = 1000
    ComplianceControls = 1000  # Uses pagination for larger datasets
    ComplianceAssessments = 1000  # Uses pagination for larger datasets
}

# Progress Reporting Settings
$ProgressThreshold = 1000  # Show progress bar for datasets larger than this

# Logging Settings
$LoggingEnabled = $true
$VerboseLogging = $false
$LogRetentionDays = 30

# Export Settings
$ExportSettings = @{
    IncludePropertiesColumn = $true
    SanitizeFilenames = $true
    CreateIndexFiles = $false
}

# Subscription Settings
$ExcludedSubscriptions = @()  # Array of subscription IDs to exclude
$IncludedResourceGroups = @()  # If specified, only include these resource groups

# Performance Settings
$ParallelProcessing = $false
$MaxConcurrentJobs = 3
$QueryTimeoutSeconds = 300

# Custom Field Mappings (for renaming columns in output)
$FieldMappings = @{
    # Example: 'properties.displayName' = 'DisplayName'
    # 'tenantId' = 'TenantID'
    # 'subscriptionId' = 'SubscriptionID'
}

# Data Filters
$DataFilters = @{
    # Include only specific severities for recommendations
    RecommendationSeverities = @('High', 'Medium', 'Low')
    
    # Include only specific compliance standards
    ComplianceStandards = @()  # Empty means include all
    
    # Include only specific assessment states
    AssessmentStates = @('Healthy', 'Unhealthy', 'NotApplicable')
}

# File naming templates
$FileNameTemplates = @{
    SecureScores = "SecureScores"
    SecureScoreControls = "SecureScoreControls"
    SecurityAssessments = "SecurityAssessments"
    SecurityRecommendations = "SecurityRecommendations"
    ComplianceStandards = "ComplianceStandards"
    ComplianceControls = "ComplianceControls"
    ComplianceAssessments = "ComplianceAssessments"
    ExportSummary = "ExportSummary"
}

# To use this configuration in your script, dot-source it:
# . .\Config.ps1