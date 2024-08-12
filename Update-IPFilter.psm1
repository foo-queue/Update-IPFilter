Set-StrictMode -Version 5

function Update-IPFilter {
    [cmdletbinding(PositionalBinding = $false)]
    param(
        [Parameter(Position = 1)]
        [AllowEmptyString()]
        [string] $ServerUrl = 'http://localhost:8083',
        [string] $UserName,
        [string] $Password,
        [string] $DestinationDir = '.',
        [int] $NumberOfOldFiltersToKeep = 1,
        [string] $IPFilterUrl = 'http://upd.emule-security.org/ipfilter.zip',
        [string]$IPFiltersNameFormat = 'ipfilters-{0}.dat'
    )

    $ErrorActionPreference = 'Stop'

    if ($UserName -AND !$Password) {
        $cred = Get-Credential -Title "Enter credentials for $ServerUrl" -UserName $UserName
        if (!$cred) {
            Write-Error "Login cancelled."
            return
        }
        $UserName = $cred.UserName
        $Password = $cred.Password | ConvertFrom-SecureString -AsPlainText
    }

    $DestinationDir = mkdir $DestinationDir -Force
    $log = Join-Path $DestinationDir 'Update-IPFilter.log'
    Start-Transcript -LiteralPath $log -Append -Force

    try {
        $ipfiltersName = $IPFiltersNameFormat -f ((Get-Date).ToString('u') -replace '\W', '')
        $zipPath = Join-Path $DestinationDir 'ipfilter.zip'
        $p2pPath = Join-Path $DestinationDir 'guarding.p2p'

        Write-Host "Downloading $IPFilterUrl to '$zipPath'"
        Invoke-WebRequest -Uri $IPFilterUrl -OutFile $zipPath -TimeoutSec 30 -UseBasicParsing

        Write-Host "Expanding '$zipPath'"
        Expand-Archive -LiteralPath $zipPath -DestinationPath $DestinationDir -Force

        Write-Host "Renaming '$p2pPath' to '$ipfiltersName'"
        Rename-Item -LiteralPath $p2pPath -NewName $ipfiltersName -Force

        if ($ServerUrl) {
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

    $ServerUrl = $ServerUrl.TrimEnd('/')
    $headers = @{}

    if ($UserName) {
        $url = "$ServerUrl/api/v2/auth/login"
        $loginResp = Invoke-WebRequest -Method Post -Uri $url -Body "username=$UserName&password=$Password" -Headers @{ Referer = $ServerUrl } -UseBasicParsing
        $headers['Cookie'] = ($loginResp.Headers['Set-Cookie'] -split ';', 2)[0]
    }

    $url = "$ServerUrl/api/v2/app/setPreferences"
    $preferences = @{
        'ip_filter_enabled' = $true
        'ip_filter_path'    = "$(Join-Path $DestinationDir $CurrentIPFiltersName)"
    } | ConvertTo-Json

    Write-Verbose "Posting $preferences to $url"

    $null = Invoke-WebRequest -Method Post -Uri $url -Body "json=$preferences" -Headers $headers -UseBasicParsing
}

function Remove-OldIPFilters {
    param(
        $CurrentIPFiltersName
    )

    Get-ChildItem -Path (Join-Path $DestinationDir ($IPFiltersNameFormat -f '*')) -Exclude $CurrentIPFiltersName |
    Sort-Object Name -Descending |
    Select-Object -Skip $NumberOfOldFiltersToKeep |
    ForEach-Object { Write-Host "Deleting old ipfilter: $_"; $_ } |
    Remove-Item -ea Continue
}

function Register-IPFilter {
    [CmdletBinding(
        SupportsShouldProcess, 
        ConfirmImpact = 'High', 
        PositionalBinding = $false)]
    param (
        [Parameter(Position = 1)]
        [string] $ServerUrl = 'http://localhost:8083',
        [string] $UserName,
        [string] $Password,
        [string] $DestinationDir = '.',
        [int] $NumberOfOldFiltersToKeep = 1,
        [switch] $RunNow,
        [switch] $Force
    )

    if ($Force) { $ConfirmPreference = 'None' }
    $func = 'Update qBittorrent IPFilter'

    if ($UserName -AND !$Password) {
        $cred = Get-Credential -Title "Enter credentials for $ServerUrl" -UserName $UserName
        if (!$cred) {
            Write-Error "Login cancelled."
            return
        }
        $UserName = $cred.UserName
        $Password = $cred.Password | ConvertFrom-SecureString -AsPlainText
    }
    
    if (!$PSCmdlet.ShouldProcess($func, "Create ScheduleTask")) { return }

    $script = "Import-Module .\Update-IPFilter.psm1; Update-IPFilter -ServerUrl '$ServerUrl' -UserName '$UserName' -Password '$Password' -DestinationDir '$DestinationDir' -NumberOfOldFiltersToKeep $NumberOfOldFiltersToKeep"

    New-ScheduledTask `
        -Action (New-ScheduledTaskAction `
            -Execute (Get-Command pwsh).Path `
            -Argument "-noexit -nop -ep bypass -c `"&{ $script }`"" `
            -WorkingDirectory $PSScriptRoot) `
        -Trigger (New-ScheduledTaskTrigger `
            -Weekly `
            -DaysOfWeek Sunday `
            -At (Get-Date '8:00 AM')) | `
        Register-ScheduledTask -TaskName $func -Force

    if ($RunNow) {
        Start-ScheduledTask -TaskName $func
    }
}

function Unregister-IPFilter {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param (
        [switch] $Force
    )

    if ($Force) { $ConfirmPreference = 'None' }
    $func = 'Update qBittorrent IPFilter'
 
    if (!$PSCmdlet.ShouldProcess($func, "Delete ScheduleTask")) { return }

    Unregister-ScheduledTask -TaskName $func -Confirm:$false
}

Export-ModuleMember -Function Update-IPFilter, Register-IPFilter, Unregister-IPFilter