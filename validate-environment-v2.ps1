# validate-environment.ps1
# System Initiative Environment Validation
# Version: 2.0
# Organization: American Sound
# Contact: dougschaefer@asei.com

<#
.SYNOPSIS
    Validates Windows environment setup for System Initiative with Azure.

.DESCRIPTION
    Comprehensive validation of all required components:
    - WSL2 installation and configuration
    - Docker Desktop and WSL2 integration
    - Azure CLI
    - Node.js in WSL2
    - System Initiative CLI
    - Optional: Claude CLI installation

.NOTES
    Run this script from PowerShell (not WSL2).
    Windows remains the primary control plane for Azure management.
#>

# Color output functions
function Write-ValidationSuccess {
    param([string]$Message)
    Write-Host "  ✓ $Message" -ForegroundColor Green
}

function Write-ValidationFailed {
    param([string]$Message)
    Write-Host "  ✗ $Message" -ForegroundColor Red
}

function Write-ValidationWarning {
    param([string]$Message)
    Write-Host "  ⚠ $Message" -ForegroundColor Yellow
}

function Write-SectionHeader {
    param([string]$Message)
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "$Message" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
}

# Track overall success
$script:AllChecksPassed = $true
$script:CriticalFailures = @()
$script:Warnings = @()

function Register-CriticalFailure {
    param([string]$Message)
    $script:AllChecksPassed = $false
    $script:CriticalFailures += $Message
}

function Register-Warning {
    param([string]$Message)
    $script:Warnings += $Message
}

# Start validation
Clear-Host
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  System Initiative Environment Validation" -ForegroundColor Cyan
Write-Host "║  Version 2.0 - American Sound" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Validating system configuration for SI with Azure..." -ForegroundColor Gray
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# ============================================================================
# Windows System Checks
# ============================================================================

Write-SectionHeader "Windows System Configuration"

# Check Windows version
try {
    $osInfo = Get-CimInstance Win32_OperatingSystem
    $osVersion = $osInfo.Caption
    $osBuild = $osInfo.BuildNumber
    
    if ($osVersion -match "Windows 11") {
        Write-ValidationSuccess "Windows version: $osVersion (Build $osBuild)"
    } elseif ($osVersion -match "Windows 10") {
        Write-ValidationWarning "Windows 10 detected - Windows 11 recommended"
        Write-Host "    Current: $osVersion (Build $osBuild)" -ForegroundColor Gray
        Register-Warning "Windows 10 may have compatibility issues"
    } else {
        Write-ValidationFailed "Unsupported Windows version: $osVersion"
        Register-CriticalFailure "WSL2 requires Windows 10 version 2004+ or Windows 11"
    }
} catch {
    Write-ValidationFailed "Could not determine Windows version"
    Register-CriticalFailure "Windows version check failed"
}

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-ValidationSuccess "Running with administrator privileges"
} else {
    Write-ValidationWarning "Not running as administrator"
    Write-Host "    Some checks may be limited" -ForegroundColor Gray
}

# ============================================================================
# WSL2 Checks
# ============================================================================

Write-SectionHeader "WSL2 Configuration"

# Check if WSL is installed
try {
    $wslOutput = wsl --status 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-ValidationSuccess "WSL is installed and configured"
        
        # Parse WSL version info from status output
        $wslOutput | Select-String "Default Version" | ForEach-Object {
            $version = $_.Line -replace ".*:\s*", ""
            Write-Host "    Default version: $version" -ForegroundColor Gray
        }
    } else {
        Write-ValidationFailed "WSL is not properly installed"
        Register-CriticalFailure "WSL installation required"
    }
} catch {
    Write-ValidationFailed "WSL command not found"
    Register-CriticalFailure "Install WSL with: wsl --install"
}

# Check WSL distributions
Write-Host ""
Write-Host "  Checking WSL distributions..." -ForegroundColor Gray

