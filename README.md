# Update-IPFilter

A PowerShell script to download a Bittorrent IPFilter and update the running qBitTorrent instance.

Register the task:

```powershell
cd C:\Dev\Update-IPFilter
schtasks /CREATE /TN "Update qBittorrent IPFilter" /XML "Update qBittorrent IPFilter.xml"
```
