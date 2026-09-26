<#
.SYNOPSIS
    dns-ai-proxy client for Windows.

.DESCRIPTION
    Points AI service names at the proxy by editing one marked block of the
    Windows hosts file. Nothing outside that block is touched, and a
    timestamped copy of the file is made before every change.

    The domain list is downloaded from the published URL on every run, so a
    name added on the server reaches you without re-downloading the client.
    If the list cannot be reached, the copy bundled in domains\fallback.txt
    is used instead.

    Works on Windows PowerShell 5.1 (the one that ships with Windows) as well
    as PowerShell 7.

.EXAMPLE
    .\dns-ai-proxy.ps1 enable
    .\dns-ai-proxy.ps1 disable
    .\dns-ai-proxy.ps1 status
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('enable', 'disable', 'status')]
    [string] $Command = 'status',

    # Entry node address. Override to use your own server.
    [string] $Entry = $(if ($env:DNS_AI_PROXY_ENTRY) { $env:DNS_AI_PROXY_ENTRY } else { '84.38.189.217' }),

    [string] $ListUrl = $(if ($env:DNS_AI_PROXY_LIST_URL) { $env:DNS_AI_PROXY_LIST_URL }
                          else { 'https://chimney.steep-man.ru/dns-ai-proxy/domains.txt' }),

    # Hosts file to edit. Point it somewhere else for a dry run.
    [string] $HostsPath = $(if ($env:DNS_AI_PROXY_HOSTS) { $env:DNS_AI_PROXY_HOSTS }
                            else { Join-Path $env:SystemRoot 'System32\drivers\etc\hosts' })
)

$ErrorActionPreference = 'Stop'

$BeginMark = '# >>> dns-ai-proxy: begin, do not edit by hand >>>'
$EndMark   = '# <<< dns-ai-proxy: end <<<'

# A list this short means the download was truncated or we were served
# something else entirely. Better the bundled copy than half a list in a
# system file.
$MinDomains = 20

$FallbackList = Join-Path (Split-Path -Parent $PSScriptRoot) 'domains\fallback.txt'

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-HostsEncoding {
    # The hosts file often carries a BOM, put there by other software.
    # Keep whatever is already in place: silently rewriting someone else's
    # file in a different encoding is not ours to do.
    param([Parameter(Mandatory)][string] $Path)
    $head = [byte[]]::new(3)
    $fs = [System.IO.File]::OpenRead($Path)
    try { $null = $fs.Read($head, 0, 3) } finally { $fs.Dispose() }
    $hasBom = ($head[0] -eq 0xEF -and $head[1] -eq 0xBB -and $head[2] -eq 0xBF)
    New-Object System.Text.UTF8Encoding($hasBom)
}

function Select-Domain {
    # Keep well-formed host names only; drop comments, blank lines, duplicates
    # and the leading-dot wildcards the proxy understands but hosts files do not.
    param([AllowEmptyCollection()][string[]] $Lines)
    $seen = New-Object System.Collections.Generic.HashSet[string]
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($raw in $Lines) {
        $line = ($raw -split '#')[0]
        # Trim the edges only. Stripping inner spaces would turn "a.com b.com"
        # into one name that passes the check.
        $line = $line.Trim()
        if (-not $line) { continue }
        if ($line.StartsWith('.')) { continue }
        if ($line -notmatch '^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$') { continue }
        if ($seen.Add($line)) { $out.Add($line) }
    }
    , $out
}

