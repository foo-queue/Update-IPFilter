Set-StrictMode -Version 4

function Update-IPFilter {
    [cmdletbinding(PositionalBinding=$false)]
    param(
        [string] $DestinationDir = '.',
        [string] $SourceUrl = 'http://upd.emule-security.org/ipfilter.zip',
        [AllowEmptyString()]
        [string] $qBitTorrentWebClientUrl = 'http://localhost:8083',
        [int] $NumberOfOldFiltersToKeep = 1,
        [string]$IPFiltersNameFormat = 'ipfilters-{0}.dat'
    )

    $ErrorActionPreference = 'Stop'

    $DestinationDir = mkdir $DestinationDir -Force
    $log = Join-Path $DestinationDir 'Update-IPFilter.log'
    Start-Transcript -LiteralPath $log -Append -Force

    try {
        $ipfiltersName = $IPFiltersNameFormat -f ((Get-Date).ToString('u') -replace '\W','')
        $zipPath = Join-Path $DestinationDir 'ipfilter.zip'
        $p2pPath = Join-Path $DestinationDir 'guarding.p2p'

        Write-Host "Downloading $SourceUrl to '$zipPath'"
        Invoke-WebRequest -Uri $SourceUrl -OutFile $zipPath -TimeoutSec 30 -UseBasicParsing

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
        Remove-Variable ErrorActionPreference -Scope local -ea Ignore
        if ($ErrorActionPreference -eq 'Stop') { throw }
        if ($ErrorActionPreference -ne 'Ignore') { $_ | Write-Error }
        return
    }
    finally {
        Stop-Transcript
    }
}

function Update-QBitTorrentPrefs {
    param(
        $CurrentIPFiltersName
    )

    $url = "$qBitTorrentWebClientUrl/api/v2/app/setPreferences"
    $preferences = @{
        'ip_filter_enabled' = $true
        'ip_filter_path' = "$(Join-Path $DestinationDir $CurrentIPFiltersName)"
    } | ConvertTo-Json

    Write-Verbose "Posting $preferences to $url"
    $null = Invoke-WebRequest -Uri $url -Body "json=$preferences" -Method Post -UseBasicParsing
}

function Remove-OldIPFilters {
    param(
        $CurrentIPFiltersName
    )

    Get-ChildItem -Path (Join-Path $DestinationDir ($IPFiltersNameFormat -f '*')) -Exclude $CurrentIPFiltersName |
        Sort-Object Name -Descending |
        Select-Object -Skip $NumberOfOldFiltersToKeep |
        ForEach-Object { Write-Host "Deleting old ipfilter: $_"; $_} |
        Remove-Item -ea Continue
}

Export-ModuleMember -Function Update-IPFilter