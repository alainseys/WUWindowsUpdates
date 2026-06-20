Param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Server,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $User,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Password
)

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

Describe 'PowerShell Cmdlets Extensions Tests' {
    BeforeAll {
        . (Join-Path -Path $PSScriptRoot -ChildPath 'PowerShellCmdletsExtensions.ps1')

        $certificateThumbprint = $null

        if ($Global:PSVersionTable.PSEdition -eq 'Desktop') {
            $initialMaxServicePointIdleTime = [System.Net.ServicePointManager]::MaxServicePointIdleTime
            $maxServicePointIdleTimeInMilliseconds = 1

            [System.Net.ServicePointManager]::MaxServicePointIdleTime = $maxServicePointIdleTimeInMilliseconds

            $certificateThumbprint = Get-TlsCertificateThumbprintFromRemoteHost -RemoteHostName $Server
        }
    }

    AfterAll {
        if ($Global:PSVersionTable.PSEdition -eq 'Desktop') {
            [System.Net.ServicePointManager]::MaxServicePointIdleTime = $initialMaxServicePointIdleTime
        }
    }

    Context 'Invoke-WebRequestX Tests' {
        It 'Should skip all Certificate checks when SkipCertificateCheck parameter is passed with $true value' {
            # Arrange
            $localVarBytes = [System.Text.Encoding]::UTF8.GetBytes($User + ':' + $Password)
            $localVarBase64Text = [Convert]::ToBase64String($localVarBytes)
            $headers = @{
                'Authorization' = "Basic $localVarBase64Text"
                'Accept' = 'application/json'
            }

            $secureStringPassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
            $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $secureStringPassword

            $invokeWebRequestParams = @{
                'Uri' = "https://$Server/api/session"
                'Method' = 'POST'
                'Headers' = $headers
                'ErrorAction' = 'Stop'
                'UseBasicParsing' = $true
                'Credential' = $credential
            }

            # Act
            if ($Global:PSVersionTable.PSEdition -eq 'Desktop') {
                [CustomCertificatesValidator]::AddCertificateToCache($certificateThumbprint)
            }

            $result = Invoke-WebRequestX -InvokeParams $invokeWebRequestParams -SkipCertificateCheck $true

            # Assert
            $result | Should -Not -Be $null
            $result.StatusCode | Should -Be 201
            $result.Content | Should -Not -BeNullOrEmpty
            $result.Headers | Should -Not -Be $null
            $result.Headers['Content-Type'] | Should -Be 'application/json'
            $result.Headers['vmware-api-session-id'] | Should -Not -BeNullOrEmpty
        }

        It 'Should throw an exception with the expected message when SkipCertificateCheck parameter is passed with $false value' {
            # Arrange
            $localVarBytes = [System.Text.Encoding]::UTF8.GetBytes($User + ':' + $Password)
            $localVarBase64Text = [Convert]::ToBase64String($localVarBytes)
            $headers = @{
                'Authorization' = "Basic $localVarBase64Text"
                'Accept' = 'application/json'
            }

            $secureStringPassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
            $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $secureStringPassword

            $invokeWebRequestParams = @{
                'Uri' = "https://$Server/api/session"
                'Method' = 'POST'
                'Headers' = $headers
                'ErrorAction' = 'Stop'
                'UseBasicParsing' = $true
                'Credential' = $credential
            }

            if ($Global:PSVersionTable.PSEdition -eq 'Desktop') {
                [CustomCertificatesValidator]::RemoveCertificateFromCache($certificateThumbprint) | Out-Null
            }

            $corePowerShellExpectedExceptionMessage = 'The SSL connection could not be established, see inner exception.'
            $desktopPowerShellExpectedExceptionMessage = 'The underlying connection was closed: Could not establish trust relationship for the SSL/TLS secure channel.'
            $expectedInnerExceptionMessage = 'The remote certificate is invalid according to the validation procedure*'

            # Act
            $actualError = $null
            try {
                Invoke-WebRequestX -InvokeParams $invokeWebRequestParams -SkipCertificateCheck $false
            } catch {
                $actualError = $_
            }

            # Assert
            $actualError | Should -Not -Be $null
            $actualError.Exception | Should -Not -Be $null

            if ($Global:PSVersionTable.PSEdition -eq 'Core') {
                $actualError.Exception.Message | Should -Be $corePowerShellExpectedExceptionMessage
            } else {
                $actualError.Exception.Message | Should -Be $desktopPowerShellExpectedExceptionMessage
            }

            $actualError.Exception.InnerException | Should -Not -Be $null
            $actualError.Exception.InnerException.Message | Should -BeLike $expectedInnerExceptionMessage
        }
    }

    Context 'Invoke-RestMethodX Tests' {
        It 'Should skip all Certificate checks when SkipCertificateCheck parameter is passed with $true value' {
            # Arrange
            $localVarBytes = [System.Text.Encoding]::UTF8.GetBytes($User + ':' + $Password)
            $localVarBase64Text = [Convert]::ToBase64String($localVarBytes)
            $headers = @{
                'Authorization' = "Basic $localVarBase64Text"
                'Accept' = 'application/json'
            }

            $secureStringPassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
            $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $secureStringPassword

            $invokeWebRequestParams = @{
                'Uri' = "https://$Server/api/session"
                'Method' = 'POST'
                'Headers' = $headers
                'ErrorAction' = 'Stop'
                'UseBasicParsing' = $true
                'Credential' = $credential
            }

            if ($Global:PSVersionTable.PSEdition -eq 'Desktop') {
                [CustomCertificatesValidator]::AddCertificateToCache($certificateThumbprint)
            }

            $sessionId = Invoke-WebRequestX -InvokeParams $invokeWebRequestParams -SkipCertificateCheck $true
            $headers['vmware-api-session-id'] = $sessionId -Replace '"', ''

            $invokeRestMethodParams = @{
                'Uri' = "https://$Server/rest/appliance/system/version"
                'Method' = 'GET'
                'Headers' = $headers
            }

            # Act
            $result = Invoke-RestMethodX -InvokeParams $invokeRestMethodParams -SkipCertificateCheck $true

            # Assert
            $result | Should -Not -Be $null
            $result.value | Should -Not -Be $null
            $result.value.version | Should -Not -Be $null
            [System.Version] $result.value.version | Should -Not -Be $null
        }

        It 'Should throw an exception with the expected message when SkipCertificateCheck parameter is passed with $false value' {
            # Arrange
            $localVarBytes = [System.Text.Encoding]::UTF8.GetBytes($User + ':' + $Password)
            $localVarBase64Text = [Convert]::ToBase64String($localVarBytes)
            $headers = @{
                'Authorization' = "Basic $localVarBase64Text"
                'Accept' = 'application/json'
            }

            $invokeRestMethodParams = @{
                'Uri' = "https://$Server/rest/appliance/system/version"
                'Method' = 'GET'
                'Headers' = $headers
            }

            if ($Global:PSVersionTable.PSEdition -eq 'Desktop') {
                [CustomCertificatesValidator]::RemoveCertificateFromCache($certificateThumbprint) | Out-Null
            }

            $corePowerShellExpectedExceptionMessage = 'The SSL connection could not be established, see inner exception.'
            $desktopPowerShellExpectedExceptionMessage = 'The underlying connection was closed: Could not establish trust relationship for the SSL/TLS secure channel.'
            $expectedInnerExceptionMessage = 'The remote certificate is invalid according to the validation procedure*'

            # Act
            $actualError = $null
            try {
                Invoke-RestMethodX -InvokeParams $invokeRestMethodParams -SkipCertificateCheck $false
            } catch {
                $actualError = $_
            }

            # Assert
            $actualError | Should -Not -Be $null
            $actualError.Exception | Should -Not -Be $null

            if ($Global:PSVersionTable.PSEdition -eq 'Core') {
                $actualError.Exception.Message | Should -Be $corePowerShellExpectedExceptionMessage
            } else {
                $actualError.Exception.Message | Should -Be $desktopPowerShellExpectedExceptionMessage
            }

            $actualError.Exception.InnerException | Should -Not -Be $null
            $actualError.Exception.InnerException.Message | Should -BeLike $expectedInnerExceptionMessage
        }
    }

    Context 'Get-PlainTextPassword Tests' {
        It 'Should retrieve the password as plain text from the SecureString' {
            # Arrange
            $expected = 'MyTestPassword'
            $secureStringPassword = ConvertTo-SecureString -String $expected -AsPlainText -Force

            # Act
            $actual = Get-PlainTextPassword -Password $secureStringPassword

            # Assert
            $actual | Should -Be $expected
        }
    }

    Context 'ConvertFrom-JsonX Tests' {
        It 'Should convert the specified JSON to the expected PSCustomObject' {
            # Arrange
            $vmInfoJson = @"
            {
                "instant_clone_frozen": false,
                "guest_OS": "WINDOWS_SERVER_2019",
                "power_state": "POWERED_OFF",
                "name": "testvm",
                "boot_devices": [],
                "custom_vm_props": ["custom_vm_prop_one", "custom_vm_prop_two"],
                "custom_vm_array": ["custom_vm_array_element"],
                "hardware": {
                    "upgrade_policy": "NEVER",
                    "upgrade_status": "NONE",
                    "version": "VMX_19"
                },
                "cdroms": {
                    "16000": {
                        "start_connected": false,
                        "backing": {
                            "device_access_type": "PASSTHRU",
                            "type": "CLIENT_DEVICE"
                        },
                        "allow_guest_control": true,
                        "label": "CD/DVD drive 1",
                        "state": "NOT_CONNECTED",
                        "type": "SATA",
                        "sata": {
                            "bus": 0,
                            "unit": 0
                        }
                    }
                }
            }
"@

            $expected = [PSCustomObject] @{
                'instant_clone_frozen' = $false
                'guest_OS' = 'WINDOWS_SERVER_2019'
                'power_state' = 'POWERED_OFF'
                'name' = 'testvm'
                'boot_devices' = @()
                'hardware' = [PSCustomObject] @{
                    'upgrade_policy' = 'NEVER'
                    'upgrade_status' = 'NONE'
                    'version' = 'VMX_19'
                }
                'cdroms' = [PSCustomObject] @{
                    '16000' = [PSCustomObject] @{
                        'start_connected' = $false
                        'backing' = [PSCustomObject] @{
                            'device_access_type' = 'PASSTHRU'
                            'type' = 'CLIENT_DEVICE'
                        }
                        'allow_guest_control' = $true
                        'label' = 'CD/DVD drive 1'
                        'state' = 'NOT_CONNECTED'
                        'type' = 'SATA'
                        'sata' = [PSCustomObject] @{
                            'bus' = 0
                            'unit' = 0
                        }
                    }
                }
                'custom_vm_props' = @(
                    "custom_vm_prop_one",
                    "custom_vm_prop_two"
                )
                'custom_vm_array' = @("custom_vm_array_element")
            }

            # Act
            $actual = ConvertFrom-JsonX -InputObject $vmInfoJson -Depth 100

            # Assert
            Test-ObjectsAreEqual $actual $expected | Should -BeTrue
        }
    }
}

