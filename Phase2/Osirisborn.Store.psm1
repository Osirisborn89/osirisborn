#requires -Version 7.0
using namespace System.Security.Cryptography
$Script:Root = Join-Path $env:USERPROFILE "Osirisborn\MythicCore"
$Script:Data = Join-Path $Script:Root "data\store.plasma"
$Script:Mirror = Join-Path $Script:Root "www\mirror.json"
$Script:Secrets = Join-Path $Script:Root ".secrets"
$Script:KeyFile = Join-Path $Script:Secrets "store.key"
$Script:SaltFile = Join-Path $Script:Secrets "store.salt"

function Get-OsKey {
    $keyB64 = Get-Content -Raw -Path $Script:KeyFile
    [Convert]::FromBase64String($keyB64)
}
function Protect-Json([string]$json) {
    $key = Get-OsKey
    $nonce = New-Object byte[] 12; [RandomNumberGenerator]::Create().GetBytes($nonce)
    $plain = [Text.Encoding]::UTF8.GetBytes($json)
    $tag = New-Object byte[] 16
    $cipher = New-Object byte[] $plain.Length
    $aes = [AesGcm]::new($key)
    $aes.Encrypt($nonce,$plain,$cipher,$tag)
    # [nonce|tag|cipher] => base64
    [Convert]::ToBase64String($nonce + $tag + $cipher)
}
function Unprotect-Json([string]$b64) {
    if ([string]::IsNullOrWhiteSpace($b64)) { return "{}" }
    $all = [Convert]::FromBase64String($b64)
    $nonce = $all[0..11]
    $tag   = $all[12..27]
    $cipher= $all[28..($all.Length-1)]
    $key = Get-OsKey
    $plain = New-Object byte[] $cipher.Length
    $aes = [AesGcm]::new($key)
    $aes.Decrypt($nonce,$cipher,$tag,$plain)
    [Text.Encoding]::UTF8.GetString($plain)
}

function Get-OsStore {
    if (-not (Test-Path $Script:Data)) { throw "Store not initialized." }
    $b64 = Get-Content -Raw -Path $Script:Data
    if ([string]::IsNullOrWhiteSpace($b64)) { return @{} }
    $json = Unprotect-Json $b64
    $obj = $json | ConvertFrom-Json -Depth 10
    return $obj
}

function Save-OsStore([object]$Store) {
    if (-not $Store) { throw "Save-OsStore: input is null" }

    # Ensure meta exists on both hashtable and PSCustomObject
    $hasMeta = $false
    if ($Store -is [hashtable]) { $hasMeta = $Store.ContainsKey('meta') }
    else { $hasMeta = $Store.PSObject.Properties.Match('meta').Count -gt 0 }

    if (-not $hasMeta -or -not $Store.meta) {
        if ($Store -is [hashtable]) { $Store['meta'] = @{} }
        else { $Store | Add-Member -NotePropertyName meta -NotePropertyValue @{} -Force }
    }

    # Update timestamp
    if ($Store -is [hashtable]) { $Store['meta']['lastWrite'] = (Get-Date).ToString("o") }
    else { $Store.meta.lastWrite = (Get-Date).ToString("o") }

    # Serialize and encrypt
    $json = $Store | ConvertTo-Json -Depth 10
    $b64 = Protect-Json $json
    $b64 | Out-File -FilePath $Script:Data -Encoding ASCII

    # Mirror (non-sensitive)
    try {
        $alias = $Store.user.alias
        $rank  = $Store.user.rank
        $xp    = [int]$Store.user.xp
        $pct   = [int]($Store.user.progressPct ?? 0)
        $summary = @{
            user = @{ alias=$alias; rank=$rank; xp=$xp; progressPct=$pct }
            updated = (Get-Date).ToString("o")
        } | ConvertTo-Json -Depth 5
        $summary | Out-File -FilePath $Script:Mirror -Encoding UTF8
    } catch {
        # ignore mirror failures
    }
}


function Initialize-OsStore {
    if (Test-Path $Script:Data) { return }
    $seed = @{
      user = @{ alias="Osirisborn"; rank="Initiate"; xp=0; progressPct=0; createdAt=(Get-Date).ToString("o") }
      settings = @{ theme="neon-purple"; ambientMode="Rainy City"; privacy=@{ lockOnExit=$true } }
      missions = @{ completed=@(); inProgress=@() }
      meta = @{ schemaVersion=1; lastWrite=(Get-Date).ToString("o") }
    }
    Save-OsStore $seed
}

function Backup-OsStore {
    $bkDir = Join-Path $Script:Root "backups"
    if (-not (Test-Path $bkDir)) { New-Item -ItemType Directory -Path $bkDir | Out-Null }
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $dest = Join-Path $bkDir "store-$stamp.plasma"
    Copy-Item -Path $Script:Data -Destination $dest -Force
    Write-Output $dest
}

function Restore-OsStore([string]$BackupFile) {
    if (-not (Test-Path $BackupFile)) { throw "Backup not found: $BackupFile" }
    Copy-Item -Path $BackupFile -Destination $Script:Data -Force
}

Export-ModuleMember -Function Initialize-OsStore,Get-OsStore,Save-OsStore,Backup-OsStore,Restore-OsStore
