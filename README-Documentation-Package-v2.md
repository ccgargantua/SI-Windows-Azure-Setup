# System Initiative Windows + Azure Setup Documentation Package

**Version:** 2.0  
**Created:** December 2025  
**Organization:** American Sound  
**Author:** Doug Schaefer (dougschaefer@asei.com)

---

## Package Overview

This documentation package provides comprehensive setup instructions for System Initiative on Windows 11 with Azure as the cloud provider. It was created based on real-world implementation and troubleshooting at American Sound, documenting both official setup methods and community-discovered alternatives.

**Key Features:**
- Complete Windows 11 + WSL2 + Docker setup
- Azure service principal configuration
- Two Claude integration methods (CLI and Desktop)
- Automated PowerShell scripts
- Comprehensive troubleshooting guidance

---

## What's Included

### Documentation Files

**[SI-Setup-Guide-Windows-Azure-v2.md](SI-Setup-Guide-Windows-Azure-v2.md)** (Main Reference)
- Complete 50+ page setup guide
- Detailed step-by-step instructions
- Both Claude Code CLI and Claude Desktop methods
- Troubleshooting section
- Reference information and best practices

**[SI-Quick-Start-Checklist-v2.md](SI-Quick-Start-Checklist-v2.md)** (Quick Reference)
- Condensed checklist format
- Essential commands and steps
- Track your progress with checkboxes
- Quick troubleshooting reference

### PowerShell Scripts

**[setup-azure-service-principal-v2.ps1](setup-azure-service-principal-v2.ps1)**
- Automated Azure service principal creation
- Configures proper RBAC permissions
- Saves credentials securely
- Validates configuration

**[validate-environment-v2.ps1](validate-environment-v2.ps1)**
- Validates WSL2, Docker, Azure CLI, Node.js
- Checks SI CLI installation
- Verifies Claude integration (optional)
- Provides actionable feedback

---

## Quick Start

### New to System Initiative?

1. **Start here:** Read [SI-Setup-Guide-Windows-Azure-v2.md](SI-Setup-Guide-Windows-Azure-v2.md)
2. **Use checklist:** Follow [SI-Quick-Start-Checklist-v2.md](SI-Quick-Start-Checklist-v2.md)
3. **Run scripts:** Use PowerShell scripts to automate setup

### Troubleshooting Existing Setup?

1. **Run validation:** Execute `validate-environment-v2.ps1` in PowerShell
2. **Check results:** Review any failures or warnings
3. **Reference guide:** See troubleshooting section in main guide

---

## Setup Process Overview

### Phase 1: Base System (30-45 minutes)
1. Enable WSL2 on Windows
2. Install Ubuntu distribution
3. Install Docker Desktop with WSL2 integration
4. Install Azure CLI
5. Install SI CLI in WSL2

### Phase 2: Azure Configuration (15-20 minutes)
1. Create Azure service principal
2. Configure RBAC permissions
3. Generate and save credentials
4. Validate access

### Phase 3: Claude Integration (10-30 minutes)
**Choose one method:**
- **Claude Code CLI** (10-15 min, official, simple)
- **Claude Desktop GUI** (20-30 min, unofficial, complex but visual)

### Phase 4: Connect and Test (10-15 minutes)
1. Create SI account and workspace
2. Configure Azure credentials in SI
3. Create test infrastructure
4. Validate end-to-end workflow

**Total Time:** 1-2 hours for complete setup

---

## Key Documentation Highlights

### What Makes This Guide Unique

**Windows-Specific Focus:**
- Most SI documentation assumes Linux or macOS
- This guide addresses Windows-specific challenges
- WSL2 integration patterns documented
- Docker Desktop configuration explained

**Azure Integration:**
- Official SI docs focus on AWS
- Complete Azure service principal setup
- RBAC vs Entra ID role clarification
- Azure-specific terminology mappings

**Two Claude Methods:**
- **Claude Code CLI:** Official supported method
- **Claude Desktop GUI:** Community-discovered method (unofficial)
- Clear comparison of pros/cons
- Working configurations for both

