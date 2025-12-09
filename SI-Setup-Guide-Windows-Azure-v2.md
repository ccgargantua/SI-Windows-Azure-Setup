# System Initiative Setup Guide for Windows 11 with Azure
## Complete Reference Documentation

**Version:** 2.0  
**Created:** December 2025  
**Organization:** American Sound  
**Author:** Doug Schaefer (dougschaefer@asei.com)  
**Purpose:** Enable System Initiative AI-powered infrastructure automation on Windows with Azure cloud provider

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [WSL2 and Docker Setup](#wsl2-and-docker-setup)
4. [Azure Service Principal Configuration](#azure-service-principal-configuration)
5. [System Initiative Installation](#system-initiative-installation)
6. [Claude AI Agent Setup - Two Methods](#claude-ai-agent-setup)
7. [Connecting Azure to System Initiative](#connecting-azure-to-system-initiative)
8. [Validation and Testing](#validation-and-testing)
9. [Troubleshooting](#troubleshooting)
10. [Reference Information](#reference-information)

---

## Overview

### What is System Initiative?

System Initiative (SI) is a collaborative DevOps platform that uses AI to help design, deploy, and manage cloud infrastructure. It provides visual modeling, automated code generation, and AI-assisted infrastructure management through integration with Claude.

### About This Guide

This guide documents the complete setup process for System Initiative on Windows 11 with Azure as the cloud provider. This package was created specifically for American Sound's infrastructure team based on real-world implementation and troubleshooting.

**Key Topics Covered:**
- WSL2 and Docker Desktop configuration for Windows
- Azure service principal creation and permission management
- System Initiative CLI installation
- Claude AI agent integration (both CLI and Desktop methods)
- Azure credential configuration in SI
- Common troubleshooting scenarios

### System Requirements

**Operating System:**
- Windows 11 Pro or Enterprise (required for WSL2 and Docker Desktop)
- Administrator access required for installation

**Hardware:**
- Minimum 16GB RAM (32GB recommended)
- 50GB free disk space
- CPU with virtualization support (Intel VT-x or AMD-V)

**Accounts Required:**
- Azure subscription with Owner or Contributor access
- System Initiative account (free tier available at app.systeminit.com)
- Anthropic Claude account (for AI agent integration)

---

## Prerequisites

### Required Software Installation

All installations should be performed on Windows (not WSL2) unless specifically noted otherwise.

#### 1. Enable WSL2

**In PowerShell (Administrator):**

```powershell
# Enable WSL
wsl --install

# Set WSL2 as default version
wsl --set-default-version 2

# Restart your computer when prompted
```

**After Restart:**

```powershell
# Verify WSL2 is installed
wsl --list --verbose

# Should show Ubuntu with VERSION 2
```

**Important:** Windows remains your primary control plane. WSL2 provides a Linux environment for Docker and SI tools, but you'll primarily use PowerShell for Azure management and validation.

#### 2. Install Ubuntu in WSL2

```powershell
# Install Ubuntu
wsl --install -d Ubuntu

# Launch Ubuntu for initial setup
wsl

# Create a Linux user when prompted (remember this username and password)
```

**Configure Ubuntu:**

```bash
# In WSL2/Ubuntu terminal

# Update package lists
sudo apt update && sudo apt upgrade -y

# Install essential tools
sudo apt install -y git curl wget

# Install Node.js (required for SI CLI and Claude Code)
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify installations
node --version
npm --version
git --version
```

#### 3. Install Docker Desktop

**Download and Install:**
1. Download Docker Desktop for Windows from https://www.docker.com/products/docker-desktop
2. Run the installer
3. **Critical:** During installation, ensure "Use WSL 2 instead of Hyper-V" is selected
4. Restart when prompted

**Configure Docker Desktop for WSL2:**

1. Open Docker Desktop
2. Go to **Settings** → **Resources** → **WSL Integration**
3. **Enable integration with Ubuntu** (toggle it on)
4. Click **Apply & Restart**

**Verify Docker in WSL2:**

```bash
# In WSL2/Ubuntu terminal
docker --version
docker ps

# Should show Docker version and empty container list (not an error)
```

#### 4. Install Azure CLI

**In PowerShell (Administrator):**

```powershell
# Download and install Azure CLI for Windows
winget install -e --id Microsoft.AzureCLI

# Or download from: https://aka.ms/installazurecliwindows

# Verify installation
az --version

# Login to Azure
az login

# Verify subscription access
az account list --output table
```

#### 5. Install System Initiative CLI

**In WSL2/Ubuntu terminal:**

```bash
# Download and install SI CLI
curl -fsSL https://raw.githubusercontent.com/systeminit/si/main/bin/install.sh | bash

# Add to PATH (add this to ~/.bashrc to make permanent)
export PATH="$HOME/.local/bin:$PATH"

# Verify installation
si --version
```

---

## WSL2 and Docker Setup

### Verify WSL2 Configuration

**In PowerShell:**

```powershell
# Check WSL version and status
wsl --list --verbose

# Expected output:
#   NAME      STATE           VERSION
# * Ubuntu    Running         2
```

### Configure WSL2 Default User

If WSL2 is defaulting to root user, configure it to use your regular user:

**In WSL2 as root:**

```bash
# Add your user if not already created
adduser yourusername

# Add to sudo and docker groups
usermod -aG sudo,docker yourusername

# Exit
exit
```

**In PowerShell:**

```bash
# Set default user
wsl -u root bash -c "cat > /etc/wsl.conf << 'EOF'
[boot]
systemd=true
[user]
default=yourusername
EOF"

# Restart WSL
wsl --shutdown

# Launch WSL again - should now be your user
wsl
```

### Verify Docker Access from WSL2

```bash
# In WSL2
docker ps
docker run hello-world

# Both should work without errors
```

---

## Azure Service Principal Configuration

### Understanding Service Principals

A service principal is an identity that applications use to access Azure resources. For System Initiative, you'll create a service principal with permissions to manage resources in your Azure subscription(s).

**Important Concepts:**
- **App Registration** creates the identity in Azure Entra ID (formerly Active Directory)
- **Client Secret** is the password SI will use to authenticate
- **RBAC Role Assignment** grants the service principal permissions to manage Azure resources
- **No Entra ID roles needed** - the service principal only needs Azure RBAC permissions

### Step 1: Create App Registration

**In Azure Portal:**

1. Navigate to **Azure Entra ID** (or **Azure Active Directory**)
2. Select **App registrations** from left menu
3. Click **New registration**
4. Configure:
   - **Name:** `SystemInitiative-Integration`
   - **Supported account types:** "Accounts in this organizational directory only"
   - **Redirect URI:** Leave blank
5. Click **Register**

**Note the following values (you'll need them):**
- **Application (client) ID** - found on Overview page
- **Directory (tenant) ID** - found on Overview page

**⚠️ Common Mistake Alert:**
On the Overview page, you'll see three GUIDs:
- **Application (client) ID** ✅ This is what SI calls "Client ID"
- **Object ID** ❌ Don't use this
- **Directory (tenant) ID** ✅ This is the Tenant ID

Copy the **Application (client) ID**, not the Object ID!

### Step 2: Create Client Secret

1. In your app registration, go to **Certificates & secrets**
2. Click **New client secret**
3. Configure:
   - **Description:** `SI-Integration-Secret`
   - **Expires:** 24 months (or per your security policy)
4. Click **Add**
5. **IMMEDIATELY COPY THE SECRET VALUE** - it's only shown once

**⚠️ CRITICAL - Which Value to Copy:**

When the secret is created, Azure shows you a table with columns:
- **Description:** `SI-Integration-Secret`
- **Secret ID:** `12345678-abcd-...` ❌ **DON'T copy this**
- **Value:** `A8Q~longAlphanumericString123...` ✅ **COPY THIS**
- **Expires:** `12/8/2026`

**You MUST copy the VALUE column, NOT the Secret ID.**

The secret VALUE:
- Is a long alphanumeric string (often starts with letters like `A8Q~`)
- Is 30+ characters long
- Contains letters, numbers, and special characters
- Is shown **only once** - you can't view it again

6. Store the VALUE securely in password manager or Azure Key Vault

If you accidentally copied the Secret ID instead of the VALUE, you'll get authentication errors in System Initiative. You'll need to create a new secret and copy the VALUE this time.

### Step 3: Assign Permissions to Subscriptions

**Important:** The service principal does NOT need any roles in Azure Entra ID. It only needs Azure RBAC permissions.

#### Option A: Grant Access to Specific Subscriptions

For each subscription where SI should manage resources:

1. Navigate to the **Subscription** in Azure Portal
2. Select **Access control (IAM)** from left menu
3. Click **Add** → **Add role assignment**
4. Select **Contributor** role (or custom role as needed)
5. Click **Next**
6. Click **Select members**
7. Search for `SystemInitiative-Integration`
8. Select it and click **Select**
9. Click **Review + assign**

#### Option B: Grant Access to Management Group

To manage multiple subscriptions at once:

1. Navigate to **Management groups** in Azure Portal
2. Select your management group
3. Select **Access control (IAM)**
4. Follow same role assignment process as above

**Permission Levels:**
- **Contributor:** Required for full resource management (create, update, delete)
- **Reader:** For discovery and monitoring only
- **Custom Roles:** Can be defined for more granular control per resource type

### Step 4: Verify Service Principal

**In PowerShell:**

```powershell
# Login if not already
az login

# Set your subscription
az account set --subscription "YOUR_SUBSCRIPTION_NAME"

# Verify the service principal exists
az ad sp list --display-name "SystemInitiative-Integration" --output table

# Verify role assignments
az role assignment list --assignee YOUR_CLIENT_ID --output table
```

### Azure Configuration Summary

**You should now have:**
- ✓ App Registration created
- ✓ Client ID (Application ID)
- ✓ Tenant ID (Directory ID)
- ✓ Client Secret (stored securely)
- ✓ Contributor role assigned to subscription(s) or management group
- ✓ NO roles assigned in Azure Entra ID (not needed)

---

## System Initiative Installation

### Create System Initiative Account

1. Go to https://app.systeminit.com
2. Sign up for a free account
3. Create a workspace (note your workspace URL)
4. Complete onboarding

### Generate API Token

**In System Initiative Web Interface:**

1. Go to **Settings** or click your profile
2. Navigate to **API Tokens** or **Tokens**
3. Click **Generate New Token** or **Create API Token**
4. Configure:
   - **Name:** `Claude-Integration` or `Local-CLI`
   - **Permissions:** Ensure automation/workspace access is enabled
5. **Copy the token immediately** - it's shown only once
6. Store securely

**Token Format:**
- API tokens are JWT format (long token starting with `eyJhbG...`)
- These are different from workspace tokens (short ULID format)
- For AI agent setup, you need the **API token** (JWT format)

### Install SI CLI in WSL2

Already completed in Prerequisites, but verify:

```bash
# In WSL2
si --version

# If not installed:
curl -fsSL https://raw.githubusercontent.com/systeminit/si/main/bin/install.sh | bash
export PATH="$HOME/.local/bin:$PATH"
```

---

## Claude AI Agent Setup

System Initiative supports AI-assisted infrastructure management through Claude. There are **two methods** to integrate Claude with SI:

1. **Claude Code CLI** (Official, Recommended) - Terminal-based interaction
2. **Claude Desktop GUI** (Community method) - Chat interface interaction

Choose the method that best fits your workflow.

---

## Method 1: Claude Code CLI (Official, Recommended)

### Overview

Claude Code is a command-line tool that allows Claude to interact with your development environment, including System Initiative. This is the officially supported method.

**Advantages:**
- Officially supported by System Initiative
- Simpler setup process
- Direct terminal integration
- Documented in SI official guides

**Disadvantages:**
- Terminal-only interface
- Less visual/exploratory workflow

### Installation

**In WSL2:**

```bash
# Claude Code is typically installed via npm
npm install -g @anthropic-ai/claude-cli

# Verify installation
claude --version
```

### Configuration

**Set up authentication with Claude:**

```bash
# Login to Claude (opens browser for auth)
claude auth login

# Or set API key directly if provided
export ANTHROPIC_API_KEY="your-api-key"
```

### Initialize SI AI Agent

**In WSL2:**

```bash
# Navigate to your workspace
cd ~

# Set your SI API token
export SI_API_TOKEN="your-jwt-token-here"

# Initialize SI AI agent
si ai-agent init

# Follow prompts to complete setup
```

**The init process will:**
- Detect Claude Code installation
- Configure MCP (Model Context Protocol) connection
- Set up SI workspace access
- Create necessary configuration files

### Testing Claude Code with SI

```bash
# Start a Claude Code session
claude

# Verify SI connection by asking:
# "Can you connect to System Initiative?"
# "What's my System Initiative workspace URL?"
```

If Claude can respond with your workspace information, the integration is working.

---

## Method 2: Claude Desktop GUI (Community Method - Unofficial)

### Overview

⚠️ **Important:** This method is NOT officially documented by System Initiative. It was discovered through community experimentation and has been confirmed working on Windows 11 + WSL2. Use at your own risk and expect potential issues with future SI updates.

**Advantages:**
- GUI-based chat interface
- Better for exploratory work
- Familiar conversational interaction
- Visual feedback

**Disadvantages:**
- Not officially supported by SI
- More complex manual setup required
- May break with SI or Claude Desktop updates
- Requires understanding of MCP configuration

**When to Use This Method:**
- You prefer GUI over CLI
- You're doing exploratory infrastructure work
- Your team is more comfortable with chat interfaces
- You need to share screenshots or collaborate visually

### Prerequisites

1. **Claude Desktop Application** - Download from https://claude.ai/download
2. **Docker Desktop running** with WSL2 integration enabled
3. **SI API Token** (JWT format) from System Initiative

### Installation

**Install Claude Desktop on Windows:**

1. Download from https://claude.ai/download
2. Run installer
3. Launch and sign in with your Anthropic account

### Manual MCP Configuration

Claude Desktop uses a configuration file to connect to MCP servers. You need to manually create this configuration.

**Step 1: Create MCP Configuration File**

**In WSL2:**

```bash
# Create the Windows config file from WSL2
cat > /mnt/c/Users/YOUR_USERNAME/AppData/Roaming/Claude/claude_desktop_config.json << 'EOF'
{
  "mcpServers": {
    "system-initiative": {
      "type": "stdio",
      "command": "wsl",
      "args": [
        "docker",
        "run",
        "-i",
        "--rm",
        "--pull=always",
        "-e",
        "SI_API_TOKEN=YOUR_JWT_TOKEN_HERE",
        "systeminit/si-mcp-server:stable"
      ]
    }
  }
}
EOF
```

**Replace:**
- `YOUR_USERNAME` with your Windows username
- `YOUR_JWT_TOKEN_HERE` with your actual SI API token (JWT format)

**Configuration Explained:**
- **type: stdio** - Communication happens via standard input/output
- **command: wsl** - Execute through Windows Subsystem for Linux
- **docker run** - Runs SI MCP server in a container on-demand
- **-i** - Interactive mode for stdin/stdout
- **--rm** - Auto-remove container after use (no persistent container)
- **--pull=always** - Always pull latest MCP server image
- **SI_API_TOKEN** - Your authentication token embedded in the command

**Step 2: Verify Configuration File**

```bash
# Check it was created correctly
cat /mnt/c/Users/YOUR_USERNAME/AppData/Roaming/Claude/claude_desktop_config.json
```

Should show the JSON configuration with your token embedded.

### Restart Claude Desktop

1. **Completely close Claude Desktop** (exit from system tray, not just close window)
2. Wait 5 seconds
3. **Reopen Claude Desktop**
4. Start a new conversation

### Testing Claude Desktop with SI

In Claude Desktop chat interface, try:

```
What's my System Initiative workspace URL?
```

```
Can you connect to System Initiative?
```

**What Should Happen:**
- Claude Desktop executes the WSL Docker command
- SI MCP server container starts briefly
- Claude connects to your SI workspace
- You get responses with your workspace information

If Claude can provide your workspace details, the integration is working.

**Validation:**

While Claude is responding to an SI query, you can watch the container in WSL2:

```bash
# In a separate WSL2 terminal
watch -n 1 docker ps

# You'll briefly see systeminit/si-mcp-server container appear and disappear
```

### Troubleshooting Claude Desktop Method

**Issue: "Server disconnected" error**

Check the Claude Desktop logs (usually shown in error messages):

```
Error: SI_API_TOKEN is not defined
```
**Fix:** The token wasn't passed correctly. Verify the config file has the token embedded directly in the `-e` argument line.

**Issue: "Invalid token format"**

```
InvalidTokenError: Invalid token specified: missing part
```
**Fix:** You used a workspace token (short ULID format) instead of API token (JWT format). Regenerate an API token from SI.

**Issue: "Claude Code not installed"**

The `si ai-agent init` command is trying to set up Claude Code, not Claude Desktop. Use the manual MCP configuration method instead.

**Issue: No Docker containers starting**

- Verify Docker Desktop is running
- Check WSL2 integration is enabled in Docker Desktop settings
- Test: `wsl docker ps` in PowerShell should work

### Comparison: Claude Code vs Claude Desktop

| Feature | Claude Code CLI | Claude Desktop GUI |
|---------|----------------|-------------------|
| Official Support | ✅ Yes | ❌ No (community method) |
| Setup Complexity | Simple | Complex |
| Interface | Terminal | Chat GUI |
| Best For | Automation, scripting | Exploration, learning |
| Collaboration | Share commands | Share screenshots |
| SI Updates | Less likely to break | May break with updates |
| Documentation | Official SI docs | This guide only |

**Recommendation:** Start with Claude Code CLI if you're comfortable with terminal workflows. Use Claude Desktop if you need the visual interface and are willing to maintain manual configuration.

---

## Connecting Azure to System Initiative

### Overview

To manage Azure resources through System Initiative, you need to:
1. Add a Microsoft Credential component
2. Configure it with your service principal details
3. Test the connection

### Step 1: Access System Initiative Workspace

1. Go to https://app.systeminit.com
2. Open your workspace
3. Navigate to **HEAD** change set (or create a new change set for testing)

### Step 2: Add Microsoft Credential Component

1. In the component panel, search for **"Microsoft"**
2. Find **"Microsoft Credential"** component
3. Drag it onto your canvas
4. Double-click to open the component details

### Step 3: Configure Azure Credentials

**Fill in the following fields:**

**Name:**
- Enter a descriptive name
- **Important:** This name should match the name of your client secret in Azure
- Example: `SI-Integration-Secret` or `Azure-Production`

**Tenant ID:**
- Paste your Azure **Directory (tenant) ID**
- Found in Azure Portal → Azure Entra ID → Overview
- This is straightforward - copy the Tenant ID value

**Client ID:**
- **IMPORTANT:** Use the **Application (client) ID**, NOT the Object ID
- Found in Azure Portal → App registrations → SystemInitiative-Integration → Overview
- Look for "Application (client) ID" specifically
- Format: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX (GUID)

**Client Secret:**
- **CRITICAL:** Use the **secret VALUE**, NOT the Secret ID
- This is the long string you saved when creating the client secret
- In Azure Portal, when you create a secret, you see both:
  - **Secret ID** (a GUID) ❌ Don't use this
  - **Value** (long alphanumeric string) ✅ Use this
- The Value is only shown once when created
- If you lost it, you must create a new secret

**Subscription ID:**
- Paste your Azure subscription ID
- Found in Azure Portal → Subscriptions
- Format: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX (GUID)

### Step 4: Save and Validate

1. Click **Save** or confirm changes
2. System Initiative will attempt to validate the credentials
3. Look for:
   - ✅ Green checkmark or "Connected" status
   - ❌ Red X or error message indicates configuration problem

### Step 5: Test Azure Connection

**Create a simple test resource:**

1. Add an **Azure Resource Group** component to your canvas
2. Connect it to your Microsoft Credential component
3. Configure the resource group:
   - Name: `test-rg-si`
   - Location: `eastus`
4. Click **Apply** or run actions
5. Verify it creates successfully in Azure Portal

### Common Azure Connection Issues

**"Authentication failed"**
- **Check client secret:** Ensure you used the secret VALUE, not the Secret ID
  - Secret ID looks like: `12345678-1234-1234-1234-123456789abc` (wrong)
  - Secret VALUE looks like: `A8Q~longAlphanumericString...` (correct)
- **Check client ID:** Ensure you used Application (client) ID, not Object ID
  - Both are GUIDs, easy to confuse
  - Must be the "Application (client) ID" from app registration Overview
- Verify client secret is not expired
- Check tenant ID is accurate
- Ensure service principal exists: `az ad sp list --display-name SystemInitiative-Integration`

**"Insufficient permissions"**
- Verify Contributor role is assigned to subscription
- Check role assignment: `az role assignment list --assignee YOUR_CLIENT_ID`
- Ensure subscription ID is correct

**"Subscription not found"**
- Verify subscription ID matches exactly
- Ensure service principal has access to the subscription
- Check subscription is active: `az account list`

---

## Validation and Testing

### System Validation

Use the provided validation scripts to confirm your setup:

**In PowerShell (Administrator):**

```powershell
# Run the environment validation script
.\validate-environment.ps1

# Expected output shows status of:
# - WSL2 installation and version
# - Ubuntu distribution
# - Docker Desktop
# - Node.js in WSL2
# - Azure CLI
# - SI CLI
```

**Note:** The validation script may show false negatives for some checks due to output parsing. If a component works but shows as failing, that's a script issue, not a setup issue.

### Manual Verification Steps

**1. WSL2 and Ubuntu:**

```powershell
# PowerShell
wsl --list --verbose

# Should show Ubuntu with VERSION 2
```

**2. Docker Integration:**

```bash
# WSL2
docker ps
docker run hello-world

# Both should work
```

**3. Node.js in WSL2:**

```bash
# WSL2
node --version
npm --version

# Should show version numbers
```

**4. Azure CLI:**

```powershell
# PowerShell
az account list --output table

# Should show your subscriptions
```

**5. SI CLI:**

```bash
# WSL2
si --version

# Should show version number
```

**6. Claude Integration:**

If using Claude Code CLI:
```bash
# WSL2
claude --version
```

If using Claude Desktop:
```
# In Claude Desktop chat
What's my System Initiative workspace URL?
```

**7. Azure Service Principal:**

```powershell
# PowerShell
az ad sp list --display-name "SystemInitiative-Integration"
az role assignment list --assignee YOUR_CLIENT_ID
```

### End-to-End Test

**Create a simple test to validate the connection:**

1. Open System Initiative workspace
2. Create a new change set: `test-connection`
3. Add a Microsoft Credential component (already configured)
4. Add an Azure Resource Group component
5. Connect the Resource Group to the Credential
6. Configure Resource Group:
   - Name: `test-si-rg`
   - Location: `eastus`
7. Apply the change set
8. Verify resource appears in Azure Portal: `az group show --name test-si-rg`
9. Clean up: Delete the resource group from Azure Portal or SI

**Success criteria:**
- Resource group created in Azure
- Visible in both SI and Azure Portal
- Can be deleted successfully

This confirms the complete authentication and integration chain is working.

---

## Troubleshooting

### WSL2 Issues

**Problem: WSL2 not starting or Ubuntu not installing**

```powershell
# Check virtualization is enabled in BIOS
systeminfo | findstr /i "hyper-v"

# Reinstall WSL
wsl --unregister Ubuntu
wsl --install -d Ubuntu
```

**Problem: WSL2 defaulting to root user**

See "Configure WSL2 Default User" section above.

**Problem: "Permission denied" errors in WSL2**

```bash
# Fix file permissions
sudo chmod +x /path/to/file

# Or add your user to necessary groups
sudo usermod -aG docker $USER

# Logout and login again
exit
wsl
```

### Docker Issues

**Problem: Docker not accessible from WSL2**

1. Open Docker Desktop
2. Settings → Resources → WSL Integration
3. Enable integration with Ubuntu
4. Apply & Restart
5. Test: `wsl docker ps`

**Problem: Docker containers failing to start**

```bash
# Check Docker daemon status
docker info

# Restart Docker Desktop from Windows
# Settings → Troubleshoot → Restart Docker
```

**Problem: "Cannot connect to Docker daemon"**

```bash
# In WSL2
sudo service docker start

# Or restart Docker Desktop from Windows
```

### Azure Authentication Issues

**Problem: Service principal authentication failing**

```powershell
# Verify service principal exists
az ad sp list --display-name "SystemInitiative-Integration"

# Check role assignments
az role assignment list --assignee YOUR_CLIENT_ID --output table

# Test manual authentication with service principal
az login --service-principal `
  --username YOUR_CLIENT_ID `
  --password YOUR_CLIENT_SECRET `
  --tenant YOUR_TENANT_ID

az account show
```

**Problem: Client secret expired**

1. Go to Azure Portal → App registrations → SystemInitiative-Integration
2. Certificates & secrets → Client secrets
3. Delete old secret
4. Create new secret
5. Update SI credential configuration

### System Initiative Issues

**Problem: SI CLI not found**

```bash
# In WSL2
export PATH="$HOME/.local/bin:$PATH"

# Make permanent
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Reinstall if needed
curl -fsSL https://raw.githubusercontent.com/systeminit/si/main/bin/install.sh | bash
```

**Problem: Cannot connect to SI workspace**

- Verify API token is correct and not expired
- Check workspace URL is accessible
- Ensure token has proper permissions
- Try generating a new API token

### Claude Integration Issues

**Problem: Claude Code - "Claude Code not installed"**

```bash
# In WSL2
npm install -g @anthropic-ai/claude-cli
claude --version
```

**Problem: Claude Desktop - "Server disconnected"**

1. Check config file exists and has correct format
2. Verify API token is JWT format (not workspace token)
3. Ensure Docker Desktop is running
4. Check WSL2 integration enabled
5. Restart Claude Desktop completely

**Problem: Environment variable not passed to Docker**

- Token must be embedded directly in the `-e` argument
- Use format: `-e "SI_API_TOKEN=your-token"`
- NOT using separate `env` section (doesn't work across WSL boundary)

### Network and Connectivity Issues

**Problem: Cannot pull Docker images**

```bash
# Check internet connectivity
ping google.com

# Check Docker Hub access
docker pull hello-world

# If behind proxy, configure Docker proxy settings
```

**Problem: Azure API calls timing out**

- Check firewall/proxy settings
- Verify Azure service health
- Test with Azure CLI: `az account show`

---

## Reference Information

### Directory Structure

**Windows Control Plane:**
- PowerShell scripts and Azure management: Any location
- Docker Desktop: Managed through GUI
- Azure CLI: Installed system-wide

**WSL2/Ubuntu:**
- SI CLI: `~/.local/bin/si`
- Claude CLI: `/usr/local/bin/claude` or `~/.npm-global/bin/claude`
- Working directory: `~/` or any location in Linux filesystem

**Claude Desktop Configuration:**
- Config file: `C:\Users\YOUR_USERNAME\AppData\Roaming\Claude\claude_desktop_config.json`

### Important File Locations

**Azure Configuration:**
- Service principal in Azure Portal → App registrations
- Role assignments in Azure Portal → Subscriptions → IAM

**System Initiative:**
- Web interface: https://app.systeminit.com
- API tokens: Settings → API Tokens in SI web interface

**Claude:**
- Claude Desktop app: Windows application
- Claude Code CLI: WSL2 Linux binary
- MCP config: AppData/Roaming/Claude/ (Windows)

### Key Concepts

**WSL2 vs Windows:**
- WSL2 provides Linux environment for Docker and SI tools
- Windows remains primary control plane for Azure management
- Two separate environments with separate binaries
- Install tools in the environment where you'll use them

**Service Principal Permissions:**
- App Registration: Creates identity in Azure Entra ID
- Client Secret: Password for authentication
- RBAC Assignment: Grants permissions to Azure resources
- No Entra ID roles needed for resource management

**Token Types:**
- **SI API Token:** JWT format (long), used for programmatic access
- **SI Workspace Token:** ULID format (short), used for web interface
- **For AI agents:** Use API token (JWT)
- **Azure Client Secret:** Service principal password

**Azure Resource Hierarchy:**
- Management Group (optional) → Subscription → Resource Group → Resources
- RBAC can be assigned at any level
- Permissions inherited down the hierarchy

### Useful Commands

**WSL2 Management:**
```powershell
# PowerShell
wsl --list --verbose              # List distributions
wsl --set-default Ubuntu          # Set default distribution
wsl --shutdown                    # Stop all WSL instances
wsl --update                      # Update WSL
wsl -d Ubuntu                     # Start specific distribution
```

**Docker Management:**
```bash
# WSL2
docker ps                         # List running containers
docker ps -a                      # List all containers
docker images                     # List downloaded images
docker logs CONTAINER_ID          # View container logs
docker system prune               # Clean up unused resources
```

**Azure CLI:**
```powershell
# PowerShell
az login                          # Login to Azure
az account list                   # List subscriptions
az account set -s SUBSCRIPTION    # Set active subscription
az group list                     # List resource groups
az ad sp list --display-name NAME # Find service principal
```

**System Initiative:**
```bash
# WSL2
si --version                      # Check version
```

### Support and Resources

**System Initiative:**
- Documentation: https://docs.systeminit.com
- Community: https://discord.gg/system-initiative
- GitHub: https://github.com/systeminit/si

**Microsoft Azure:**
- Documentation: https://docs.microsoft.com/azure
- Portal: https://portal.azure.com
- CLI Reference: https://docs.microsoft.com/cli/azure

**Docker:**
- Documentation: https://docs.docker.com
- Desktop: https://www.docker.com/products/docker-desktop

**Claude:**
- Website: https://claude.ai
- Documentation: https://docs.anthropic.com
- API: https://console.anthropic.com

**American Sound Contact:**
- Author: Doug Schaefer
- Email: dougschaefer@asei.com
- Organization: American Sound

---

## Security Best Practices

**Credential Management:**
- Never commit secrets to source control
- Rotate service principal secrets every 6-12 months
- Use Azure Key Vault for production secret storage
- Limit service principal permissions to minimum required

**Azure RBAC:**
- Start with resource group scope, not subscription
- Use custom roles for granular permissions when possible
- Regularly audit role assignments
- Remove unused service principals

**Network Security:**
- Configure Azure network security groups appropriately
- Use private endpoints for sensitive resources
- Enable Azure Defender for enhanced security monitoring
- Review Azure Security Center recommendations

**Monitoring:**
- Enable Azure Monitor for resource tracking
- Set up alerts for unusual service principal activity
- Log SI changes and deployments
- Regular security audits

---

## Next Steps

After completing this setup, you're ready to begin working with System Initiative and Azure. Refer to the official System Initiative documentation at https://docs.systeminit.com for usage guidance and tutorials.

---

**Document Version:** 2.0  
**Last Updated:** December 2025  
**Maintained By:** Doug Schaefer (dougschaefer@asei.com)  
**Organization:** American Sound
