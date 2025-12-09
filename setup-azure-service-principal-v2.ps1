# setup-azure-service-principal.ps1
# System Initiative Azure Service Principal Setup
# Version: 2.0
# Organization: American Sound
# Contact: dougschaefer@asei.com

<#
.SYNOPSIS
    Creates and configures an Azure service principal for System Initiative integration.

.DESCRIPTION
    This script automates the creation of an Azure App Registration and Service Principal
    with the necessary permissions to manage Azure resources through System Initiative.
    
    The service principal will have:
    - App Registration in Azure Entra ID
    - Client secret for authentication
    - Contributor role on specified subscription(s) or management group
    - NO Entra ID administrative roles (not needed for resource management)

.PARAMETER AppName
    Name of the app registration (default: SystemInitiative-Integration)

.PARAMETER SubscriptionIds
    Array of subscription IDs to grant access to. If empty, uses current subscription.

.PARAMETER ManagementGroupId
    Optional management group ID to grant access at management group level

.PARAMETER SecretExpirationMonths
    Number of months until client secret expires (default: 24)

.PARAMETER Role
    Azure RBAC role to assign (default: Contributor)

.EXAMPLE
    .\setup-azure-service-principal.ps1
    Creates service principal with Contributor access to current subscription

.EXAMPLE
    .\setup-azure-service-principal.ps1 -SubscriptionIds @("sub-id-1", "sub-id-2")
    Creates service principal with access to multiple subscriptions

.EXAMPLE
    .\setup-azure-service-principal.ps1 -ManagementGroupId "mg-prod" -Role "Contributor"
    Creates service principal with Contributor access at management group level
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$AppName = "SystemInitiative-Integration",
    
    [Parameter(Mandatory=$false)]
    [string[]]$SubscriptionIds = @(),
    
    [Parameter(Mandatory=$false)]
    [string]$ManagementGroupId = "",
    
    [Parameter(Mandatory=$false)]
    [int]$SecretExpirationMonths = 24,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Owner", "Contributor", "Reader")]
    [string]$Role = "Contributor"
)

# Color output functions
function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "→ $Message" -ForegroundColor Cyan
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

# Main script
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Azure Service Principal Setup for SI" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Azure CLI is installed
Write-Info "Checking Azure CLI installation..."
try {
    $azVersion = az version --output json 2>$null | ConvertFrom-Json
    Write-Success "Azure CLI version $($azVersion.'azure-cli') installed"
} catch {
    Write-Error "Azure CLI is not installed or not in PATH"
    Write-Host "Install from: https://aka.ms/installazurecliwindows"
    exit 1
}

# Check if logged in to Azure
Write-Info "Checking Azure login status..."
try {
    $account = az account show 2>$null | ConvertFrom-Json
    Write-Success "Logged in as: $($account.user.name)"
    Write-Success "Tenant: $($account.tenantId)"
} catch {
    Write-Error "Not logged in to Azure"
    Write-Info "Running 'az login'..."
    az login
    $account = az account show | ConvertFrom-Json
}

# Get subscription(s) to use
if ($SubscriptionIds.Count -eq 0 -and $ManagementGroupId -eq "") {
    $currentSubId = $account.id
    $currentSubName = $account.name
    Write-Info "No subscription IDs specified, using current subscription:"
    Write-Host "  Subscription: $currentSubName" -ForegroundColor Yellow
    Write-Host "  ID: $currentSubId" -ForegroundColor Yellow
    $SubscriptionIds = @($currentSubId)
    
    $confirm = Read-Host "Continue with this subscription? (Y/n)"
    if ($confirm -eq 'n' -or $confirm -eq 'N') {
        Write-Host "Aborted by user"
        exit 0
    }
}

# Display configuration
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  App Name: $AppName"
Write-Host "  Role: $Role"
Write-Host "  Secret Expiration: $SecretExpirationMonths months"
if ($ManagementGroupId -ne "") {
    Write-Host "  Scope: Management Group $ManagementGroupId"
} else {
    Write-Host "  Scope: $($SubscriptionIds.Count) subscription(s)"
    foreach ($subId in $SubscriptionIds) {
        $subInfo = az account show --subscription $subId | ConvertFrom-Json
        Write-Host "    - $($subInfo.name) ($subId)"
    }
}
Write-Host ""

