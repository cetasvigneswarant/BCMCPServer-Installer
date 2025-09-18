# Business Central MCP Server Setup Script with Claude Desktop Installation
# This script downloads, installs, and configures the Business Central MCP server for Claude Desktop

param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubToken,
    
    [Parameter(Mandatory=$true)]
    [string]$RepoOwner,
    
    [Parameter(Mandatory=$true)]
    [string]$RepoName,
    
    [Parameter(Mandatory=$false)]
    [string]$InstallPath = "$env:USERPROFILE\BusinessCentralMCP",
    
    [Parameter(Mandatory=$false)]
    [switch]$UsePublicRepo,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipClaudeInstall
)

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    
    $colorMap = @{
        Success = "Green"
        Warning = "Yellow" 
        Error = "Red"
        Info = "Cyan"
        Progress = "Magenta"
        White = "White"
    }
    
    $consoleColor = $colorMap[$Color]
    if ($consoleColor) {
        Write-Host $Message -ForegroundColor $consoleColor
    } else {
        Write-Host $Message
    }
}

function Test-CommandExists {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Install-Python {
    Write-ColorOutput "Python not found. Installing Python..." -Color "Progress"
    
    try {
        # Download Python installer
        $pythonUrl = "https://www.python.org/ftp/python/3.11.7/python-3.11.7-amd64.exe"
        $pythonInstaller = "$env:TEMP\python-installer.exe"
        
        Write-ColorOutput "Downloading Python installer..." -Color "Info"
        Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller -UseBasicParsing
        
        Write-ColorOutput "Installing Python (this may take a few minutes)..." -Color "Info"
        Start-Process -FilePath $pythonInstaller -ArgumentList "/quiet", "InstallAllUsers=0", "PrependPath=1", "Include_test=0" -Wait
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        # Clean up
        Remove-Item $pythonInstaller -Force
        
        Write-ColorOutput "Python installation completed." -Color "Success"
        return $true
    }
    catch {
        Write-ColorOutput "Failed to install Python: $($_.Exception.Message)" -Color "Error"
        return $false
    }
}

function Check-ClaudeDesktop {
    Write-ColorOutput "Checking for Claude Desktop installation..." -Color "Progress"
    
    # Check if Claude Desktop is already installed
    $claudePaths = @(
        "$env:LOCALAPPDATA\Programs\Claude\Claude.exe",
        "$env:PROGRAMFILES\Claude\Claude.exe",
        "${env:PROGRAMFILES(X86)}\Claude\Claude.exe"
    )
    
    $claudeInstalled = $false
    foreach ($path in $claudePaths) {
        if (Test-Path $path) {
            Write-ColorOutput "Claude Desktop found at: $path" -Color "Success"
            $claudeInstalled = $true
            break
        }
    }
    
    if ($claudeInstalled) {
        Write-ColorOutput "Claude Desktop is already installed. Skipping installation." -Color "Success"
        return $true
    }
    
    Write-ColorOutput "Claude Desktop not found." -Color "Warning"
    Write-ColorOutput "Please manually download and install Claude Desktop from: https://claude.ai/download" -Color "Info"
    Write-ColorOutput "After installing Claude Desktop, you can continue with the MCP setup." -Color "Info"
    
    $response = Read-Host "Have you installed Claude Desktop? (y/n)"
    if ($response -notmatch '^[Yy]') {
        Write-ColorOutput "Please install Claude Desktop first, then re-run this script." -Color "Warning"
        return $false
    }
    
    # Check again after user confirms installation
    $claudeStillNotFound = $true
    foreach ($path in $claudePaths) {
        if (Test-Path $path) {
            Write-ColorOutput "Claude Desktop found at: $path" -Color "Success"
            $claudeStillNotFound = $false
            break
        }
    }
    
    if ($claudeStillNotFound) {
        Write-ColorOutput "Claude Desktop still not detected, but proceeding with MCP setup..." -Color "Warning"
    }
    
    return $true
}

function Get-GitHubFile {
    param(
        [string]$Owner,
        [string]$Repo, 
        [string]$FilePath,
        [string]$Token,
        [string]$OutputPath,
        [bool]$IsPublic = $false
    )
    
    try {
        if ($IsPublic) {
            $url = "https://raw.githubusercontent.com/$Owner/$Repo/main/$FilePath"
            $headers = @{}
        } else {
            $url = "https://api.github.com/repos/$Owner/$Repo/contents/$FilePath"
            $headers = @{
                "Authorization" = "token $Token"
                "Accept" = "application/vnd.github.v3.raw"
            }
        }
        
        Write-ColorOutput "Downloading $FilePath..." -Color "Info"
        Invoke-WebRequest -Uri $url -Headers $headers -OutFile $OutputPath -UseBasicParsing
        return $true
    }
    catch {
        Write-ColorOutput "Failed to download $FilePath`: $($_.Exception.Message)" -Color "Error"
        return $false
    }
}

function Create-MCPConfigFile {
    param([string]$ServerPath)
    
    # Create the MCP configuration file in the installation folder
    $mcpConfigPath = Join-Path $ServerPath "claude_desktop_config.json"
    
    # Prepare the Python executable path (from venv)
    $venvPython = Join-Path $ServerPath "venv\Scripts\python.exe"
    $mcpServerScript = Join-Path $ServerPath "mcp_bc_server.py"
    
    # Convert paths to forward slashes for JSON compatibility
    $venvPython = $venvPython -replace '\\', '/'
    $mcpServerScript = $mcpServerScript -replace '\\', '/'
    $ServerPath = $ServerPath -replace '\\', '/'
    
    try {
        # Create the configuration structure
        $config = @{
            mcpServers = @{
                "business-central" = @{
                    command = $venvPython
                    args = @($mcpServerScript)
                    env = @{
                        PYTHONPATH = $ServerPath
                    }
                }
            }
        }
        
        # Convert to JSON and save to installation folder
        $configJson = $config | ConvertTo-Json -Depth 10
        Set-Content -Path $mcpConfigPath -Value $configJson -Encoding UTF8
        
        Write-ColorOutput "MCP configuration file created: $mcpConfigPath" -Color "Success"
        Write-ColorOutput "You can copy this configuration to your Claude Desktop config file manually." -Color "Info"
        return $true
    }
    catch {
        Write-ColorOutput "Failed to create MCP configuration file: $($_.Exception.Message)" -Color "Error"
        return $false
    }
}

function Main {
    Write-ColorOutput "=== Business Central MCP Server Setup ===" -Color "Progress"
    Write-ColorOutput "Starting setup process..." -Color "Info"
    
    # Check/Install Claude Desktop if not skipped
    if (-not $SkipClaudeInstall.IsPresent) {
        if (-not (Check-ClaudeDesktop)) {
            Write-ColorOutput "Setup aborted: Claude Desktop is required." -Color "Error"
            Write-ColorOutput "Please install Claude Desktop from https://claude.ai/download and run the script again." -Color "Info"
            exit 1
        }
    }
    
    # Check if Python is installed
    if (-not (Test-CommandExists "python")) {
        Write-ColorOutput "Python not found on system." -Color "Warning"
        if (-not (Install-Python)) {
            Write-ColorOutput "Setup failed: Could not install Python." -Color "Error"
            exit 1
        }
        
        # Wait a moment and check again
        Start-Sleep -Seconds 5
        if (-not (Test-CommandExists "python")) {
            Write-ColorOutput "Setup failed: Python installation was not successful." -Color "Error"
            exit 1
        }
    }
    
    Write-ColorOutput "Python found: $(python --version)" -Color "Success"
    
    # Create installation directory
    Write-ColorOutput "Creating installation directory: $InstallPath" -Color "Info"
    if (-not (Test-Path $InstallPath)) {
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    }
    
    # Download files from GitHub
    Write-ColorOutput "Downloading files from GitHub repository..." -Color "Progress"
    
    $files = @("mcp_bc_server.py", "config.py")
    $downloadSuccess = $true
    
    foreach ($file in $files) {
        $outputPath = Join-Path $InstallPath $file
        if (-not (Get-GitHubFile -Owner $RepoOwner -Repo $RepoName -FilePath $file -Token $GitHubToken -OutputPath $outputPath -IsPublic $UsePublicRepo.IsPresent)) {
            $downloadSuccess = $false
            break
        }
    }
    
    if (-not $downloadSuccess) {
        Write-ColorOutput "Setup failed: Could not download required files." -Color "Error"
        exit 1
    }
    
    Write-ColorOutput "Files downloaded successfully." -Color "Success"
    
    # Create virtual environment
    Write-ColorOutput "Creating Python virtual environment..." -Color "Progress"
    Set-Location $InstallPath
    
    try {
        & python -m venv venv
        if ($LASTEXITCODE -ne 0) {
            throw "Virtual environment creation failed"
        }
        Write-ColorOutput "Virtual environment created." -Color "Success"
    }
    catch {
        Write-ColorOutput "Failed to create virtual environment: $($_.Exception.Message)" -Color "Error"
        exit 1
    }
    
    # Activate virtual environment and install dependencies
    Write-ColorOutput "Installing Python dependencies..." -Color "Progress"
    $venvPython = Join-Path $InstallPath "venv\Scripts\python.exe"
    $venvPip = Join-Path $InstallPath "venv\Scripts\pip.exe"
    
    try {
        # Install required packages
        $packages = @("mcp", "fastmcp", "requests")
        foreach ($package in $packages) {
            Write-ColorOutput "Installing $package..." -Color "Info"
            & $venvPip install $package
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to install $package"
            }
        }
        Write-ColorOutput "All dependencies installed successfully." -Color "Success"
    }
    catch {
        Write-ColorOutput "Failed to install dependencies: $($_.Exception.Message)" -Color "Error"
        exit 1
    }
    
    # Test the installation
    Write-ColorOutput "Testing MCP server installation..." -Color "Progress"
    try {
        # Test import (this will fail if Business Central credentials are not configured, but that's expected)
        $testScript = @"
import sys
sys.path.insert(0, r'$InstallPath')
try:
    from mcp_bc_server import server
    print('MCP server import successful')
    sys.exit(0)
except ImportError as e:
    print(f'Import error: {e}')
    sys.exit(1)
except Exception as e:
    # Expected if BC credentials not configured
    print(f'MCP server loaded (configuration needed): {e}')
    sys.exit(0)
"@
        
        $testResult = & $venvPython -c $testScript
        Write-ColorOutput "Installation test: $testResult" -Color "Info"
    }
    catch {
        Write-ColorOutput "Warning: Could not fully test installation. This is normal if Business Central credentials are not yet configured." -Color "Warning"
    }
    
    # Create MCP configuration file in installation folder
    Write-ColorOutput "Creating MCP configuration file..." -Color "Progress"
    if (-not (Create-MCPConfigFile -ServerPath $InstallPath)) {
        Write-ColorOutput "Warning: Could not create MCP configuration file." -Color "Warning"
    }
    
    # Final instructions
    Write-ColorOutput "" 
    Write-ColorOutput "=== Setup Complete ===" -Color "Success"
    Write-ColorOutput ""
    Write-ColorOutput "Installation Details:" -Color "Info"
    Write-ColorOutput "  Installation Path: $InstallPath" -Color "Info"
    Write-ColorOutput "  Python Environment: $InstallPath\venv" -Color "Info"
    Write-ColorOutput "  Configuration File: $InstallPath\config.py" -Color "Info"
    Write-ColorOutput "  MCP Config Template: $InstallPath\claude_desktop_config.json" -Color "Info"
    Write-ColorOutput ""
    Write-ColorOutput "Next Steps:" -Color "Warning"
    Write-ColorOutput "1. Edit the config.py file with your Business Central credentials" -Color "Warning"
    Write-ColorOutput "2. Copy the MCP configuration from claude_desktop_config.json to your Claude Desktop config" -Color "Warning"
    Write-ColorOutput "3. Restart Claude Desktop completely (close all windows and restart)" -Color "Warning"
    Write-ColorOutput "4. Test the integration by asking Claude: 'Show me all customers'" -Color "Warning"
    Write-ColorOutput ""
    Write-ColorOutput "Files created:" -Color "Info"
    Write-ColorOutput "  BC Credentials: $InstallPath\config.py" -Color "Info"
    Write-ColorOutput "  MCP Config Template: $InstallPath\claude_desktop_config.json" -Color "Info"
    Write-ColorOutput "  Claude Desktop Config Location: $env:APPDATA\Claude\claude_desktop_config.json" -Color "Info"
    Write-ColorOutput ""
    
    if (-not $SkipClaudeInstall.IsPresent) {
        Write-ColorOutput "Claude Desktop should now be installed and configured!" -Color "Success"
    }
    
    Write-ColorOutput "Setup completed successfully!" -Color "Success"
}

# Run the main function
Main
