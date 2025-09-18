# Dynamic Business Central MCP Generator - Standalone Version

param(
    [Parameter(Mandatory=$false)]
    [string]$InstallPath = "$env:USERPROFILE\BusinessCentralMCP",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipClaudeInstall
)

# Colors for output
$colors = @{
    Success = "Green"
    Warning = "Yellow" 
    Error = "Red"
    Info = "Cyan"
    Progress = "Magenta"
    White = "White"
}

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    
    # Use the color if it exists in our hashtable, otherwise default to White
    if ($colors.ContainsKey($Color)) {
        Write-Host $Message -ForegroundColor $colors[$Color]
    } else {
        Write-Host $Message -ForegroundColor White
    }
}

function Test-CommandExists {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Get-BCCredentials {
    Write-ColorOutput "=== Business Central Configuration ===" -Color "Progress"
    Write-ColorOutput "Please provide your Business Central API details:" -Color "Info"
    
    $bcConfig = @{}
    
    # Get metadata URL
    Write-ColorOutput "Enter your BC Metadata URL:" -Color "Info"
    Write-ColorOutput "Example: https://api.businesscentral.dynamics.com/v2.0/{tenant}/{environment}/api/v2.0/`$metadata" -Color "Info"
    $bcConfig.MetadataUrl = Read-Host "Metadata URL"
    
    # Extract tenant and environment from URL if possible
    if ($bcConfig.MetadataUrl -match "businesscentral\.dynamics\.com/v2\.0/([^/]+)/([^/]+)") {
        $bcConfig.TenantId = $matches[1]
        $bcConfig.Environment = $matches[2]
        $bcConfig.BaseUrl = "https://api.businesscentral.dynamics.com/v2.0/$($bcConfig.TenantId)/$($bcConfig.Environment)"
        Write-ColorOutput "Detected Tenant: $($bcConfig.TenantId)" -Color "Success"
        Write-ColorOutput "Detected Environment: $($bcConfig.Environment)" -Color "Success"
    } else {
        Write-ColorOutput "Could not auto-detect tenant/environment from URL" -Color "Warning"
        $bcConfig.TenantId = Read-Host "Enter Tenant ID"
        $bcConfig.Environment = Read-Host "Enter Environment Name"  
        $bcConfig.BaseUrl = Read-Host "Enter Base API URL"
    }
    
    # Get authentication details
    $bcConfig.ClientId = Read-Host "Enter Client ID"
    $bcConfig.ClientSecret = Read-Host "Enter Client Secret" -AsSecureString
    $bcConfig.ClientSecretPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($bcConfig.ClientSecret))
    $bcConfig.Scope = "https://api.businesscentral.dynamics.com/.default"
    
    # Get company ID
    Write-ColorOutput "You can get the Company ID from the BC API or enter it manually" -Color "Info"
    $bcConfig.CompanyId = Read-Host "Enter Company ID"
    
    return $bcConfig
}

function Get-BCAccessToken {
    param([hashtable]$Config)
    
    $tokenUrl = "https://login.microsoftonline.com/$($Config.TenantId)/oauth2/v2.0/token"
    
    $body = @{
        grant_type = "client_credentials"
        client_id = $Config.ClientId
        client_secret = $Config.ClientSecretPlain
        scope = $Config.Scope
    }
    
    try {
        Write-ColorOutput "Authenticating with Microsoft Identity Platform..." -Color "Info"
        $response = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"
        
        return @{
            Success = $true
            Token = $response.access_token
        }
        
    } catch {
        return @{
            Success = $false
            Error = "Authentication failed: $($_.Exception.Message)"
        }
    }
}

function Get-BCMetadata {
    param([hashtable]$Config)
    
    Write-ColorOutput "Fetching metadata from: $($Config.MetadataUrl)" -Color "Info"
    
    # First, get an access token
    $tokenResult = Get-BCAccessToken -Config $Config
    if (-not $tokenResult.Success) {
        return @{
            Success = $false
            Error = "Failed to get access token: $($tokenResult.Error)"
        }
    }
    
    try {
        $headers = @{
            "Authorization" = "Bearer $($tokenResult.Token)"
            "Accept" = "application/xml"
        }
        
        Write-ColorOutput "Requesting metadata with authentication..." -Color "Info"
        $response = Invoke-RestMethod -Uri $Config.MetadataUrl -Headers $headers -Method Get
        
        return @{
            Success = $true
            Metadata = $response
        }
        
    } catch {
        return @{
            Success = $false
            Error = "Failed to fetch metadata: $($_.Exception.Message)"
        }
    }
}

