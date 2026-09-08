# C01 I015. Private redirected transport only; no real store is configured here.
# DPAPI is bound to the current Windows user and nominal plan/account/purpose.
param()

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
$InformationPreference = 'SilentlyContinue'
Set-StrictMode -Version Latest

function Stop-Store([string] $Code) {
    throw [System.InvalidOperationException]::new($Code)
}

function Assert-Fields($Value, [string[]] $Names) {
    if ($Value -isnot [System.Collections.IDictionary] -or $Value.Count -ne $Names.Count) {
        Stop-Store 'SECRET_STORE_INVALID_REQUEST'
    }
    foreach ($name in $Names) {
        if (@($Value.Keys) -cnotcontains $name) { Stop-Store 'SECRET_STORE_INVALID_REQUEST' }
    }
}

function Assert-UniqueJsonProperties([System.Text.Json.JsonElement] $Element) {
    if ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Object) {
        $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($property in $Element.EnumerateObject()) {
            if (-not $seen.Add($property.Name)) { Stop-Store 'SECRET_STORE_INVALID_REQUEST' }
            Assert-UniqueJsonProperties $property.Value
        }
    } elseif ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Array) {
        foreach ($item in $Element.EnumerateArray()) { Assert-UniqueJsonProperties $item }
    }
}

function Convert-StrictJson([byte[]] $Bytes) {
    $text = $script:Utf8.GetString($Bytes)
    $document = [System.Text.Json.JsonDocument]::Parse($text)
    try { Assert-UniqueJsonProperties $document.RootElement } finally { $document.Dispose() }
    return ConvertFrom-Json -InputObject $text -AsHashtable -Depth 16
}

function Assert-Receipt($Receipt, [string] $PlanId, [string] $AuthUserId) {
    Assert-Fields $Receipt @('planId', 'authUserId', 'password', 'state')
    if ($Receipt.planId -isnot [string] -or $Receipt.authUserId -isnot [string] -or
        $Receipt.state -isnot [string] -or $Receipt.planId -cne $PlanId -or
        $Receipt.authUserId -cne $AuthUserId -or $Receipt.state -cne 'reserved' -or
        $Receipt.password -isnot [string] -or
        $Receipt.password.Length -lt 32 -or $Receipt.password.Length -gt 256 -or
        $Receipt.password -match '[\x00-\x1f\x7f]') {
        Stop-Store 'SECRET_STORE_INVALID_REQUEST'
    }
}

function Get-AttributesOrNull([string] $Path) {
    try { return [System.IO.File]::GetAttributes($Path) }
    catch [System.IO.FileNotFoundException] { return $null }
    catch [System.IO.DirectoryNotFoundException] { return $null }
}