$confirm = Read-Host "Proceed with setup? (Y/n)"
if ($confirm -eq 'n' -or $confirm -eq 'N') {
    Write-Host "Aborted by user"
    exit 0
}

Write-Host ""

# Check if app registration already exists
Write-Info "Checking if app registration already exists..."
$existingApp = az ad app list --display-name $AppName | ConvertFrom-Json
if ($existingApp.Count -gt 0) {
    Write-Warning "App registration '$AppName' already exists"
    Write-Host "  App ID: $($existingApp[0].appId)"
    $useExisting = Read-Host "Use existing app registration? (Y/n)"
    if ($useExisting -eq 'n' -or $useExisting -eq 'N') {
        Write-Host "Aborted by user"
        exit 0
    }
    $appId = $existingApp[0].appId
    $objectId = $existingApp[0].id
} else {
    # Create app registration
    Write-Info "Creating app registration: $AppName"
    $newApp = az ad app create --display-name $AppName | ConvertFrom-Json
    $appId = $newApp.appId
    $objectId = $newApp.id
    Write-Success "App registration created"
    Write-Host "  App ID: $appId"
    Start-Sleep -Seconds 5  # Wait for propagation
}

# Get or create service principal
Write-Info "Setting up service principal..."
$sp = az ad sp list --filter "appId eq '$appId'" | ConvertFrom-Json
if ($sp.Count -eq 0) {
    Write-Info "Creating service principal..."
    $sp = az ad sp create --id $appId | ConvertFrom-Json
    Write-Success "Service principal created"
    Start-Sleep -Seconds 10  # Wait for propagation
} else {
    Write-Success "Service principal already exists"
    $sp = $sp[0]
}

$spObjectId = $sp.id
Write-Host "  Service Principal Object ID: $spObjectId"

# Create client secret
Write-Info "Creating client secret..."
$secretName = "SI-Integration-Secret"
$endDate = (Get-Date).AddMonths($SecretExpirationMonths).ToString("yyyy-MM-ddTHH:mm:ssZ")

try {
    $secretResult = az ad app credential reset `
        --id $appId `
        --append `
        --display-name $secretName `
        --end-date $endDate | ConvertFrom-Json
    
    $clientSecret = $secretResult.password
    Write-Success "Client secret created"
    Write-Host "  Expires: $endDate" -ForegroundColor Yellow
} catch {
    Write-Error "Failed to create client secret: $_"
    exit 1
}

# Assign RBAC roles
Write-Host ""
Write-Info "Assigning RBAC roles..."
Write-Warning "Note: Service principal does NOT need any roles in Azure Entra ID"
Write-Warning "      Only Azure RBAC roles on subscriptions/resources are required"
Write-Host ""

$roleAssignments = @()

