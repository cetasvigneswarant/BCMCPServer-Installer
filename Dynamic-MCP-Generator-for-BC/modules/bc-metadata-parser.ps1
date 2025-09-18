# bc-metadata-parser.ps1
# Business Central Metadata Parser Module

function Get-BCMetadata {
    param(
        [hashtable]$Config
    )
    
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

function Get-BCAccessToken {
    param(
        [hashtable]$Config
    )
    
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

function Parse-BCMetadata {
    param(
        [string]$MetadataXml
    )
    
    Write-ColorOutput "Parsing Business Central metadata..." -Color "Info"
    
    # Define the entities we know from the metadata with their capabilities
    $knownEntities = @(
        @{ Name = "companies"; Insertable = $false; Updatable = $false; Deletable = $false; Description = "Company information (read-only)" },
        @{ Name = "items"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Product/inventory management" },
        @{ Name = "customers"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Customer management" },
        @{ Name = "vendors"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Vendor/supplier management" },
        @{ Name = "salesOrders"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Sales order processing" },
        @{ Name = "salesOrderLines"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Sales order line items" },
        @{ Name = "salesInvoices"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Sales invoice management" },
        @{ Name = "salesInvoiceLines"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Sales invoice line items" },
        @{ Name = "salesQuotes"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Sales quotation management" },
        @{ Name = "salesQuoteLines"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Sales quote line items" },
        @{ Name = "salesCreditMemos"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Sales credit memo management" },
        @{ Name = "purchaseOrders"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Purchase order processing" },
        @{ Name = "purchaseOrderLines"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Purchase order line items" },
        @{ Name = "purchaseInvoices"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Purchase invoice management" },
        @{ Name = "generalLedgerEntries"; Insertable = $false; Updatable = $false; Deletable = $false; Description = "General ledger entries (read-only)" },
        @{ Name = "itemLedgerEntries"; Insertable = $false; Updatable = $false; Deletable = $false; Description = "Item ledger entries (read-only)" },
        @{ Name = "employees"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Employee management" },
        @{ Name = "timeRegistrationEntries"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Time registration/tracking" },
        @{ Name = "projects"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Project management" },
        @{ Name = "bankAccounts"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Bank account management" },
        @{ Name = "currencies"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Currency management" },
        @{ Name = "paymentTerms"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Payment terms setup" },
        @{ Name = "paymentMethods"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Payment methods setup" },
        @{ Name = "shipmentMethods"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Shipment methods setup" },
        @{ Name = "locations"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Warehouse/location management" },
        @{ Name = "unitsOfMeasure"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Units of measure setup" },
        @{ Name = "itemCategories"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Item category classification" },
        @{ Name = "taxGroups"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Tax group configuration" },
        @{ Name = "dimensions"; Insertable = $false; Updatable = $false; Deletable = $false; Description = "Dimension setup (read-only)" },
        @{ Name = "dimensionValues"; Insertable = $false; Updatable = $false; Deletable = $false; Description = "Dimension values (read-only)" },
        @{ Name = "contacts"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Contact management" },
        @{ Name = "opportunities"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Sales opportunity tracking" },
        @{ Name = "customerPayments"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Customer payment processing" },
        @{ Name = "vendorPayments"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "Vendor payment processing" },
        @{ Name = "journals"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "General journal management" },
        @{ Name = "journalLines"; Insertable = $true; Updatable = $true; Deletable = $true; Description = "General journal line entries" }
    )
    
    # In a full implementation, we would parse the XML to extract this information
    # For now, we'll use the predefined entities from the metadata analysis
    
    Write-ColorOutput "Identified $($knownEntities.Count) Business Central entities" -Color "Success"
    
    return $knownEntities
}

function Show-EntitySelection {
    param(
        [array]$Entities
    )
    
    Write-ColorOutput ""
    Write-ColorOutput "Available Business Central Entities:" -Color "Progress"
    Write-ColorOutput ""
    
    # Group entities by category for better presentation
    $coreEntities = @()
    $salesEntities = @()
    $purchaseEntities = @()
    $financeEntities = @()
    $setupEntities = @()
    $hrEntities = @()
    
    foreach ($entity in $Entities) {
        switch -Wildcard ($entity.Name) {
            "sales*" { $salesEntities += $entity }
            "purchase*" { $purchaseEntities += $entity }
            "*ledger*" { $financeEntities += $entity }
            "general*" { $financeEntities += $entity }
            "employee*" { $hrEntities += $entity }
            "time*" { $hrEntities += $entity }
            "payment*" { $setupEntities += $entity }
            "shipment*" { $setupEntities += $entity }
            "currency*" { $setupEntities += $entity }
            "tax*" { $setupEntities += $entity }
            "unit*" { $setupEntities += $entity }
            "dimension*" { $setupEntities += $entity }
            "location*" { $setupEntities += $entity }
            default { $coreEntities += $entity }
        }
    }
    
    $index = 1
    $entityMap = @{}
    
    # Display core entities first
    if ($coreEntities.Count -gt 0) {
        Write-ColorOutput "Core Business Entities:" -Color "Info"
        foreach ($entity in $coreEntities) {
            $crudInfo = Get-CRUDString $entity
            Write-ColorOutput "  $index. $($entity.Name) - $($entity.Description) $crudInfo" -Color "White"
            $entityMap[$index] = $entity
            $index++
        }
        Write-ColorOutput ""
    }
    
    # Display sales entities
    if ($salesEntities.Count -gt 0) {
        Write-ColorOutput "Sales & Marketing:" -Color "Info"
        foreach ($entity in $salesEntities) {
            $crudInfo = Get-CRUDString $entity
            Write-ColorOutput "  $index. $($entity.Name) - $($entity.Description) $crudInfo" -Color "White"
            $entityMap[$index] = $entity
            $index++
        }
        Write-ColorOutput ""
    }
    
    # Display purchase entities
    if ($purchaseEntities.Count -gt 0) {
        Write-ColorOutput "Purchasing & Procurement:" -Color "Info"
        foreach ($entity in $purchaseEntities) {
            $crudInfo = Get-CRUDString $entity
            Write-ColorOutput "  $index. $($entity.Name) - $($entity.Description) $crudInfo" -Color "White"
            $entityMap[$index] = $entity
            $index++
        }
        Write-ColorOutput ""
    }
    
    # Display finance entities
    if ($financeEntities.Count -gt 0) {
        Write-ColorOutput "Finance & Accounting:" -Color "Info"
        foreach ($entity in $financeEntities) {
            $crudInfo = Get-CRUDString $entity
            Write-ColorOutput "  $index. $($entity.Name) - $($entity.Description) $crudInfo" -Color "White"
            $entityMap[$index] = $entity
            $index++
        }
        Write-ColorOutput ""
    }
    
    # Display HR entities
    if ($hrEntities.Count -gt 0) {
        Write-ColorOutput "Human Resources:" -Color "Info"
        foreach ($entity in $hrEntities) {
            $crudInfo = Get-CRUDString $entity
            Write-ColorOutput "  $index. $($entity.Name) - $($entity.Description) $crudInfo" -Color "White"
            $entityMap[$index] = $entity
            $index++
        }
        Write-ColorOutput ""
    }
    
    # Display setup entities
    if ($setupEntities.Count -gt 0) {
        Write-ColorOutput "Setup & Configuration:" -Color "Info"
        foreach ($entity in $setupEntities) {
            $crudInfo = Get-CRUDString $entity
            Write-ColorOutput "  $index. $($entity.Name) - $($entity.Description) $crudInfo" -Color "White"
            $entityMap[$index] = $entity
            $index++
        }
        Write-ColorOutput ""
    }
    
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

function Get-CRUDString {
    param($Entity)
    
    $crud = @()
    if ($Entity.Insertable) { $crud += "Create" }
    $crud += "Read"  # All entities support read
    if ($Entity.Updatable) { $crud += "Update" }
    if ($Entity.Deletable) { $crud += "Delete" }
    
    return "($($crud -join ', '))"
}