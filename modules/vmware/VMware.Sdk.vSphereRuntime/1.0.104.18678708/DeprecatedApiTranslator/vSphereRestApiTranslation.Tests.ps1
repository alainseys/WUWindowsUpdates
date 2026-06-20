BeforeAll {
    function Test-ObjectsAreEqual {
        [CmdletBinding()]
        [OutputType([bool])]
        param (
            [Parameter(Mandatory = $true)]
            [AllowNull()]
            [object]
            $Actual,

            [Parameter(Mandatory = $true)]
            [AllowNull()]
            [object]
            $Expected,

            [Parameter(Mandatory = $false)]
            [type]
            $ExpectedType,

            [Parameter(Mandatory = $false)]
            [int]
            $Depth = 10
        )

        process {
            $result = $true

            if ($null -ne $ExpectedType -and $Actual -IsNot $ExpectedType) {
                Write-Verbose -Message "The actual object's type [$($Actual.GetType())] doesn't match the expected one [$ExpectedType]"
                $result = $false
            }
            elseif ($Expected.GetType().IsPrimitive -or $Expected -Is [string]) {
                Write-Verbose -Message "Primitive type [$($Expected.GetType())] found"
                $result = ($Actual -eq $Expected)
            }
            else {
                Write-Verbose -Message "Complex type [$($Expected.GetType())] found"
                $expectedProperties = $Expected | Get-Member -MemberType Properties

                foreach ($property in $expectedProperties) {
                    Write-Verbose -Message "Asserting property $($property.Name)"

                    $expectedValue = $Expected | Select-Object -ExpandProperty $property.Name
                    $actualValue = $Actual | Select-Object -ExpandProperty $property.Name

                    Write-Verbose -Message "Expected value = $expectedValue"
                    Write-Verbose -Message "Actual value = $actualValue"

                    if ($expectedValue -eq $actualValue) {
                        Write-Verbose -Message "Values are equal"
                        continue
                    }
                    elseif ($Depth -eq -1) {
                        $result = $true
                    }
                    else {
                        $areObjectsEqual = Test-ObjectsAreEqual -Expected $expectedValue -Actual $actualValue -Depth ($Depth - 1)
                        if (!$areObjectsEqual) {
                            $result = $false
                            break
                        }
                    }
                }
            }

            return $result
        }
    }
}

