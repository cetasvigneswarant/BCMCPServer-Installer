# system-installer.ps1
# System Installation Module for Dynamic MCP Server

function Install-Prerequisites {
    param(
        [string]$InstallPath,
        [switch]$SkipClaude
    )
    
    Write-ColorOutput "Installing system prerequisites..." -Color "Progress"
    
    try {
        # Check/Install Claude Desktop
        if (-not $SkipClaude.IsPresent) {
            $claudeResult = Install-ClaudeDesktopIfNeeded
            if (-not $claudeResult.Success) {
                Write-ColorOutput "Claude Desktop installation issue: $($claudeResult.Message)" -Color "Warning"
            }
        }
        
        # Check/Install Python
        $pythonResult = Install-PythonIfNeeded
        if (-not $pythonResult.Success) {
            return @{ Success = $false; Error = "Python installation failed: $($pythonResult.Error)" }
        }
        
        # Create virtual environment
        $venvResult = Create-VirtualEnvironment -InstallPath $InstallPath
        if (-not $venvResult.Success) {
            return @{ Success = $false; Error = "Virtual environment creation failed: $($venvResult.Error)" }
        }
        
        # Install Python dependencies
        $depsResult = Install-PythonDependencies -InstallPath $InstallPath
        if (-not $depsResult.Success) {
            return @{ Success = $false; Error = "Dependency installation failed: $($depsResult.Error)" }
        }
        
        # Test the installation
        $testResult = Test-MCPInstallation -InstallPath $InstallPath
        if (-not $testResult.Success) {
            Write-ColorOutput "Installation test warning: $($testResult.Message)" -Color "Warning"
        }
        
        return @{ Success = $true; Message = "All prerequisites installed successfully" }
        
    } catch {
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Install-ClaudeDesktopIfNeeded {
    Write-ColorOutput "Checking for Claude Desktop installation..." -Color "Info"
    
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
        return @{ Success = $true; Message = "Claude Desktop is already installed" }
    }
    
    Write-ColorOutput "Claude Desktop not found. Manual installation required." -Color "Warning"
    Write-ColorOutput "Please download Claude Desktop from: https://claude.ai/download" -Color "Info"
    
    $response = Read-Host "Have you installed Claude Desktop? (y/n)"
    if ($response -match '^[Yy]') {
        return @{ Success = $true; Message = "User confirmed Claude Desktop installation" }
    } else {
        return @{ Success = $false; Message = "Claude Desktop installation incomplete - user can install manually later" }
    }
}

function Install-PythonIfNeeded {
    Write-ColorOutput "Checking for Python installation..." -Color "Info"
    
    try {
        $pythonVersion = & python --version 2>$null
        if ($pythonVersion -and $pythonVersion -match "Python (\d+\.\d+)") {
            $version = [version]$matches[1]
            if ($version -ge [version]"3.8") {
                Write-ColorOutput "Python found: $pythonVersion" -Color "Success"
                return @{ Success = $true }
            } else {
                Write-ColorOutput "Python version $pythonVersion is too old. Need Python 3.8+" -Color "Warning"
            }
        }
    } catch {
        Write-ColorOutput "Python not found or not accessible" -Color "Warning"
    }
    
    Write-ColorOutput "Installing Python..." -Color "Info"
    
    try {
        # Download Python installer
        $pythonUrl = "https://www.python.org/ftp/python/3.11.7/python-3.11.7-amd64.exe"
        $pythonInstaller = "$env:TEMP\python-installer.exe"
        
        Write-ColorOutput "Downloading Python installer..." -Color "Info"
        Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller -UseBasicParsing
        
        Write-ColorOutput "Installing Python (this may take a few minutes)..." -Color "Info"
        $installArgs = @("/quiet", "InstallAllUsers=0", "PrependPath=1", "Include_test=0", "Include_launcher=1")
        Start-Process -FilePath $pythonInstaller -ArgumentList $installArgs -Wait
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        # Clean up
        Remove-Item $pythonInstaller -Force -ErrorAction SilentlyContinue
        
        # Verify installation
        Start-Sleep -Seconds 3
        $pythonVersion = & python --version 2>$null
        if ($pythonVersion) {
            Write-ColorOutput "Python installation completed: $pythonVersion" -Color "Success"
            return @{ Success = $true }
        } else {
            return @{ Success = $false; Error = "Python installation verification failed" }
        }
        
    } catch {
        return @{ Success = $false; Error = "Python installation failed: $($_.Exception.Message)" }
    }
}

function Create-VirtualEnvironment {
    param([string]$InstallPath)
    
    Write-ColorOutput "Creating Python virtual environment..." -Color "Info"
    
    $venvPath = Join-Path $InstallPath "venv"
    
    try {
        Set-Location $InstallPath
        & python -m venv venv
        
        if ($LASTEXITCODE -eq 0 -and (Test-Path $venvPath)) {
            Write-ColorOutput "Virtual environment created successfully" -Color "Success"
            return @{ Success = $true }
        } else {
            return @{ Success = $false; Error = "Virtual environment creation failed with exit code: $LASTEXITCODE" }
        }
        
    } catch {
        return @{ Success = $false; Error = "Virtual environment creation failed: $($_.Exception.Message)" }
    }
}

function Install-PythonDependencies {
    param([string]$InstallPath)
    
    Write-ColorOutput "Installing Python dependencies..." -Color "Info"
    
    $venvPip = Join-Path $InstallPath "venv\Scripts\pip.exe"
    
    if (-not (Test-Path $venvPip)) {
        return @{ Success = $false; Error = "pip not found in virtual environment" }
    }
    
    $packages = @("mcp", "fastmcp", "requests")
    
    try {
        foreach ($package in $packages) {
            Write-ColorOutput "Installing $package..." -Color "Info"
            & $venvPip install $package --quiet
            if ($LASTEXITCODE -ne 0) {
                return @{ Success = $false; Error = "Failed to install $package" }
            }
        }
        
        Write-ColorOutput "All Python dependencies installed successfully" -Color "Success"
        return @{ Success = $true }
        
    } catch {
        return @{ Success = $false; Error = "Dependency installation failed: $($_.Exception.Message)" }
    }
}

function Test-MCPInstallation {
    param([string]$InstallPath)
    
    Write-ColorOutput "Testing MCP server installation..." -Color "Info"
    
    $venvPython = Join-Path $InstallPath "venv\Scripts\python.exe"
    $serverFile = Join-Path $InstallPath "dynamic_bc_mcp_server.py"
    
    if (-not (Test-Path $venvPython)) {
        return @{ Success = $false; Message = "Python virtual environment not found" }
    }
    
    if (-not (Test-Path $serverFile)) {
        return @{ Success = $false; Message = "MCP server file not found" }
    }
    
    try {
        # Test import capabilities
        $testScript = @"
import sys
sys.path.insert(0, r'$InstallPath')
try:
    # Test MCP imports
    from mcp.server.fastmcp import FastMCP
    import requests
    print('Core dependencies imported successfully')
    
    # Test server file import (will fail on BC auth, but import should work)
    try:
        import dynamic_bc_mcp_server
        print('MCP server file imported successfully')
    except Exception as e:
        if 'authenticate' in str(e).lower() or 'token' in str(e).lower():
            print('MCP server import successful (BC authentication needed)')
        else:
            print(f'MCP server import issue: {e}')
    
    sys.exit(0)
except ImportError as e:
    print(f'Import error: {e}')
    sys.exit(1)
except Exception as e:
    print(f'Test error: {e}')
    sys.exit(2)
"@
        
        $testResult = & $venvPython -c $testScript
        Write-ColorOutput "Installation test result: $testResult" -Color "Info"
        
        return @{ Success = $true; Message = "Installation test completed" }
        
    } catch {
        return @{ Success = $false; Message = "Installation test failed: $($_.Exception.Message)" }
    }
}

function Show-InstallationSummary {
    param(
        [string]$InstallPath,
        [array]$SelectedEntities
    )
    
    Write-ColorOutput ""
    Write-ColorOutput "=== Installation Summary ===" -Color "Success"
    Write-ColorOutput ""
    Write-ColorOutput "Installation Location: $InstallPath" -Color "Info"
    Write-ColorOutput "Generated Files:" -Color "Info"
    
    $files = @(
        "dynamic_bc_mcp_server.py",
        "config.py", 
        "claude_desktop_config.json",
        "venv\" 
    )
    
    foreach ($file in $files) {
        $filePath = Join-Path $InstallPath $file
        if (Test-Path $filePath) {
            Write-ColorOutput "  ✓ $file" -Color "Success"
        } else {
            Write-ColorOutput "  ✗ $file (missing)" -Color "Error"
        }
    }
    
    Write-ColorOutput ""
    Write-ColorOutput "Selected Business Central Entities: $($SelectedEntities.Count)" -Color "Info"
    foreach ($entity in $SelectedEntities) {
        $operations = @()
        if ($entity.Insertable) { $operations += "Create" }
        $operations += "Read"
        if ($entity.Updatable) { $operations += "Update" }
        if ($entity.Deletable) { $operations += "Delete" }
        
        Write-ColorOutput "  • $($entity.Name) ($($operations -join ', '))" -Color "Info"
    }
    
    Write-ColorOutput ""
    Write-ColorOutput "Next Steps:" -Color "Warning"
    Write-ColorOutput "1. Copy claude_desktop_config.json content to your Claude Desktop config" -Color "Warning"
    Write-ColorOutput "2. Restart Claude Desktop completely" -Color "Warning"
    Write-ColorOutput "3. Test with queries like 'Show me all customers' or 'Get items with filters'" -Color "Warning"
    Write-ColorOutput ""
}