**Real-World Troubleshooting:**
- Based on actual implementation experience
- Common error messages and solutions
- False positives in validation tools
- WSL2-specific issues and fixes

---

## Critical Concepts Explained

### Token Confusion (IMPORTANT)

System Initiative uses confusing token terminology:
- **API Tokens:** JWT format (long), used for programmatic access and AI agents
- **Workspace Tokens:** ULID format (short), used for web interface
- **For AI integration:** Use API token (JWT format)
- **Environment variable name:** `SI_API_TOKEN` (even though it's an API token)

### Service Principal Permissions

**What You Need:**
- App Registration in Azure Entra ID (creates identity)
- Client Secret (password for authentication)
- Azure RBAC role on subscriptions/resources (Contributor or custom)

**What You DON'T Need:**
- NO Entra ID administrative roles
- NO Microsoft Graph API permissions
- NO Global Administrator or similar roles

The service principal only needs resource management permissions via Azure RBAC.

### Azure Credential Values (CRITICAL)

**Common mistake that causes authentication failures:**

When configuring System Initiative's Microsoft Credential:

| SI Field | Azure Portal Location | ⚠️ Common Mistake |
|----------|----------------------|-------------------|
| **Client ID** | Application (client) ID | ❌ Don't use Object ID |
| **Client Secret** | Secret VALUE | ❌ Don't use Secret ID |
| **Tenant ID** | Directory (tenant) ID | ✅ Straightforward |

**Client Secret Details:**
- When you create a secret in Azure, you see a table with columns
- **Secret ID** = A GUID like `12345678-abcd-...` ❌ Wrong
- **Value** = Long string like `A8Q~abc123...` ✅ Correct
- Copy the VALUE column (30+ character string)
- It's only shown once when created

**Client ID Details:**
- App registration Overview shows three GUIDs
- **Application (client) ID** ✅ Use this
- **Object ID** ❌ Not this
- Both are GUIDs, easy to confuse

### WSL2 vs Windows

**Two Separate Environments:**
- WSL2: Linux environment for Docker, SI tools, Claude CLI
- Windows: Primary control plane for Azure management, validation

**Install tools in the environment where you'll use them:**
- Azure CLI: Install on Windows (use PowerShell)
- Docker: Managed by Docker Desktop (Windows), runs in WSL2
- Node.js: Install separately in WSL2
- SI CLI: Install in WSL2
- Claude Code: Install in WSL2
- Claude Desktop: Install on Windows

### Claude Code vs Claude Desktop

| Aspect | Claude Code CLI | Claude Desktop GUI |
|--------|----------------|-------------------|
| **Official Support** | ✅ Yes | ❌ No |
| **Setup Complexity** | Simple | Complex |
| **Interface** | Terminal | Chat GUI |
| **Documentation** | SI official docs | This guide only |
| **Best For** | Automation, scripting | Exploration, learning |
| **Updates** | Less likely to break | May break with updates |

**Recommendation:** Start with Claude Code CLI if comfortable with terminals. Use Claude Desktop if you need the visual interface and accept the maintenance burden.

---

## Prerequisites Summary

### Required Software
- Windows 11 Pro or Enterprise
- WSL2 with Ubuntu distribution
- Docker Desktop for Windows (WSL2 mode)
- Azure CLI for Windows
- Node.js in WSL2
- System Initiative CLI in WSL2

### Required Accounts
- Azure subscription (Owner or Contributor access)
- System Initiative account (free tier available)
- Anthropic Claude account (for AI integration)

### Hardware Requirements
- 16GB RAM minimum (32GB recommended)
- 50GB free disk space
- CPU with virtualization support

---

## Validation and Testing

### Before You Begin

Run validation script to check prerequisites:

```powershell
# In PowerShell
.\validate-environment-v2.ps1
```

Review output for any critical failures or warnings.

### After Setup

Verify end-to-end functionality:
1. WSL2 and Docker working
2. Azure CLI authenticated
3. SI CLI functional
4. Claude can query SI workspace
5. Can create Azure resources from SI
6. Resources appear in Azure Portal

---

## Troubleshooting Quick Reference

### Most Common Issues

**"WSL2 not starting"**
```powershell
wsl --shutdown
wsl
```

**"Docker not accessible from WSL2"**
- Docker Desktop → Settings → Resources → WSL Integration
- Enable Ubuntu integration
- Apply & Restart

**"SI CLI not found"**
```bash
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

**"Claude Desktop - Server disconnected"**
- Verify config file: `%APPDATA%\Claude\claude_desktop_config.json`
- Ensure token is JWT format (not workspace token)
- Check Docker Desktop is running
- Restart Claude Desktop completely

**"Azure authentication failed"**
```powershell
az ad sp list --display-name "SystemInitiative-Integration"
az role assignment list --assignee YOUR_CLIENT_ID
```

For detailed troubleshooting, see the main guide.

---

## Security Considerations

### Credential Management
- Store client secrets in password manager or Azure Key Vault
- Never commit secrets to source control
- Rotate service principal secrets every 6-12 months
- Use minimum required permissions (start with resource group scope)

### Azure RBAC Best Practices
- Grant Contributor role at most granular scope needed
- Use custom roles for production environments
- Regular audit of role assignments
- Remove unused service principals

### System Initiative
- API tokens have expiration dates
- Separate tokens for dev/prod environments
- Configure approval workflows for production changes
- Enable audit logging

---

## Support and Resources

### System Initiative
- Official Docs: https://docs.systeminit.com
- Community Discord: https://discord.gg/system-initiative
- GitHub: https://github.com/systeminit/si

### Microsoft Azure
- Azure Portal: https://portal.azure.com
- Documentation: https://docs.microsoft.com/azure
- CLI Reference: https://docs.microsoft.com/cli/azure

### Docker
- Docker Desktop: https://www.docker.com/products/docker-desktop
- Documentation: https://docs.docker.com

### Claude
- Website: https://claude.ai
- Documentation: https://docs.anthropic.com

### American Sound
- Contact: Doug Schaefer
- Email: dougschaefer@asei.com
- Organization: American Sound

---

## Version History

### Version 2.0 (December 2025)
- Complete rewrite based on feedback and real-world testing
- Added both Claude Code CLI and Claude Desktop methods
- Improved validation scripts with better output handling
- Clarified Azure RBAC vs Entra ID permissions
- Fixed token type confusion (API vs workspace tokens)
- Streamlined setup process
- Removed user-specific directory structures
- Updated all scripts and documentation

### Version 1.0 (December 2025)
- Initial documentation package
- Windows 11 + WSL2 + Docker setup
- Azure service principal configuration
- Basic validation scripts

---

## Contributing and Feedback

This documentation was created for American Sound's internal use but may be helpful to others setting up System Initiative on Windows with Azure.

**Found an issue?**
- Contact: dougschaefer@asei.com
- Include: Error messages, system details, and steps to reproduce

**Suggestions for improvement?**
- We welcome feedback on clarity and completeness
- Let us know what worked and what didn't
- Share your own troubleshooting discoveries

---

## License and Usage

This documentation is provided "as-is" for informational purposes. While created for American Sound, others are welcome to use and adapt it for their own System Initiative setup needs.

**Disclaimer:** The Claude Desktop integration method is not officially supported by System Initiative and may change or break with future updates. The official method is Claude Code CLI.

---

## Getting Started Now

1. **Read the main guide:** [SI-Setup-Guide-Windows-Azure-v2.md](SI-Setup-Guide-Windows-Azure-v2.md)
2. **Follow the checklist:** [SI-Quick-Start-Checklist-v2.md](SI-Quick-Start-Checklist-v2.md)
3. **Run validation:** `.\validate-environment-v2.ps1`
4. **Create service principal:** `.\setup-azure-service-principal-v2.ps1`
5. **Configure and test**

**Good luck with your System Initiative setup!**

---

**Document Version:** 2.0  
**Last Updated:** December 2025  
**Author:** Doug Schaefer (dougschaefer@asei.com)  
**Organization:** American Sound
