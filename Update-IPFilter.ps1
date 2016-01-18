Set-StrictMode -Version 4

$script:IPFiltersNameFormat = 'ipfilters-{0}.dat'

function script:Assert-DestinationDirExists
{
    if (!(Test-Path -LiteralPath $DestinationDir -PathType Container)) {
        Write-Host "Creating '$DestinationDir'"
        $null = New-Item -Path $DestinationDir -ItemType Directory -Force
    }
}

function script:Update-QBitTorrentPrefs {
    param(
        $CurrentIPFiltersName
    )

    $url = "$qBitTorrentWebClientUrl/command/setPreferences"
    $preferences = @{
        'ip_filter_enabled' = $true
        'ip_filter_path' = "$(Join-Path $DestinationDir $CurrentIPFiltersName)"
    }
    
    Add-Type -AssemblyName 'System.Web.Extensions'
    $jsonSerializer = New-Object 'System.Web.Script.Serialization.JavaScriptSerializer'
    $json = $jsonSerializer.Serialize($preferences)

    Write-Verbose "Posting $json to $url"
    $null = Invoke-WebRequest -Uri $url -Body "json=$json" -Method Post
}

function script:Remove-OldIPFilters {
    param(
        $CurrentIPFiltersName
    )

    Get-ChildItem -Path (Join-Path $DestinationDir ($IPFiltersNameFormat -f '*')) -Exclude $CurrentIPFiltersName | 
        Sort-Object Name -Descending | 
        Select-Object -Skip $NumberOfOldFiltersToKeep | 
        ForEach-Object { Write-Host "Deleting old ipfilter: $_"; $_} | 
        Remove-Item -ea Continue
}

function Update-IPFilter {

    [cmdletbinding(PositionalBinding=$false)]
    param(
        [string] $DestinationDir,
        [string] $SourceUrl = 'http://upd.emule-security.org/ipfilter.zip',
        [AllowEmptyString()]
        [string] $qBitTorrentWebClientUrl = 'http://localhost:8083',
        [int] $NumberOfOldFiltersToKeep = 1
    )

    if (!$DestinationDir) {
        $DestinationDir = $PSScriptRoot
    }

    $log = Join-Path $DestinationDir 'Update-IPFilter.log'
    Start-Transcript -LiteralPath $log -Append -Force

    $local:ErrorActionPreference = 'Stop'
    try {
        Assert-DestinationDirExists

        $ipfiltersName = $IPFiltersNameFormat -f ((Get-Date).ToString('u') -replace '\W','')
        $zipPath = Join-Path $DestinationDir 'ipfilter.zip'
        $p2pPath = Join-Path $DestinationDir 'guarding.p2p'

        Write-Host "Downloading $SourceUrl to '$zipPath'"
        Invoke-WebRequest -Uri $SourceUrl -OutFile $zipPath -TimeoutSec 30

        Write-Host "Expanding '$zipPath'"
        Expand-Archive -LiteralPath $zipPath -DestinationPath $DestinationDir -Force

        Write-Host "Renaming '$p2pPath' to '$ipfiltersName'"
        Rename-Item -LiteralPath $p2pPath -NewName $ipfiltersName -Force

        if ($qBitTorrentWebClientUrl) {
            Write-Host 'Updating qBitTorrent'
            Update-QBitTorrentPrefs $ipfiltersName
        }

        Remove-OldIPFilters $ipfiltersName
    }
    catch {
        Remove-Variable -Name 'ErrorActionPreference' -ea Ignore
        $_ | Write-Error
        return
    }
    finally {
        Stop-Transcript
    }
}