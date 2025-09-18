# Get started with MCP Server for Business Central

A Model Context Protocol (MCP) server that integrates Microsoft Dynamics 365 Business Central with Claude Desktop, enabling natural language interactions with your Business Central data.

## Features

### Supported Operations

**Items Management**
- Get items with OData filtering and field expansion
- Get specific item by item number
- Create new items
- Get all items

**Customers Management**
- Get customers with OData filtering and expansion
- Get specific customer by display name
- Create new customers
- Get all customers

**Sales Orders Management**
- Get sales orders with filtering (can expand lines and customer info)
- Get specific sales order by number
- Create new sales orders
- Get all sales orders

**Sales Order Lines Management**
- Get lines for specific orders
- Add lines to existing orders
- Create complete orders with multiple lines in one operation

### Key Capabilities

- **Dynamic OData Filtering**: Use complex filter expressions for precise data queries
- **Field Expansion**: Include related data (customer info, order lines, etc.)
- **Batch Operations**: Create sales orders with multiple lines in a single operation
- **Error Handling**: Comprehensive validation and meaningful error messages
- **OAuth 2.0 Authentication**: Secure authentication with Business Central

## Prerequisites

### System Requirements

- **Operating System**: Windows 10/11
- **Python**: 3.8 or higher (automatically installed by script)
- **Claude Desktop**: Latest version
- **Business Central**: Access to Microsoft Dynamics 365 Business Central with API permissions

### Business Central Requirements

- Valid Business Central tenant with API access
- Azure AD application registration with appropriate permissions
- Client ID, Client Secret, and Tenant ID
- Company ID from your Business Central environment

### Required Permissions

Your Azure AD application needs these permissions:
- `Dynamics 365 Business Central.FullAccess` or specific API permissions
- `User.Read` (if using delegated permissions)

## Installation

### Option 1: Automated Installation (Recommended)

1. **Download the setup script** from the repository
2. **Open PowerShell as Administrator**
3. **Run the installation script**:

```powershell
# For public repository
.\setup-bc-mcp.ps1 -GitHubToken "dummy" -RepoOwner "yourusername" -RepoName "your-repo-name" -UsePublicRepo

# For private repository  
.\setup-bc-mcp.ps1 -GitHubToken "your_github_token" -RepoOwner "yourusername" -RepoName "your-repo-name"

# Skip Claude Desktop installation if already installed
.\setup-bc-mcp.ps1 -GitHubToken "your_token" -RepoOwner "username" -RepoName "repo" -SkipClaudeInstall
```

4. **Follow the prompts** for Claude Desktop installation
5. **Configure your credentials** (see Configuration section)

### Option 2: Manual Installation

#### Step 1: Install Prerequisites