Describe 'Test Output translation' {
    Context 'Output Object Translation' {
        It 'Translates GetVM Operation Output' {
            # Arrange
            . (Join-Path $PSScriptRoot 'vSphereRestApiTranslation.ps1')

            $operationTranslationSchema = Get-OperationTranslationSchema -operationPath '/api/vcenter/vm/{vm}' -operationVerb 'get'

            $vmInfoJson = '{"value":{"instant_clone_frozen":false,"cdroms":[{"value":{"start_connected":false,"backing":{"device_access_type":"PASSTHRU","type":"CLIENT_DEVICE"},"allow_guest_control":true,"label":"CD/DVD drive 1","state":"NOT_CONNECTED","type":"SATA","sata":{"bus":0,"unit":0}},"key":"16000"}],"memory":{"size_MiB":4,"hot_add_enabled":false},"disks":[{"value":{"scsi":{"bus":0,"unit":0},"backing":{"vmdk_file":"[local-0] testvm/testvm.vmdk","type":"VMDK_FILE"},"label":"Hard disk 1","type":"SCSI","capacity":8589934592},"key":"2000"}],"parallel_ports":[],"sata_adapters":[{"value":{"bus":0,"label":"SATA controller 0","type":"AHCI"},"key":"15000"}],"cpu":{"hot_remove_enabled":false,"count":2,"hot_add_enabled":false,"cores_per_socket":2},"scsi_adapters":[{"value":{"scsi":{"bus":0,"unit":7},"label":"SCSI controller 0","sharing":"NONE","type":"LSILOGICSAS"},"key":"1000"}],"power_state":"POWERED_OFF","floppies":[],"identity":{"name":"testvm","instance_uuid":"501d5a5f-8e1b-770a-8e76-ba9eb8c77043","bios_uuid":"421d24e8-732f-693d-653e-0492a4dea3b2"},"name":"testvm","nics":[{"value":{"start_connected":true,"backing":{"network_name":"VM Network","type":"STANDARD_PORTGROUP","network":"network-19"},"mac_address":"00:50:56:9d:2a:b5","mac_type":"ASSIGNED","allow_guest_control":true,"wake_on_lan_enabled":true,"label":"Network adapter 1","state":"NOT_CONNECTED","type":"E1000E"},"key":"4000"}],"boot":{"delay":0,"efi_legacy_boot":false,"retry_delay":10000,"enter_setup_mode":false,"network_protocol":"IPV4","type":"EFI","retry":false},"serial_ports":[],"boot_devices":[],"guest_OS":"WINDOWS_SERVER_2019","hardware":{"upgrade_policy":"NEVER","upgrade_status":"NONE","version":"VMX_19"}}}'
            $vmInfoObject = $vmInfoJson | ConvertFrom-JsonX -Depth 100

            $expectedJson = '{"instant_clone_frozen":false,"cdroms":{"16000":{"start_connected":false,"backing":{"device_access_type":"PASSTHRU","type":"CLIENT_DEVICE"},"allow_guest_control":true,"label":"CD/DVD drive 1","state":"NOT_CONNECTED","type":"SATA","sata":{"bus":0,"unit":0}}},"memory":{"size_MiB":4,"hot_add_enabled":false},"disks":{"2000":{"scsi":{"bus":0,"unit":0},"backing":{"vmdk_file":"[local-0] testvm/testvm.vmdk","type":"VMDK_FILE"},"label":"Hard disk 1","type":"SCSI","capacity":8589934592}},"parallel_ports":{},"sata_adapters":{"15000":{"bus":0,"label":"SATA controller 0","type":"AHCI"}},"cpu":{"hot_remove_enabled":false,"count":2,"hot_add_enabled":false,"cores_per_socket":2},"scsi_adapters":{"1000":{"scsi":{"bus":0,"unit":7},"label":"SCSI controller 0","sharing":"NONE","type":"LSILOGICSAS"}},"power_state":"POWERED_OFF","floppies":{},"identity":{"name":"testvm","instance_uuid":"501d5a5f-8e1b-770a-8e76-ba9eb8c77043","bios_uuid":"421d24e8-732f-693d-653e-0492a4dea3b2"},"name":"testvm","nics":{"4000":{"start_connected":true,"backing":{"network_name":"VM Network","type":"STANDARD_PORTGROUP","network":"network-19"},"mac_address":"00:50:56:9d:2a:b5","mac_type":"ASSIGNED","allow_guest_control":true,"wake_on_lan_enabled":true,"label":"Network adapter 1","state":"NOT_CONNECTED","type":"E1000E"}},"boot":{"delay":0,"efi_legacy_boot":false,"retry_delay":10000,"enter_setup_mode":false,"network_protocol":"IPV4","type":"EFI","retry":false},"serial_ports":{},"boot_devices":[],"guest_OS":"WINDOWS_SERVER_2019","hardware":{"upgrade_policy":"NEVER","upgrade_status":"NONE","version":"VMX_19"}}'
            $expected = $expectedJson | ConvertFrom-JsonX -Depth 100

            # Act
            $actual = Convert-OutputBody $operationTranslationSchema $vmInfoObject

            # Assert
            Test-ObjectsAreEqual $actual $expected | Should -BeTrue
        }

        It 'Translates Appliance ListServices Operation Output' {
            # Arrange
            . (Join-Path $PSScriptRoot 'vSphereRestApiTranslation.ps1')

            $operationTranslationSchema = Get-OperationTranslationSchema -operationPath '/api/appliance/services' -operationVerb 'get'

            $servicesJson = '{"value":[{"value":{"description":"/etc/rc.local.shutdown Compatibility","state":"STOPPED"},"key":"appliance-shutdown"},{"value":{"description":"The tftp server serves files using the trivial file transfer protocol.","state":"STOPPED"},"key":"atftpd"}]}'
            $servicesObject = $servicesJson | ConvertFrom-JsonX -Depth 100

            $expectedJson = '{"appliance-shutdown":{"description":"/etc/rc.local.shutdown Compatibility","state":"STOPPED"},"atftpd":{"description":"The tftp server serves files using the trivial file transfer protocol.","state":"STOPPED"}}'
            $expected = $expectedJson | ConvertFrom-JsonX -Depth 100

            # Act
            $actual = Convert-OutputBody $operationTranslationSchema $servicesObject

            # Assert
            Test-ObjectsAreEqual $actual $expected | Should -BeTrue
        }

        It 'Should translate GetChainCertificateManagementTrustedRootChains Operation Output with one element correctly' {
            # Arrange
            . (Join-Path $PSScriptRoot 'vSphereRestApiTranslation.ps1')

            $operationTranslationSchema = Get-OperationTranslationSchema -operationPath '/api/vcenter/certificate-management/vcenter/trusted-root-chains/{chain}' -operationVerb 'get'

            $certChainJson = '{"value":{"cert_chain":{"cert_chain":["-----BEGIN CERTIFICATE-----trusted-root-chains-----END CERTIFICATE-----"]}}}'
            $certChainObject = $certChainJson | ConvertFrom-JsonX -Depth 100

            $expectedJson = '{"cert_chain":{"cert_chain":["-----BEGIN CERTIFICATE-----trusted-root-chains-----END CERTIFICATE-----"]}}'
            $expected = $expectedJson | ConvertFrom-JsonX -Depth 100

            # Act
            $actual = Convert-OutputBody $operationTranslationSchema $certChainObject

            # Assert
            Test-ObjectsAreEqual $actual $expected | Should -BeTrue
        }

        It 'Should translate GetChainCertificateManagementTrustedRootChains Operation Output with more than one element correctly' {
            # Arrange
            . (Join-Path $PSScriptRoot 'vSphereRestApiTranslation.ps1')

            $operationTranslationSchema = Get-OperationTranslationSchema -operationPath '/api/vcenter/certificate-management/vcenter/trusted-root-chains/{chain}' -operationVerb 'get'

            $certChainJson = '{"value":{"cert_chain":{"cert_chain":["-----BEGIN CERTIFICATE-----trusted-root-chains-1-----END CERTIFICATE-----", "-----BEGIN CERTIFICATE-----trusted-root-chains-2-----END CERTIFICATE-----"]}}}'
            $certChainObject = $certChainJson | ConvertFrom-JsonX -Depth 100

            $expectedJson = '{"cert_chain":{"cert_chain":["-----BEGIN CERTIFICATE-----trusted-root-chains-1-----END CERTIFICATE-----", "-----BEGIN CERTIFICATE-----trusted-root-chains-2-----END CERTIFICATE-----"]}}'
            $expected = $expectedJson | ConvertFrom-JsonX -Depth 100

            # Act
            $actual = Convert-OutputBody $operationTranslationSchema $certChainObject

            # Assert
            Test-ObjectsAreEqual $actual $expected | Should -BeTrue
        }
    }
}