try {
    # Use wsl -l -v and parse output carefully
    $wslList = wsl -l -v 2>$null
    
    if ($null -ne $wslList) {
        $hasUbuntu = $false
        $ubuntuVersion = "unknown"
        
        # Parse the output
        foreach ($line in $wslList) {
            # Skip header lines and empty lines
            if ($line -match "^\s*NAME\s+STATE\s+VERSION" -or $line.Trim() -eq "") {
                continue
            }
            
            # Look for Ubuntu
            if ($line -match "Ubuntu") {
                $hasUbuntu = $true
                # Extract version number from the line
                if ($line -match "(\d+)") {
                    $ubuntuVersion = $Matches[1]
                }
            }
        }
        
        if ($hasUbuntu) {
            if ($ubuntuVersion -eq "2") {
                Write-ValidationSuccess "Ubuntu distribution found (WSL $ubuntuVersion)"
            } elseif ($ubuntuVersion -eq "1") {
                Write-ValidationWarning "Ubuntu is using WSL 1 (should be WSL 2)"
                Write-Host "    Run: wsl --set-version Ubuntu 2" -ForegroundColor Yellow
                Register-Warning "Ubuntu should use WSL 2 for Docker compatibility"
            } else {
                Write-ValidationWarning "Ubuntu found but version unclear"
                Write-Host "    Manually verify with: wsl -l -v" -ForegroundColor Yellow
            }
        } else {
            Write-ValidationFailed "Ubuntu distribution not found"
            Write-Host "    Install with: wsl --install -d Ubuntu" -ForegroundColor Yellow
            Register-CriticalFailure "Ubuntu distribution required"
        }
        
        # Show all distributions
        Write-Host "    Installed distributions:" -ForegroundColor Gray
        foreach ($line in $wslList) {
            if ($line -match "^\s*NAME\s+STATE\s+VERSION" -or $line.Trim() -eq "") {
                continue
            }
            Write-Host "      $($line.Trim())" -ForegroundColor Gray
        }
    } else {
        Write-ValidationFailed "No WSL distributions found"
        Register-CriticalFailure "Install Ubuntu with: wsl --install -d Ubuntu"
    }
} catch {
    Write-ValidationFailed "Error checking WSL distributions: $_"
    Write-Host "    Try manually: wsl -l -v" -ForegroundColor Yellow
    Register-Warning "WSL distribution check failed - verify manually"
}

# Test WSL execution
Write-Host ""
Write-Host "  Testing WSL execution..." -ForegroundColor Gray

try {
    $testResult = wsl echo "test" 2>$null
    if ($testResult -eq "test") {
        Write-ValidationSuccess "WSL can execute commands"
    } else {
        Write-ValidationFailed "WSL execution test failed"
        Register-Warning "WSL may not be properly configured"
    }
} catch {
    Write-ValidationFailed "Cannot execute WSL commands"
    Register-CriticalFailure "WSL execution failed"
}

# ============================================================================
# Docker Desktop Checks
# ============================================================================

Write-SectionHeader "Docker Desktop Configuration"

# Check if Docker Desktop is installed
$dockerDesktopPath = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
if (Test-Path $dockerDesktopPath) {
    Write-ValidationSuccess "Docker Desktop is installed"
    
    # Get version
    try {
        $dockerVersion = docker --version 2>$null
        if ($null -ne $dockerVersion) {
            Write-Host "    $dockerVersion" -ForegroundColor Gray
        }
    } catch {
        # Silent fail - version not critical
    }
} else {
    Write-ValidationFailed "Docker Desktop not found"
    Write-Host "    Install from: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    Register-CriticalFailure "Docker Desktop required"
}

# Check if Docker is running
Write-Host ""
Write-Host "  Checking Docker daemon..." -ForegroundColor Gray

