# Azure Defender for Cloud Data Export Script

This PowerShell script captures comprehensive Azure Defender for Cloud security data including Secure Score metrics, Cloud Security Posture Management (CSPM) data, and Regulatory Compliance assessments, then exports everything to CSV files for analysis and reporting.

## Features

- **Secure Score Data**: Current scores, maximum scores, controls, and detailed breakdowns
- **CSPM Data**: Security assessments, recommendations, and posture management information
- **Compliance Data**: Regulatory compliance standards, controls, and assessment states
- **CSV Export**: Well-formatted CSV files with timestamps for historical tracking
- **Comprehensive Logging**: Detailed logging with multiple severity levels
- **Error Handling**: Robust error handling with detailed error messages
- **Progress Reporting**: Progress indicators for large data exports
- **Multi-Subscription Support**: Process single subscription or all accessible subscriptions

## Prerequisites

### Software Requirements
- **PowerShell 7.0 or higher** (recommended: latest version)
- **Azure PowerShell Modules**:
  - `Az.Accounts` (for authentication)
  - `Az.ResourceGraph` (for resource queries)
  - `Az.Security` (for security data)

### Azure Permissions
Your account needs the following minimum permissions:
- **Security Reader** role (or higher) at the subscription level
- **Reader** role for Azure Resource Graph queries
- Access to the target subscription(s)

### Installation

1. **Install PowerShell 7.0+**:
   ```powershell
   # Windows (using winget)
   winget install Microsoft.PowerShell
   
   # Or download from: https://github.com/PowerShell/PowerShell/releases
   ```

2. **Install required Azure modules**:
   ```powershell
   Install-Module -Name Az.Accounts, Az.ResourceGraph, Az.Security -Force -AllowClobber
   ```

3. **Authenticate to Azure**:
   ```powershell
   Connect-AzAccount
   ```

## Usage

### Basic Usage

Export secure score and CSPM data for all accessible subscriptions (outputs to `.\Reports` directory):
```powershell
.\Export-AzureDefenderData.ps1
```

### Advanced Usage Examples

**Export data for a specific subscription with compliance data:**
```powershell
.\Export-AzureDefenderData.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -IncludeCompliance
```

**Export all data types with date suffix to a custom directory:**
```powershell
.\Export-AzureDefenderData.ps1 -OutputPath "C:\SecurityReports" -IncludeCompliance -IncludeRecommendations -DateSuffix
```

**Export with verbose logging:**
```powershell
.\Export-AzureDefenderData.ps1 -Verbose -IncludeCompliance -IncludeRecommendations
```

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `SubscriptionId` | String | No | Specific Azure subscription ID to analyze. If not provided, all accessible subscriptions will be processed |
| `OutputPath` | String | No | Directory path where CSV files will be saved. Defaults to `.\Reports` directory |
| `IncludeCompliance` | Switch | No | Include regulatory compliance data in the export |
| `IncludeRecommendations` | Switch | No | Include detailed security recommendations in the export |
| `DateSuffix` | Switch | No | Add date/time suffix to output files for historical tracking |

## Output Files

The script generates the following CSV files:

### Always Generated
- **`SecureScores.csv`**: Overall secure scores per subscription
  - Columns: tenantId, subscriptionId, percentageScore, currentScore, maxScore, weight, etc.

- **`SecureScoreControls.csv`**: Detailed security controls data
  - Columns: tenantId, subscriptionId, controlName, displayName, maxScore, currentScore, percentage, etc.

- **`SecurityAssessments.csv`**: All security assessments
  - Columns: tenantId, subscriptionId, assessmentName, severity, status, resourceType, etc.

- **`ExportSummary.csv`**: Summary information about the export run
  - Columns: ReportDate, TenantId, SubscriptionId, OutputPath, ScriptVersion, etc.

### Optional Files (based on parameters)

- **`SecurityRecommendations.csv`** (when `-IncludeRecommendations` is specified):
  - Detailed security recommendations for unhealthy resources
  - Columns: recommendationName, severity, description, remediationDescription, resourceId, etc.

- **`ComplianceStandards.csv`** (when `-IncludeCompliance` is specified):
  - Regulatory compliance standards overview
  - Columns: complianceStandard, state, passedControls, failedControls, etc.

- **`ComplianceControls.csv`** (when `-IncludeCompliance` is specified):
  - Detailed compliance controls data
  - Columns: complianceStandard, controlName, description, state, assessments, etc.

- **`ComplianceAssessments.csv`** (when `-IncludeCompliance` is specified):
  - Individual compliance assessments
  - Columns: complianceStandard, complianceControl, assessmentName, state, resources, etc.

