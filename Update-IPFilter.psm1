Set-StrictMode -Version 5

function Get-LatestIPFilters {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Position = 1)]
        [string] $DestinationPath = './ipfilters.dat',
        [uri] $SourceUrl = 'http://upd.emule-security.org/ipfilter.zip',
        [string] $SourceFile = 'guarding.p2p'
    )

    $DestinationPath = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($DestinationPath)
    if (Test-Path $DestinationPath -PathType Container) {
        Write-Error 'DestinationPath cannot be a folder.'
        return
    }

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid())
    $null = mkdir $tempDir -Force -ea Stop
    try {
        $zipPath = Join-Path $tempDir 'source.zip'
        $p2pPath = Join-Path $tempDir $SourceFile

        Write-Verbose "Downloading $SourceUrl to '$zipPath'"
        Invoke-WebRequest -Uri $SourceUrl -OutFile $zipPath -TimeoutSec 30 -UseBasicParsing -ea Stop -Verbose:$false

        Write-Verbose "Expanding '$zipPath'"
        Expand-Archive -LiteralPath $zipPath -DestinationPath $tempDir -Force -ea Stop -Verbose:$false

        if (Test-Path $DestinationPath) {
            $incoming = Get-FileHash $p2pPath -ea Stop
            $existing = Get-FileHash $DestinationPath -ea Stop
            if ($incoming.Hash -eq $existing.Hash) {
                Write-Host "No change to existing IPFilters."
                return Get-Item $DestinationPath | Add-Member 'Updated' $false -PassThru
            }
        }

        Write-Verbose "Copying '$p2pPath' to '$DestinationPath'"
        $null = mkdir (Split-Path $DestinationPath -Parent) -Force -ea Stop
        Copy-Item -LiteralPath $p2pPath -Destination $DestinationPath -Force -ea Stop
        Get-Item $DestinationPath | Add-Member 'Updated' $true -PassThru
    }
    finally {
        Remove-Item $tempDir -Force -Recurse -ea Ignore 
    }
}

function getQbtCreds(
    [uri] $ServerUrl,
    [string] $UserName
) {
    $extraArgs = @{}
    if ($UserName) { $extraArgs['UserName'] = $UserName }
    $cred = Get-Credential -Title "Enter credentials for $ServerUrl" @extraArgs
    if (!$cred) {
        Write-Error "Login cancelled."
        return
    }
    
    $UserName = $cred.UserName
    $Password = $cred.Password | ConvertFrom-SecureString -AsPlainText -ea Stop
    @($UserName, $Password)
}
function Update-QBittorrentPrefs {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Position = 1)]
        [uri] $ServerUrl = 'http://localhost:8083',
        [string] $UserName,
        [string] $Password,

        [AllowEmptyString()]
        [string] $IPFilterPath
    )

    if ($UserName -AND !$Password) {
        $UserName, $Password = getQbtCreds $ServerUrl $UserName
        if (!$UserName) { return }
    }    

    [string]$ServerUrl = $ServerUrl.ToString().TrimEnd('/')
    $headers = @{}
    if ($UserName) {
        $url = "$ServerUrl/api/v2/auth/login"
        Write-Verbose "Logging into $url as $UserName..."
        $resp = Invoke-WebRequest -Method Post -Uri $url -Body "username=$UserName&password=$Password" -Headers @{ Referer = $ServerUrl } -UseBasicParsing -SkipHttpErrorCheck -ea Stop -Verbose:$false
        if ($resp.StatusCode -ge 300 -OR $resp.Content -ne 'Ok.') {
            Write-Error "Authorization error: $($resp.StatusCode) - $($resp.Content)"
            return
        }
        $headers['Cookie'] = ($resp.Headers['Set-Cookie'] -split ';')[0]
    }

    $preferences = @{}    
    if ($PSBoundParameters.ContainsKey('IPFilterPath')) {
        $preferences['ip_filter_enabled'] = !!$IPFilterPath
        $preferences['ip_filter_path'] = $IPFilterPath
    }
    
    $url = "$ServerUrl/api/v2/app/setPreferences"
    $preferencesJson = $preferences | ConvertTo-Json -Compress
    Write-Verbose "Posting $preferencesJson to $url..."
    $resp = Invoke-WebRequest -Method Post -Uri $url -Body "json=$preferencesJson" -Headers $headers -UseBasicParsing -SkipHttpErrorCheck -ea Stop -Verbose:$false
    if ($resp.StatusCode -ge 300) {
        Write-Error "Set Preferences failed: $($resp.StatusCode) - $($resp.Content)"
        return
    }
}