try {
    $dockerInfo = docker info 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-ValidationSuccess "Docker daemon is running"
    } else {
        Write-ValidationFailed "Docker daemon is not running"
        Write-Host "    Start Docker Desktop application" -ForegroundColor Yellow
        Register-CriticalFailure "Docker must be running"
    }
} catch {
    Write-ValidationFailed "Docker command not accessible"
    Write-Host "    Ensure Docker Desktop is installed and running" -ForegroundColor Yellow
    Register-CriticalFailure "Docker not accessible"
}

# Check Docker WSL2 integration
Write-Host ""
Write-Host "  Checking Docker in WSL2..." -ForegroundColor Gray

try {
    $wslDockerVersion = wsl docker --version 2>$null
    if ($null -ne $wslDockerVersion -and $LASTEXITCODE -eq 0) {
        Write-ValidationSuccess "Docker accessible from WSL2"
        Write-Host "    $wslDockerVersion" -ForegroundColor Gray
    } else {
        Write-ValidationFailed "Docker not accessible from WSL2"
        Write-Host "    Enable in Docker Desktop → Settings → Resources → WSL Integration" -ForegroundColor Yellow
        Register-CriticalFailure "Docker WSL2 integration must be enabled"
    }
} catch {
    Write-ValidationFailed "Cannot test Docker in WSL2"
    Register-Warning "Verify Docker WSL2 integration manually"
}

# ============================================================================
# Azure CLI Checks
# ============================================================================

Write-SectionHeader "Azure CLI Configuration"

try {
    $azVersion = az version --output json 2>$null | ConvertFrom-Json
    if ($null -ne $azVersion) {
        Write-ValidationSuccess "Azure CLI is installed"
        Write-Host "    Version: $($azVersion.'azure-cli')" -ForegroundColor Gray
    } else {
        Write-ValidationFailed "Azure CLI not found or not responding"
        Write-Host "    Install from: https://aka.ms/installazurecliwindows" -ForegroundColor Yellow
        Register-CriticalFailure "Azure CLI required"
    }
} catch {
    Write-ValidationFailed "Azure CLI not accessible"
    Write-Host "    Install with: winget install -e --id Microsoft.AzureCLI" -ForegroundColor Yellow
    Register-CriticalFailure "Azure CLI required"
}

# Check Azure login status
Write-Host ""
Write-Host "  Checking Azure authentication..." -ForegroundColor Gray

try {
    $azAccount = az account show 2>$null | ConvertFrom-Json
    if ($null -ne $azAccount) {
        Write-ValidationSuccess "Logged in to Azure"
        Write-Host "    Account: $($azAccount.user.name)" -ForegroundColor Gray
        Write-Host "    Tenant: $($azAccount.tenantId)" -ForegroundColor Gray
        Write-Host "    Subscription: $($azAccount.name)" -ForegroundColor Gray
    } else {
        Write-ValidationWarning "Not logged in to Azure"
        Write-Host "    Run: az login" -ForegroundColor Yellow
        Register-Warning "Azure login required for setup"
    }
} catch {
    Write-ValidationWarning "Could not verify Azure login status"
    Write-Host "    Run: az login" -ForegroundColor Yellow
    Register-Warning "Verify Azure authentication"
}

# ============================================================================
# WSL2 Development Tools
# ============================================================================

Write-SectionHeader "WSL2 Development Environment"

# Check Node.js in WSL2
Write-Host "  Checking Node.js in WSL2..." -ForegroundColor Gray

try {
    $nodeVersion = wsl node --version 2>$null
    if ($null -ne $nodeVersion -and $LASTEXITCODE -eq 0) {
        Write-ValidationSuccess "Node.js installed in WSL2"
        Write-Host "    Version: $nodeVersion" -ForegroundColor Gray
    } else {
        Write-ValidationFailed "Node.js not found in WSL2"
        Write-Host "    Install in WSL2: curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -" -ForegroundColor Yellow
        Write-Host "    Then: sudo apt-get install -y nodejs" -ForegroundColor Yellow
        Register-CriticalFailure "Node.js required in WSL2 for SI CLI and Claude Code"
    }
} catch {
    Write-ValidationFailed "Cannot check Node.js in WSL2"
    Register-Warning "Verify Node.js installation manually in WSL2"
}

