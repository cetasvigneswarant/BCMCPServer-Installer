# Install-BusinessCentralMCP.ps1
# Automated Business Central MCP Server Installation Script
# This script will set up everything needed to run the BC MCP server

param(
    [string]$InstallPath = "$env:USERPROFILE\BusinessCentral-MCP",
    [string]$GitHubRepo = "cetasvigneswarant/BCMCPServers",  # Replace with actual repo
    [string]$GitHubToken = "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",  # GitHub Personal Access Token for private repos
    [switch]$SkipPrerequisites = $false,
    [switch]$Force = $false
)

# Script configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

# Color functions for better output
function Write-ColorOutput($ForegroundColor, $Message) {
    $currentColor = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = $ForegroundColor
    Write-Output $Message
    $Host.UI.RawUI.ForegroundColor = $currentColor
}

function Write-Success($Message) { Write-ColorOutput "Green" "✅ $Message" }
function Write-Info($Message) { Write-ColorOutput "Cyan" "ℹ️  $Message" }
function Write-Warning($Message) { Write-ColorOutput "Yellow" "⚠️  $Message" }
function Write-Error($Message) { Write-ColorOutput "Red" "❌ $Message" }

# Banner
Write-Host @"
╔══════════════════════════════════════════════════════════════════╗
║            Business Central MCP Server Installer                ║
║                    Automated Setup Tool                         ║
╚══════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Info "Starting installation process..."
Write-Info "Install Path: $InstallPath"

# Check if running as Administrator for certain operations
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Not running as Administrator. Some features may require elevated privileges."
}

# =============================================================================
# PREREQUISITE CHECKS AND INSTALLATION
# =============================================================================

function Test-PythonInstallation {
    Write-Info "Checking Python installation..."
    
    try {
        $pythonVersion = python --version 2>$null
        if ($pythonVersion -match "Python (\d+\.\d+\.\d+)") {
            $version = [Version]$Matches[1]
            if ($version -ge [Version]"3.8.0") {
                Write-Success "Python $($Matches[1]) found"
                return $true
            } else {
                Write-Warning "Python version $($Matches[1]) is too old. Minimum required: 3.8.0"
                return $false
            }
        }
    } catch {
        Write-Warning "Python not found in PATH"
        return $false
    }
    
    return $false
}

function Install-Python {
    Write-Info "Installing Python..."
    
    if ($isAdmin) {
        # Try using winget first
        try {
            Write-Info "Attempting to install Python using winget..."
            winget install Python.Python.3.12 --accept-source-agreements --accept-package-agreements
            Write-Success "Python installed via winget"
            return $true
        } catch {
            Write-Warning "Winget installation failed, trying Chocolatey..."
        }
        
        # Try using Chocolatey
        try {
            if (Get-Command choco -ErrorAction SilentlyContinue) {
                choco install python -y
                Write-Success "Python installed via Chocolatey"
                return $true
            }
        } catch {
            Write-Warning "Chocolatey installation failed"
        }
    }
    
    # Manual download instructions
    Write-Error "Automatic Python installation failed."
    Write-Info "Please manually install Python:"
    Write-Info "1. Go to https://python.org/downloads/"
    Write-Info "2. Download Python 3.8 or later"
    Write-Info "3. Run the installer with 'Add Python to PATH' checked"
    Write-Info "4. Restart this script after installation"
    
    return $false
}

function Test-GitInstallation {
    Write-Info "Checking Git installation..."
    
    try {
        $gitVersion = git --version 2>$null
        if ($gitVersion) {
            Write-Success "Git found: $gitVersion"
            return $true
        }
    } catch {
        Write-Warning "Git not found"
        return $false
    }
    
    return $false
}

function Install-Git {
    Write-Info "Installing Git..."
    
    if ($isAdmin) {
        try {
            Write-Info "Attempting to install Git using winget..."
            winget install Git.Git --accept-source-agreements --accept-package-agreements
            Write-Success "Git installed via winget"
            return $true
        } catch {
            Write-Warning "Winget installation failed"
        }
        
        try {
            if (Get-Command choco -ErrorAction SilentlyContinue) {
                choco install git -y
                Write-Success "Git installed via Chocolatey"
                return $true
            }
        } catch {
            Write-Warning "Chocolatey installation failed"
        }
    }
    
    Write-Error "Automatic Git installation failed."
    Write-Info "Please manually install Git:"
    Write-Info "1. Go to https://git-scm.com/download/windows"
    Write-Info "2. Download and run the installer"
    Write-Info "3. Restart this script after installation"
    
    return $false
}

# =============================================================================
# MAIN INSTALLATION PROCESS
# =============================================================================