function Update-IPFilters {
    [CmdletBinding(PositionalBinding = $false)]
    param (
        [Parameter(Position = 1)]
        [uri] $ServerUrl = 'http://localhost:8083',
        [string] $UserName,
        [string] $Password,
        [string] $DestinationPath = './ipfilters.dat',
        [string] $ServerIPFiltersPath,
        [switch] $Force
    )

    $ipfilters = Get-LatestIPFilters -DestinationPath $DestinationPath
    if (!$ipfilters -OR (!$ipfilters.Updated -AND !$Force)) { 
        return
    }

    if (!$ServerIPFiltersPath) { $ServerIPFiltersPath = $ipfilters.FullName }
    Update-QBittorrentPrefs -ServerUrl $ServerUrl -UserName $UserName -Password $Password -IPFilterPath $ServerIPFiltersPath -ea Stop -Verbose
}

$DefaultTaskName = 'Update qBittorrent IPFilter'

function Register-UpdateIPFilters {
    [CmdletBinding(PositionalBinding = $false)]
    param (
        [uri] $ServerUrl = 'http://localhost:8083',
        [string] $UserName,
        [string] $Password,
        [string] $DestinationPath = './ipfilters.dat',
        [string] $ServerIPFiltersPath,
        [string] $TaskName = $DefaultTaskName,
        [object] $TaskTrigger = (New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At (Get-Date '8:00 AM')),
        [switch] $Force,
        [switch] $RunNow
    )

    # Resolve relative paths...
    $DestinationPath = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($DestinationPath)
    if (Test-Path $DestinationPath -PathType Container) {
        Write-Error 'DestinationPath cannot be a folder.'
        return
    }

    # Prompt for missing inputs...
    if ($UserName -AND !$Password) {
        $UserName, $Password = getQbtCreds $ServerUrl $UserName
        if (!$UserName) { return }
    }

    function escapeDQ ([string]$s) { $s -replace '"', '""' }
    function escapeSQ ([string]$s) { $s -replace "'", "''" }

    $script = "
        Import-Module .\Update-IPFilter.psm1
        Update-IPFilters -ServerUrl '$(escapeSQ $ServerUrl)' -UserName '$(escapeSQ $UserName)' -Password '$(escapeSQ $Password)' -DestinationPath '$(escapeSQ $DestinationPath)' -ServerIPFiltersPath '$(escapeSQ $ServerIPFiltersPath)' -Verbose
        "
    # convert to a single line...
    $script = ($script.Trim()) -replace '\r?\n', '; '
    Write-verbose "Script: $script"

    New-ScheduledTask `
        -Action (New-ScheduledTaskAction `
            -Execute (Get-Command pwsh).Path `
            -Argument "-noexit -nop -ep bypass -c `"$(escapeDQ $script)`"" `
            -WorkingDirectory $PSScriptRoot) `
        -Trigger $TaskTrigger | `
        Register-ScheduledTask -TaskName $TaskName -Force:$Force -ea Stop

    if ($RunNow) {
        Start-ScheduledTask -TaskName $TaskName
    }
}

function Unregister-UpdateIPFilters {
    param(
        [string] $TaskName = $DefaultTaskName
    )
    Unregister-ScheduledTask -TaskName $TaskName
}

Export-ModuleMember -Function Get-LatestIPFilters, Update-QBittorrentPrefs, Update-IPFilters, Register-UpdateIPFilters, Unregister-UpdateIPFilters