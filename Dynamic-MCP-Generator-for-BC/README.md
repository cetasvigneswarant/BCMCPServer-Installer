# Dynamic Business Central MCP Generator

A PowerShell-based tool that automatically generates custom MCP (Model Context Protocol) servers for Microsoft Dynamics 365 Business Central, enabling natural language interactions with your Business Central data through Claude Desktop.

## What This Tool Does

This generator transforms Business Central integration from manual coding to automated customization:

- **Discovers** your Business Central environment automatically
- **Lists** all available entities with their capabilities (Create, Read, Update, Delete)
- **Lets you select** which entities you want to interact with
- **Generates** a complete MCP server with tools for your selected entities
- **Installs** all prerequisites and configures Claude Desktop integration

## Key Benefits

**Dynamic Discovery**: Instead of hardcoding specific entities, the tool reads your actual Business Central metadata to discover what's available in your environment.

**Custom Selection**: Choose only the entities you need - from basic items and customers to complex sales orders and financial data.

**Complete Automation**: Handles Python installation, virtual environments, dependencies, and Claude Desktop configuration.

**Natural Language Interface**: Once configured, interact with your Business Central data using plain English queries in Claude Desktop.

## Prerequisites

**System Requirements:**
- Windows 10/11 with PowerShell 5.1+
- Internet connection for downloads
- Administrative access for Python installation (if needed)

**Business Central Requirements:**
- Microsoft Dynamics 365 Business Central (SaaS or On-Premises)
- Azure AD App Registration with API permissions
- Business Central API access enabled

**Azure AD App Setup:**
1. Create an App Registration in Azure Portal
2. Generate a Client Secret
3. Grant permissions: `Dynamics 365 Business Central.FullAccess`
4. Note your Tenant ID, Client ID, and Client Secret

## Installation & Setup

### Quick Start

1. **Download the script** to your desired location
2. **Open PowerShell as Administrator**
3. **Run the generator:**

```powershell
.\setup-bc-mcp-dynamic.ps1
```

### Step-by-Step Process

The script will guide you through five phases:

**Phase 1: Business Central Configuration**
You'll be prompted for:
- Metadata URL (e.g., `https://api.businesscentral.dynamics.com/v2.0/{tenant}/{environment}/api/v2.0/$metadata`)
- Client ID (from Azure AD App Registration)
- Client Secret (from Azure AD App Registration)
- Company ID (from your BC environment)

**Phase 2: Metadata Discovery**
The tool authenticates with Business Central and fetches your environment's metadata to discover available entities.

**Phase 3: Entity Selection**
Choose from discovered entities organized by category:

```
Available Business Central Entities:

  1. companies - Company information (Read)
  2. items - Product/inventory management (Create, Read, Update, Delete)
  3. customers - Customer management (Create, Read, Update, Delete)
  4. vendors - Vendor/supplier management (Create, Read, Update, Delete)
  5. salesOrders - Sales order processing (Create, Read, Update, Delete)
  6. salesInvoices - Sales invoice management (Create, Read, Update, Delete)
  7. generalLedgerEntries - General ledger entries (Read)
  8. employees - Employee management (Create, Read, Update, Delete)
  ...

Select entities (e.g., 1|2|3|5): 2|3|5|6
```

**Phase 4: MCP Server Generation**
Creates your custom MCP server with tools for selected entities only.

**Phase 5: System Installation**
- Creates Python virtual environment
- Installs required packages (mcp, fastmcp, requests)
- Generates Claude Desktop configuration

### Installation Location

**Default Path:** `C:\Users\[Username]\BusinessCentralMCP\`

**Custom Path:**
```powershell
.\setup-bc-mcp-dynamic-fixed.ps1 -InstallPath "C:\MyCustomPath"
```

## Generated Files

After successful setup, you'll have:

```
BusinessCentralMCP/
├── dynamic_bc_mcp_server.py          # Your custom MCP server
├── config.py                         # Business Central credentials
├── claude_desktop_config.json        # Claude Desktop configuration
└── venv/                             # Python virtual environment
    ├── Scripts/python.exe
    └── Lib/ (mcp, fastmcp, requests packages)
