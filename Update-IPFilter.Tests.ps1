BeforeAll {
    $moduleName = 'Update-IPFilter'
    Import-Module "$PSScriptRoot/$moduleName.psm1" -Force
    function Mock { Pester\Mock -ModuleName $moduleName @args }
    function Should { Pester\Should -ModuleName $moduleName @args }
}

Describe 'Update-IPFilter' {
    BeforeAll {
        $fake_sourceUrl = 'http://example.com/ipfilter.zip'
        $fake_ipfiltername = 'ipfilters-20001122012345Z.dat'
        $fake_now = [datetime]'2000-11-22T01:23:45'

        Mock Start-Transcript {}
        Mock Stop-Transcript {}
        Mock Get-Date { $fake_now }
        Mock Write-Host {}
        Mock Invoke-WebRequest {}
        Mock Expand-Archive {}
        Mock Rename-Item {}
        Mock Update-QBitTorrentPrefs {}
        Mock Remove-OldIPFilters {}
    }

    Context 'DestinationDir' {
        AfterEach {
            Should -Invoke Invoke-WebRequest -ParameterFilter { $Uri -eq $fake_sourceUrl -AND $OutFile -eq (Join-Path $TestDrive 'ipfilter.zip') }
            Should -Invoke Expand-Archive -ParameterFilter { $LiteralPath -eq (Join-Path $TestDrive 'ipfilter.zip') }
            Should -Invoke Rename-Item -ParameterFilter { $LiteralPath -eq (Join-Path $TestDrive 'guarding.p2p') }
            Should -Invoke Update-QBitTorrentPrefs -ParameterFilter { $CurrentIPFiltersName -eq $fake_ipfiltername }
            Should -Invoke Remove-OldIPFilters -ParameterFilter { $CurrentIPFiltersName -eq $fake_ipfiltername }
        }

        It 'Should extract to explicit destination dir' {
            Update-IPFilter -DestinationDir $TestDrive -SourceUrl $fake_sourceUrl
        }

        It 'Should extract to default/current destination dir' {
            Push-Location $TestDrive
            Update-IPFilter -SourceUrl $fake_sourceUrl
            Pop-Location
        }
    }
}
