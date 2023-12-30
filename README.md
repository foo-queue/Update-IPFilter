# Update-IPFilter

A PowerShell script to download a Bittorrent IPFilter and update the running qBitTorrent instance.

Register the task:

```powershell
cd ~\Dev\Update-IPFilter

New-ScheduledTask `
    -Action (New-ScheduledTaskAction `
        -Execute (Get-Command pwsh).Path `
        -Argument '-noexit -nop -ep bypass -c "&{ Import-Module .\Update-IPFilter.psm1; Update-IPFilter }"' `
        -WorkingDirectory $PWD) `
    -Trigger (New-ScheduledTaskTrigger `
        -Weekly `
        -DaysOfWeek Sunday `
        -At (Get-Date '8:00 AM')) | `
Register-ScheduledTask -TaskName 'Update qBittorrent IPFilter' -Force

# Execute now:
Start-ScheduledTask -TaskName 'Update qBittorrent IPFilter'

# Delete:
# Unregister-ScheduledTask -TaskName 'Update qBittorrent IPFilter'
```