```

## Claude Desktop Integration

### Final Setup Steps

1. **Install Claude Desktop** (if not already installed):
   - Download from: https://claude.ai/download

2. **Configure Claude Desktop:**
   - Copy content from `claude_desktop_config.json`
   - Paste into: `%APPDATA%\Claude\claude_desktop_config.json`

3. **Restart Claude Desktop** completely

### Verify Integration

Your MCP server should appear as "business-central-dynamic" in Claude Desktop. You can now use natural language queries like:

- "Show me all customers"
- "Get items where price is greater than $100"
- "Create a new customer named 'Acme Corp'"
- "List all open sales orders"

## Usage Examples

### Basic Queries
```
"Show me all items"
"Get customer information for Contoso"
"List all vendors in California"
```

### Filtered Queries
```
"Show customers where city equals 'Seattle'"
"Get items with inventory less than 10 units"
"Find sales orders created after January 1st, 2024"
```

### Create Operations
```
"Create a new customer with name 'New Company' and city 'Boston'"
"Add a new item called 'Widget Pro' with price $29.99"
"Create a sales order for customer number '10000'"
```
## Available Entity Categories

**Core Business:**
- companies, items, customers, vendors, contacts, projects

**Sales & Marketing:**
- salesOrders, salesInvoices, salesQuotes, opportunities

**Purchasing:**
- purchaseOrders, purchaseInvoices

**Finance & Accounting:**
- generalLedgerEntries, itemLedgerEntries, customerPayments, vendorPayments

**Human Resources:**
- employees, timeRegistrationEntries

**Setup & Configuration:**
- currencies, paymentTerms, paymentMethods, locations, itemCategories

## Troubleshooting

### Common Issues

**Authentication Errors:**
```
Error: "Failed to get access token"
```
**Solutions:**
- Verify Client ID and Secret are correct
- Check Azure AD app permissions
- Ensure tenant ID matches your BC environment

**Python Not Found:**
```
Error: "Python not found"
```
**Solutions:**
- Install Python 3.8+ from python.org
- Ensure Python is added to PATH during installation
- Restart PowerShell after Python installation

**Claude Desktop JSON Error:**
```
Error: "not valid JSON"
```
**Solutions:**
- Ensure the JSON file is UTF-8 encoded without BOM
- Verify no extra characters in the configuration file
- Use the PowerShell method to recreate the config file

**MCP Server Not Loading:**
```
"Server disconnected" in Claude Desktop
```
**Solutions:**
- Check that all file paths are correct in the configuration
- Verify Python virtual environment has required packages
- Test the Python server manually from command line

## Security Considerations

**Credential Management:**
- Store the `config.py` file securely
- Never commit credentials to version control
- Regularly rotate client secrets
- Use least-privilege permissions

**Network Security:**
- Ensure HTTPS connections to Business Central
- Monitor API access logs
- Consider network restrictions for production use

## Customization

### Adding Custom Entities

Edit `dynamic_bc_mcp_server.py` to add support for custom Business Central entities not included in the standard list.
Additionally you can Rename the Standard mcp server and create using custom metadata endpoint.

### Extending Functionality

The generated server can be enhanced with:
- Custom business logic
- Advanced OData queries
- Batch operations
- Real-time notifications

### Multiple Environments

Run the generator multiple times for different BC environments:

```powershell
# Production
.\setup-bc-mcp-dynamic.ps1 -InstallPath "C:\BC-Production"

# Sandbox
.\setup-bc-mcp-dynamic.ps1 -InstallPath "C:\BC-Sandbox"
```

## Support

### Getting Help

1. Check this documentation
2. Verify Azure AD app configuration
3. Test Business Central API access directly
4. Review Claude Desktop MCP documentation
5. Contact Cetas for the Help and Question...

## License

This project is provided as-is under the MIT License. Users are responsible for ensuring compliance with their Business Central licensing and security requirements.

---

**Version:** 1.0  
**Last Updated:** September 2024  
**Compatibility:** Business Central SaaS & On-Premises, Claude Desktop
