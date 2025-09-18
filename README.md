# MCP Server for Business Central

Two PowerShell-based tools for integrating Microsoft Dynamics 365 Business Central with Claude Desktop through Model Context Protocol (MCP) servers.

## Solutions Overview

### 1. Instant MCP Server (`Instant-MCP-Server/`)

**What it does:** Creates a pre-configured MCP server with hardcoded Business Central entities (Items, Customers, Sales Orders)

**Use when:**
- If you are new to mcp server then it is best option to get started
- You want a quick, ready-to-use solution
- You need the standard BC entities (items, customers, sales orders)
- You prefer a tested, stable configuration

**Key Features:**
- Pre-built MCP server with common BC operations
- Template-based configuration
- Automated Python environment setup
- Claude Desktop integration

**Setup:** Run `setup-bc-mcp.ps1` and provide your BC credentials.

### 2. Dynamic MCP Generator (`Dynamic-MCP-Generator-for-BC/`)

**What it does:** Connects to your Business Central environment, discovers available entities dynamically, and generates a custom MCP server based on your selections.

**Use when:**
- You have specific BC entities you want to work with
- Your BC environment has custom entities
- You want full control over which operations are available
- You need different entity combinations for different projects

**Key Features:**
- Reads your BC metadata to discover all available entities
- Interactive selection of entities by category
- Generates custom MCP server with only selected entities
- Supports both standard and custom BC entities
- Dynamic CRUD capability detection

**Setup:** Run `setup-bc-mcp-dynamic-fixed.ps1` for guided entity discovery and selection.

## Quick Comparison

| Feature | Instant Server | Dynamic Generator |
|---------|----------------|-------------------|
| Setup Time | 5 minutes | 10-15 minutes |
| Entity Selection | Fixed (3 entities) | Flexible (20+ entities) |
| Custom Entities | No | Yes |
| Complexity | Simple | Moderate |
| Use Case | Standard BC integration | Custom BC solutions |

## Prerequisites (Both Solutions)

**System Requirements:**
- Windows 10/11 with PowerShell
- Internet connection
- Python 3.8+ (auto-installed if missing)

**Business Central Requirements:**
- BC SaaS or On-Premises access
- Azure AD App Registration
- API permissions configured
- Company ID and tenant details

**Claude Desktop:**
- Download from https://claude.ai/download

## Installation Location

Both solutions install to: `C:\Users\[Username]\BusinessCentralMCP\` by default

Custom path: Add `-InstallPath "C:\YourPath"` parameter

## After Installation

Both solutions create:
- Python MCP server file
- BC configuration file
- Claude Desktop configuration template
- Python virtual environment with dependencies

**Final step:** Copy the generated Claude Desktop config to `%APPDATA%\Claude\claude_desktop_config.json` and restart Claude Desktop.

## Choose Your Solution

- **New to MCP and BC integration?** Start with **Instant MCP Server**
- **Need specific entities?** Use **Dynamic MCP Generator**
- **Custom BC environment?** Use **Dynamic MCP Generator**
- **Quick prototype?** Use **Instant MCP Server**

Both solutions provide the same end result: natural language access to your Business Central data through Claude Desktop.
