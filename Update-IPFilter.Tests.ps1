$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe 'Update-IPFilter' {

    $destFolder = 'TestDrive:\'
    $fake_now = [datetime]'2000-11-22T01:23:45'
    $fake_ipfiltername = 'ipfilters-20001122012345Z.dat'
    $fake_sourceUrl = 'http://example.com/ipfilter.zip'

    Mock Start-Transcript {}
    Mock Stop-Transcript {}
    Mock Get-Date { $fake_now }
    Mock Write-Host {}

    Mock Invoke-WebRequest {}
    Mock Expand-Archive {}
    Mock Rename-Item {}
    Mock Assert-DestinationDirExists {}
    Mock Update-QBitTorrentPrefs {}
    Mock Remove-OldIPFilters {}

    It 'Should extract to explcit destination dir' {
        $destFolder = 'TestDrive:\'
        Update-IPFilter -DestinationDir $destFolder -SourceUrl $fake_sourceUrl
        Assert-MockCalled 'Invoke-WebRequest' -ParameterFilter {$Uri -eq $fake_sourceUrl -AND $OutFile -eq (Join-Path $destFolder 'ipfilter.zip')}
        Assert-MockCalled 'Expand-Archive' -ParameterFilter {$LiteralPath -eq (Join-Path $destFolder 'ipfilter.zip')}
        Assert-MockCalled 'Rename-Item' -ParameterFilter {$LiteralPath -eq (Join-Path $destFolder 'guarding.p2p')}
        Assert-MockCalled 'Update-QBitTorrentPrefs' -ParameterFilter {$CurrentIPFiltersName -eq $fake_ipfiltername}
        Assert-MockCalled 'Remove-OldIPFilters' -ParameterFilter {$CurrentIPFiltersName -eq $fake_ipfiltername}
    }
    It 'Should extract to default destination dir' {
        $destFolder = $here
        Update-IPFilter -SourceUrl $fake_sourceUrl
        Assert-MockCalled 'Invoke-WebRequest' -ParameterFilter {$Uri -eq $fake_sourceUrl -AND $OutFile -eq (Join-Path $destFolder 'ipfilter.zip')}
        Assert-MockCalled 'Expand-Archive' -ParameterFilter {$LiteralPath -eq (Join-Path $destFolder 'ipfilter.zip')}
        Assert-MockCalled 'Rename-Item' -ParameterFilter {$LiteralPath -eq (Join-Path $destFolder 'guarding.p2p')}
        Assert-MockCalled 'Update-QBitTorrentPrefs' -ParameterFilter {$CurrentIPFiltersName -eq $fake_ipfiltername}
        Assert-MockCalled 'Remove-OldIPFilters' -ParameterFilter {$CurrentIPFiltersName -eq $fake_ipfiltername}
    }
}
