# Update-IPFilter

A PowerShell script to download a Bittorrent IPFilter and update the running qBitTorrent instance.

Register the task:

```powershell
Import-Module .\Update-IPFilter

# Local qBittorrent listening on port 8083
Register-IPFilter -RunNow

# Secured qBittorrent with custom domain (will prompt for password)
Register-IPFilter https://qbt.belcherjohn.com -UserName belcherjohn -RunNow

# Delete:
# Unregister-IPFilter
```
