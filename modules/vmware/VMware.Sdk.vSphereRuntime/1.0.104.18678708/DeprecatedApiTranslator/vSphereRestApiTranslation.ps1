# Unhandled cases that algorithm is going to fail:

#
# 1.
# "OldPath": "/rest/appliance/recovery/backup/schedules/{schedule}"
# "NewPath": "/api/appliance/recovery/backup/schedules"

#
# 2.
#  "OldPath": "/rest/appliance/recovery/backup/system-name/{system_name}/archives",
#  "NewPath": "/api/appliance/recovery/backup/system-name/{system_name}/archives?action=list",

#
# 3. Structure with sefref properties
#

#
# 4. Query parameters
#

# The algorithm searches for matching substructs in the translation scheme
# comparing the first property of the Old and New structure scheme
# There is a risk of wrong translation if in the New structure scheme
# a property is added in front. Meaning the New APIs extend existing structure
# with new property added on the first position.

# Import All Translation Function
. (Join-Path $PSScriptRoot 'CommonAPITranslation.ps1')
. (Join-Path $PSScriptRoot 'InputTransformation.ps1')

$script:apiToTranslationFunction = @{}

# Example Function Registration

# $script:apiToTranslationFunction['post./api/appliance/recovery/backup/system-name/{system_name}/archives?action=list'] = @{
# 'ConvertToDeprecatedBody' = (Get-Command -Name 'ConvertTo-DeprecatedBodyApplianceRecoveryBackupList')
# 'ConvertFromDeprecatedBody' = $null
# 'ConvertDeprecatedQueryParam' = $null
# }

function Get-ConvertToDeprecatedBodyTranslationFunction {
    param(
        [Parameter()]
        [PSCustomObject]
        $OperationTranslateSchema)

    if ($OperationTranslateSchema -ne $null -and `
            $OperationTranslateSchema.NewVerb -ne $null -and `
            $OperationTranslateSchema.NewPath -ne $null) {

        $apiToTranslationFunctionKey = "$($OperationTranslateSchema.NewVerb).$($OperationTranslateSchema.NewPath)"
        if ($script:apiToTranslationFunction.ContainsKey($apiToTranslationFunctionKey) -and `
                $script:apiToTranslationFunction[$apiToTranslationFunctionKey]['ConvertToDeprecatedBody'] -ne $null) {

            return $script:apiToTranslationFunction[$apiToTranslationFunctionKey]['ConvertToDeprecatedBody']
        }
        else {
            return (Get-Command -Name 'ConvertTo-DeprecatedBodyCommon')
        }
    }
}

function Get-ConvertFromDeprecatedBodyTranslationFunction {
    param(
        [Parameter()]
        [PSCustomObject]
        $OperationTranslateSchema)

    if ($OperationTranslateSchema -ne $null -and `
            $OperationTranslateSchema.NewVerb -ne $null -and `
            $OperationTranslateSchema.NewPath -ne $null) {

        $apiToTranslationFunctionKey = "$($OperationTranslateSchema.NewVerb).$($OperationTranslateSchema.NewPath)"
        if ($script:apiToTranslationFunction.ContainsKey($apiToTranslationFunctionKey) -and `
                $script:apiToTranslationFunction[$apiToTranslationFunctionKey]['ConvertFromDeprecatedBody'] -ne $null) {

            return $script:apiToTranslationFunction[$apiToTranslationFunctionKey]['ConvertFromDeprecatedBody']
        }
        else {
            return (Get-Command -Name 'ConvertFrom-DeprecatedBodyCommon')
        }
    }
}