if ($ManagementGroupId -ne "") {
    # Assign at management group level
    Write-Info "Assigning $Role role at management group level..."
    try {
        az role assignment create `
            --assignee $appId `
            --role $Role `
            --scope "/providers/Microsoft.Management/managementGroups/$ManagementGroupId" `
            --output none
        Write-Success "Role assigned at management group: $ManagementGroupId"
        $roleAssignments += "Management Group: $ManagementGroupId - $Role"
    } catch {
        Write-Error "Failed to assign role at management group level: $_"
    }
} else {
    # Assign at subscription level
    foreach ($subId in $SubscriptionIds) {
        Write-Info "Assigning $Role role to subscription: $subId"
        
        # Check if role already assigned
        $existing = az role assignment list `
            --assignee $appId `
            --scope "/subscriptions/$subId" `
            --role $Role | ConvertFrom-Json
        
        if ($existing.Count -gt 0) {
            Write-Warning "Role already assigned to this subscription"
        } else {
            try {
                az role assignment create `
                    --assignee $appId `
                    --role $Role `
                    --scope "/subscriptions/$subId" `
                    --output none
                Write-Success "Role assigned successfully"
            } catch {
                Write-Error "Failed to assign role: $_"
                continue
            }
        }
        
        $subInfo = az account show --subscription $subId | ConvertFrom-Json
        $roleAssignments += "$($subInfo.name) - $Role"
    }
}

# Get tenant ID
$tenantId = $account.tenantId

# Display summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "Service Principal Details:" -ForegroundColor Cyan
Write-Host "  Tenant ID:     $tenantId"
Write-Host "  Client ID:     $appId"
Write-Host "  Client Secret: $clientSecret" -ForegroundColor Yellow
Write-Host ""

Write-Host "Role Assignments:" -ForegroundColor Cyan
foreach ($assignment in $roleAssignments) {
    Write-Host "  ✓ $assignment"
}
Write-Host ""

Write-Warning "IMPORTANT: Save the client secret securely!"
Write-Warning "It will not be shown again."
Write-Host ""

# Save to file
$outputFile = "azure-sp-credentials-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
$outputPath = Join-Path $PSScriptRoot $outputFile

$output = @"
System Initiative Azure Service Principal Configuration
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Organization: American Sound
Contact: dougschaefer@asei.com

AZURE SERVICE PRINCIPAL DETAILS:
================================
Tenant ID:       $tenantId
Client ID:       $appId
Client Secret:   $clientSecret

App Name:        $AppName
Role:            $Role
Secret Expires:  $endDate

ROLE ASSIGNMENTS:
================
$($roleAssignments -join "`n")

IMPORTANT NOTES:
===============
1. The service principal has NO roles in Azure Entra ID (this is correct)
2. It ONLY has Azure RBAC roles for managing resources
3. Store the client secret securely (password manager or Azure Key Vault)
4. Rotate the client secret every 6-12 months
5. Review role assignments regularly

SYSTEM INITIATIVE CONFIGURATION:
===============================
In SI, create a Microsoft Credential component with:
- Name: SI-Integration-Secret (or any descriptive name)
- Tenant ID: $tenantId
- Client ID: $appId (this is the Application ID, not Object ID)
- Client Secret: $clientSecret (this is the secret VALUE, not Secret ID)
- Subscription ID: (one of your subscription IDs)

IMPORTANT - Common Mistakes:
- Client ID = Application (client) ID from app registration (NOT Object ID)
- Client Secret = The secret VALUE shown when created (NOT Secret ID)
- If you see "authentication failed", verify you used the VALUE not the ID

VALIDATION COMMANDS:
===================
# Verify service principal exists
az ad sp show --id $appId

# Verify role assignments
az role assignment list --assignee $appId --output table

# Test authentication
az login --service-principal \
  --username $appId \
  --password $clientSecret \
  --tenant $tenantId

WARNING: Do not commit this file to source control!
"@

$output | Out-File -FilePath $outputPath -Encoding UTF8
Write-Success "Configuration saved to: $outputPath"
Write-Warning "This file contains secrets - store it securely and delete after saving credentials"
Write-Host ""

# Validation
Write-Info "Running validation checks..."
Write-Host ""

# Verify service principal
try {
    $spCheck = az ad sp show --id $appId | ConvertFrom-Json
    Write-Success "Service principal verified"
} catch {
    Write-Error "Service principal verification failed"
}

# Verify role assignments
try {
    $roles = az role assignment list --assignee $appId --output json | ConvertFrom-Json
    if ($roles.Count -gt 0) {
        Write-Success "Role assignments verified: $($roles.Count) role(s)"
    } else {
        Write-Warning "No role assignments found"
    }
} catch {
    Write-Error "Role assignment verification failed"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Save the client secret to your password manager or Azure Key Vault"
Write-Host "2. Configure the Microsoft Credential in System Initiative"
Write-Host "3. Test the connection by creating a test Azure resource"
Write-Host "4. Delete the credentials file after saving: $outputPath"
Write-Host "5. Set up regular secret rotation reminders"
Write-Host ""
Write-Host "Documentation: See SI-Setup-Guide-Windows-Azure-v2.md" -ForegroundColor Green
Write-Host ""