Describe 'Test Input Body Translation' {
    Context 'FindLibrarySpec Input Object Translation' {
        It 'Translates Input Object' {
            # Arrange
            . (Join-Path $PSScriptRoot 'vSphereRestApiTranslation.ps1')

            $operationTranslationSchema = Get-OperationTranslationSchema -operationPath '/api/content/library/item?action=find' -operationVerb 'post'

            $inputSpec = '{"name":"lib-1"}'
            $inputSpecObject = $inputSpec | ConvertFrom-JsonX -Depth 100

            $expectedJson = '{"spec":{"name":"lib-1"}}'
            $expected = $expectedJson | ConvertFrom-JsonX -Depth 100

            # Act
            $actual = Convert-InputStructure $operationTranslationSchema $inputSpecObject -InputType Body

            # Assert
            Test-ObjectsAreEqual $actual $expected | Should -BeTrue
        }

        It 'Translates Body Input Object with client_token moved to header' {
            # Arrange
            . (Join-Path $PSScriptRoot 'vSphereRestApiTranslation.ps1')

            $operationTranslationSchema = Get-OperationTranslationSchema -operationPath '/api/content/library/item/download-session' -operationVerb 'post'

            $libraryItemId = '105dc95e-dd76-4398-91d2-cd0a7183bff3'
            $libraryItemIdOldBodyInput = [PSCustomObject] @{
                'create_spec' = @{
                    'library_item_id' = $libraryItemId
                }
            }
            $libraryItemIdNewBodyInput = [PSCustomObject] @{
                'library_item_id' = $libraryItemId
            }

            # Act
            $actual = Convert-InputStructure $operationTranslationSchema $libraryItemIdNewBodyInput -InputType Body

            # Assert
            $actual | Should -Not -BeNullOrEmpty
            $actual.create_spec.library_item_id | Should -Be $libraryItemIdOldBodyInput.create_spec.library_item_id
        }
    }

    Context 'TagCategory Input Object Translation' {
        It "Should translate array with one item to an array of one item" {
            # Arrange
            . (Join-Path $PSScriptRoot 'vSphereRestApiTranslation.ps1')

            $operationTranslationSchema = Get-OperationTranslationSchema -operationPath '/api/cis/tagging/category' -operationVerb 'post'

            $categoryCreateSpec =  [PSCustomObject] @{
                "associable_types" = @("VirtualMachine")
                "cardinality" = "MULTIPLE"
                "description" = "TestDescription"
                "name" = "TestCategory"
            }

            # Act
            $actual = Convert-InputStructure $operationTranslationSchema $categoryCreateSpec -InputType Body

            # Assert
            $actual | Should -Not -Be $null
            $actual.create_spec.associable_types -is [array] | Should -Be $true
            $actual.create_spec.associable_types.Count | Should -Be 1
            $actual.create_spec.associable_types[0] | Should -Be $categoryCreateSpec.associable_types[0]
            $actual.create_spec.cardinality | Should -Be $categoryCreateSpec.cardinality
            $actual.create_spec.description | Should -Be $categoryCreateSpec.description
            $actual.create_spec.name | Should -Be $categoryCreateSpec.name
        }
    }
}


