# Install-BusinessCentralMCP.ps1
# Business Central MCP Server Installer

param(
    [string]$InstallPath = "C:\Development\BusinessCentral-MCP",
    [string]$GitHubRepo = "cetasvigneswarant/BCMCPServers",
    [string]$GitHubToken = $env:GITHUB_TOKEN,
    [switch]$SkipPrerequisites = $false,
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"

Write-Host "Business Central MCP Server Installer" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host "Install Path: $InstallPath"
Write-Host "Repository: $GitHubRepo"
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "WARNING: Not running as Administrator. Some installations may fail." -ForegroundColor Yellow
}

# Test Python installation
function Test-PythonInstallation {
    Write-Host "Checking Python installation..."
    
    try {
        $pythonVersion = python --version 2>$null
        if ($pythonVersion -match "Python (\d+\.\d+\.\d+)") {
            $version = [Version]$Matches[1]
            if ($version -ge [Version]"3.8.0") {
                Write-Host "Python $($Matches[1]) found" -ForegroundColor Green
                return $true
            } else {
                Write-Host "Python version $($Matches[1]) is too old. Minimum required: 3.8.0" -ForegroundColor Red
                return $false
            }
        }
    } catch {
        Write-Host "Python not found in PATH" -ForegroundColor Red
        return $false
    }
    
    return $false
}

# Install Python
function Install-Python {
    Write-Host "Installing Python..."
    
    if ($isAdmin) {
        try {
            Write-Host "Attempting to install Python using winget..."
            winget install Python.Python.3.12 --accept-source-agreements --accept-package-agreements
            Write-Host "Python installed via winget" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "Winget installation failed" -ForegroundColor Yellow
        }
        
        try {
            if (Get-Command choco -ErrorAction SilentlyContinue) {
                choco install python -y
                Write-Host "Python installed via Chocolatey" -ForegroundColor Green
                return $true
            }
        } catch {
            Write-Host "Chocolatey installation failed" -ForegroundColor Yellow
        }
    }
    
    Write-Host "Automatic Python installation failed." -ForegroundColor Red
    Write-Host "Please manually install Python:"
    Write-Host "1. Go to https://python.org/downloads/"
    Write-Host "2. Download Python 3.8 or later"
    Write-Host "3. Run the installer with 'Add Python to PATH' checked"
    Write-Host "4. Restart this script after installation"
    
    return $false
}

# Test Git installation
function Test-GitInstallation {
    Write-Host "Checking Git installation..."
    
    try {
        $gitVersion = git --version 2>$null
        if ($gitVersion) {
            Write-Host "Git found: $gitVersion" -ForegroundColor Green
            return $true
        }
    } catch {
        Write-Host "Git not found" -ForegroundColor Red
        return $false
    }
    
    return $false
}

# Install Git
function Install-Git {
    Write-Host "Installing Git..."
    
    if ($isAdmin) {
        try {
            Write-Host "Attempting to install Git using winget..."
            winget install Git.Git --accept-source-agreements --accept-package-agreements
            Write-Host "Git installed via winget" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "Winget installation failed" -ForegroundColor Yellow
        }
        
        try {
            if (Get-Command choco -ErrorAction SilentlyContinue) {
                choco install git -y
                Write-Host "Git installed via Chocolatey" -ForegroundColor Green
                return $true
            }
        } catch {
            Write-Host "Chocolatey installation failed" -ForegroundColor Yellow
        }
    }
    
    Write-Host "Automatic Git installation failed." -ForegroundColor Red
    Write-Host "Please manually install Git from: https://git-scm.com/download/windows"
    
    return $false
}

# Initialize installation directory
function Initialize-InstallationDirectory {
    Write-Host "Setting up installation directory..."
    
    if (Test-Path $InstallPath) {
        if ($Force) {
            Write-Host "Removing existing installation directory..." -ForegroundColor Yellow
            Remove-Item $InstallPath -Recurse -Force
        } else {
            Write-Host "Installation directory already exists: $InstallPath" -ForegroundColor Yellow
            $response = Read-Host "Do you want to overwrite it? (y/N)"
            if ($response -eq 'y' -or $response -eq 'Y') {
                Remove-Item $InstallPath -Recurse -Force
            } else {
                Write-Host "Installation cancelled." -ForegroundColor Red
                exit 1
            }
        }
    }
    
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    Write-Host "Created installation directory: $InstallPath" -ForegroundColor Green
}