# Check npm in WSL2
Write-Host ""
Write-Host "  Checking npm in WSL2..." -ForegroundColor Gray

try {
    $npmVersion = wsl npm --version 2>$null
    if ($null -ne $npmVersion -and $LASTEXITCODE -eq 0) {
        Write-ValidationSuccess "npm installed in WSL2"
        Write-Host "    Version: $npmVersion" -ForegroundColor Gray
    } else {
        Write-ValidationWarning "npm not found in WSL2"
        Write-Host "    Should be installed with Node.js" -ForegroundColor Yellow
        Register-Warning "npm required for package installation"
    }
} catch {
    Write-ValidationWarning "Cannot check npm in WSL2"
}

# Check Git in WSL2
Write-Host ""
Write-Host "  Checking Git in WSL2..." -ForegroundColor Gray

try {
    $gitVersion = wsl git --version 2>$null
    if ($null -ne $gitVersion -and $LASTEXITCODE -eq 0) {
        Write-ValidationSuccess "Git installed in WSL2"
        Write-Host "    $gitVersion" -ForegroundColor Gray
    } else {
        Write-ValidationWarning "Git not found in WSL2"
        Write-Host "    Install in WSL2: sudo apt-get install git" -ForegroundColor Yellow
        Register-Warning "Git recommended for development"
    }
} catch {
    Write-ValidationWarning "Cannot check Git in WSL2"
}

# ============================================================================
# System Initiative CLI
# ============================================================================

Write-SectionHeader "System Initiative CLI"

