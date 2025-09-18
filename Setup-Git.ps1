# Git Repository Setup Script for Azure Defender for Cloud Data Export

Write-Host "=== Git Repository Setup ===" -ForegroundColor Green
Write-Host "This script will initialize a Git repository for the Azure Defender Export project.`n" -ForegroundColor White

# Check if Git is installed
try {
    $gitVersion = git --version 2>$null
    if ($gitVersion) {
        Write-Host "✓ Git is installed: $gitVersion" -ForegroundColor Green
    } else {
        throw "Git not found"
    }
}
catch {
    Write-Host "✗ Git is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Git from: https://git-scm.com/downloads" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Check if already a Git repository
if (Test-Path ".git") {
    Write-Host "✓ This directory is already a Git repository" -ForegroundColor Yellow
    $reinit = Read-Host "Reinitialize repository? (y/N)"
    if ($reinit -notmatch '^[Yy]') {
        Write-Host "Exiting without changes" -ForegroundColor Yellow
        exit 0
    }
}

# Initialize Git repository
Write-Host "Initializing Git repository..." -ForegroundColor Yellow
try {
    git init
    Write-Host "✓ Git repository initialized" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed to initialize Git repository: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Set up basic Git configuration (optional)
Write-Host "Git configuration:" -ForegroundColor Yellow
$userName = git config user.name 2>$null
$userEmail = git config user.email 2>$null

if (-not $userName) {
    $inputName = Read-Host "Enter your name for Git commits (or press Enter to skip)"
    if ($inputName) {
        git config user.name "$inputName"
        Write-Host "✓ Set user name: $inputName" -ForegroundColor Green
    }
} else {
    Write-Host "✓ Git user name already set: $userName" -ForegroundColor Green
}

if (-not $userEmail) {
    $inputEmail = Read-Host "Enter your email for Git commits (or press Enter to skip)"
    if ($inputEmail) {
        git config user.email "$inputEmail"
        Write-Host "✓ Set user email: $inputEmail" -ForegroundColor Green
    }
} else {
    Write-Host "✓ Git user email already set: $userEmail" -ForegroundColor Green
}

Write-Host ""

# Add files to repository
Write-Host "Adding files to repository..." -ForegroundColor Yellow
try {
    # Add all tracked files (respecting .gitignore)
    git add .
    Write-Host "✓ Files added to staging area" -ForegroundColor Green
    
    # Show what will be committed
    Write-Host "`nFiles to be committed:" -ForegroundColor Cyan
    git status --porcelain | Where-Object { $_ -match '^A ' } | ForEach-Object {
        Write-Host "  $_" -ForegroundColor White
    }
}
catch {
    Write-Host "✗ Failed to add files: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Create initial commit
$createCommit = Read-Host "Create initial commit? (Y/n)"
if ($createCommit -notmatch '^[Nn]') {
    try {
        git commit -m "Initial commit: Azure Defender for Cloud Data Export Script

- PowerShell script for exporting Azure Defender for Cloud data
- Includes secure score, CSPM, and compliance data export
- Comprehensive logging and error handling
- CSV export functionality with configurable options
- Installation and configuration scripts
- Documentation and usage examples"
        
        Write-Host "✓ Initial commit created" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed to create initial commit: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""

# Show repository status
Write-Host "Repository status:" -ForegroundColor Cyan
git status

Write-Host ""

# Provide next steps
Write-Host "=== Next Steps ===" -ForegroundColor Green
Write-Host "Your Git repository is ready! Here are some common next steps:" -ForegroundColor White
Write-Host ""
Write-Host "1. Connect to a remote repository (GitHub, Azure DevOps, etc.):" -ForegroundColor Yellow
Write-Host "   git remote add origin <repository-url>" -ForegroundColor White
Write-Host "   git branch -M main" -ForegroundColor White
Write-Host "   git push -u origin main" -ForegroundColor White
Write-Host ""
Write-Host "2. Create a new branch for development:" -ForegroundColor Yellow
Write-Host "   git checkout -b feature/new-feature" -ForegroundColor White
Write-Host ""
Write-Host "3. Common Git commands:" -ForegroundColor Yellow
Write-Host "   git status          # Check repository status" -ForegroundColor White
Write-Host "   git add .           # Stage all changes" -ForegroundColor White
Write-Host "   git commit -m 'msg' # Commit changes" -ForegroundColor White
Write-Host "   git push            # Push to remote" -ForegroundColor White
Write-Host "   git pull            # Pull from remote" -ForegroundColor White
Write-Host ""
Write-Host "4. Files excluded by .gitignore:" -ForegroundColor Yellow
Write-Host "   - Reports/ directory (CSV files)" -ForegroundColor White
Write-Host "   - Logs/ directory (log files)" -ForegroundColor White
Write-Host "   - Temporary and sensitive files" -ForegroundColor White

Write-Host ""
Write-Host "Git repository setup completed! 🎉" -ForegroundColor Green