function Initialize-InstallationDirectory {
    Write-Info "Setting up installation directory..."
    
    if (Test-Path $InstallPath) {
        if ($Force) {
            Write-Warning "Removing existing installation directory..."
            Remove-Item $InstallPath -Recurse -Force
        } else {
            Write-Warning "Installation directory already exists: $InstallPath"
            $response = Read-Host "Do you want to overwrite it? (y/N)"
            if ($response -eq 'y' -or $response -eq 'Y') {
                Remove-Item $InstallPath -Recurse -Force
            } else {
                Write-Error "Installation cancelled."
                exit 1
            }
        }
    }
    
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    Write-Success "Created installation directory: $InstallPath"
}

function Get-SourceFiles {
    Write-Info "Downloading source files from GitHub..."
    
    try {
        # Prepare git clone command with token if provided
        $gitUrl = if ($GitHubToken) {
            "https://$GitHubToken@github.com/$GitHubRepo.git"
        } else {
            "https://github.com/$GitHubRepo.git"
        }
        
        # Clone the repository
        Write-Info "Cloning repository: $GitHubRepo"
        git clone $gitUrl $InstallPath
        Write-Success "Repository cloned successfully"
        
        # Verify required files exist
        $requiredFiles = @("bc_mcp_server.py", "config.py", "requirements.txt")
        foreach ($file in $requiredFiles) {
            $filePath = Join-Path $InstallPath $file
            if (-not (Test-Path $filePath)) {
                throw "Required file not found: $file"
            }
        }
        
        Write-Success "All required files downloaded successfully"
        return $true
        
    } catch {
        Write-Error "Failed to download from GitHub: $_"
        
        # Fallback: Download individual files with token
        if ($GitHubToken) {
            Write-Info "Attempting to download files individually with authentication..."
            try {
                $headers = @{
                    "Authorization" = "token $GitHubToken"
                    "Accept" = "application/vnd.github.v3.raw"
                }
                
                $baseUrl = "https://api.github.com/repos/$GitHubRepo/contents"
                $files = @("bc_mcp_server.py", "config.py", "requirements.txt")
                
                foreach ($file in $files) {
                    $filePath = Join-Path $InstallPath $file
                    Write-Info "Downloading $file..."
                    Invoke-WebRequest -Uri "$baseUrl/$file" -Headers $headers -OutFile $filePath
                }
                
                Write-Success "Files downloaded individually with authentication"
                return $true
                
            } catch {
                Write-Error "Failed to download files with authentication: $_"
                return $false
            }
        } else {
            Write-Error "Repository appears to be private. Please provide a GitHub token."
            Write-Info "Run with: -GitHubToken 'your_token_here'"
            return $false
        }
    }
}

function Setup-PythonVirtualEnvironment {
    Write-Info "Setting up Python virtual environment..."
    
    $venvPath = Join-Path $InstallPath "venv"
    
    try {
        # Create virtual environment
        Write-Info "Creating virtual environment..."
        python -m venv $venvPath
        
        # Activate virtual environment
        $activateScript = Join-Path $venvPath "Scripts\Activate.ps1"
        if (Test-Path $activateScript) {
            Write-Info "Activating virtual environment..."
            & $activateScript
            Write-Success "Virtual environment activated"
        } else {
            throw "Virtual environment activation script not found"
        }
        
        # Upgrade pip
        Write-Info "Upgrading pip..."
        python -m pip install --upgrade pip
        
        # Install requirements
        $requirementsPath = Join-Path $InstallPath "requirements.txt"
        if (Test-Path $requirementsPath) {
            Write-Info "Installing Python dependencies..."
            python -m pip install -r $requirementsPath
            Write-Success "Dependencies installed successfully"
        } else {
            Write-Warning "requirements.txt not found, installing basic dependencies..."
            python -m pip install mcp requests asyncio-mqtt pydantic colorama
        }
        
        return $true
        
    } catch {
        Write-Error "Failed to set up Python environment: $_"
        return $false
    }
}

function Create-ClaudeDesktopConfig {
    Write-Info "Creating Claude Desktop configuration..."
    
    try {
        # Find Claude Desktop config directory
        $claudeConfigDir = "$env:APPDATA\Claude"
        if (-not (Test-Path $claudeConfigDir)) {
            New-Item -ItemType Directory -Path $claudeConfigDir -Force | Out-Null
        }
        
        $configPath = Join-Path $claudeConfigDir "claude_desktop_config.json"
        $pythonExePath = Join-Path $InstallPath "venv\Scripts\python.exe"
        $serverScriptPath = Join-Path $InstallPath "bc_mcp_server.py"
        
        # Create or update config
        $config = @{}
        if (Test-Path $configPath) {
            $existingConfig = Get-Content $configPath -Raw | ConvertFrom-Json
            $config = $existingConfig
        }
        
        if (-not $config.mcpServers) {
            $config | Add-Member -Name "mcpServers" -Value @{} -MemberType NoteProperty
        }
        
        # Add Business Central MCP server configuration
        $bcServerConfig = @{
            command = $pythonExePath
            args = @($serverScriptPath)
            env = @{}
        }
        
        $config.mcpServers | Add-Member -Name "business-central" -Value $bcServerConfig -MemberType NoteProperty -Force
        
        # Save configuration
        $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
        
        Write-Success "Claude Desktop configuration created: $configPath"
        return $true
        
    } catch {
        Write-Error "Failed to create Claude Desktop configuration: $_"
        return $false
    }
}

