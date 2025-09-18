# Example Usage Scripts for Azure Defender for Cloud Data Export

# 1. Basic Usage - Export secure score and assessments for current subscription
Write-Host "Example 1: Basic export for current subscription" -ForegroundColor Green
.\Export-AzureDefenderData.ps1

Write-Host "`n" -NoNewline

# 2. Full Export - All data types with date suffix
Write-Host "Example 2: Full export with all data types and date suffix" -ForegroundColor Green
.\Export-AzureDefenderData.ps1 -IncludeCompliance -IncludeRecommendations -DateSuffix -Verbose

Write-Host "`n" -NoNewline

# 3. Specific Subscription - Target a specific subscription with custom output path
Write-Host "Example 3: Specific subscription with custom output path" -ForegroundColor Green
$subscriptionId = "12345678-1234-1234-1234-123456789012"  # Replace with your subscription ID
$outputPath = "C:\SecurityReports\$(Get-Date -Format 'yyyy-MM')"
.\Export-AzureDefenderData.ps1 -SubscriptionId $subscriptionId -OutputPath $outputPath -IncludeCompliance

Write-Host "`n" -NoNewline

# 4. Compliance Focus - Export only compliance-related data
Write-Host "Example 4: Compliance-focused export" -ForegroundColor Green
.\Export-AzureDefenderData.ps1 -IncludeCompliance -OutputPath "C:\ComplianceReports" -DateSuffix

Write-Host "`n" -NoNewline

# 5. Daily Automated Report - Script for daily automation
Write-Host "Example 5: Daily automated report script" -ForegroundColor Green
$dailyReportPath = "C:\DailySecurityReports\$(Get-Date -Format 'yyyy-MM-dd')"
.\Export-AzureDefenderData.ps1 -OutputPath $dailyReportPath -IncludeCompliance -IncludeRecommendations -DateSuffix

Write-Host "`n" -NoNewline

# 6. Multi-Subscription Processing - Process multiple subscriptions
Write-Host "Example 6: Multi-subscription processing" -ForegroundColor Green
$subscriptions = @(
    "12345678-1234-1234-1234-123456789012",
    "87654321-4321-4321-4321-210987654321",
    "11111111-2222-3333-4444-555555555555"
)

foreach ($sub in $subscriptions) {
    Write-Host "Processing subscription: $sub" -ForegroundColor Yellow
    $subOutputPath = "C:\MultiSubReports\$sub\$(Get-Date -Format 'yyyy-MM-dd')"
    .\Export-AzureDefenderData.ps1 -SubscriptionId $sub -OutputPath $subOutputPath -IncludeCompliance -DateSuffix
}

Write-Host "`n" -NoNewline

# 7. Error Handling Example - With try-catch for automation
Write-Host "Example 7: Error handling for automation" -ForegroundColor Green
try {
    .\Export-AzureDefenderData.ps1 -IncludeCompliance -IncludeRecommendations -DateSuffix -ErrorAction Stop
    Write-Host "Export completed successfully" -ForegroundColor Green
    
    # Optional: Send success notification
    # Send-MailMessage -To "admin@company.com" -Subject "Azure Security Export Success" -Body "Daily export completed successfully"
}
catch {
    Write-Host "Export failed: $($_.Exception.Message)" -ForegroundColor Red
    
    # Optional: Send failure notification
    # Send-MailMessage -To "admin@company.com" -Subject "Azure Security Export Failed" -Body "Export failed: $($_.Exception.Message)"
    
    # Log to Windows Event Log
    Write-EventLog -LogName Application -Source "Azure Security Export" -EventId 1001 -EntryType Error -Message "Export failed: $($_.Exception.Message)"
}

Write-Host "`n" -NoNewline

# 8. Scheduled Task Example - PowerShell command for Task Scheduler
Write-Host "Example 8: Command for Windows Task Scheduler" -ForegroundColor Green
$taskCommand = @"
PowerShell.exe -ExecutionPolicy Bypass -File "C:\Scripts\Export-AzureDefenderData.ps1" -OutputPath "C:\ScheduledReports" -IncludeCompliance -IncludeRecommendations -DateSuffix
"@
Write-Host "Task Scheduler Command: $taskCommand" -ForegroundColor Cyan

Write-Host "`n" -NoNewline

# 9. Performance Optimized - For large environments
Write-Host "Example 9: Performance optimized for large environments" -ForegroundColor Green
# Pre-authenticate to avoid timeouts
Connect-AzAccount -Identity  # For managed identity
# Or Connect-AzAccount for interactive

# Run with minimal data first to test
.\Export-AzureDefenderData.ps1 -OutputPath "C:\LargeEnvReports" -Verbose

Write-Host "`n" -NoNewline

# 10. Custom Analysis Example - Process exported data
Write-Host "Example 10: Post-export data analysis" -ForegroundColor Green
.\Export-AzureDefenderData.ps1 -OutputPath "C:\AnalysisReports" -IncludeCompliance -DateSuffix

# Example analysis of exported data
$secureScores = Import-Csv "C:\AnalysisReports\SecureScores_*.csv" | Sort-Object Name -Descending | Select-Object -First 1
$assessments = Import-Csv "C:\AnalysisReports\SecurityAssessments_*.csv" | Sort-Object Name -Descending | Select-Object -First 1

if ($secureScores) {
    $avgScore = ($secureScores | Measure-Object -Property percentageScore -Average).Average
    Write-Host "Average Secure Score: $([math]::Round($avgScore, 2))%" -ForegroundColor Cyan
}

if ($assessments) {
    $unhealthyCount = ($assessments | Where-Object { $_.status -eq 'Unhealthy' }).Count
    $totalCount = $assessments.Count
    Write-Host "Unhealthy Assessments: $unhealthyCount out of $totalCount ($([math]::Round(($unhealthyCount/$totalCount)*100, 2))%)" -ForegroundColor Cyan
}

Write-Host "`nAll examples completed!" -ForegroundColor Green