# Get source files from GitHub
function Get-SourceFiles {
    Write-Host "Downloading source files from GitHub..."
    
    # Get GitHub token if not provided
    if (-not $GitHubToken) {
        Write-Host "GitHub Personal Access Token required for private repository access" -ForegroundColor Yellow
        Write-Host "Create token at: https://github.com/settings/tokens"
        Write-Host "Required scope: 'repo' (Full control of private repositories)"
        $GitHubToken = Read-Host "Enter your GitHub token (ghp_...)"
        
        if (-not $GitHubToken) {
            Write-Host "Token required for private repository access." -ForegroundColor Red
            return $false
        }
    }
    
    try {
        # Try git clone first
        $gitUrl = "https://$GitHubToken@github.com/$GitHubRepo.git"
        Write-Host "Cloning repository: $GitHubRepo"
        
        # Clone to temp directory then move files
        $tempDir = Join-Path $env:TEMP "bc-mcp-temp"
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force
        }
        
        git clone $gitUrl $tempDir
        
        # Move files to install directory
        $sourceFiles = @("bc_mcp_server.py", "config.py", "requirements.txt")
        foreach ($file in $sourceFiles) {
            $sourcePath = Join-Path $tempDir $file
            $destPath = Join-Path $InstallPath $file
            
            if (Test-Path $sourcePath) {
                Copy-Item $sourcePath $destPath -Force
                Write-Host "Copied: $file" -ForegroundColor Green
            } else {
                Write-Host "Warning: $file not found in repository" -ForegroundColor Yellow
            }
        }
        
        # Copy any additional files
        $additionalFiles = Get-ChildItem $tempDir -File | Where-Object { $_.Name -notmatch "\.git|\.md$|LICENSE" }
        foreach ($file in $additionalFiles) {
            if ($sourceFiles -notcontains $file.Name) {
                Copy-Item $file.FullName (Join-Path $InstallPath $file.Name) -Force
                Write-Host "Copied additional file: $($file.Name)" -ForegroundColor Green
            }
        }
        
        # Cleanup
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        
        Write-Host "All files downloaded successfully" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Host "Git clone failed: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Attempting individual file downloads..."
        
        # Fallback: Download individual files
        try {
            $headers = @{
                "Authorization" = "token $GitHubToken"
                "Accept" = "application/vnd.github.v3.raw"
            }
            
            $files = @("bc_mcp_server.py", "config.py", "requirements.txt")
            
            foreach ($file in $files) {
                $url = "https://api.github.com/repos/$GitHubRepo/contents/$file"
                $filePath = Join-Path $InstallPath $file
                Write-Host "Downloading $file..."
                Invoke-WebRequest -Uri $url -Headers $headers -OutFile $filePath
                Write-Host "Downloaded: $file" -ForegroundColor Green
            }
            
            Write-Host "Files downloaded individually" -ForegroundColor Green
            return $true
            
        } catch {
            Write-Host "Failed to download files: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Please check:"
            Write-Host "1. Your GitHub token has 'repo' scope"
            Write-Host "2. You have access to the repository: $GitHubRepo"
            Write-Host "3. The repository contains the required files"
            return $false
        }
    }
}