function Create-StartupScripts {
    Write-Info "Creating startup scripts..."
    
    try {
        # Create batch file for easy startup
        $batContent = @"
@echo off
cd /d "$InstallPath"
call venv\Scripts\activate.bat
python bc_mcp_server.py
pause
"@
        
        $batPath = Join-Path $InstallPath "start_bc_mcp.bat"
        $batContent | Set-Content $batPath -Encoding ASCII
        
        # Create PowerShell startup script
        $psContent = @"
# Start Business Central MCP Server
Set-Location "$InstallPath"
& "venv\Scripts\Activate.ps1"
python bc_mcp_server.py
"@
        
        $psPath = Join-Path $InstallPath "start_bc_mcp.ps1"
        $psContent | Set-Content $psPath -Encoding UTF8
        
        # Create configuration validation script
        $configTestContent = @"
# Test Business Central Configuration
Set-Location "$InstallPath"
& "venv\Scripts\Activate.ps1"
python -c "from config import validate_config; validate_config()"
"@
        
        $configTestPath = Join-Path $InstallPath "test_config.ps1"
        $configTestContent | Set-Content $configTestPath -Encoding UTF8
        
        Write-Success "Startup scripts created"
        return $true
        
    } catch {
        Write-Error "Failed to create startup scripts: $_"
        return $false
    }
}

function Show-NextSteps {
    Write-Host @"

╔══════════════════════════════════════════════════════════════════╗
║                     Installation Complete!                      ║
╚══════════════════════════════════════════════════════════════════╝

🎉 Business Central MCP Server has been installed successfully!

📁 Installation Location: $InstallPath

📋 NEXT STEPS:

1. 🔧 CONFIGURE YOUR BUSINESS CENTRAL CONNECTION:
   Edit: $InstallPath\config.py
   - Replace all "YOUR_..._HERE" placeholders with your actual values
   - See the configuration instructions in the file

2. ✅ TEST YOUR CONFIGURATION:
   Run: $InstallPath\test_config.ps1
   This will validate your Business Central connection settings

3. 🚀 START THE MCP SERVER:
   Option A: Double-click $InstallPath\start_bc_mcp.bat
   Option B: Run $InstallPath\start_bc_mcp.ps1

4. 📱 USE WITH CLAUDE DESKTOP:
   - Restart Claude Desktop application
   - The Business Central MCP server should appear automatically
   - Look for "business-central" in your available tools

🔗 HELPFUL COMMANDS:
   Test config:     cd "$InstallPath" && .\test_config.ps1
   Start server:    cd "$InstallPath" && .\start_bc_mcp.ps1
   Update server:   cd "$InstallPath" && git pull

📚 AVAILABLE OPERATIONS:
   👥 Customers: get_customers, create_customer, get_customer_by_name
   📦 Items: get_items, create_item, get_item_by_number
   📄 Sales Orders: get_sales_orders, create_sales_order, add_sales_order_line

⚠️  REMEMBER:
   - Keep your config.py file secure (contains sensitive credentials)
   - Test your configuration before using with Claude
   - Check the server logs if you encounter issues

🆘 SUPPORT:
   - Check the GitHub repository for documentation
   - Review the setup instructions in config.py
   - Ensure your Azure app registration has correct permissions

"@ -ForegroundColor Green
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

try {
    # Check prerequisites
    if (-not $SkipPrerequisites) {
        Write-Info "Checking prerequisites..."
        
        if (-not (Test-PythonInstallation)) {
            if (-not (Install-Python)) {
                exit 1
            }
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        }
        
        if (-not (Test-GitInstallation)) {
            if (-not (Install-Git)) {
                exit 1
            }
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        }
    }
    
    # Initialize installation
    Initialize-InstallationDirectory
    
    # Download source files
    if (-not (Get-SourceFiles)) {
        exit 1
    }
    
    # Set up Python environment
    if (-not (Setup-PythonVirtualEnvironment)) {
        exit 1
    }
    
    # Create Claude Desktop configuration
    if (-not (Create-ClaudeDesktopConfig)) {
        Write-Warning "Claude Desktop configuration failed, but installation can continue"
    }
    
    # Create startup scripts
    if (-not (Create-StartupScripts)) {
        Write-Warning "Startup script creation failed, but installation can continue"
    }
    
    # Show next steps
    Show-NextSteps
    
} catch {
    Write-Error "Installation failed: $_"
    Write-Info "Please check the error messages above and try again"
    exit 1
}

Write-Success "Installation completed successfully!"