# SIG # Begin signature block
# MIIexgYJKoZIhvcNAQcCoIIetzCCHrMCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDu63KScQ0w2hBJ
# 05jUMpGtEbFlU73lYU6nQxd2OjUmdaCCDdowggawMIIEmKADAgECAhAIrUCyYNKc
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
# CQQxIgQgQ1SATk3LEqVYSVa4pSG7x3SH4yz1E3MjaKOug8ovJ5wwDQYJKoZIhvcN
# AQEBBQAEggGAvvW8iPhGTLAGLrWhGpEbPhOWuolfnC0Kep2ZuEmcRsX2NDI+ZL3j
# wuo+7rd/rwOBZ1ELmHkrXQPsXo7W54qltXoSzG0V8DRC5qIx9TXaO5oI5AHjk+qN
# mit3RBuJlL9hoMd7AIqKTdTin9XAtj8GFcfoa6qkQQqqVV9bnTuApBalwOqO2BgD
# 1PY4IUlC+tDy2b28R6bKHVmiT5S5Q+HqqSX/QweDLsmU8wBI4ZB4LqnpU1ZNvtRs
# bJbecFGMYGGJ0aW4OIap9M6S+wZf9agvoj2WPobeCqtMMbdJXdBvVSVvQBrV2fBg
# wCAXlTk4kuTRGq7bg7cZFCCejcoCW6fAPw7IEN704ekF5OjaHXEjcqOYs2+iktdg
# qygftPAmfMtl91HuNcmkVXQkGF9WsFTd/NEt1OhbHShOdUcoCObMJVruo0gjgEVv
# ovFkRlOTbt9C7O5sva7tjG1Mzv8Szki9Ix7tmMugk9QC9fxfPm+/541tA+SlJ2B1
# gXAKPkHwmZS8oYINfTCCDXkGCisGAQQBgjcDAwExgg1pMIINZQYJKoZIhvcNAQcC
# oIINVjCCDVICAQMxDzANBglghkgBZQMEAgEFADB3BgsqhkiG9w0BCRABBKBoBGYw
# ZAIBAQYJYIZIAYb9bAcBMDEwDQYJYIZIAWUDBAIBBQAEIKjicO2YVUOavqmZyFAy
# 8GNJS7OOs18uY4J5kRbEAhqbAhAq7u82V64T+onEiW/hCroLGA8yMDIxMDkxNDE2
# MDQ1M1qgggo3MIIE/jCCA+agAwIBAgIQDUJK4L46iP9gQCHOFADw3TANBgkqhkiG
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
# DxcNMjEwOTE0MTYwNDUzWjArBgsqhkiG9w0BCRACDDEcMBowGDAWBBTh14Ko4ZG+
# 72vKFpG1qrSUpiSb8zAvBgkqhkiG9w0BCQQxIgQgtIaZO9LKihn0pQMH17XaZeSN
# zheWeEj2OTMnTDljp18wNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgsxCQBrwK2YMH
# kVcp4EQDQVyD4ykrYU8mlkyNNXHs9akwDQYJKoZIhvcNAQEBBQAEggEAY8X8wIBO
# cfCzX1AwLJQ1F7zqyanfWiK79OFrGz7mjM1wEc3Ot9sqMZippq4uu1s/ZZXDZqxm
# T7ukFzfE9cZas8XDkCXFDvbJILG3C5U+zFPDLBSHNQQFfLCOrC6g3BeidGhGbfPY
# 1D9VxmX2gJWT+1QtxaN2muWVQ+V4hCMKDWfe9Jj6GC+dFdlP2OLADBtZw4P5Lxtm
# jYR3nCP7mWy0J8qkY3gp8rjjsp3AZMDy3a7yYskGk0yDmPoRRjxxuVhavw5ZSpDl
# DXZZ0bYtglD8N4EzRzY/PKkWvMitrsMxneOd9wpch4rqUsdKeQ/rOSdwYSaCnRLp
# OkH+QPFa48cYBQ==
# SIG # End signature block