function Get-ConvertDeprecatedQueryParamTranslationFunction {
    param(
        [Parameter()]
        [PSCustomObject]
        $OperationTranslateSchema)

    if ($OperationTranslateSchema -ne $null -and `
            $OperationTranslateSchema.NewVerb -ne $null -and `
            $OperationTranslateSchema.NewPath -ne $null) {

        $apiToTranslationFunctionKey = "$($OperationTranslateSchema.NewVerb).$($OperationTranslateSchema.NewPath)"
        if ($script:apiToTranslationFunction.ContainsKey($apiToTranslationFunctionKey) -and `
                $script:apiToTranslationFunction[$apiToTranslationFunctionKey]['ConvertDeprecatedQueryParam'] -ne $null) {

            return $script:apiToTranslationFunction[$apiToTranslationFunctionKey]['ConvertDeprecatedQueryParam']
        }
        else {
            return (Get-Command -Name 'ConvertTo-DeprecatedQueryParamCommon')
        }
    }
}

function Read-OperationTranslationSchema {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript( { Test-Path $_ })]
        [string]
        $TranslationSchemeFilePath
    )

    Get-Content $TranslationSchemeFilePath -Raw | ConvertFrom-JsonX -Depth 100
}

$script:translationSchema = $null
function Load-OperationTranslationSchema {
    if (-not $script:translationSchema)	{
        $script:translationSchema = Read-OperationTranslationSchema (Join-Path $PSScriptRoot 'translation-scheme.json')
    }
}

function Get-OperationTranslationSchema {
    param(
        [Parameter()]
        [string]
        $operationPath = $null,

        [Parameter()]
        [string]
        $operationVerb = $null)

    Load-OperationTranslationSchema

    $script:translationSchema | Where-Object {
        ([string]::IsNullOrEmpty($operationPath) -or $_.NewPath -eq $operationPath) -and `
        ([string]::IsNullOrEmpty($operationVerb) -or $_.NewVerb -eq $operationVerb)
    }
}

function Convert-OutputBody {
    <#
    .SYNOPSIS
    Converts Body Output object from Deprecated APIs to New APIs

    .PARAMETER OperationTranslateSchema
    Translation Schema Object retrieved from Get-OperationTranslationSchema

    .PARAMETER OperationOutputObject
    API Operation Ouput Body Object to translate
#>
    param(
        [Parameter()]
        [PSCustomObject]
        $OperationTranslateSchema,

        [Parameter()]
        [PSCustomObject]
        $OperationOutputObject
    )
    $translationFunction = Get-ConvertFromDeprecatedBodyTranslationFunction -OperationTranslateSchema $OperationTranslateSchema
    & $translationFunction -OperationTranslateSchema $OperationTranslateSchema -OperationOutputObject $OperationOutputObject
}

function ConvertTo-DeprecatedBody {
    <#
    .SYNOPSIS
    Converts Body Parameter object from new APIs to Deprecated APIs

    .PARAMETER OperationTranslateSchema
    Translation Schema Object retrieved from Get-OperationTranslationSchema

    .PARAMETER OperationQueryInputObject
    API Operation Input Body Parameter Object to translate
#>
    param(
        [Parameter()]
        [PSCustomObject]
        $OperationTranslateSchema,

        [Parameter()]
        [PSCustomObject]
        $OperationInputObject
    )
    $translationFunction = Get-ConvertToDeprecatedBodyTranslationFunction -OperationTranslateSchema $OperationTranslateSchema
    & $translationFunction -OperationTranslateSchema $OperationTranslateSchema -OperationInputObject $OperationInputObject
}

function ConvertTo-DeprecatedQueryParam {
<#
    .SYNOPSIS
    Converts Query Param object from new APIs to Deprecated APIs

    .PARAMETER OperationTranslateSchema
    Translation Schema Object retrieved from Get-OperationTranslationSchema

    .PARAMETER OperationQueryInputObject
    API Operation Input Query Parameter Object to translate
#>
    param(
        [Parameter()]
        [PSCustomObject]
        $OperationTranslateSchema,

        [Parameter()]
        [PSCustomObject]
        $OperationQueryInputObject
    )

    $translationFunction = Get-ConvertDeprecatedQueryParamTranslationFunction -OperationTranslateSchema $OperationTranslateSchema
    & $translationFunction -OperationTranslateSchema $OperationTranslateSchema -OperationQueryInputObject $OperationQueryInputObject
}

function Convert-InputStructure {
    param(
        [Parameter()]
        [PSCustomObject]
        $OperationTranslateSchema,

        [Parameter()]
        [PSCustomObject]
        $OperationInputObject,

        [Parameter()]
        [ValidateSet('Body', 'Query')]
        [string]
        $InputType
    )

    if (
        $null -ne $OperationTranslateSchema.OldInQueryParams -and
        $null -eq $OperationTranslateSchema.OldInBodyStruct -and
        $null -eq $OperationTranslateSchema.NewInQueryParams -and
        $null -ne $OperationTranslateSchema.NewInBodyStruct -and
        $InputType -eq 'Query'
    ) {
        # Old operation has input in query that is migrated to body in the New APIs
        # Convert Body to Query

        $translationSchema = [PSCustomObject]@{
            'OldVerb' = $OperationTranslateSchema.OldVerb
            'NewVerb' = $OperationTranslateSchema.NewVerb
            'OldPath' = $OperationTranslateSchema.OldPath
            'NewPath' = $OperationTranslateSchema.NewPath
            'OldInQueryParams' = $OperationTranslateSchema.OldInQueryParams
            'NewInQueryParams' = $OperationTranslateSchema.NewInBodyStruct
        }

        # return
        (ConvertTo-DeprecatedQueryParam -OperationTranslateSchema $translationSchema -OperationQueryInputObject $OperationInputObject)
    }

    if (
        $null -eq $OperationTranslateSchema.OldInQueryParams -and
        $null -ne $OperationTranslateSchema.OldInBodyStruct -and
        $null -ne $OperationTranslateSchema.NewInQueryParams -and
        $null -eq $OperationTranslateSchema.NewInBodyStruct -and
        $InputType -eq 'Body'
    ) {
        # Old operation has input in body that is migrated to Query Params in the New APIs
        # Convert Query to Body

        $translationSchema = [PSCustomObject]@{
            'OldVerb' = $OperationTranslateSchema.OldVerb
            'NewVerb' = $OperationTranslateSchema.NewVerb
            'OldPath' = $OperationTranslateSchema.OldPath
            'NewPath' = $OperationTranslateSchema.NewPath
            'OldInBodyStruct' = $OperationTranslateSchema.OldInBodyStruct
            'NewInBodyStruct' = $OperationTranslateSchema.NewInQueryParams
        }

        $queryInputParameter = $OperationInputObject
        $oldStructProps = $translationSchema.OldInBodyStruct | Get-Member -MemberType NoteProperty

        # Handles query input parameter which is array.
        if (
            $OperationInputObject -is [array] -and
            $OperationInputObject.Count -gt 0 -and
            $oldStructProps.Count -eq 1 -and
            $translationSchema.NewInBodyStruct.Count -eq 1 -and
            $oldStructProps[0].Name -eq $translationSchema.NewInBodyStruct[0]
        ) {
            $queryInputParameter = [PSCustomObject] @{
                $translationSchema.NewInBodyStruct[0] = $OperationInputObject
            }
        }

        # return
        (ConvertTo-DeprecatedBody -OperationTranslateSchema $translationSchema -OperationInputObject $queryInputParameter)
    }

    if (
        $null -eq $OperationTranslateSchema.OldInQueryParams -and
        $null -ne $OperationTranslateSchema.OldInBodyStruct -and
        $null -eq $OperationTranslateSchema.NewInQueryParams -and
        $null -ne $OperationTranslateSchema.NewInBodyStruct -and
        $InputType -eq 'Body'
    ) {
        # Convert Body to Body
        # return
        (ConvertTo-DeprecatedBody -OperationTranslateSchema $OperationTranslateSchema -OperationInputObject $OperationInputObject)
    }

    if (
        $null -ne $OperationTranslateSchema.OldInQueryParams -and
        $null -eq $OperationTranslateSchema.OldInBodyStruct -and
        $null -ne $OperationTranslateSchema.NewInQueryParams -and
        $null -eq $OperationTranslateSchema.NewInBodyStruct -and
        $InputType -eq 'Query'
    ) {
        # Convert Query to Query
        # return
        (ConvertTo-DeprecatedQueryParam -OperationTranslateSchema $OperationTranslateSchema -OperationQueryInputObject $OperationInputObject)
    }
}

# SIG # Begin signature block
# MIIexwYJKoZIhvcNAQcCoIIeuDCCHrQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAPUgSTCsdjIQuv
# I3FxXJTa8np+So3sH38nK9JMfa8Es6CCDdowggawMIIEmKADAgECAhAIrUCyYNKc
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
# tKncUjJ1xAAtAExGdCh6VD2U5iYxghBDMIIQPwIBATB9MGkxCzAJBgNVBAYTAlVT
# MRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1
# c3RlZCBHNCBDb2RlIFNpZ25pbmcgUlNBNDA5NiBTSEEzODQgMjAyMSBDQTECEA7G
# 8rJ2oUagfQ5tk1e14QgwDQYJYIZIAWUDBAIBBQCggZYwGQYJKoZIhvcNAQkDMQwG
# CisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwKgYKKwYB
# BAGCNwIBDDEcMBqhGIAWaHR0cDovL3d3dy52bXdhcmUuY29tLzAvBgkqhkiG9w0B
# CQQxIgQg2AkQLhskIzS/gRCDspFtHbet39NwU2Z0TB98kv0YL48wDQYJKoZIhvcN
# AQEBBQAEggGAIusGpDS+1GOaCMy9kufUs9bQgjkI1j4sk6kgsl5pShlOtydtAZcD
# 7E7wwEuawDzO5X67Mz+9cpDK1XJrImDsVReEWdrn7IvBND/LFlqCngwYmn2i1fp3
# VXhnpWd2wjd5ZJmhx090wZWHBfY4LQwFjIBHaqGQCWYzUxsWV0nY6162GeQl8bTP
# Jpt7FehIOg42h2BSZpWz8gfMsi53p1J4D2tMrG22MZRPQxe2bKjQN70S7xdsKoZt
# ivIWKpilc6nQXtvDU1MaA+5jQ8wxzAoTjdE5uejV8uOZGS2y+TkxcmCJHaybbY3f
# /F828t466zfANIhJsvfTwjZWbA3Qi+veYzTDgkBpoQCCnyErTtJwaHp1MtUjf0N3
# 4FPSy1JgKmbFFps3Z7yfDrwRXLc44Q6CKRhrsdiQbNKU2ks9hIT0tgXVw17T6M1X
# /ICTVDWydTcSTjYBtRwA8jXuhaAYLBQf+yL8PfRppUO9iZthmGIxf2PgSSBDcp1w
# zWjXrHWhuG5boYINfjCCDXoGCisGAQQBgjcDAwExgg1qMIINZgYJKoZIhvcNAQcC
# oIINVzCCDVMCAQMxDzANBglghkgBZQMEAgEFADB4BgsqhkiG9w0BCRABBKBpBGcw
# ZQIBAQYJYIZIAYb9bAcBMDEwDQYJYIZIAWUDBAIBBQAEIEuYDAHWS17Iza/+hrp1
# sczY3VHIk+RI/JtErz5/0MXFAhEA3jDE98pvq2WgzVwUYVnceBgPMjAyMTA5MjQx
# NjExMTZaoIIKNzCCBP4wggPmoAMCAQICEA1CSuC+Ooj/YEAhzhQA8N0wDQYJKoZI
# hvcNAQELBQAwcjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZ
# MBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hB
# MiBBc3N1cmVkIElEIFRpbWVzdGFtcGluZyBDQTAeFw0yMTAxMDEwMDAwMDBaFw0z
# MTAxMDYwMDAwMDBaMEgxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwg
# SW5jLjEgMB4GA1UEAxMXRGlnaUNlcnQgVGltZXN0YW1wIDIwMjEwggEiMA0GCSqG
# SIb3DQEBAQUAA4IBDwAwggEKAoIBAQDC5mGEZ8WK9Q0IpEXKY2tR1zoRQr0KdXVN
# lLQMULUmEP4dyG+RawyW5xpcSO9E5b+bYc0VkWJauP9nC5xj/TZqgfop+N0rcIXe
# AhjzeG28ffnHbQk9vmp2h+mKvfiEXR52yeTGdnY6U9HR01o2j8aj4S8bOrdh1nPs
# Tm0zinxdRS1LsVDmQTo3VobckyON91Al6GTm3dOPL1e1hyDrDo4s1SPa9E14RuMD
# gzEpSlwMMYpKjIjF9zBa+RSvFV9sQ0kJ/SYjU/aNY+gaq1uxHTDCm2mCtNv8VlS8
# H6GHq756WwogL0sJyZWnjbL61mOLTqVyHO6fegFz+BnW/g1JhL0BAgMBAAGjggG4
# MIIBtDAOBgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAK
# BggrBgEFBQcDCDBBBgNVHSAEOjA4MDYGCWCGSAGG/WwHATApMCcGCCsGAQUFBwIB
# FhtodHRwOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwHwYDVR0jBBgwFoAU9LbhIB3+
# Ka7S5GGlsqIlssgXNW4wHQYDVR0OBBYEFDZEho6kurBmvrwoLR1ENt3janq8MHEG
# A1UdHwRqMGgwMqAwoC6GLGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9zaGEyLWFz
# c3VyZWQtdHMuY3JsMDKgMKAuhixodHRwOi8vY3JsNC5kaWdpY2VydC5jb20vc2hh
# Mi1hc3N1cmVkLXRzLmNybDCBhQYIKwYBBQUHAQEEeTB3MCQGCCsGAQUFBzABhhho
# dHRwOi8vb2NzcC5kaWdpY2VydC5jb20wTwYIKwYBBQUHMAKGQ2h0dHA6Ly9jYWNl
# cnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFNIQTJBc3N1cmVkSURUaW1lc3RhbXBp
# bmdDQS5jcnQwDQYJKoZIhvcNAQELBQADggEBAEgc3LXpmiO85xrnIA6OZ0b9QnJR
# dAojR6OrktIlxHBZvhSg5SeBpU0UFRkHefDRBMOG2Tu9/kQCZk3taaQP9rhwz2Lo
# 9VFKeHk2eie38+dSn5On7UOee+e03UEiifuHokYDTvz0/rdkd2NfI1Jpg4L6GlPt
# kMyNoRdzDfTzZTlwS/Oc1np72gy8PTLQG8v1Yfx1CAB2vIEO+MDhXM/EEXLnG2RJ
# 2CKadRVC9S0yOIHa9GCiurRS+1zgYSQlT7LfySmoc0NR2r1j1h9bm/cuG08THfdK
# DXF+l7f0P4TrweOjSaH6zqe/Vs+6WXZhiV9+p7SOZ3j5NpjhyyjaW4emii8wggUx
# MIIEGaADAgECAhAKoSXW1jIbfkHkBdo2l8IVMA0GCSqGSIb3DQEBCwUAMGUxCzAJ
# BgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5k
# aWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBD
# QTAeFw0xNjAxMDcxMjAwMDBaFw0zMTAxMDcxMjAwMDBaMHIxCzAJBgNVBAYTAlVT
# MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
# b20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBUaW1lc3RhbXBp
# bmcgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC90DLuS82Pf92p
# uoKZxTlUKFe2I0rEDgdFM1EQfdD5fU1ofue2oPSNs4jkl79jIZCYvxO8V9PD4X4I
# 1moUADj3Lh477sym9jJZ/l9lP+Cb6+NGRwYaVX4LJ37AovWg4N4iPw7/fpX786O6
# Ij4YrBHk8JkDbTuFfAnT7l3ImgtU46gJcWvgzyIQD3XPcXJOCq3fQDpct1HhoXkU
# xk0kIzBdvOw8YGqsLwfM/fDqR9mIUF79Zm5WYScpiYRR5oLnRlD9lCosp+R1PrqY
# D4R/nzEU1q3V8mTLex4F0IQZchfxFwbvPc3WTe8GQv2iUypPhR3EHTyvz9qsEPXd
# rKzpVv+TAgMBAAGjggHOMIIByjAdBgNVHQ4EFgQU9LbhIB3+Ka7S5GGlsqIlssgX
# NW4wHwYDVR0jBBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8wEgYDVR0TAQH/BAgw
# BgEB/wIBADAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwgweQYI
# KwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5j
# b20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwgYEGA1UdHwR6MHgwOqA4oDaGNGh0dHA6
# Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmww
# OqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJ
# RFJvb3RDQS5jcmwwUAYDVR0gBEkwRzA4BgpghkgBhv1sAAIEMCowKAYIKwYBBQUH
# AgEWHGh0dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwCwYJYIZIAYb9bAcBMA0G
# CSqGSIb3DQEBCwUAA4IBAQBxlRLpUYdWac3v3dp8qmN6s3jPBjdAhO9LhL/KzwMC
# /cWnww4gQiyvd/MrHwwhWiq3BTQdaq6Z+CeiZr8JqmDfdqQ6kw/4stHYfBli6F6C
# JR7Euhx7LCHi1lssFDVDBGiy23UC4HLHmNY8ZOUfSBAYX4k4YU1iRiSHY4yRUiyv
# KYnleB/WCxSlgNcSR3CzddWThZN+tpJn+1Nhiaj1a5bA9FhpDXzIAbG5KHW3mWOF
# IoxhynmUfln8jA/jb7UBJrZspe6HUSHkWGCbugwtK22ixH67xCUrRwIIfEmuE7bh
# fEJCKMYYVs9BNLZmXbZ0e/VWMyIvIjayS6JKldj1po5SMYIChjCCAoICAQEwgYYw
# cjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQ
# d3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVk
# IElEIFRpbWVzdGFtcGluZyBDQQIQDUJK4L46iP9gQCHOFADw3TANBglghkgBZQME
# AgEFAKCB0TAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkF
# MQ8XDTIxMDkyNDE2MTExNlowKwYLKoZIhvcNAQkQAgwxHDAaMBgwFgQU4deCqOGR
# vu9ryhaRtaq0lKYkm/MwLwYJKoZIhvcNAQkEMSIEIAQMGgJuvPPlZrPN2nIkeLdm
# i9tvxrIJaiir0cuMXU9hMDcGCyqGSIb3DQEJEAIvMSgwJjAkMCIEILMQkAa8CtmD
# B5FXKeBEA0Fcg+MpK2FPJpZMjTVx7PWpMA0GCSqGSIb3DQEBAQUABIIBAGDGNSCR
# DQwZAOT9CLeDnCZhlnVWr/OXGHKZeXW8JtKmTcYJAviI/hIFJ7ABWZ28glADzuxh
# QDxikirHGnkVq5lb6ttovVwtvL6/0mR9PCz3PCzgOjeGfH1pVuSnV0ug7QeHMGvu
# kEXYKxJ970dpZu/ekyXso1y4nsvPRepjDsiBe/KtGBB8JIuxuUxcW1TixiU/F2+n
# BnFRg37BUT08U9DNVvl30hjxp+XctPCnAS92uR4SZJH8L4jkLsL1RGjoFWMMBfYl
# imitgrvQt+2AT6sRUh6OyJZwvbCs4s9FUDbA5NuSxZMUuvbgMuOb0I+hpgf6+PTO
# +ApdIvChfONNnCA=
# SIG # End signature block