# Setup Python virtual environment
function Setup-PythonVirtualEnvironment {
    Write-Host "Setting up Python virtual environment..."
    
    $venvPath = Join-Path $InstallPath "venv"
    
    try {
        Set-Location $InstallPath
        
        # Create virtual environment
        Write-Host "Creating virtual environment..."
        python -m venv $venvPath
        
        # Activate virtual environment
        $activateScript = Join-Path $venvPath "Scripts\Activate.ps1"
        if (Test-Path $activateScript) {
            Write-Host "Activating virtual environment..."
            & $activateScript
            Write-Host "Virtual environment activated" -ForegroundColor Green
        } else {
            throw "Virtual environment activation script not found"
        }
        
        # Upgrade pip
        Write-Host "Upgrading pip..."
        python -m pip install --upgrade pip
        
        # Install requirements
        $requirementsPath = Join-Path $InstallPath "requirements.txt"
        if (Test-Path $requirementsPath) {
            Write-Host "Installing Python dependencies..."
            python -m pip install -r $requirementsPath
            Write-Host "Dependencies installed successfully" -ForegroundColor Green
        } else {
            Write-Host "requirements.txt not found, installing basic dependencies..." -ForegroundColor Yellow
            python -m pip install mcp requests pydantic colorama asyncio-mqtt
        }
        
        return $true
        
    } catch {
        Write-Host "Failed to set up Python environment: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Create startup scripts
function Create-StartupScripts {
    Write-Host "Creating startup scripts..."
    
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
        
        Write-Host "Startup scripts created" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Host "Failed to create startup scripts: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Create Claude Desktop configuration
function Create-ClaudeDesktopConfig {
    Write-Host "Creating Claude Desktop configuration files..."
    
    try {
        $pythonExePath = Join-Path $InstallPath "venv\Scripts\python.exe"
        $serverScriptPath = Join-Path $InstallPath "bc_mcp_server.py"
        
        # Create config for Claude Desktop
        $claudeConfig = @{
            mcpServers = @{
                "business-central" = @{
                    command = $pythonExePath
                    args = @($serverScriptPath)
                    env = @{}
                }
            }
        }
        
        # Save in installation directory
        $configPath = Join-Path $InstallPath "claude_desktop_config.json"
        $claudeConfig | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
        Write-Host "Claude config created: $configPath" -ForegroundColor Green
        
        # Also try to save to Claude's directory
        $claudeConfigDir = "$env:APPDATA\Claude"
        if (-not (Test-Path $claudeConfigDir)) {
            New-Item -ItemType Directory -Path $claudeConfigDir -Force | Out-Null
        }
        
        $claudeConfigPath = Join-Path $claudeConfigDir "claude_desktop_config.json"
        
        # Check if config already exists and merge
        if (Test-Path $claudeConfigPath) {
            try {
                $existingConfig = Get-Content $claudeConfigPath -Raw | ConvertFrom-Json
                if (-not $existingConfig.mcpServers) {
                    $existingConfig | Add-Member -Name "mcpServers" -Value @{} -MemberType NoteProperty
                }
                $existingConfig.mcpServers | Add-Member -Name "business-central" -Value $claudeConfig.mcpServers."business-central" -MemberType NoteProperty -Force
                $existingConfig | ConvertTo-Json -Depth 10 | Set-Content $claudeConfigPath -Encoding UTF8
                Write-Host "Updated existing Claude Desktop configuration" -ForegroundColor Green
            } catch {
                $claudeConfig | ConvertTo-Json -Depth 10 | Set-Content $claudeConfigPath -Encoding UTF8
                Write-Host "Created new Claude Desktop configuration" -ForegroundColor Green
            }
        } else {
            $claudeConfig | ConvertTo-Json -Depth 10 | Set-Content $claudeConfigPath -Encoding UTF8
            Write-Host "Created Claude Desktop configuration: $claudeConfigPath" -ForegroundColor Green
        }
        
        return $true
        
    } catch {
        Write-Host "Failed to create Claude Desktop configuration: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "You can manually copy the config from: $InstallPath\claude_desktop_config.json" -ForegroundColor Yellow
        Write-Host "To: $env:APPDATA\Claude\claude_desktop_config.json" -ForegroundColor Yellow
        return $false
    }
}

# Show completion message
function Show-CompletionMessage {
    Write-Host ""
    Write-Host "======================================" -ForegroundColor Green
    Write-Host "Installation Complete!" -ForegroundColor Green
    Write-Host "======================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Installation Location: $InstallPath"
    Write-Host ""
    Write-Host "NEXT STEPS:"
    Write-Host "1. Configure Business Central connection:"
    Write-Host "   Edit: $InstallPath\config.py"
    Write-Host "   Replace all 'YOUR_..._HERE' placeholders"
    Write-Host ""
    Write-Host "2. Test configuration:"
    Write-Host "   Run: $InstallPath\test_config.ps1"
    Write-Host ""
    Write-Host "3. Start MCP server:"
    Write-Host "   Run: $InstallPath\start_bc_mcp.bat"
    Write-Host "   Or:  $InstallPath\start_bc_mcp.ps1"
    Write-Host ""
    Write-Host "4. Restart Claude Desktop application"
    Write-Host ""
    Write-Host "FILES CREATED:"
    Get-ChildItem $InstallPath | ForEach-Object {
        Write-Host "   $($_.Name)"
    }
    Write-Host ""
    Write-Host "Claude Desktop Config: $env:APPDATA\Claude\claude_desktop_config.json"
    Write-Host "Backup Config: $InstallPath\claude_desktop_config.json"
}

# Main execution
try {
    # Check prerequisites
    if (-not $SkipPrerequisites) {
        Write-Host "Checking prerequisites..."
        
        if (-not (Test-PythonInstallation)) {
            if (-not (Install-Python)) {
                exit 1
            }
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        }
        
        if (-not (Test-GitInstallation)) {
            if (-not (Install-Git)) {
                Write-Host "Git installation failed, but continuing..." -ForegroundColor Yellow
                Write-Host "Individual file downloads will be used instead." -ForegroundColor Yellow
            } else {
                # Refresh PATH
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            }
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
    
    # Create startup scripts
    if (-not (Create-StartupScripts)) {
        Write-Host "Startup script creation failed, but installation can continue" -ForegroundColor Yellow
    }
    
    # Create Claude Desktop configuration
    if (-not (Create-ClaudeDesktopConfig)) {
        Write-Host "Claude Desktop configuration failed, but installation can continue" -ForegroundColor Yellow
    }
    
    # Show completion message
    Show-CompletionMessage
    
} catch {
    Write-Host "Installation failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please check the error messages above and try again" -ForegroundColor Red
    exit 1
}

Write-Host "Installation completed successfully!" -ForegroundColor Green
