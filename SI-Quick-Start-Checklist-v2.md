# System Initiative Quick-Start Checklist
## Windows 11 + Azure Setup

**Version:** 2.0  
**Organization:** American Sound  
**Contact:** Doug Schaefer (dougschaefer@asei.com)

---

## Prerequisites Checklist

- [ ] Windows 11 Pro or Enterprise
- [ ] Administrator access
- [ ] 16GB+ RAM (32GB recommended)
- [ ] Azure subscription access
- [ ] System Initiative account (app.systeminit.com)
- [ ] Anthropic Claude account (claude.ai)

---

## Phase 1: Base System Setup

### WSL2 Installation

**In PowerShell (Administrator):**

```powershell
# Install WSL2
wsl --install

# Set as default
wsl --set-default-version 2

# Restart computer
```

**After Restart:**

```powershell
# Verify
wsl --list --verbose
```

- [ ] WSL2 installed
- [ ] VERSION shows 2
- [ ] Computer restarted

---

### Ubuntu Setup

```powershell
# Install Ubuntu
wsl --install -d Ubuntu

# Launch Ubuntu
wsl
```

**In Ubuntu (first launch):**
- [ ] Created Linux username
- [ ] Set Linux password
- [ ] Noted credentials

**Configure Ubuntu:**

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install essentials
sudo apt install -y git curl wget

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify
node --version
npm --version
```

- [ ] System updated
- [ ] Git installed
- [ ] Node.js installed
- [ ] npm installed

---

### Docker Desktop Installation

**Download and Install:**
1. Download from https://www.docker.com/products/docker-desktop
2. Run installer
3. Select "Use WSL 2 instead of Hyper-V"
4. Restart when prompted

**Configure Docker:**

1. Open Docker Desktop
2. Settings → Resources → WSL Integration
3. Enable Ubuntu integration
4. Apply & Restart

**Verify in WSL2:**

```bash
docker --version
docker ps
```

- [ ] Docker Desktop installed
- [ ] WSL2 integration enabled
- [ ] Docker commands work in WSL2

---

### Azure CLI Installation

**In PowerShell (Administrator):**

```powershell
# Install
winget install -e --id Microsoft.AzureCLI

# Verify
az --version

# Login
az login

# Check subscriptions
az account list --output table
```

- [ ] Azure CLI installed
- [ ] Logged in to Azure
- [ ] Can see subscriptions

---

### System Initiative CLI Installation

**In WSL2:**

```bash
# Install SI CLI
curl -fsSL https://raw.githubusercontent.com/systeminit/si/main/bin/install.sh | bash

# Add to PATH
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# Verify
si --version
```

- [ ] SI CLI installed
- [ ] si command works
- [ ] Added to PATH

---

## Phase 2: Azure Service Principal Setup

### Create App Registration

**In Azure Portal:**

1. Navigate to Azure Entra ID
2. App registrations → New registration
3. Name: `SystemInitiative-Integration`
4. Register

**Note these values:**
- [ ] Application (client) ID: _______________
- [ ] Directory (tenant) ID: _______________

---

### Create Client Secret

1. App registration → Certificates & secrets
2. New client secret
3. Description: `SI-Integration-Secret`
4. Expiration: 24 months
5. Add and COPY secret value immediately

- [ ] Client secret created
- [ ] Secret value saved securely: _______________

---

### Assign Permissions

**For each subscription:**

1. Navigate to Subscription
2. Access control (IAM)
3. Add role assignment
4. Role: Contributor
5. Select SystemInitiative-Integration
6. Assign

**Verify:**

```powershell
# PowerShell
az ad sp list --display-name "SystemInitiative-Integration"
az role assignment list --assignee YOUR_CLIENT_ID
```

- [ ] Contributor role assigned
- [ ] Role assignment verified
- [ ] No Entra ID roles needed (correct)

---

## Phase 3: System Initiative Account Setup

### Create Account

1. Go to app.systeminit.com
2. Sign up / Sign in
3. Create workspace
4. Note workspace URL: _______________

- [ ] SI account created
- [ ] Workspace created
- [ ] Workspace URL noted

---

### Generate API Token

1. Settings → API Tokens
2. Create new token
3. Name: `Claude-Integration`
4. Copy token immediately (JWT format, starts with eyJhbG...)

- [ ] API token generated (JWT format)
- [ ] Token saved securely: _______________

---

## Phase 4: Claude AI Agent Setup

**Choose ONE method:**

- [ ] Method 1: Claude Code CLI (Recommended)
- [ ] Method 2: Claude Desktop GUI (Unofficial)

---

### Method 1: Claude Code CLI (Official)

**Install Claude Code:**

```bash
# In WSL2
npm install -g @anthropic-ai/claude-cli

# Verify
claude --version
```

**Configure and Initialize:**

```bash
# Login to Claude
claude auth login

# Set SI token
export SI_API_TOKEN="your-jwt-token-here"