function Get-PublishedList {
    param([Parameter(Mandatory)][string] $Url)
    try {
        # Windows PowerShell 5.1 still defaults to TLS 1.0, which no current
        # server accepts. Ask for 1.2 explicitly.
        [Net.ServicePointManager]::SecurityProtocol =
            [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 20
        return ($response.Content -split "`r?`n")
    } catch {
        return $null
    }
}

function Resolve-DomainList {
    param([Parameter(Mandatory)][string] $Url)
    $raw = Get-PublishedList -Url $Url
    if ($raw) {
        $names = Select-Domain -Lines $raw
        if ($names.Count -ge $MinDomains) {
            Write-Host "list: $($names.Count) names from $Url"
            return $names
        }
    }
    if (-not (Test-Path -LiteralPath $FallbackList)) {
        throw "Could not download the list and there is no bundled copy at $FallbackList"
    }
    $names = Select-Domain -Lines ([System.IO.File]::ReadAllLines($FallbackList))
    if ($names.Count -lt $MinDomains) {
        throw "The bundled list at $FallbackList looks broken ($($names.Count) names)"
    }
    Write-Host "list: could not reach $Url, using the bundled copy ($($names.Count) names)"
    return $names
}

function Assert-BlockIntact {
    # A begin without an end means a hand edit or an interrupted run. Cutting
    # "everything to the end of file" would take the user's own lines with it.
    # Mandatory is deliberately absent here: PowerShell 5.1 rejects a string
    # array that contains an empty string, and a hosts file has those.
    param([AllowEmptyString()][AllowEmptyCollection()][string[]] $Lines,
          [Parameter(Mandatory)][string] $Path)
    $begins = @($Lines | Where-Object { $_ -eq $BeginMark }).Count
    $ends   = @($Lines | Where-Object { $_ -eq $EndMark }).Count
    if ($begins -ne $ends) {
        throw ("The dns-ai-proxy block in $Path is damaged: $begins begin marks, " +
               "$ends end marks. Nothing changed. Check the file, or restore one of " +
               "the $Path.bak-dns-ai-proxy-* copies.")
    }
}

function Remove-ProxyBlock {
    param([AllowEmptyString()][AllowEmptyCollection()][string[]] $Lines)
    $kept = New-Object System.Collections.Generic.List[string]
    $inside = $false
    foreach ($line in $Lines) {
        if ($line -eq $BeginMark) { $inside = $true; continue }
        if ($line -eq $EndMark)   { $inside = $false; continue }
        if (-not $inside) { $kept.Add($line) }
    }
    while ($kept.Count -gt 0 -and [string]::IsNullOrWhiteSpace($kept[$kept.Count - 1])) {
        $kept.RemoveAt($kept.Count - 1)
    }
    , $kept
}

function Backup-Hosts {
    param([Parameter(Mandatory)][string] $Path)
    $stamp = Get-Date -Format yyyyMMdd-HHmmss
    $backup = "$Path.bak-dns-ai-proxy-$stamp"
    # Two runs in the same second must not overwrite each other's copy.
    $n = 1
    while (Test-Path -LiteralPath $backup) {
        $backup = "$Path.bak-dns-ai-proxy-$stamp-$n"
        $n++
    }
    Copy-Item -LiteralPath $Path -Destination $backup
    $backup
}

function Write-HostsAtomic {
    # Write to a temporary file next to the original and swap it in one move.
    # A direct write truncates first, and an interruption there would leave the
    # machine with no hosts file.
    param([Parameter(Mandatory)][string] $Path,
          [AllowEmptyString()][AllowEmptyCollection()][string[]] $Lines,
          [Parameter(Mandatory)] $Encoding)
    $tmp = "$Path.dns-ai-proxy.tmp"
    [System.IO.File]::WriteAllLines($tmp, $Lines, $Encoding)
    try {
        # Replace keeps the original file's owner and permissions.
        [System.IO.File]::Replace($tmp, $Path, $null, $true)
    } catch {
        [System.IO.File]::WriteAllLines($Path, $Lines, $Encoding)
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
}

function Clear-DnsCache {
    try { ipconfig /flushdns | Out-Null } catch { }
}

function Show-Support {
    # Shown once, after a successful enable. The people who find this useful
    # are exactly the people who never see the repository page.
    Write-Host ""
    Write-Host "------------------------------------------------------------------------"
    Write-Host " Working for you? A star costs nothing and is the only metric we have:"
    Write-Host "   https://github.com/SteepMans/dns-ai-proxy" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " The exit servers are rented and paid for every month. If this is worth"
    Write-Host " a coffee to you:"
    Write-Host "   BTC   bc1qfkqmazqmg44uzk286j93f84dzecdarsf7nwxrj"
    Write-Host "   ETH   0xB193C1A2067a911C8df9dB7883C0a2993Ec2c05A   (also USDT ERC-20)"
    Write-Host "   TRX   TSeaXnbc8XVWdXg1RDCEVpqLUvsEakTcnz           (also USDT TRC-20)"
    Write-Host "   TON   UQCWcoMOvwc_2Q9c3bbLHWJA_PJoJK4xzRwK0mvYurGwHC7u   (USDT TON)"
    Write-Host "------------------------------------------------------------------------"
}

function Invoke-Enable {
    if (-not (Test-Admin)) { throw "This needs administrator rights. Run enable.bat, it asks for them itself." }
    if (-not (Test-Path -LiteralPath $HostsPath)) { throw "No hosts file at $HostsPath" }

    $lines = [System.IO.File]::ReadAllLines($HostsPath)
    Assert-BlockIntact -Lines $lines -Path $HostsPath

    $domains = Resolve-DomainList -Url $ListUrl
    $encoding = Get-HostsEncoding -Path $HostsPath
    $backup = Backup-Hosts -Path $HostsPath

    $out = Remove-ProxyBlock -Lines $lines
    $out.Add($BeginMark)
    $out.Add("# enabled $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $($domains.Count) names -> $Entry")
    foreach ($d in $domains) { $out.Add("$Entry`t$d") }
    $out.Add($EndMark)

    Write-HostsAtomic -Path $HostsPath -Lines $out -Encoding $encoding
    Clear-DnsCache

    Write-Host "enabled: $($domains.Count) names now point at $Entry" -ForegroundColor Green
    Write-Host "backup:  $backup"
    Write-Host "undo:    disable.bat"
    Show-Support
}

function Invoke-Disable {
    if (-not (Test-Admin)) { throw "This needs administrator rights. Run disable.bat, it asks for them itself." }
    if (-not (Test-Path -LiteralPath $HostsPath)) { throw "No hosts file at $HostsPath" }

    $lines = [System.IO.File]::ReadAllLines($HostsPath)
    Assert-BlockIntact -Lines $lines -Path $HostsPath
    if (-not ($lines -contains $BeginMark)) {
        Write-Host "nothing to undo: no dns-ai-proxy block in $HostsPath"
        return
    }
    $encoding = Get-HostsEncoding -Path $HostsPath
    $backup = Backup-Hosts -Path $HostsPath
    Write-HostsAtomic -Path $HostsPath -Lines (Remove-ProxyBlock -Lines $lines) -Encoding $encoding
    Clear-DnsCache

    Write-Host "disabled: the dns-ai-proxy block is gone from $HostsPath" -ForegroundColor Green
    Write-Host "backup:   $backup"
}

function Invoke-Status {
    if (-not (Test-Path -LiteralPath $HostsPath)) { throw "No hosts file at $HostsPath" }
    $lines = [System.IO.File]::ReadAllLines($HostsPath)
    if (-not ($lines -contains $BeginMark)) {
        Write-Host "off: no dns-ai-proxy block in $HostsPath"
        return
    }
    $inside = @()
    $on = $false
    foreach ($line in $lines) {
        if ($line -eq $BeginMark) { $on = $true; continue }
        if ($line -eq $EndMark)   { $on = $false; continue }
        if ($on) { $inside += $line }
    }
    $entries = @($inside | Where-Object { $_ -notmatch '^#' })
    $addresses = ($entries | ForEach-Object { ($_ -split "\s+")[0] } | Sort-Object -Unique) -join ' '
    Write-Host "on: $($entries.Count) names in $HostsPath point at $addresses" -ForegroundColor Green
    $inside | Where-Object { $_ -match '^# enabled ' } | ForEach-Object { Write-Host $_ }
}

switch ($Command) {
    'enable'  { Invoke-Enable }
    'disable' { Invoke-Disable }
    'status'  { Invoke-Status }
}
