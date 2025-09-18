# code-generator.ps1
# Code Generation Module for Dynamic MCP Server

function Generate-MCPServer {
    param(
        [hashtable]$Config,
        [array]$Entities,
        [string]$OutputPath
    )
    
    Write-ColorOutput "Generating dynamic MCP server..." -Color "Progress"
    
    try {
        # Download templates
        $templateResult = Download-Templates -OutputPath $OutputPath
        if (-not $templateResult.Success) {
            return @{ Success = $false; Error = $templateResult.Error }
        }
        
        # Generate the MCP server file
        $serverResult = Generate-ServerFile -Config $Config -Entities $Entities -OutputPath $OutputPath
        if (-not $serverResult.Success) {
            return @{ Success = $false; Error = $serverResult.Error }
        }
        
        # Generate the configuration file
        $configResult = Generate-ConfigFile -Config $Config -OutputPath $OutputPath
        if (-not $configResult.Success) {
            return @{ Success = $false; Error = $configResult.Error }
        }
        
        # Generate Claude Desktop configuration
        $claudeResult = Generate-ClaudeConfig -OutputPath $OutputPath
        if (-not $claudeResult.Success) {
            return @{ Success = $false; Error = $claudeResult.Error }
        }
        
        return @{ Success = $true }
        
    } catch {
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Download-Templates {
    param([string]$OutputPath)
    
    Write-ColorOutput "Creating MCP server templates..." -Color "Info"
    
    # Since we can't download from GitHub in this context, we'll create the templates directly
    $templates = @{
        "mcp_server_template.py" = Get-ServerTemplate
        "config_template.py" = Get-ConfigTemplate
        "claude_config_template.json" = Get-ClaudeConfigTemplate
    }
    
    try {
        foreach ($template in $templates.GetEnumerator()) {
            $filePath = Join-Path $OutputPath $template.Key
            Set-Content -Path $filePath -Value $template.Value -Encoding UTF8
            Write-ColorOutput "Created template: $($template.Key)" -Color "Info"
        }
        
        return @{ Success = $true }
    } catch {
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Generate-ServerFile {
    param(
        [hashtable]$Config,
        [array]$Entities,
        [string]$OutputPath
    )
    
    Write-ColorOutput "Generating MCP server code for $($Entities.Count) entities..." -Color "Info"
    
    # Load the template
    $templatePath = Join-Path $OutputPath "mcp_server_template.py"
    $template = Get-Content $templatePath -Raw
    
    # Generate entity tools
    $entityTools = Generate-EntityTools -Entities $Entities
    
    # Generate server registrations
    $serverRegistrations = Generate-ServerRegistrations -Entities $Entities
    
    # Generate entity list for comments
    $entityList = ($Entities | ForEach-Object { $_.Name }) -join ', '
    
    # Replace placeholders in template
    $generatedCode = $template -replace '{{GENERATED_COMMENT}}', "Generated for entities: $entityList"
    $generatedCode = $generatedCode -replace '{{ENTITY_TOOLS_PLACEHOLDER}}', $entityTools
    $generatedCode = $generatedCode -replace '{{SERVER_REGISTRATION_PLACEHOLDER}}', $serverRegistrations
    
    # Save the generated server file
    $outputFile = Join-Path $OutputPath "dynamic_bc_mcp_server.py"
    try {
        Set-Content -Path $outputFile -Value $generatedCode -Encoding UTF8
        Write-ColorOutput "Generated MCP server: $outputFile" -Color "Success"
        return @{ Success = $true }
    } catch {
        return @{ Success = $false; Error = "Failed to write server file: $($_.Exception.Message)" }
    }
}

function Generate-EntityTools {
    param([array]$Entities)
    
    $toolsCode = @()
    
    foreach ($entity in $Entities) {
        $entityName = $entity.Name
        $entitySingle = $entityName.TrimEnd('s')  # Simple singularization
        $description = $entity.Description
        
        # Generate GET tool (always available)
        $toolsCode += @"
@server.tool()
def get_${entityName}_with_filter(filter_expression: str = None, expand_fields: str = None) -> list:
    """"""
    Fetches $entityName from Business Central with optional OData filtering and expansion.
    
    Args:
        filter_expression: Optional OData filter expression as a string.
        expand_fields: Optional fields to expand (e.g., "relatedEntity1,relatedEntity2")
    
    Returns:
        A list of dictionaries representing the $entityName data or an error message.
    """"""
    api_endpoint = f"/api/v2.0/companies({BC_COMPANY_ID})/$entityName"
    params = {}
    if filter_expression:
        params["`$filter"] = filter_expression
    if expand_fields:
        params["`$expand"] = expand_fields
        
    response = _make_bc_api_call(api_endpoint, params=params)
    
    if "error" in response:
        return response

    return response.get("value", [])

@server.tool()
def get_all_${entityName}() -> list:
    """"""
    Fetches all $entityName without any filter.
    """"""
    return get_${entityName}_with_filter()
"@

        # Generate POST tool (if insertable)
        if ($entity.Insertable) {
            $toolsCode += @"

@server.tool()
def create_${entitySingle}(${entitySingle}_data: dict) -> dict:
    """"""
    Creates a new $entitySingle in Business Central.
    
    Args:
        ${entitySingle}_data: A dictionary containing the $entitySingle data.
    
    Returns:
        A dictionary representing the created $entitySingle or an error message.
    """"""
    api_endpoint = f"/api/v2.0/companies({BC_COMPANY_ID})/$entityName"
    
    response = _make_bc_api_call(api_endpoint, method="POST", data=${entitySingle}_data)
    
    return response
"@
        }
        
        # Generate PATCH tool (if updatable)
        if ($entity.Updatable) {
            $toolsCode += @"

@server.tool()
def update_${entitySingle}(${entitySingle}_id: str, ${entitySingle}_data: dict) -> dict:
    """"""
    Updates an existing $entitySingle in Business Central.
    
    Args:
        ${entitySingle}_id: The ID of the $entitySingle to update.
        ${entitySingle}_data: A dictionary containing the updated $entitySingle data.
    
    Returns:
        A dictionary representing the updated $entitySingle or an error message.
    """"""
    api_endpoint = f"/api/v2.0/companies({BC_COMPANY_ID})/$entityName({${entitySingle}_id})"
    
    response = _make_bc_api_call(api_endpoint, method="PATCH", data=${entitySingle}_data)
    
    return response
"@
        }
        
        # Generate DELETE tool (if deletable)
        if ($entity.Deletable) {
            $toolsCode += @"

@server.tool()
def delete_${entitySingle}(${entitySingle}_id: str) -> dict:
    """"""
    Deletes a $entitySingle from Business Central.
    
    Args:
        ${entitySingle}_id: The ID of the $entitySingle to delete.
    
    Returns:
        A confirmation message or an error message.
    """"""
    api_endpoint = f"/api/v2.0/companies({BC_COMPANY_ID})/$entityName({${entitySingle}_id})"
    
    response = _make_bc_api_call(api_endpoint, method="DELETE")
    
    if "error" in response:
        return response
        
    return {"message": f"$entitySingle with ID {${entitySingle}_id} deleted successfully"}
"@
        }
    }
    
    return $toolsCode -join "`n`n"
}

function Generate-ServerRegistrations {
    param([array]$Entities)
    
    # No explicit registration needed for FastMCP with @server.tool() decorator
    # Just return a comment about the generated tools
    
    $toolCount = 0
    foreach ($entity in $Entities) {
        $toolCount += 2  # get_all and get_with_filter
        if ($entity.Insertable) { $toolCount++ }
        if ($entity.Updatable) { $toolCount++ }
        if ($entity.Deletable) { $toolCount++ }
    }
    
    return "# Generated $toolCount tools for $($Entities.Count) entities"
}

function Generate-ConfigFile {
    param(
        [hashtable]$Config,
        [string]$OutputPath
    )
    
    Write-ColorOutput "Generating configuration file..." -Color "Info"
    
    $configContent = @"
# config.py
# Generated Business Central MCP Server Configuration

# Your Business Central tenant and environment details
BC_TENANT_ID = "$($Config.TenantId)"
BC_BASE_URL = "$($Config.BaseUrl)"
BC_CLIENT_ID = "$($Config.ClientId)"
BC_CLIENT_SECRET = "$($Config.ClientSecretPlain)"
BC_SCOPE = "$($Config.Scope)"

# Configure your Business Central Company ID here
BC_COMPANY_ID = "$($Config.CompanyId)"

# Metadata URL used for generation
BC_METADATA_URL = "$($Config.MetadataUrl)"
"@
    
    $configPath = Join-Path $OutputPath "config.py"
    try {
        Set-Content -Path $configPath -Value $configContent -Encoding UTF8
        Write-ColorOutput "Generated configuration: $configPath" -Color "Success"
        return @{ Success = $true }
    } catch {
        return @{ Success = $false; Error = "Failed to write config file: $($_.Exception.Message)" }
    }
}

function Generate-ClaudeConfig {
    param([string]$OutputPath)
    
    Write-ColorOutput "Generating Claude Desktop configuration..." -Color "Info"
    
    $venvPython = Join-Path $OutputPath "venv\Scripts\python.exe"
    $mcpServer = Join-Path $OutputPath "dynamic_bc_mcp_server.py"
    
    # Convert to forward slashes for JSON
    $venvPython = $venvPython -replace '\\', '/'
    $mcpServer = $mcpServer -replace '\\', '/'
    $outputPath = $OutputPath -replace '\\', '/'
    
    $claudeConfig = @{
        mcpServers = @{
            "business-central-dynamic" = @{
                command = $venvPython
                args = @($mcpServer)
                env = @{
                    PYTHONPATH = $outputPath
                }
            }
        }
    } | ConvertTo-Json -Depth 10
    
    $claudeConfigPath = Join-Path $OutputPath "claude_desktop_config.json"
    try {
        Set-Content -Path $claudeConfigPath -Value $claudeConfig -Encoding UTF8
        Write-ColorOutput "Generated Claude config: $claudeConfigPath" -Color "Success"
        return @{ Success = $true }
    } catch {
        return @{ Success = $false; Error = "Failed to write Claude config: $($_.Exception.Message)" }
    }
}

function Get-ServerTemplate {
    return @'
# dynamic_bc_mcp_server.py
# {{GENERATED_COMMENT}}

import os
import requests
import asyncio
import json
from mcp.server.fastmcp import FastMCP
from requests.auth import HTTPBasicAuth
from typing import Dict, List, Optional, Any

# Import configuration from the config.py file.
from config import BC_BASE_URL, BC_CLIENT_ID, BC_CLIENT_SECRET, BC_SCOPE, BC_COMPANY_ID, BC_TENANT_ID

# Global variable to hold the access token.
bc_access_token = None

def get_bc_access_token():
    """
    Fetches a new OAuth 2.0 access token for Business Central.
    """
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
        print("Successfully fetched new access token.")
        return True
    except requests.exceptions.RequestException as e:
        print(f"Error fetching access token: {e}")
        bc_access_token = None
        return False

# Create the MCP server instance
server = FastMCP(name="DynamicBusinessCentralServer")

def _make_bc_api_call(api_endpoint: str, method: str = "GET", params: dict = None, data: dict = None):
    """
    Makes API requests to the Business Central API with centralized authentication and error handling.
    """
    global bc_access_token

    if not bc_access_token:
        return {"error": "Could not authenticate with Business Central. Token is missing."}

    url = f"{BC_BASE_URL}{api_endpoint}"

    headers = {
        "Authorization": f"Bearer {bc_access_token}",
        "Content-Type": "application/json"
    }
    
    try:
        print(f"Calling Business Central API: {method} {url} with params: {params}")
        
        if method.upper() == "GET":
            response = requests.get(url, headers=headers, params=params)
        elif method.upper() == "POST":
            response = requests.post(url, headers=headers, params=params, json=data)
        elif method.upper() == "PATCH":
            response = requests.patch(url, headers=headers, params=params, json=data)
        elif method.upper() == "DELETE":
            response = requests.delete(url, headers=headers, params=params)
        else:
            return {"error": f"Unsupported HTTP method: {method}"}
            
        response.raise_for_status()
        
        # Handle responses that might not have JSON content
        try:
            return response.json()
        except json.JSONDecodeError:
            return {"message": "Operation completed successfully", "status_code": response.status_code}
            
    except requests.exceptions.RequestException as e:
        print(f"Error calling Business Central API: {e}")
        return {"error": f"API call failed: {e}"}

# Generated MCP Tools
{{ENTITY_TOOLS_PLACEHOLDER}}

# Server registration and startup
{{SERVER_REGISTRATION_PLACEHOLDER}}

if __name__ == "__main__":
    print("Starting Dynamic MCP server for Business Central...")
    
    if get_bc_access_token():
        print("Available operations: GET, POST, PATCH, DELETE for selected entities")
        server.run()
    else:
        print("Server could not be started due to authentication failure.")
'@
}

function Get-ConfigTemplate {
    return @'
# config_template.py
# Template configuration file - will be replaced with actual values

BC_TENANT_ID = "{{TENANT_ID}}"
BC_BASE_URL = "{{BASE_URL}}"
BC_CLIENT_ID = "{{CLIENT_ID}}"
BC_CLIENT_SECRET = "{{CLIENT_SECRET}}"
BC_SCOPE = "{{SCOPE}}"
BC_COMPANY_ID = "{{COMPANY_ID}}"
'@
}

function Get-ClaudeConfigTemplate {
    return @'
{
  "mcpServers": {
    "business-central-dynamic": {
      "command": "{{PYTHON_PATH}}",
      "args": ["{{SERVER_PATH}}"],
      "env": {
        "PYTHONPATH": "{{INSTALL_PATH}}"
      }
    }
  }
}
'@
}