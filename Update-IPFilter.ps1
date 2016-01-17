[cmdletbinding(PositionalBinding=$false)]
param(
    $DestinationDir,
    $SourceUrl = 'http://upd.emule-security.org/ipfilter.zip',
    $qBitTorrentPort = 8083,
    $NumberOfOldFiltersToKeep = 1
)
Set-StrictMode -Version 4

if (!$DestinationDir) {
    $DestinationDir = $PSScriptRoot
}

$log = Join-Path $DestinationDir 'update-ipfilter.log'
Start-Transcript -LiteralPath $log -Append -Force

$local:ErrorActionPreference = 'Stop'
try {
    if (!(Test-Path -LiteralPath $DestinationDir -PathType Container)) {
        Write-Host "Creating '$DestinationDir'"
        $null = New-Item -Path $DestinationDir -ItemType Directory -Force
    }

    $zipPath = Join-Path $DestinationDir 'ipfilter.zip'
    $p2pPath = Join-Path $DestinationDir 'guarding.p2p'
    $ipfiltersPath = Join-Path $DestinationDir "ipfilters-$((Get-Date -Format 'u') -replace '\W','').dat"
    $ipfiltersPathWildcard = Join-Path $DestinationDir 'ipfilters-*.dat'

    Write-Host "Downloading $SourceUrl to '$zipPath'"
    Invoke-WebRequest -Uri $SourceUrl -OutFile $zipPath -TimeoutSec 30

    Write-Host "Expanding '$zipPath'"
    Expand-Archive -LiteralPath $zipPath -DestinationPath $DestinationDir -Force

    Write-Host "Renaming '$p2pPath' to '$ipfiltersPath'"
    Move-Item -LiteralPath $p2pPath -Destination $ipfiltersPath -Force

    # Refresh qBitTorrent...
    if (Get-Process -Name 'qbittorrent' -ErrorAction Ignore) {
        Write-Host 'Updating qBitTorrent preferences'
        $preferences = @{
            'ip_filter_enabled' = $true
            'ip_filter_path' = "$ipfiltersPath"
        }
        $qBitTorrentWebClientUrl = "http://localhost:$qBitTorrentPort/command/setPreferences"

        Add-Type -AssemblyName 'System.Web.Extensions'
        $jsonSerializer = New-Object 'System.Web.Script.Serialization.JavaScriptSerializer'
        $json = $jsonSerializer.Serialize($preferences.PSObject.BaseObject)

        Write-Host "Posting $json to $qBitTorrentWebClientUrl"
        $null = Invoke-WebRequest `
            -Uri $qBitTorrentWebClientUrl `
            -Body "json=$json" `
            -Method Post
    }
    else {
        Write-Host 'qBitTorrent is not running.'
    }

    # Delete old ipfilters...
    Get-ChildItem -Path $ipfiltersPathWildcard -Exclude (Split-Path $ipfiltersPath -Leaf) | 
        Sort-Object Name -Descending | 
        Select-Object -Skip $NumberOfOldFiltersToKeep | 
        ForEach-Object { Write-Host "Deleting old ipfilter: $_"; $_} | 
        Remove-Item -ea Continue
}
catch {
    Remove-Item variable:\ErrorActionPreference -ea Ignore
    $_ | Write-Error
    return
}
finally {
    Stop-Transcript
}