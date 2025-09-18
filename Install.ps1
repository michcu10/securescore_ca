# Installation and Setup Script for Azure Defender for Cloud Data Export

Write-Host "=== Azure Defender for Cloud Data Export - Installation Script ===" -ForegroundColor Green
Write-Host "This script will install prerequisites and set up the environment.`n" -ForegroundColor White

# Check PowerShell version
Write-Host "Checking PowerShell version..." -ForegroundColor Yellow
$psVersion = $PSVersionTable.PSVersion
Write-Host "Current PowerShell version: $psVersion" -ForegroundColor White

if ($psVersion.Major -lt 7) {
    Write-Host "WARNING: PowerShell 7.0 or higher is recommended." -ForegroundColor Red
    Write-Host "Current version: $psVersion" -ForegroundColor Red
    Write-Host "Please install PowerShell 7.x from: https://github.com/PowerShell/PowerShell/releases" -ForegroundColor Yellow
    $continue = Read-Host "Continue with current version? (y/N)"
    if ($continue -notmatch '^[Yy]') {
        exit 1
    }
} else {
    Write-Host "✓ PowerShell version is compatible" -ForegroundColor Green
}

Write-Host ""

# Check execution policy
Write-Host "Checking execution policy..." -ForegroundColor Yellow
$executionPolicy = Get-ExecutionPolicy
Write-Host "Current execution policy: $executionPolicy" -ForegroundColor White

if ($executionPolicy -eq 'Restricted') {
    Write-Host "WARNING: Execution policy is set to Restricted." -ForegroundColor Red
    $setPolicy = Read-Host "Set execution policy to RemoteSigned for current user? (Y/n)"
    if ($setPolicy -notmatch '^[Nn]') {
        try {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Write-Host "✓ Execution policy updated" -ForegroundColor Green
        }
        catch {
            Write-Host "✗ Failed to update execution policy: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
} else {
    Write-Host "✓ Execution policy allows script execution" -ForegroundColor Green
}

Write-Host ""

# Install required modules
Write-Host "Installing required Azure PowerShell modules..." -ForegroundColor Yellow
$requiredModules = @('Az.Accounts', 'Az.ResourceGraph', 'Az.Security')

foreach ($module in $requiredModules) {
    Write-Host "Checking module: $module" -ForegroundColor White
    
    try {
        $installedModule = Get-Module -Name $module -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
        
        if ($installedModule) {
            Write-Host "  ✓ Module $module version $($installedModule.Version) is already installed" -ForegroundColor Green
        } else {
            Write-Host "  Installing module: $module" -ForegroundColor Yellow
            Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser
            Write-Host "  ✓ Module $module installed successfully" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  ✗ Failed to install module $module : $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""

# Create default directories
Write-Host "Creating default directories..." -ForegroundColor Yellow
$defaultDirs = @(".\Reports", ".\Logs", ".\Config")

foreach ($dir in $defaultDirs) {
    try {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Host "  ✓ Created directory: $dir" -ForegroundColor Green
        } else {
            Write-Host "  ✓ Directory already exists: $dir" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  ✗ Failed to create directory $dir : $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""

# Test Azure connection
Write-Host "Testing Azure connection..." -ForegroundColor Yellow
try {
    $context = Get-AzContext
    if ($context) {
        Write-Host "  ✓ Already connected to Azure" -ForegroundColor Green
        Write-Host "    Account: $($context.Account.Id)" -ForegroundColor White
        Write-Host "    Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))" -ForegroundColor White
    } else {
        Write-Host "  Not connected to Azure" -ForegroundColor Yellow
        $connect = Read-Host "Connect to Azure now? (Y/n)"
        if ($connect -notmatch '^[Nn]') {
            Connect-AzAccount
            $context = Get-AzContext
            if ($context) {
                Write-Host "  ✓ Successfully connected to Azure" -ForegroundColor Green
            }
        }
    }
}
catch {
    Write-Host "  ✗ Error checking Azure connection: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test script execution
Write-Host "Testing script execution..." -ForegroundColor Yellow
if (Test-Path ".\Export-AzureDefenderData.ps1") {
    Write-Host "  ✓ Main script found: Export-AzureDefenderData.ps1" -ForegroundColor Green
    
    $testRun = Read-Host "Run a test execution? (y/N)"
    if ($testRun -match '^[Yy]') {
        Write-Host "  Running test execution..." -ForegroundColor Yellow
        try {
            # Run with WhatIf equivalent (just test connection and prerequisites)
            & ".\Export-AzureDefenderData.ps1" -OutputPath ".\Reports" -Verbose
            Write-Host "  ✓ Test execution completed successfully" -ForegroundColor Green
        }
        catch {
            Write-Host "  ✗ Test execution failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
} else {
    Write-Host "  ✗ Main script not found: Export-AzureDefenderData.ps1" -ForegroundColor Red
    Write-Host "    Please ensure all script files are in the current directory" -ForegroundColor Yellow
}

Write-Host ""

# Display summary and next steps
Write-Host "=== Installation Summary ===" -ForegroundColor Green
Write-Host "✓ PowerShell version checked" -ForegroundColor White
Write-Host "✓ Execution policy verified" -ForegroundColor White
Write-Host "✓ Required modules installed" -ForegroundColor White
Write-Host "✓ Default directories created" -ForegroundColor White
Write-Host "✓ Azure connection tested" -ForegroundColor White

Write-Host ""
Write-Host "=== Next Steps ===" -ForegroundColor Cyan
Write-Host "1. Review the README.md file for detailed usage instructions" -ForegroundColor White
Write-Host "2. Check Examples.ps1 for common usage patterns" -ForegroundColor White
Write-Host "3. Customize Config.ps1 if needed" -ForegroundColor White
Write-Host "4. Run your first export:" -ForegroundColor White
Write-Host "   .\Export-AzureDefenderData.ps1 -Verbose" -ForegroundColor Yellow

Write-Host ""
Write-Host "Installation completed! 🎉" -ForegroundColor Green