# Initialize SI agent
si ai-agent init
```

**Test:**

```bash
# Start Claude session
claude

# Try: "List my System Initiative workspaces"
```

- [ ] Claude Code installed
- [ ] Authenticated with Claude
- [ ] SI AI agent initialized
- [ ] Can query SI workspace

---

### Method 2: Claude Desktop GUI (Unofficial)

⚠️ **Not officially supported by SI**

**Install Claude Desktop:**

1. Download from claude.ai/download
2. Install on Windows
3. Launch and sign in

- [ ] Claude Desktop installed
- [ ] Signed in

**Create MCP Configuration:**

**In WSL2:**

```bash
# Replace YOUR_USERNAME and YOUR_TOKEN
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

**Verify config:**

```bash
cat /mnt/c/Users/YOUR_USERNAME/AppData/Roaming/Claude/claude_desktop_config.json
```

**Restart and Test:**

1. Close Claude Desktop completely (exit from system tray)
2. Reopen Claude Desktop
3. Ask: "What's my System Initiative workspace URL?"

- [ ] Config file created
- [ ] Token embedded in config
- [ ] Claude Desktop restarted
- [ ] Can connect to SI workspace

---

## Phase 5: Connect Azure to System Initiative

### Add Microsoft Credential

**In SI Web Interface:**

1. Open workspace at app.systeminit.com
2. Go to HEAD or create test change set
3. Search for "Microsoft" in components
4. Add "Microsoft Credential" to canvas
5. Open component details

### Configure Credential

**Fill in fields:**

- **Name:** `SI-Integration-Secret` (match Azure secret name)
- **Tenant ID:** [Your Azure tenant ID]
- **Client ID:** [Your Azure Application (client) ID - NOT Object ID]
- **Client Secret:** [Your Azure client secret VALUE - NOT Secret ID]
- **Subscription ID:** [Your Azure subscription ID]

**Important:**
- Client ID = Application (client) ID from app registration Overview
- Client Secret = The VALUE (long string) shown when you created the secret, NOT the Secret ID (GUID)

6. Save configuration
7. Look for green checkmark/Connected status

- [ ] Microsoft Credential added
- [ ] All fields configured correctly
- [ ] Used Application ID (not Object ID)
- [ ] Used secret VALUE (not Secret ID)
- [ ] Connection validated

---

### Test Azure Connection

1. Add "Azure Resource Group" component
2. Connect to Microsoft Credential
3. Configure:
   - Name: `test-rg-si`
   - Location: `eastus`
4. Apply changes
5. Verify in Azure Portal

- [ ] Test resource group created
- [ ] Visible in Azure Portal
- [ ] Azure connection working

---

## Phase 6: Validation

### Quick Validation

**In PowerShell:**

```powershell
# WSL2 check
wsl --list --verbose

# Azure CLI check
az account show
```

**In WSL2:**

```bash
# Docker check
docker ps

# Node.js check
node --version

# SI CLI check
si --version

# Claude check (if using CLI)
claude --version
```

- [ ] WSL2 working
- [ ] Docker working
- [ ] Azure CLI working
- [ ] SI CLI working
- [ ] Claude integration working

---

### End-to-End Test

**Create test infrastructure:**

1. Open SI workspace
2. Create change set: `test-connection`
3. Add components:
   - Microsoft Credential (configured)
   - Azure Resource Group
4. Connect Resource Group to Credential
5. Configure Resource Group:
   - Name: `test-si-rg`
   - Location: `eastus`
6. Apply changes
7. Verify in Azure Portal
8. Clean up: Delete resource group

- [ ] Can create change sets
- [ ] Can add and connect components
- [ ] Can configure resources
- [ ] Can apply changes
- [ ] Resource appears in Azure Portal
- [ ] Can delete resources

---

## Troubleshooting Quick Reference

**WSL2 not starting:**
```powershell
wsl --shutdown
wsl
```

**Docker not accessible in WSL2:**
- Docker Desktop → Settings → WSL Integration → Enable Ubuntu

**Azure auth failing:**
```powershell
az ad sp list --display-name "SystemInitiative-Integration"
az role assignment list --assignee YOUR_CLIENT_ID
```

**SI CLI not found:**
```bash
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

**Claude Desktop not connecting:**
- Verify config file location
- Check token is JWT format (not workspace token)
- Ensure Docker Desktop is running
- Restart Claude Desktop completely

---

## Success Criteria

✅ **Your setup is complete when:**

- [ ] All Phase 1-6 checkboxes are checked
- [ ] Can query SI workspace through Claude
- [ ] Can create Azure resources from SI
- [ ] Resources appear in Azure Portal
- [ ] Can apply and delete changes successfully

---

## Next Steps

Once your setup is validated and working, refer to the official System Initiative documentation at https://docs.systeminit.com for usage guidance.

---

**Document Version:** 2.0  
**Last Updated:** December 2025  
**Contact:** dougschaefer@asei.com  
**Organization:** American Sound