function Assert-PathAncestors([string] $Directory) {
    $cursor = $Directory
    while ($null -ne $cursor) {
        $attributes = Get-AttributesOrNull $cursor
        if ($null -ne $attributes -and
            (($attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0 -or
             ($attributes -band [System.IO.FileAttributes]::Directory) -eq 0)) {
            Stop-Store 'SECRET_STORE_INSECURE_DIRECTORY'
        }
        if ($null -ne (Get-AttributesOrNull ([System.IO.Path]::Combine($cursor, '.git')))) {
            Stop-Store 'SECRET_STORE_INSECURE_DIRECTORY'
        }
        $parent = [System.IO.Directory]::GetParent($cursor)
        $cursor = if ($null -eq $parent) { $null } else { $parent.FullName }
    }
}

function New-PrivateSecurity([bool] $Directory) {
    $security = if ($Directory) {
        [System.Security.AccessControl.DirectorySecurity]::new()
    } else { [System.Security.AccessControl.FileSecurity]::new() }
    $security.SetOwner($script:CurrentSid)
    $security.SetAccessRuleProtection($true, $false)
    $inheritance = if ($Directory) {
        [System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
    } else { [System.Security.AccessControl.InheritanceFlags]::None }
    $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
        $script:CurrentSid, [System.Security.AccessControl.FileSystemRights]::FullControl,
        $inheritance, [System.Security.AccessControl.PropagationFlags]::None,
        [System.Security.AccessControl.AccessControlType]::Allow)
    $security.AddAccessRule($rule)
    return $security
}

function Assert-PrivateAccess([string] $Path, [bool] $Directory) {
    $attributes = Get-AttributesOrNull $Path
    if ($null -eq $attributes -or ($attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0 -or
        ((($attributes -band [System.IO.FileAttributes]::Directory) -ne 0) -ne $Directory)) {
        Stop-Store 'SECRET_STORE_INSECURE_DIRECTORY'
    }
    $security = if ($Directory) {
        [System.IO.FileSystemAclExtensions]::GetAccessControl([System.IO.DirectoryInfo]::new($Path))
    } else {
        [System.IO.FileSystemAclExtensions]::GetAccessControl([System.IO.FileInfo]::new($Path))
    }
    if (-not $security.AreAccessRulesProtected -or
        $security.GetOwner([System.Security.Principal.SecurityIdentifier]).Value -cne $script:CurrentSid.Value) {
        Stop-Store 'SECRET_STORE_INSECURE_DIRECTORY'
    }
    $rules = @($security.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))
    if ($rules.Count -ne 1) { Stop-Store 'SECRET_STORE_INSECURE_DIRECTORY' }
    $rule = $rules[0]
    $expectedInheritance = if ($Directory) {
        [System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
    } else { [System.Security.AccessControl.InheritanceFlags]::None }
    if ($rule.IdentityReference.Value -cne $script:CurrentSid.Value -or $rule.IsInherited -or
        $rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow -or
        $rule.FileSystemRights -ne [System.Security.AccessControl.FileSystemRights]::FullControl -or
        $rule.InheritanceFlags -ne $expectedInheritance -or
        $rule.PropagationFlags -ne [System.Security.AccessControl.PropagationFlags]::None) {
        Stop-Store 'SECRET_STORE_INSECURE_DIRECTORY'
    }
}

function Assert-StoreDirectory([string] $Directory, [bool] $Create) {
    Assert-PathAncestors $Directory
    if ($null -eq (Get-AttributesOrNull $Directory)) {
        if (-not $Create) { return $false }
        $parent = [System.IO.Directory]::GetParent($Directory)
        if ($null -eq $parent -or -not $parent.Exists) { Stop-Store 'SECRET_STORE_INSECURE_DIRECTORY' }
        # Create with the private descriptor; never repair an existing directory.
        [System.IO.FileSystemAclExtensions]::Create(
            [System.IO.DirectoryInfo]::new($Directory), (New-PrivateSecurity $true))
    }
    Assert-PrivateAccess $Directory $true
    return $true
}

function Get-Entropy([string] $Purpose) {
    return ,$script:Utf8.GetBytes("C01-AUTH-PERSONAS-v1|$($script:Request.planId)|$($script:Request.authUserId)|$Purpose")
}

function Read-Encrypted([string] $Path, [string] $Purpose) {
    Assert-PrivateAccess $Path $false
    $stream = [System.IO.FileStream]::new($Path, [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
    try {
        if ($stream.Length -le 0 -or $stream.Length -gt 65536) { Stop-Store 'SECRET_STORE_CORRUPT' }
        $bytes = [byte[]]::new([int]$stream.Length)
        $offset = 0
        while ($offset -lt $bytes.Length) {
            $count = $stream.Read($bytes, $offset, $bytes.Length - $offset)
            if ($count -eq 0) { Stop-Store 'SECRET_STORE_CORRUPT' }
            $offset += $count
        }
    } finally { $stream.Dispose() }
    $plain = $null
    try {
        $plain = [System.Security.Cryptography.ProtectedData]::Unprotect(
            $bytes, (Get-Entropy $Purpose), [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
        $value = Convert-StrictJson $plain
        return @{ value = $value; hash = [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant() }
    } catch { Stop-Store 'SECRET_STORE_CORRUPT' }
    finally { if ($null -ne $plain) { [System.Array]::Clear($plain, 0, $plain.Length) } }
}

function Publish-Encrypted([string] $Path, $Value, [string] $Purpose) {
    [void](Assert-StoreDirectory $script:Directory $false)
    if ($null -ne (Get-AttributesOrNull $Path)) { return $false }
    $plain = $script:Utf8.GetBytes((ConvertTo-Json -InputObject $Value -Depth 8 -Compress))
    try {
        $encrypted = [System.Security.Cryptography.ProtectedData]::Protect(
            $plain, (Get-Entropy $Purpose), [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    } finally { [System.Array]::Clear($plain, 0, $plain.Length) }
    $temporary = [System.IO.Path]::Combine($script:Directory,
        "$($script:Request.authUserId).$([guid]::NewGuid().ToString('N')).pending.dpapi")
    $created = $false
    try {
        $stream = [System.IO.FileSystemAclExtensions]::Create(
            [System.IO.FileInfo]::new($temporary), [System.IO.FileMode]::CreateNew,
            [System.Security.AccessControl.FileSystemRights]::FullControl,
            [System.IO.FileShare]::None, 4096, [System.IO.FileOptions]::WriteThrough,
            (New-PrivateSecurity $false))
        $created = $true
        try {
            $stream.Write($encrypted, 0, $encrypted.Length)
            $stream.Flush($true)
        } finally { $stream.Dispose() }
        [void](Assert-StoreDirectory $script:Directory $false)
        try { [System.IO.File]::Move($temporary, $Path, $false) }
        catch [System.IO.IOException] {
            if ($null -ne (Get-AttributesOrNull $Path)) { return $false }
            throw
        }
        Assert-PrivateAccess $Path $false
        return $true
    } finally {
        # Only this process's unique encrypted temporary file; no recursive cleanup.
        if ($created -and [System.IO.File]::Exists($temporary)) { [System.IO.File]::Delete($temporary) }
    }
}

function Assert-Marker($Marker, [string] $ReceiptHash) {
    try {
        Assert-Fields $Marker @('planId', 'authUserId', 'receiptHash', 'state')
        if ($Marker.planId -isnot [string] -or $Marker.authUserId -isnot [string] -or
            $Marker.receiptHash -isnot [string] -or $Marker.state -isnot [string] -or
            $Marker.planId -cne $script:Request.planId -or $Marker.authUserId -cne $script:Request.authUserId -or
            $Marker.receiptHash -cne $ReceiptHash -or $Marker.state -cne 'created') {
            Stop-Store 'SECRET_STORE_CORRUPT'
        }
    } catch { Stop-Store 'SECRET_STORE_CORRUPT' }
}

try {
    if (-not [System.Console]::IsInputRedirected -or -not [System.Console]::IsOutputRedirected) {
        Stop-Store 'SECRET_STORE_CHANNEL_REQUIRED'
    }
    if ($PSVersionTable.PSVersion.Major -lt 7 -or -not $IsWindows -or $args.Count -ne 0) {
        Stop-Store 'SECRET_STORE_INVALID_REQUEST'
    }
    $script:Utf8 = [System.Text.UTF8Encoding]::new($false, $true)
    $script:CurrentSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
    $inputStream = [System.Console]::OpenStandardInput()
    $buffer = [byte[]]::new(4096)
    $inputBytes = [System.IO.MemoryStream]::new()
    try {
        while (($count = $inputStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            if ($inputBytes.Length + $count -gt 65536) { Stop-Store 'SECRET_STORE_INVALID_REQUEST' }
            $inputBytes.Write($buffer, 0, $count)
        }
        try { $script:Request = Convert-StrictJson $inputBytes.ToArray() }
        catch { Stop-Store 'SECRET_STORE_INVALID_REQUEST' }
    } finally { $inputBytes.Dispose(); [System.Array]::Clear($buffer, 0, $buffer.Length) }
    if ($script:Request -isnot [System.Collections.IDictionary]) { Stop-Store 'SECRET_STORE_INVALID_REQUEST' }
    $operation = $script:Request['operation']
    $fields = @('version', 'operation', 'directory', 'planId', 'authUserId')
    if ($operation -ceq 'reserve') { $fields += 'receipt' }
    Assert-Fields $script:Request $fields
    $uuidPattern = '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    if (($script:Request.version -isnot [long] -and $script:Request.version -isnot [int]) -or
        $script:Request.version -ne 1 -or @('read', 'reserve', 'mark-created') -cnotcontains $operation -or
        $script:Request.planId -isnot [string] -or $script:Request.planId -cnotmatch $uuidPattern -or
        $script:Request.authUserId -isnot [string] -or $script:Request.authUserId -cnotmatch $uuidPattern -or
        $script:Request.directory -isnot [string] -or
        $script:Request.directory -notmatch '^[a-zA-Z]:[\\/]' -or
        $script:Request.directory -match '[\x00-\x1f\x7f]' -or
        $script:Request.directory.Substring(2).Contains(':')) {
        Stop-Store 'SECRET_STORE_INVALID_REQUEST'
    }
    if ($operation -ceq 'reserve') {
        Assert-Receipt $script:Request.receipt $script:Request.planId $script:Request.authUserId
    }
    $script:Directory = [System.IO.Path]::TrimEndingDirectorySeparator(
        [System.IO.Path]::GetFullPath($script:Request.directory))
    if ($script:Directory -eq [System.IO.Path]::GetPathRoot($script:Directory)) {
        Stop-Store 'SECRET_STORE_INSECURE_DIRECTORY'
    }
    $exists = Assert-StoreDirectory $script:Directory ($operation -ceq 'reserve')
    $reservePath = [System.IO.Path]::Combine($script:Directory, "$($script:Request.authUserId).reserve.dpapi")
    $markerPath = [System.IO.Path]::Combine($script:Directory, "$($script:Request.authUserId).created.dpapi")
    $response = [ordered]@{
        version = 1; ok = $true; operation = $operation
        planId = $script:Request.planId; authUserId = $script:Request.authUserId
    }
    if ($operation -ceq 'reserve') {
        if ($null -ne (Get-AttributesOrNull $reservePath) -or $null -ne (Get-AttributesOrNull $markerPath) -or
            -not (Publish-Encrypted $reservePath $script:Request.receipt 'reserve')) {
            Stop-Store 'SECRET_STORE_COLLISION'
        }
    } elseif (-not $exists -or $null -eq (Get-AttributesOrNull $reservePath)) {
        if ($null -ne (Get-AttributesOrNull $markerPath)) { Stop-Store 'SECRET_STORE_CORRUPT' }
        if ($operation -cne 'read') { Stop-Store 'SECRET_STORE_MISSING_RECEIPT' }
        $response['receipt'] = $null
    } else {
        $stored = Read-Encrypted $reservePath 'reserve'
        try { Assert-Receipt $stored.value $script:Request.planId $script:Request.authUserId }
        catch { Stop-Store 'SECRET_STORE_CORRUPT' }
        if ($operation -ceq 'mark-created' -and $null -eq (Get-AttributesOrNull $markerPath)) {
            $marker = @{
                planId = $script:Request.planId; authUserId = $script:Request.authUserId
                receiptHash = $stored.hash; state = 'created'
            }
            # Concurrent valid markers reconcile; a marker never rewrites the receipt.
            [void](Publish-Encrypted $markerPath $marker 'created')
        }
        $hasMarker = $null -ne (Get-AttributesOrNull $markerPath)
        if ($hasMarker) { Assert-Marker (Read-Encrypted $markerPath 'created').value $stored.hash }
        elseif ($operation -ceq 'mark-created') { Stop-Store 'SECRET_STORE_IO' }
        if ($operation -ceq 'read') {
            $receipt = $stored.value
            if ($hasMarker) { $receipt.state = 'created' }
            $response['receipt'] = $receipt
        }
    }
    [System.Console]::Out.WriteLine((ConvertTo-Json -InputObject $response -Depth 8 -Compress))
    exit 0
} catch {
    $allowed = @('SECRET_STORE_CHANNEL_REQUIRED', 'SECRET_STORE_INVALID_REQUEST',
        'SECRET_STORE_INSECURE_DIRECTORY', 'SECRET_STORE_COLLISION', 'SECRET_STORE_CORRUPT',
        'SECRET_STORE_MISSING_RECEIPT', 'SECRET_STORE_IO')
    $code = if ($allowed -ccontains $_.Exception.Message) { $_.Exception.Message } else { 'SECRET_STORE_IO' }
    [System.Console]::Out.WriteLine((ConvertTo-Json -Compress -InputObject @{
        version = 1; ok = $false; code = $code
    }))
    exit 1
}