Describe 'Test Input Query Translation' {
    Context 'DatastoreFilterSpec Query Input Translation' {
        It 'Translates Query Input Object' {
            # Arrange
            . (Join-Path $PSScriptRoot 'vSphereRestApiTranslation.ps1')

            $operationTranslationSchema = Get-OperationTranslationSchema -operationPath '/api/vcenter/datastore' -operationVerb 'get'
            $inputSpec = '{"names":["datastore-0"],"datastores":["ds-2"]}'
            $inputSpecObject = $inputSpec | ConvertFrom-JsonX -Depth 100

            $expectedJson = '{"filter.names":["datastore-0"],"filter.datastores":["ds-2"]}'
            $expected = $expectedJson | ConvertFrom-JsonX -Depth 100

            # Act
            $actual = Convert-InputStructure $operationTranslationSchema $inputSpecObject -InputType Query

            # Assert
            $actual."filter.names".Count | Should -Be 1
            $actual."filter.names" | Should -Be $expected."filter.names"
            $actual."filter.datastores" | Should -Be $expected."filter.datastores"
            $actual."filter.types" | Should -Be $null
        }

        It 'Should not translate Appliance Pending Query Params' {
            # Arrange
            . (Join-Path $PSScriptRoot 'vSphereRestApiTranslation.ps1')

            $operationTranslationSchema = Get-OperationTranslationSchema -operationPath '/api/appliance/update/pending' -operationVerb 'get'
            $expectedJson = '{"source_type":"test","url":"localhost"}'
            $expected = $expectedJson | ConvertFrom-JsonX -Depth 100

            # Act
            $actual = Convert-InputStructure $operationTranslationSchema $expected -InputType Query

            # Assert
            $actual.source_type | Should -Be $expected.source_type
            $actual.url | Should -Be $expected.url
        }
    }
}

Describe 'Test Input Body to Query Translation' {
    Context 'RecoveryBackupLocationSpec Body to Query Input Translation' {
        It 'Translates Body to Query Input Object' {

            # Arrange
            . (Join-Path $PSScriptRoot 'vSphereRestApiTranslation.ps1')

            $operationTranslationSchema = Get-OperationTranslationSchema -operationPath '/api/appliance/recovery/backup/system-name?action=list' -operationVerb 'post'
            $inputSpec = '{"location":"https"}'
            $inputSpecObject = $inputSpec | ConvertFrom-JsonX

            # Act
            $actual = Convert-InputStructure $operationTranslationSchema $inputSpecObject -InputType Query

            # Assert
            $actual | Should -Not -Be $null
            $actual."loc_spec.location" | Should -Be 'https'
        }
    }

    Context 'RecoveryBackupLocationSpec and RecoveryBackupFilterSpec Body to Query Input Translation' {
        It 'Translates Body to Query Input Object' {

            # Arrange
            . (Join-Path $PSScriptRoot 'vSphereRestApiTranslation.ps1')

            $operationTranslationSchema = Get-OperationTranslationSchema -operationPath '/api/appliance/recovery/backup/system-name/{system_name}/archives?action=list' -operationVerb 'post'
            $inputSpec = '{"loc_spec":{"location":"https"},"filter_spec":{"max_results":10}}'
            $inputSpecObject = $inputSpec | ConvertFrom-JsonX

            # Act
            $actual = Convert-InputStructure $operationTranslationSchema $inputSpecObject -InputType Query

            # Assert
            $actual | Should -Not -Be $null
            $actual."loc_spec.location" | Should -Be 'https'
            $actual."filter_spec.max_results" | Should -Be 10
        }
    }
}

Describe 'Test Input Query to Body Translation' {
    It 'Translates Query to Body Input simple type' {
        # Arrange
        . (Join-Path $PSScriptRoot 'vSphereRestApiTranslation.ps1')

        $operationTranslationSchema = Get-OperationTranslationSchema -operationPath '/api/content/library/item/download-session/{download_session_id}/file?file_name' -operationVerb 'get'

        $fileName = 'my_custom_file_name.json'
        $fileNameBodyInput = [PSCustomObject] @{
            'file_name' = $fileName
        }
        $fileNameQueryInput = $fileName

        # Act
        $actual = Convert-InputStructure $operationTranslationSchema $fileNameQueryInput -InputType Body

        # Assert
        $actual | Should -Not -BeNullOrEmpty
        $actual.file_name | Should -Be $fileNameBodyInput.file_name
    }

    It 'Translates Query to Body Input array type' {
        # Arrange
        . (Join-Path $PSScriptRoot 'vSphereRestApiTranslation.ps1')

        $operationTranslationSchema = Get-OperationTranslationSchema -operationPath '/api/vcenter/inventory/network' -operationVerb 'get'

        $networks = @('network 1', 'network 2')
        $networksBodyInput = [PSCustomObject] @{
            'networks' = $networks
        }
        $networksQueryInput = $networks

        # Act
        $actual = Convert-InputStructure $operationTranslationSchema $networksQueryInput -InputType Body

        # Assert
        $actual | Should -Not -BeNullOrEmpty
        $actual.networks.Count | Should -Be $networksBodyInput.networks.Count
        $actual.networks | Should -Be $networksBodyInput.networks
    }
}

