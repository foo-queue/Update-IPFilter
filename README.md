# Update-IPFilter

A PowerShell script to download Bittorrent IPFilters and update a running qBittorrent instance.

Register the task:

```powershell
Import-Module .\Update-IPFilter

# Unprotected qBittorrent running in host context (not a container):
Register-UpdateIPFilters 'http://localhost:8083' -RunNow

# Secured qBittorrent running in a container with mounted volume and custom domain:
Register-UpdateIPFilters `
  -ServerUrl 'https://qbt.belcherjohn.com/' `
  -UserName 'belcherjohn' `
  -DestinationPath 'M:\Multimedia\Torrents\IPFilter\ipfilters.dat' `
  -ServerIPFiltersPath '/data/Torrents/IPFilter/ipfilters.dat' `
  -RunNow

# Delete the scheduled task:
Register-UpdateIPFilters
```