## File Naming

- **Without DateSuffix**: `SecureScores.csv`, `ComplianceStandards.csv`, etc.
- **With DateSuffix**: `SecureScores_20240918_143052.csv`, `ComplianceStandards_20240918_143052.csv`, etc.

## Logging

The script creates a detailed log file in the `.\Logs` directory: `AzureDefenderExport_YYYYMMDD_HHMMSS.log`

Log levels:
- **Info**: General information and progress updates
- **Success**: Successful operations
- **Warning**: Non-critical issues
- **Error**: Critical errors that may stop execution

## Data Sources

The script uses Azure Resource Graph queries to collect data from:
- `microsoft.security/securescores`
- `microsoft.security/securescores/securescorecontrols`
- `microsoft.security/assessments`
- `microsoft.security/regulatorycompliancestandards`
- `microsoft.security/regulatorycompliancestandards/regulatorycompliancecontrols`
- `microsoft.security/regulatorycompliancestandards/regulatorycompliancecontrols/regulatorycomplianceassessments`

## Troubleshooting

### Common Issues

1. **"Prerequisites check failed"**
   - Ensure PowerShell 7.0+ is installed
   - Install required Azure modules: `Install-Module Az.Accounts, Az.ResourceGraph, Az.Security`

2. **"Azure connection test failed"**
   - Run `Connect-AzAccount` to authenticate
   - Verify you have access to the target subscription

3. **"No data returned"**
   - Verify Defender for Cloud is enabled on the subscription
   - Check your permissions (need Security Reader role minimum)
   - Some subscriptions may not have security data if Defender for Cloud isn't configured

4. **"Failed to set subscription context"**
   - Verify the subscription ID is correct
   - Ensure you have access to the specified subscription

### Performance Considerations

- Large environments (1000+ resources) may take several minutes to complete
- Azure Resource Graph has a maximum limit of 1000 records per query
- The script warns if the 1000 record limit is reached (indicating potential additional data)
- For environments with >1000 security assessments, consider filtering by resource group or running per subscription
- Consider running during off-peak hours for large exports

## Security Considerations

- The script uses read-only operations and doesn't modify any Azure resources
- Exported CSV files may contain sensitive information - handle appropriately
- Log files contain detailed execution information - review before sharing
- Follow your organization's data handling policies for exported security data

### Git History Security

If you accidentally committed sensitive data files to Git:

**Quick cleanup** (removes files from Git history):
```powershell
.\Quick-PurgeHistory.ps1
```

**Advanced cleanup** (comprehensive history rewriting):
```powershell
.\Purge-GitHistory.ps1
```

⚠️ **Important**: These operations rewrite Git history and require force-pushing to remote repositories. All collaborators will need to re-clone the repository.

## Examples

### Daily Security Report
```powershell
# Create a daily report with all data types (uses default .\Reports directory)
.\Export-AzureDefenderData.ps1 -IncludeCompliance -IncludeRecommendations -DateSuffix

# Or specify a custom path
$date = Get-Date -Format "yyyyMMdd"
$outputPath = "C:\SecurityReports\Daily_$date"
.\Export-AzureDefenderData.ps1 -OutputPath $outputPath -IncludeCompliance -IncludeRecommendations -DateSuffix
```

### Compliance Audit Report
```powershell
# Focus on compliance data for audit purposes
.\Export-AzureDefenderData.ps1 -IncludeCompliance -OutputPath "C:\AuditReports" -Verbose
```

### Multi-Subscription Analysis
```powershell
# Process specific subscriptions
$subscriptions = @("sub1-guid", "sub2-guid", "sub3-guid")
foreach ($sub in $subscriptions) {
    $outputPath = "C:\Reports\$sub"
    .\Export-AzureDefenderData.ps1 -SubscriptionId $sub -OutputPath $outputPath -IncludeCompliance -DateSuffix
}
```

## Version Control

The project includes Git configuration files:
- **`.gitignore`**: Excludes output files, logs, and sensitive data from version control
- **`.gitattributes`**: Ensures proper line endings and file handling
- **`Setup-Git.ps1`**: Helper script to initialize a Git repository

To set up version control:
```powershell
.\Setup-Git.ps1
```

## Version History

- **v1.0**: Initial release with secure score, CSPM, and compliance data export

## Support

For issues or questions:
1. Check the log file for detailed error messages
2. Verify prerequisites and permissions
3. Test with a single subscription first
4. Review the troubleshooting section above

## License

This script is provided as-is for educational and operational purposes. Use in accordance with your organization's policies and Microsoft's terms of service.