1. **Install Python 3.8+**:
   - Download from [python.org](https://www.python.org/downloads/)
   - Ensure "Add to PATH" is checked during installation

2. **Install Claude Desktop**:
   - Download from [claude.ai/download](https://claude.ai/download)
   - Install using the downloaded installer

#### Step 2: Setup MCP Server

1. **Create project directory**:
```powershell
mkdir C:\BusinessCentralMCP
cd C:\BusinessCentralMCP
```

2. **Download the files**:
   - Download `mcp_bc_server.py` and `config.py` from the repository
   - Place them in your project directory

3. **Create virtual environment**:
```powershell
python -m venv venv
venv\Scripts\activate
```

4. **Install dependencies**:
```powershell
pip install mcp fastmcp requests
```

#### Step 3: Configure Claude Desktop

1. **Locate Claude Desktop config file**:
   - Path: `%APPDATA%\Claude\claude_desktop_config.json`
   - Create the directory if it doesn't exist

2. **Add MCP server configuration**:
```json
{
  "mcpServers": {
    "business-central": {
      "command": "C:/BusinessCentralMCP/venv/Scripts/python.exe",
      "args": ["C:/BusinessCentralMCP/mcp_bc_server.py"],
      "env": {
        "PYTHONPATH": "C:/BusinessCentralMCP"
      }
    }
  }
}
```

## Configuration

### Business Central Credentials

Edit the `config.py` file with your Business Central details:

```python
# Your Business Central tenant information
BC_TENANT_ID = "your-tenant-id-here"
BC_BASE_URL = "https://api.businesscentral.dynamics.com/v2.0/your-tenant-id/environment-name"
BC_CLIENT_ID = "your-client-id-here"
BC_CLIENT_SECRET = "your-client-secret-here"
BC_SCOPE = "https://api.businesscentral.dynamics.com/.default"
BC_COMPANY_ID = "your-company-id-here"
```

### Finding Your Business Central Information

#### Tenant ID
- Found in Azure Portal → Azure Active Directory → Properties
- Also visible in your Business Central URL

#### Company ID
- In Business Central, go to Companies page
- The ID is visible in the browser URL or use the API endpoint:
  `GET /api/v2.0/companies`

#### Client ID & Secret
- Created in Azure Portal → App Registrations
- Generate new client secret in "Certificates & secrets"

#### Base URL Format
```
https://api.businesscentral.dynamics.com/v2.0/{tenant-id}/{environment-name}
```
Common environment names: `Production`, `Sandbox`, or custom names

### Authentication Setup

1. **Create Azure AD App Registration**:
   - Go to Azure Portal → App Registrations → New registration
   - Note the Application (client) ID

2. **Generate Client Secret**:
   - In your app registration → Certificates & secrets → New client secret
   - Copy the secret value immediately

3. **Configure API Permissions**:
   - Add `Dynamics 365 Business Central` permissions
   - Grant admin consent for the permissions

## Usage Examples

### Basic Queries

Once configured, you can ask Claude Desktop:

```
"Show me all customers"
"Get items where the price is greater than $100"
"Find customer named 'Contoso'"
"Show sales orders from last month"
```

### Advanced Queries

```
"Create a new customer named 'Acme Corp' with address '123 Main St, New York'"
"Add a new item called 'Widget Pro' with price $29.99"
"Create a sales order for customer 'Contoso' with 5 units of item '1000'"
"Show sales orders with their line items expanded"
```

### OData Filtering Examples

```
"Get customers where city equals 'Seattle'"
"Show items where inventory is less than 10"
"Find sales orders where total amount is greater than $1000"
"Get customers created after January 1st, 2024"
```

## Troubleshooting

### Common Issues

#### Authentication Errors
- **Error**: "Could not authenticate with Business Central"
- **Solution**: 
  - Verify your client ID and secret in `config.py`
  - Ensure the Azure AD app has proper permissions
  - Check that the tenant ID is correct

#### Claude Desktop Not Detecting MCP Server
- **Error**: MCP tools not available in Claude Desktop
- **Solution**:
  - Verify the config file path: `%APPDATA%\Claude\claude_desktop_config.json`
  - Check that all paths in the config use forward slashes
  - Restart Claude Desktop completely
  - Verify Python and dependencies are installed in the virtual environment

#### Import Errors
- **Error**: "ModuleNotFoundError" when starting the server
- **Solution**:
  - Ensure virtual environment is created: `python -m venv venv`
  - Install dependencies: `pip install mcp fastmcp requests`
  - Verify PYTHONPATH in Claude Desktop config

#### API Permission Errors
- **Error**: "Insufficient privileges" or "Access denied"
- **Solution**:
  - Check Azure AD app permissions
  - Ensure admin consent is granted
  - Verify the scope in `config.py` matches your API permissions

### Debugging Steps

1. **Test Python Installation**:
```powershell
python --version
```

2. **Test Virtual Environment**:
```powershell
C:\BusinessCentralMCP\venv\Scripts\python.exe -c "import mcp; print('MCP installed successfully')"
```

3. **Test Business Central Connection**:
```powershell
# Run a simple test to verify authentication
C:\BusinessCentralMCP\venv\Scripts\python.exe -c "from config import *; print('Config loaded successfully')"
```

4. **Check Claude Desktop Logs**:
   - Look for MCP server connection status in Claude Desktop settings
   - Check for error messages in the Claude Desktop interface

## API Reference

### Available Tools

#### Items
- `get_items_with_filter(filter_expression, expand_fields)`
- `get_item_by_number(item_number)`
- `create_item(item_data)`
- `get_all_items()`

#### Customers  
- `get_customers_with_filter(filter_expression, expand_fields)`
- `get_customer_by_display_name(display_name)`
- `create_customer(customer_data)`
- `get_all_customers()`

#### Sales Orders
- `get_sales_orders_with_filter(filter_expression, expand_lines, expand_customer)`
- `get_sales_order_by_number(order_number, expand_lines)`
- `create_sales_order(order_data)`
- `get_all_sales_orders()`

#### Sales Order Lines
- `get_sales_order_lines(order_id, filter_expression)`
- `create_sales_order_line(order_id, line_data)`
- `create_sales_order_with_lines(order_data, lines_data)`

### Data Formats

#### Item Creation
```json
{
  "displayName": "Widget Pro",
  "description": "Professional widget",
  "type": "Inventory",
  "baseUnitOfMeasureCode": "PCS",
  "unitPrice": 29.99
}
```

#### Customer Creation
```json
{
  "displayName": "Acme Corp",
  "addressLine1": "123 Business Ave",
  "city": "New York",
  "postalCode": "10001",
  "email": "orders@acme.com"
}
```

#### Sales Order Creation
```json
{
  "customerNumber": "10000",
  "orderDate": "2024-01-15"
}
```

## Security Considerations

- **Never commit `config.py` with real credentials to version control**
- **Use environment variables for production deployments**
- **Regularly rotate client secrets**
- **Follow principle of least privilege for API permissions**
- **Monitor API usage and access logs**
- **Mask sensitive Data in API for usage **

## Support and Contributing

### Getting Help

1. **Check the troubleshooting section** above
2. **Review Business Central API documentation**
3. **Verify Azure AD app configuration**
4. **Test with Business Central API directly** using tools like Postman
5. for more help contact Cetas ...

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Changelog

### Version 1.0.0
- Initial release with Items, Customers, and Sales Orders support
- Full CRUD operations for supported entities
- OData filtering and field expansion
- Automated installation script
- Comprehensive error handling and validation