function Get-KnownEntities {
    # Return the predefined entities from BC metadata analysis
    return @(
        @{ Name = "companies"; Insertable = $false; Updatable = $false; Deletable = $false; Description = "Company information (read-only)" },
        @{ Name = "items"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Product/inventory management" },
        @{ Name = "customers"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Customer management" },
        @{ Name = "vendors"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Vendor/supplier management" },
        @{ Name = "salesOrders"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Sales order processing" },
        @{ Name = "salesOrderLines"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Sales order line items" },
        @{ Name = "salesInvoices"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Sales invoice management" },
        @{ Name = "salesInvoiceLines"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Sales invoice line items" },
        @{ Name = "salesQuotes"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Sales quotation management" },
        @{ Name = "purchaseOrders"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Purchase order processing" },
        @{ Name = "purchaseInvoices"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Purchase invoice management" },
        @{ Name = "generalLedgerEntries"; Insertable = $false; Updatable = $false; Deletable = $false; Description = "General ledger entries (read-only)" },
        @{ Name = "itemLedgerEntries"; Insertable = $false; Updatable = $false; Deletable = $false; Description = "Item ledger entries (read-only)" },
        @{ Name = "employees"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Employee management" },
        @{ Name = "projects"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Project management" },
        @{ Name = "currencies"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Currency management" },
        @{ Name = "paymentTerms"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Payment terms setup" },
        @{ Name = "paymentMethods"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Payment methods setup" },
        @{ Name = "locations"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Warehouse/location management" },
        @{ Name = "contacts"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Contact management" },
        @{ Name = "bankAccounts"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Bank account management" }
    )
}

function Show-EntitySelection {
    param([array]$Entities)
    
    Write-ColorOutput "" -Color "White"
    Write-ColorOutput "Available Business Central Entities:" -Color "Progress"
    Write-ColorOutput "" -Color "White"
    
    $index = 1
    $entityMap = @{}
    
    foreach ($entity in $Entities) {
        $crud = @()
        if ($entity.Insertable) { $crud += "Create" }
        $crud += "Read"
        if ($entity.Updatable) { $crud += "Update" }
        if ($entity.Deletable) { $crud += "Delete" }
        $crudInfo = "($($crud -join ', '))"
        
        Write-ColorOutput "  $index. $($entity.Name) - $($entity.Description) $crudInfo" -Color "White"
        $entityMap[$index] = $entity
        $index++
    }
    
    Write-ColorOutput "" -Color "White"
    Write-ColorOutput "Select entities to include in your MCP server:" -Color "Progress"
    Write-ColorOutput "Enter numbers separated by | (e.g., 1|3|5|8) or 'all' for all entities:" -Color "Info"
    
    $selection = Read-Host
    
    if ($selection.ToLower() -eq 'all') {
        Write-ColorOutput "Selected all entities" -Color "Success"
        return $Entities
    }
    
    $selectedNumbers = $selection -split '\|' | ForEach-Object { $_.Trim() }
    $selectedEntities = @()
    
    foreach ($num in $selectedNumbers) {
        if ($entityMap.ContainsKey([int]$num)) {
            $selectedEntities += $entityMap[[int]$num]
        } else {
            Write-ColorOutput "Warning: Invalid selection '$num' ignored" -Color "Warning"
        }
    }
    
    if ($selectedEntities.Count -gt 0) {
        Write-ColorOutput "Selected entities:" -Color "Success"
        foreach ($entity in $selectedEntities) {
            Write-ColorOutput "  - $($entity.Name)" -Color "Success"
        }
    }
    
    return $selectedEntities
}

function Generate-MCPServer {
    param(
        [hashtable]$Config,
        [array]$Entities,
        [string]$OutputPath
    )
    
    Write-ColorOutput "Generating MCP server for $($Entities.Count) entities..." -Color "Progress"
    
    # Generate the server code
    $serverContent = Generate-ServerTemplate -Config $Config -Entities $Entities
    $serverPath = Join-Path $OutputPath "dynamic_bc_mcp_server.py"
    
    # Generate config file
    $configContent = Generate-ConfigFile -Config $Config
    $configPath = Join-Path $OutputPath "config.py"
    
    # Generate Claude config
    $claudeContent = Generate-ClaudeConfig -OutputPath $OutputPath
    $claudePath = Join-Path $OutputPath "claude_desktop_config.json"
    
    try {
        Set-Content -Path $serverPath -Value $serverContent -Encoding UTF8
        Set-Content -Path $configPath -Value $configContent -Encoding UTF8
        Set-Content -Path $claudePath -Value $claudeContent -Encoding UTF8
        
        Write-ColorOutput "Generated files:" -Color "Success"
        Write-ColorOutput "  - $serverPath" -Color "Info"
        Write-ColorOutput "  - $configPath" -Color "Info"
        Write-ColorOutput "  - $claudePath" -Color "Info"
        
        return @{ Success = $true }
        
    } catch {
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Generate-ServerTemplate {
    param([hashtable]$Config, [array]$Entities)
    
    $entityTools = ""
    
    foreach ($entity in $Entities) {
        $entityName = $entity.Name
        $entitySingle = $entityName.TrimEnd('s')
        $description = $entity.Description
        
        # Add GET tools
        $entityTools += @"

@server.tool()
def get_${entityName}_with_filter(filter_expression: str = None, expand_fields: str = None) -> list:
    '''
    Fetches $entityName from Business Central with optional filtering and expansion.
    
    Args:
        filter_expression: Optional OData filter expression
        expand_fields: Optional fields to expand
    
    Returns:
        List of $entityName or error message
    '''
    api_endpoint = f"/api/v2.0/companies({BC_COMPANY_ID})/$entityName"
    params = {}
    if filter_expression:
        params["`$filter"] = filter_expression
    if expand_fields:
        params["`$expand"] = expand_fields
        
    response = _make_bc_api_call(api_endpoint, params=params)
    return response.get("value", []) if "error" not in response else response

@server.tool()
def get_all_${entityName}() -> list:
    '''Fetches all $entityName without filters'''
    return get_${entityName}_with_filter()
"@
        
        # Add CREATE tool if insertable
        if ($entity.Insertable) {
            $entityTools += @"

@server.tool()
def create_${entitySingle}(${entitySingle}_data: dict) -> dict:
    '''Creates a new $entitySingle'''
    api_endpoint = f"/api/v2.0/companies({BC_COMPANY_ID})/$entityName"
    return _make_bc_api_call(api_endpoint, method="POST", data=${entitySingle}_data)
"@
        }
        
        # Add UPDATE tool if updatable  
        if ($entity.Updatable) {
            $entityTools += @"

@server.tool()
def update_${entitySingle}(${entitySingle}_id: str, ${entitySingle}_data: dict) -> dict:
    '''Updates an existing $entitySingle'''
    api_endpoint = f"/api/v2.0/companies({BC_COMPANY_ID})/$entityName({${entitySingle}_id})"
    return _make_bc_api_call(api_endpoint, method="PATCH", data=${entitySingle}_data)
"@
        }
        
        # Add DELETE tool if deletable
        if ($entity.Deletable) {
            $entityTools += @"

@server.tool()
def delete_${entitySingle}(${entitySingle}_id: str) -> dict:
    '''Deletes a $entitySingle'''
    api_endpoint = f"/api/v2.0/companies({BC_COMPANY_ID})/$entityName({${entitySingle}_id})"
    response = _make_bc_api_call(api_endpoint, method="DELETE")
    return {"message": f"$entitySingle deleted successfully"} if "error" not in response else response
"@
        }
    }
    
    $entityList = ($Entities | ForEach-Object { $_.Name }) -join ', '
    
    return @"
# dynamic_bc_mcp_server.py
# Generated MCP server for Business Central entities: $entityList

import requests
import json
from mcp.server.fastmcp import FastMCP

# Import configuration
from config import BC_BASE_URL, BC_CLIENT_ID, BC_CLIENT_SECRET, BC_SCOPE, BC_COMPANY_ID, BC_TENANT_ID

# Global access token
bc_access_token = None

def get_bc_access_token():
    global bc_access_token
    token_url = f"https://login.microsoftonline.com/{BC_TENANT_ID}/oauth2/v2.0/token"
    
    payload = {
        "grant_type": "client_credentials",
        "client_id": BC_CLIENT_ID,
        "client_secret": BC_CLIENT_SECRET,
        "scope": BC_SCOPE
    }

    try:
        response = requests.post(token_url, data=payload)
        response.raise_for_status()
        bc_access_token = response.json()["access_token"]
        print("Successfully fetched access token")
        return True
    except Exception as e:
        print(f"Error fetching access token: {e}")
        return False

# Create MCP server
server = FastMCP(name="DynamicBusinessCentralServer")

def _make_bc_api_call(api_endpoint: str, method: str = "GET", params: dict = None, data: dict = None):
    global bc_access_token
    
    if not bc_access_token:
        return {"error": "No access token available"}

    url = f"{BC_BASE_URL}{api_endpoint}"
    headers = {
        "Authorization": f"Bearer {bc_access_token}",
        "Content-Type": "application/json"
    }
    
    try:
        if method == "GET":
            response = requests.get(url, headers=headers, params=params)
        elif method == "POST":
            response = requests.post(url, headers=headers, json=data)
        elif method == "PATCH":
            response = requests.patch(url, headers=headers, json=data)
        elif method == "DELETE":
            response = requests.delete(url, headers=headers)
        else:
            return {"error": f"Unsupported method: {method}"}
            
        response.raise_for_status()
        
        try:
            return response.json()
        except:
            return {"message": "Operation completed", "status_code": response.status_code}
            
    except Exception as e:
        return {"error": f"API call failed: {e}"}

# Generated MCP Tools
$entityTools

if __name__ == "__main__":
    print("Starting Dynamic Business Central MCP Server...")
    print(f"Supporting entities: $entityList")
    
    if get_bc_access_token():
        server.run()
    else:
        print("Failed to authenticate with Business Central")
"@
}

function Generate-ConfigFile {
    param([hashtable]$Config)
    
    return @"
# config.py
# Generated Business Central Configuration

BC_TENANT_ID = "$($Config.TenantId)"
BC_BASE_URL = "$($Config.BaseUrl)"
BC_CLIENT_ID = "$($Config.ClientId)"
BC_CLIENT_SECRET = "$($Config.ClientSecretPlain)"
BC_SCOPE = "$($Config.Scope)"
BC_COMPANY_ID = "$($Config.CompanyId)"
"@
}

function Generate-ClaudeConfig {
    param([string]$OutputPath)
    
    $venvPython = Join-Path $OutputPath "venv\Scripts\python.exe" 
    $serverScript = Join-Path $OutputPath "dynamic_bc_mcp_server.py"
    
    $venvPython = $venvPython -replace '\\', '/'
    $serverScript = $serverScript -replace '\\', '/'
    $outputPath = $OutputPath -replace '\\', '/'
    
    $config = @{
        mcpServers = @{
            "business-central-dynamic" = @{
                command = $venvPython
                args = @($serverScript)
                env = @{ PYTHONPATH = $outputPath }
            }
        }
    }
    
    return $config | ConvertTo-Json -Depth 10
}

function Install-Prerequisites {
    param([string]$InstallPath)
    
    Write-ColorOutput "Installing prerequisites..." -Color "Progress"
    
    # Check Python
    if (-not (Test-CommandExists "python")) {
        Write-ColorOutput "Python not found. Please install Python 3.8+ from https://python.org" -Color "Error"
        return $false
    }
    
    Write-ColorOutput "Python found: $(python --version)" -Color "Success"
    
    # Create virtual environment
    Write-ColorOutput "Creating virtual environment..." -Color "Info"
    Set-Location $InstallPath
    & python -m venv venv
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "Failed to create virtual environment" -Color "Error"
        return $false
    }
    
    # Install packages
    Write-ColorOutput "Installing Python packages..." -Color "Info"
    $venvPip = Join-Path $InstallPath "venv\Scripts\pip.exe"
    
    & $venvPip install mcp fastmcp requests --quiet
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "Prerequisites installed successfully" -Color "Success"
        return $true
    } else {
        Write-ColorOutput "Failed to install packages" -Color "Error"
        return $false
    }
}

function Main {
    Write-ColorOutput "=== Dynamic Business Central MCP Generator ===" -Color "Progress"
    Write-ColorOutput "This tool creates a custom MCP server for your BC environment" -Color "Info"
    Write-ColorOutput "" -Color "White"
    
    # Create installation directory
    Write-ColorOutput "Creating installation directory: $InstallPath" -Color "Info"
    if (-not (Test-Path $InstallPath)) {
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    }
    
    # Phase 1: Get BC Configuration  
    Write-ColorOutput "=== Phase 1: Business Central Configuration ===" -Color "Progress"
    $bcConfig = Get-BCCredentials
    
    # Phase 2: Test connection and get metadata
    Write-ColorOutput "=== Phase 2: Metadata Discovery ===" -Color "Progress"
    $metadataResult = Get-BCMetadata -Config $bcConfig
    if (-not $metadataResult.Success) {
        Write-ColorOutput "Failed to fetch metadata: $($metadataResult.Error)" -Color "Error"
        Write-ColorOutput "Please check your credentials and try again" -Color "Info"
        return
    }
    
    Write-ColorOutput "Successfully connected to Business Central!" -Color "Success"
    
    # Phase 3: Entity Selection
    Write-ColorOutput "=== Phase 3: Entity Selection ===" -Color "Progress"
    $entities = Get-KnownEntities
    $selectedEntities = Show-EntitySelection -Entities $entities
    
    if ($selectedEntities.Count -eq 0) {
        Write-ColorOutput "No entities selected. Exiting." -Color "Warning"
        return
    }
    
    # Phase 4: Generate MCP Server
    Write-ColorOutput "=== Phase 4: MCP Server Generation ===" -Color "Progress" 
    $genResult = Generate-MCPServer -Config $bcConfig -Entities $selectedEntities -OutputPath $InstallPath
    
    if (-not $genResult.Success) {
        Write-ColorOutput "Generation failed: $($genResult.Error)" -Color "Error"
        return
    }
    
    # Phase 5: Install Prerequisites
    Write-ColorOutput "=== Phase 5: System Installation ===" -Color "Progress"
    $installSuccess = Install-Prerequisites -InstallPath $InstallPath
    
    if (-not $installSuccess) {
        Write-ColorOutput "Installation failed. Please install prerequisites manually" -Color "Error"
        return
    }
    
    # Final Summary
    Write-ColorOutput "" -Color "White"
    Write-ColorOutput "=== Setup Complete ===" -Color "Success"
    Write-ColorOutput "" -Color "White"
    Write-ColorOutput "Your dynamic Business Central MCP server is ready!" -Color "Success"
    Write-ColorOutput "" -Color "White"
    Write-ColorOutput "Generated Files:" -Color "Info"
    Write-ColorOutput "  - $InstallPath\dynamic_bc_mcp_server.py" -Color "Info"
    Write-ColorOutput "  - $InstallPath\config.py" -Color "Info"
    Write-ColorOutput "  - $InstallPath\claude_desktop_config.json" -Color "Info"
    Write-ColorOutput "  - $InstallPath\venv\ (Python environment)" -Color "Info"
    Write-ColorOutput "" -Color "White"
    Write-ColorOutput "Selected Entities ($($selectedEntities.Count)):" -Color "Info"
    foreach ($entity in $selectedEntities) {
        Write-ColorOutput "  - $($entity.Name)" -Color "Info"
    }
    Write-ColorOutput "" -Color "White"
    Write-ColorOutput "Next Steps:" -Color "Warning"
    Write-ColorOutput "1. Copy the claude_desktop_config.json content to: `$env:APPDATA\Claude\claude_desktop_config.json" -Color "Warning"
    Write-ColorOutput "2. Restart Claude Desktop completely" -Color "Warning"  
    Write-ColorOutput "3. Test with queries like 'Show me all customers'" -Color "Warning"
    Write-ColorOutput "" -Color "White"
    Write-ColorOutput "Setup completed successfully!" -Color "Success"
}

# Run the main function
try {
    Main
} catch {
    Write-ColorOutput "Fatal error: $($_.Exception.Message)" -Color "Error"
    exit 1
}