# SIG # Begin signature block
# MIIexgYJKoZIhvcNAQcCoIIetzCCHrMCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAUa+fwg0FUUgog
# eO8Gcgn7HquDbijN7STwXHF0wfUl7KCCDdowggawMIIEmKADAgECAhAIrUCyYNKc
# TJ9ezam9k67ZMA0GCSqGSIb3DQEBDAUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNV
# BAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDAeFw0yMTA0MjkwMDAwMDBaFw0z
# NjA0MjgyMzU5NTlaMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwg
# SW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBDb2RlIFNpZ25pbmcg
# UlNBNDA5NiBTSEEzODQgMjAyMSBDQTEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAw
# ggIKAoICAQDVtC9C0CiteLdd1TlZG7GIQvUzjOs9gZdwxbvEhSYwn6SOaNhc9es0
# JAfhS0/TeEP0F9ce2vnS1WcaUk8OoVf8iJnBkcyBAz5NcCRks43iCH00fUyAVxJr
# Q5qZ8sU7H/Lvy0daE6ZMswEgJfMQ04uy+wjwiuCdCcBlp/qYgEk1hz1RGeiQIXhF
# LqGfLOEYwhrMxe6TSXBCMo/7xuoc82VokaJNTIIRSFJo3hC9FFdd6BgTZcV/sk+F
# LEikVoQ11vkunKoAFdE3/hoGlMJ8yOobMubKwvSnowMOdKWvObarYBLj6Na59zHh
# 3K3kGKDYwSNHR7OhD26jq22YBoMbt2pnLdK9RBqSEIGPsDsJ18ebMlrC/2pgVItJ
# wZPt4bRc4G/rJvmM1bL5OBDm6s6R9b7T+2+TYTRcvJNFKIM2KmYoX7BzzosmJQay
# g9Rc9hUZTO1i4F4z8ujo7AqnsAMrkbI2eb73rQgedaZlzLvjSFDzd5Ea/ttQokbI
# YViY9XwCFjyDKK05huzUtw1T0PhH5nUwjewwk3YUpltLXXRhTT8SkXbev1jLchAp
# QfDVxW0mdmgRQRNYmtwmKwH0iU1Z23jPgUo+QEdfyYFQc4UQIyFZYIpkVMHMIRro
# OBl8ZhzNeDhFMJlP/2NPTLuqDQhTQXxYPUez+rbsjDIJAsxsPAxWEQIDAQABo4IB
# WTCCAVUwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQUaDfg67Y7+F8Rhvv+
# YXsIiGX0TkIwHwYDVR0jBBgwFoAU7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYDVR0P
# AQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMDMHcGCCsGAQUFBwEBBGswaTAk
# BggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAC
# hjVodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9v
# dEc0LmNydDBDBgNVHR8EPDA6MDigNqA0hjJodHRwOi8vY3JsMy5kaWdpY2VydC5j
# b20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNybDAcBgNVHSAEFTATMAcGBWeBDAED
# MAgGBmeBDAEEATANBgkqhkiG9w0BAQwFAAOCAgEAOiNEPY0Idu6PvDqZ01bgAhql
# +Eg08yy25nRm95RysQDKr2wwJxMSnpBEn0v9nqN8JtU3vDpdSG2V1T9J9Ce7FoFF
# UP2cvbaF4HZ+N3HLIvdaqpDP9ZNq4+sg0dVQeYiaiorBtr2hSBh+3NiAGhEZGM1h
# mYFW9snjdufE5BtfQ/g+lP92OT2e1JnPSt0o618moZVYSNUa/tcnP/2Q0XaG3Ryw
# YFzzDaju4ImhvTnhOE7abrs2nfvlIVNaw8rpavGiPttDuDPITzgUkpn13c5Ubdld
# AhQfQDN8A+KVssIhdXNSy0bYxDQcoqVLjc1vdjcshT8azibpGL6QB7BDf5WIIIJw
# 8MzK7/0pNVwfiThV9zeKiwmhywvpMRr/LhlcOXHhvpynCgbWJme3kuZOX956rEnP
# LqR0kq3bPKSchh/jwVYbKyP/j7XqiHtwa+aguv06P0WmxOgWkVKLQcBIhEuWTatE
# QOON8BUozu3xGFYHKi8QxAwIZDwzj64ojDzLj4gLDb879M4ee47vtevLt/B3E+bn
# KD+sEq6lLyJsQfmCXBVmzGwOysWGw/YmMwwHS6DTBwJqakAwSEs0qFEgu60bhQji
# WQ1tygVQK+pKHJ6l/aCnHwZ05/LWUpD9r4VIIflXO7ScA+2GRfS0YW6/aOImYIbq
# yK+p/pQd52MbOoZWeE4wggciMIIFCqADAgECAhAOxvKydqFGoH0ObZNXteEIMA0G
# CSqGSIb3DQEBCwUAMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwg
# SW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBDb2RlIFNpZ25pbmcg
# UlNBNDA5NiBTSEEzODQgMjAyMSBDQTEwHhcNMjEwODEwMDAwMDAwWhcNMjMwODEw
# MjM1OTU5WjCBhzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCkNhbGlmb3JuaWExEjAQ
# BgNVBAcTCVBhbG8gQWx0bzEVMBMGA1UEChMMVk13YXJlLCBJbmMuMRUwEwYDVQQD
# EwxWTXdhcmUsIEluYy4xITAfBgkqhkiG9w0BCQEWEm5vcmVwbHlAdm13YXJlLmNv
# bTCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAMD6lJG8OWkM12huIQpO
# /q9JnhhhW5UyW9if3/UnoFY3oqmp0JYX/ZrXogUHYXmbt2gk01zz2P5Z89mM4gqR
# bGYC2tx+Lez4GxVkyslVPI3PXYcYSaRp39JsF3yYifnp9R+ON8O3Gf5/4EaFmbeT
# ElDCFBfExPMqtSvPZDqekodzX+4SK1PIZxCyR3gml8R3/wzhb6Li0mG7l0evQUD0
# FQAbKJMlBk863apeX4ALFZtrnCpnMlOjRb85LsjV5Ku4OhxQi1jlf8wR+za9C3DU
# ki60/yiWPu+XXwEUqGInIihECBbp7hfFWrnCCaOgahsVpgz8kKg/XN4OFq7rbh4q
# 5IkTauqFhHaE7HKM5bbIBkZ+YJs2SYvu7aHjw4Z8aRjaIbXhI1G+NtaNY7kSRrE4
# fAyC2X2zV5i4a0AuAMM40C1Wm3gTaNtRTHnka/pbynUlFjP+KqAZhOniJg4AUfjX
# sG+PG1LH2+w/sfDl1A8liXSZU1qJtUs3wBQFoSGEaGBeDQIDAQABo4ICJTCCAiEw
# HwYDVR0jBBgwFoAUaDfg67Y7+F8Rhvv+YXsIiGX0TkIwHQYDVR0OBBYEFIhC+HL9
# QlvsWsztP/I5wYwdfCFNMB0GA1UdEQQWMBSBEm5vcmVwbHlAdm13YXJlLmNvbTAO
# BgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwgbUGA1UdHwSBrTCB
# qjBToFGgT4ZNaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3Rl
# ZEc0Q29kZVNpZ25pbmdSU0E0MDk2U0hBMzg0MjAyMUNBMS5jcmwwU6BRoE+GTWh0
# dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNENvZGVTaWdu
# aW5nUlNBNDA5NlNIQTM4NDIwMjFDQTEuY3JsMD4GA1UdIAQ3MDUwMwYGZ4EMAQQB
# MCkwJwYIKwYBBQUHAgEWG2h0dHA6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzCBlAYI
# KwYBBQUHAQEEgYcwgYQwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0
# LmNvbTBcBggrBgEFBQcwAoZQaHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0Rp
# Z2lDZXJ0VHJ1c3RlZEc0Q29kZVNpZ25pbmdSU0E0MDk2U0hBMzg0MjAyMUNBMS5j
# cnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAgEACQAYaQI6Nt2KgxdN
# 6qqfcHB33EZRSXkvs8O9iPZkdDjEx+2fgbBPLUvk9A7T8mRw7brbcJv4PLTYJDFo
# c5mlcmG7/5zwTOuIs2nBGXc/uxCnyW8p7kD4Y0JxPKEVQoIQ8lJS9Uy/hBjyakeV
# ef982JyzvDbOlLBy6AS3ZpXVkRY5y3Va+3v0R/0xJ+JRxUicQhiZRidq2TCiWEas
# d+tLL6jrKaBO+rmP52IM4eS9d4Yids7ogKEBAlJi0NbvuKO0CkgOlFjp1tOvD4sQ
# taHIMmqi40p4Tjyf/sY6yGjROXbMeeF1vlwbBAASPWpQuEIxrNHoVN30YfJyuOWj
# zdiJUTpeLn9XdjM3UlhfaHP+oIAKcmkd33c40SFRlQG9+P9Wlm7TcPxGU4wzXI8n
# Cw/h235jFlAAiWq9L2r7Un7YduqsheJVpGoXmRXJH0T2G2eNFS5/+2sLn98kN2Cn
# J7j6C242onjkZuGL2/+gqx8m5Jbpu9P4IAeTC1He/mX9j6XpIu+7uBoRVwuWD1i0
# N5SiUz7Lfnbr6Q1tHMXKDLFdwVKZos2AKEZhv4SU0WvenMJKDgkkhVeHPHbTahQf
# P1MetR8tdRs7uyTWAjPK5xf5DLEkXbMrUkpJ089fPvAGVHBcHRMqFA5egexOb6sj
# tKncUjJ1xAAtAExGdCh6VD2U5iYxghBCMIIQPgIBATB9MGkxCzAJBgNVBAYTAlVT
# MRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1
# c3RlZCBHNCBDb2RlIFNpZ25pbmcgUlNBNDA5NiBTSEEzODQgMjAyMSBDQTECEA7G
# 8rJ2oUagfQ5tk1e14QgwDQYJYIZIAWUDBAIBBQCggZYwGQYJKoZIhvcNAQkDMQwG
# CisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwKgYKKwYB
# BAGCNwIBDDEcMBqhGIAWaHR0cDovL3d3dy52bXdhcmUuY29tLzAvBgkqhkiG9w0B
# CQQxIgQgfTBHlBsxRV/ly8qB4fKpgXCxtd3619Cj9HfMYu3B+5wwDQYJKoZIhvcN
# AQEBBQAEggGAOk6c7udaFV+8YomZLiqLYdTobJ6r9RXurWab11Y+y8Y7ugCxpXsu
# cI6yBmHKxL6IwMFWq1RJlgZiL6R662k3EUz51lW8x3+WSVJ7QikCqcel/oFTYUkO
# 09axRP+0922X9AKleTbDChQNyn+lUw596y0/4AwN+xpCSLER9FVrGeSFfk9sSTw7
# RGf6lmbwrwRJ2fTfL5S3MnPkxfY1WwgbbVxG+KnYt+EcCpYZ8Q+V5+FHZ3PhEVPt
# MGF/goFbPFDAeOP26VUBeCtXKvbhcX/pqQSAcXbe2C3HaZYVISVUAHmbTh7bvzyz
# iIxoDTE8YBAc8MDqM2NAEIedn98ac9ULKjFw4BCgsdDilnYawUURh8CVg0ykSlqw
# 432YLubWcYNiC00grWwuG4OGn57REkQjAGncRE6qYq9wKic1ebOHPSEvkBTXJuZF
# hjSZsVlnBX57GmKLBTI78y3tcqBbcIg52D4bbR4HUT0Hik0OTfHKDvvHyhYdj9bM
# AQvimPm3N4V6oYINfTCCDXkGCisGAQQBgjcDAwExgg1pMIINZQYJKoZIhvcNAQcC
# oIINVjCCDVICAQMxDzANBglghkgBZQMEAgEFADB3BgsqhkiG9w0BCRABBKBoBGYw
# ZAIBAQYJYIZIAYb9bAcBMDEwDQYJYIZIAWUDBAIBBQAEIOmPQ25L8hTZwAyU46O8
# T2m5vtM56dgna0Sx8/1jeQSoAhAktjh5zcn1kGoSabPykMlSGA8yMDIxMDkyNDE2
# MTExNlqgggo3MIIE/jCCA+agAwIBAgIQDUJK4L46iP9gQCHOFADw3TANBgkqhkiG
# 9w0BAQsFADByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkw
# FwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEy
# IEFzc3VyZWQgSUQgVGltZXN0YW1waW5nIENBMB4XDTIxMDEwMTAwMDAwMFoXDTMx
# MDEwNjAwMDAwMFowSDELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJ
# bmMuMSAwHgYDVQQDExdEaWdpQ2VydCBUaW1lc3RhbXAgMjAyMTCCASIwDQYJKoZI
# hvcNAQEBBQADggEPADCCAQoCggEBAMLmYYRnxYr1DQikRcpja1HXOhFCvQp1dU2U
# tAxQtSYQ/h3Ib5FrDJbnGlxI70Tlv5thzRWRYlq4/2cLnGP9NmqB+in43Stwhd4C
# GPN4bbx9+cdtCT2+anaH6Yq9+IRdHnbJ5MZ2djpT0dHTWjaPxqPhLxs6t2HWc+xO
# bTOKfF1FLUuxUOZBOjdWhtyTI433UCXoZObd048vV7WHIOsOjizVI9r0TXhG4wOD
# MSlKXAwxikqMiMX3MFr5FK8VX2xDSQn9JiNT9o1j6BqrW7EdMMKbaYK02/xWVLwf
# oYervnpbCiAvSwnJlaeNsvrWY4tOpXIc7p96AXP4Gdb+DUmEvQECAwEAAaOCAbgw
# ggG0MA4GA1UdDwEB/wQEAwIHgDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoG
# CCsGAQUFBwMIMEEGA1UdIAQ6MDgwNgYJYIZIAYb9bAcBMCkwJwYIKwYBBQUHAgEW
# G2h0dHA6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzAfBgNVHSMEGDAWgBT0tuEgHf4p
# rtLkYaWyoiWyyBc1bjAdBgNVHQ4EFgQUNkSGjqS6sGa+vCgtHUQ23eNqerwwcQYD
# VR0fBGowaDAyoDCgLoYsaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL3NoYTItYXNz
# dXJlZC10cy5jcmwwMqAwoC6GLGh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9zaGEy
# LWFzc3VyZWQtdHMuY3JsMIGFBggrBgEFBQcBAQR5MHcwJAYIKwYBBQUHMAGGGGh0
# dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBPBggrBgEFBQcwAoZDaHR0cDovL2NhY2Vy
# dHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0U0hBMkFzc3VyZWRJRFRpbWVzdGFtcGlu
# Z0NBLmNydDANBgkqhkiG9w0BAQsFAAOCAQEASBzctemaI7znGucgDo5nRv1CclF0
# CiNHo6uS0iXEcFm+FKDlJ4GlTRQVGQd58NEEw4bZO73+RAJmTe1ppA/2uHDPYuj1
# UUp4eTZ6J7fz51Kfk6ftQ55757TdQSKJ+4eiRgNO/PT+t2R3Y18jUmmDgvoaU+2Q
# zI2hF3MN9PNlOXBL85zWenvaDLw9MtAby/Vh/HUIAHa8gQ74wOFcz8QRcucbZEnY
# Ipp1FUL1LTI4gdr0YKK6tFL7XOBhJCVPst/JKahzQ1HavWPWH1ub9y4bTxMd90oN
# cX6Xt/Q/hOvB46NJofrOp79Wz7pZdmGJX36ntI5nePk2mOHLKNpbh6aKLzCCBTEw
# ggQZoAMCAQICEAqhJdbWMht+QeQF2jaXwhUwDQYJKoZIhvcNAQELBQAwZTELMAkG
# A1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRp
# Z2ljZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENB
# MB4XDTE2MDEwNzEyMDAwMFoXDTMxMDEwNzEyMDAwMFowcjELMAkGA1UEBhMCVVMx
# FTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNv
# bTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIFRpbWVzdGFtcGlu
# ZyBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAL3QMu5LzY9/3am6
# gpnFOVQoV7YjSsQOB0UzURB90Pl9TWh+57ag9I2ziOSXv2MhkJi/E7xX08PhfgjW
# ahQAOPcuHjvuzKb2Mln+X2U/4Jvr40ZHBhpVfgsnfsCi9aDg3iI/Dv9+lfvzo7oi
# PhisEeTwmQNtO4V8CdPuXciaC1TjqAlxa+DPIhAPdc9xck4Krd9AOly3UeGheRTG
# TSQjMF287DxgaqwvB8z98OpH2YhQXv1mblZhJymJhFHmgudGUP2UKiyn5HU+upgP
# hH+fMRTWrdXyZMt7HgXQhBlyF/EXBu89zdZN7wZC/aJTKk+FHcQdPK/P2qwQ9d2s
# rOlW/5MCAwEAAaOCAc4wggHKMB0GA1UdDgQWBBT0tuEgHf4prtLkYaWyoiWyyBc1
# bjAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzASBgNVHRMBAf8ECDAG
# AQH/AgEAMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDCDB5Bggr
# BgEFBQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNv
# bTBDBggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lD
# ZXJ0QXNzdXJlZElEUm9vdENBLmNydDCBgQYDVR0fBHoweDA6oDigNoY0aHR0cDov
# L2NybDQuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDA6
# oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElE
# Um9vdENBLmNybDBQBgNVHSAESTBHMDgGCmCGSAGG/WwAAgQwKjAoBggrBgEFBQcC
# ARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzALBglghkgBhv1sBwEwDQYJ
# KoZIhvcNAQELBQADggEBAHGVEulRh1Zpze/d2nyqY3qzeM8GN0CE70uEv8rPAwL9
# xafDDiBCLK938ysfDCFaKrcFNB1qrpn4J6JmvwmqYN92pDqTD/iy0dh8GWLoXoIl
# HsS6HHssIeLWWywUNUMEaLLbdQLgcseY1jxk5R9IEBhfiThhTWJGJIdjjJFSLK8p
# ieV4H9YLFKWA1xJHcLN11ZOFk362kmf7U2GJqPVrlsD0WGkNfMgBsbkodbeZY4Ui
# jGHKeZR+WfyMD+NvtQEmtmyl7odRIeRYYJu6DC0rbaLEfrvEJStHAgh8Sa4TtuF8
# QkIoxhhWz0E0tmZdtnR79VYzIi8iNrJLokqV2PWmjlIxggKGMIICggIBATCBhjBy
# MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
# d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQg
# SUQgVGltZXN0YW1waW5nIENBAhANQkrgvjqI/2BAIc4UAPDdMA0GCWCGSAFlAwQC
# AQUAoIHRMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUx
# DxcNMjEwOTI0MTYxMTE2WjArBgsqhkiG9w0BCRACDDEcMBowGDAWBBTh14Ko4ZG+
# 72vKFpG1qrSUpiSb8zAvBgkqhkiG9w0BCQQxIgQgcRaK5IOmen00+f6r1z9pzh6C
# BEo5hkJeD/dxisUidgYwNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgsxCQBrwK2YMH
# kVcp4EQDQVyD4ykrYU8mlkyNNXHs9akwDQYJKoZIhvcNAQEBBQAEggEAGQm849jI
# 8L0e1PtMW6alWMindGoyaBV56YQLu8dQyq473ii1+9M9w5dFnPpKJmhkXz6sS9c9
# EPXQNnnG1AktZuPUMlKBUfKGqXhLoOKTxJVfTyFUR4Ai2q9US+CkWmQxkygUJGh0
# VbyOE28y2b9Zov8xuRXjaHrOAUkvk+eMM9c7gIwlXfH8JKMljcLe9YscVzvqj+eq
# BRpcj/xF0mhS77A8+ww0ls2SbpfsoVWzhOtDfZNtG31LWZ1bSsEyUscAg7utbNDv
# hQHd47eL4HMKJqHnw/SGGUpRk/Ty5Ms4tmbwhLvPFN9cjy7GikoO0BoL1RxqpDzT
# 7n30ajiUbrT+gQ==
# SIG # End signature block