try {
    $siVersion = wsl si --version 2>$null
    if ($null -ne $siVersion -and $LASTEXITCODE -eq 0) {
        Write-ValidationSuccess "SI CLI installed in WSL2"
        Write-Host "    Version: $siVersion" -ForegroundColor Gray
    } else {
        Write-ValidationWarning "SI CLI not found in WSL2"
        Write-Host "    Install: curl -fsSL https://raw.githubusercontent.com/systeminit/si/main/bin/install.sh | bash" -ForegroundColor Yellow
        Write-Host "    Add to PATH: export PATH=`"`$HOME/.local/bin:`$PATH`"" -ForegroundColor Yellow
        Register-Warning "SI CLI required for System Initiative"
    }
} catch {
    Write-ValidationWarning "Cannot check SI CLI in WSL2"
    Write-Host "    Verify installation manually in WSL2 terminal" -ForegroundColor Yellow
    Register-Warning "SI CLI verification failed"
}

# ============================================================================
# Claude Integration (Optional)
# ============================================================================

Write-SectionHeader "Claude Integration (Optional)"

# Check Claude CLI
Write-Host "  Checking Claude Code CLI..." -ForegroundColor Gray

try {
    $claudeVersion = wsl claude --version 2>$null
    if ($null -ne $claudeVersion -and $LASTEXITCODE -eq 0) {
        Write-ValidationSuccess "Claude Code CLI installed"
        Write-Host "    Version: $claudeVersion" -ForegroundColor Gray
    } else {
        Write-Host "    ○ Claude Code CLI not found (optional)" -ForegroundColor Gray
        Write-Host "      Install: npm install -g @anthropic-ai/claude-cli" -ForegroundColor Gray
    }
} catch {
    Write-Host "    ○ Claude Code CLI not installed (optional)" -ForegroundColor Gray
}

# Check Claude Desktop
Write-Host ""
Write-Host "  Checking Claude Desktop..." -ForegroundColor Gray

$claudeDesktopPaths = @(
    "$env:LOCALAPPDATA\Programs\Claude\Claude.exe",
    "$env:LOCALAPPDATA\AnthropicClaude\Claude.exe",
    "$env:ProgramFiles\Claude\Claude.exe"
)

$claudeDesktopFound = $false
foreach ($path in $claudeDesktopPaths) {
    if (Test-Path $path) {
        $claudeDesktopFound = $true
        Write-ValidationSuccess "Claude Desktop installed"
        Write-Host "    Location: $path" -ForegroundColor Gray
        break
    }
}

if (-not $claudeDesktopFound) {
    Write-Host "    ○ Claude Desktop not found (optional)" -ForegroundColor Gray
    Write-Host "      Download from: https://claude.ai/download" -ForegroundColor Gray
}

# Check Claude Desktop MCP config
if ($claudeDesktopFound) {
    Write-Host ""
    Write-Host "  Checking Claude Desktop MCP configuration..." -ForegroundColor Gray
    
    $mcpConfigPath = "$env:APPDATA\Claude\claude_desktop_config.json"
    if (Test-Path $mcpConfigPath) {
        Write-ValidationSuccess "MCP configuration file exists"
        
        try {
            $mcpConfig = Get-Content $mcpConfigPath -Raw | ConvertFrom-Json
            if ($mcpConfig.mcpServers.PSObject.Properties['system-initiative']) {
                Write-ValidationSuccess "System Initiative MCP server configured"
            } else {
                Write-Host "    ○ SI MCP server not configured yet" -ForegroundColor Gray
            }
        } catch {
            Write-ValidationWarning "Could not parse MCP configuration"
        }
    } else {
        Write-Host "    ○ MCP configuration not created yet" -ForegroundColor Gray
        Write-Host "      Configuration needed for Claude Desktop integration" -ForegroundColor Gray
    }
}

# ============================================================================
# Summary
# ============================================================================

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Validation Summary" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if ($script:AllChecksPassed -and $script:CriticalFailures.Count -eq 0) {
    Write-Host "✓ All critical checks passed!" -ForegroundColor Green
    Write-Host ""
    
    if ($script:Warnings.Count -gt 0) {
        Write-Host "Warnings ($($script:Warnings.Count)):" -ForegroundColor Yellow
        foreach ($warning in $script:Warnings) {
            Write-Host "  ⚠ $warning" -ForegroundColor Yellow
        }
        Write-Host ""
    }
    
    Write-Host "Your system is ready for System Initiative setup." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Create Azure service principal (run setup-azure-service-principal-v2.ps1)"
    Write-Host "  2. Create System Initiative account at app.systeminit.com"
    Write-Host "  3. Configure Claude integration (Claude Code or Claude Desktop)"
    Write-Host "  4. Connect Azure credentials in System Initiative"
    Write-Host ""
    
} else {
    Write-Host "✗ Environment validation failed" -ForegroundColor Red
    Write-Host ""
    
    if ($script:CriticalFailures.Count -gt 0) {
        Write-Host "Critical issues ($($script:CriticalFailures.Count)):" -ForegroundColor Red
        foreach ($failure in $script:CriticalFailures) {
            Write-Host "  ✗ $failure" -ForegroundColor Red
        }
        Write-Host ""
    }
    
    if ($script:Warnings.Count -gt 0) {
        Write-Host "Warnings ($($script:Warnings.Count)):" -ForegroundColor Yellow
        foreach ($warning in $script:Warnings) {
            Write-Host "  ⚠ $warning" -ForegroundColor Yellow
        }
        Write-Host ""
    }
    
    Write-Host "Please resolve the critical issues before proceeding." -ForegroundColor Yellow
    Write-Host "Refer to SI-Setup-Guide-Windows-Azure-v2.md for detailed instructions." -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "Validation complete: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""
Write-Host "For detailed setup instructions, see:" -ForegroundColor Cyan
Write-Host "  SI-Setup-Guide-Windows-Azure-v2.md" -ForegroundColor White
Write-Host "  SI-Quick-Start-Checklist-v2.md" -ForegroundColor White
Write-Host ""
Write-Host "Contact: dougschaefer@asei.com" -ForegroundColor Gray
Write-Host "Organization: American Sound" -ForegroundColor Gray
Write-Host ""
