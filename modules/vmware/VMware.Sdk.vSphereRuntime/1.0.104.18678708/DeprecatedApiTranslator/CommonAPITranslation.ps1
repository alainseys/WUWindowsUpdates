
# The algorithm searches for matching substructs in the translation scheme
# comparing the first property of the Old and New structure scheme
# There is a risk of wrong translation if in the New structure scheme
# a property is added in front. Meaning the New APIs extend existing structure
# with new property added on the first position.

function ConvertFrom-DeprecatedBodyCommon {
    # Output body translation is always old -> new direction
    param(
        [Parameter()]
        [PSCustomObject]
        $OperationTranslateSchema,

        [Parameter()]
        [PSCustomObject]
        $OperationOutputObject
    )
    $convertArrayToPSObject = $false

    if ($OperationOutputObject -is [array]) {
        if ($OperationOutputObject.Count -eq 0) {
            $result = @()
            return , $result
        }
        else {
            if ($null -ne $OperationTranslateSchema.OldOutBodyStruct) {
                $oldSchemaProperties = $OperationTranslateSchema.OldOutBodyStruct | Get-Member -MemberType NoteProperty
                $convertArrayToPSObject = ($null -ne $oldSchemaProperties -and `
                        $oldSchemaProperties.Count -eq 2 -and `
                        $oldSchemaProperties[0].Name -eq 'key' -and `
                        $oldSchemaProperties[1].Name -eq 'value')
            }
        }
    }

    if ($convertArrayToPSObject) {
        $resultObject = New-Object PSCustomObject

        foreach ($outputObject in $OperationOutputObject) {
            $translationSchema = [PSCustomObject]@{
                'OldOutBodyStruct' = $($OperationTranslateSchema.OldOutBodyStruct.value)
                'NewOutBodyStruct' = $($OperationTranslateSchema.NewOutBodyStruct)
            }
            $resultObject | Add-Member -MemberType NoteProperty -Name $outputObject.Key -Value (ConvertFrom-DeprecatedBodyCommon $translationSchema $outputObject.value)
        }

        $resultObject

    }
    else {

        foreach ($outputObject in $OperationOutputObject) {

            if (-not $OperationTranslateSchema.OldOutBodyStruct -and -not $OperationTranslateSchema.NewOutBodyStruct) {
                # No Translation Needed
                # return
                $outputObject
            }

            if (-not $OperationTranslateSchema.OldOutBodyStruct -and $OperationTranslateSchema.NewOutBodyStruct) {
                # Translation Impossible
                # return
                $outputObject
            }

            if ($OperationTranslateSchema.OldOutBodyStruct -and -not $OperationTranslateSchema.NewOutBodyStruct) {
                # Old Operation Presents Simple Type as a Structure

                $oldSchemaProperties = $OperationTranslateSchema.OldOutBodyStruct | Get-Member -MemberType NoteProperty
                if ($null -ne $oldSchemaProperties -and $oldSchemaProperties.Count -eq 1) {
                    # Value Wrapper Pattern

                    foreach ($element in $outputObject) {
                        if ($element -is [array] -and $element.Length -eq 0) {
                            # empty array isconverted to empty object
                            $result = New-Object PSCustomObject
                            # return
                            $result
                        }
                        else {
                            # return
                            $element.$($oldSchemaProperties[0].Name)
                        }
                    }
                }

                if ($null -ne $oldSchemaProperties -and `
                        $oldSchemaProperties.Count -eq 2 -and `
                        $oldSchemaProperties[0].Name -eq 'key' -and `
                        $oldSchemaProperties[1].Name -eq 'value') {

                    $result = New-Object PSCustomObject

                    # Map to Array Pattern
                    foreach ($element in $outputObject) {
                        if ($element -is [array] -and $element.Length -eq 0) {
                            # empty array isconverted to empty object
                        }
                        else {
                            $result = New-Object PSCustomObject
                            $result | Add-Member -MemberType NoteProperty -Name $element.key -Value $element.Value
                        }
                    }

                    # return
                    $result
                }
            }


            if ($OperationTranslateSchema.OldOutBodyStruct -and $OperationTranslateSchema.NewOutBodyStruct) {
                # Structure to Structure Translation
                $oldStructProps = $OperationTranslateSchema.OldOutBodyStruct | Get-Member -MemberType NoteProperty
                $newStructProps = $OperationTranslateSchema.NewOutBodyStruct | Get-Member -MemberType NoteProperty
                if ($null -ne $newStructProps -and $null -ne $oldStructProps) {
                    if ($newStructProps[0].Name -eq $oldStructProps[0].Name) {
                        # Structures match no translation needed
                        # Traverse and Translate each property

                        $resultObject = New-Object PSCustomObject

                        foreach ($prop in $oldStructProps) {
                            $translationSchema = [PSCustomObject]@{
                                'OldOutBodyStruct' = $($OperationTranslateSchema.OldOutBodyStruct.$($prop.Name))
                                'NewOutBodyStruct' = $($OperationTranslateSchema.NewOutBodyStruct.$($prop.Name))
                            }

                            $translatedValue = (ConvertFrom-DeprecatedBodyCommon $translationSchema $outputObject.($prop.Name))

                            if ($null -ne $translatedValue) {
                                $resultObject | Add-Member `
                                    -MemberType NoteProperty `
                                    -Name $prop.Name `
                                    -Value $translatedValue
                            }
                        }

                        # return
                        $resultObject
                    }
                    else {
                        if ($oldStructProps.Count -eq 1) {
                            # Value Wrapper Pattern
                            $translationSchema = [PSCustomObject]@{
                                'OldOutBodyStruct' = $($OperationTranslateSchema.OldOutBodyStruct.$($oldStructProps[0].Name))
                                'NewOutBodyStruct' = $($OperationTranslateSchema.NewOutBodyStruct)
                            }

                            # return
                            (ConvertFrom-DeprecatedBodyCommon $translationSchema $outputObject.($oldStructProps[0].Name))
                        }

                        if ($oldStructProps.Count -eq 2 -and `
                                $oldStructProps[0].Name -eq 'key' -and `
                                $oldStructProps[1].Name -eq 'value') {
                            # Map to Array pattern

                            # Handle Empty array
                            if ($outputObject -is [array] -and $outputObject.Length -eq 0) {
                                # empty array isconverted to empty object
                                $result = New-Object PSCustomObject
                                # return
                                $result
                            }
                            else {
                                $result = New-Object PSCustomObject

                                foreach ($element in $outputObject) {
                                    $translationSchema = [PSCustomObject]@{
                                        'OldOutBodyStruct' = $($OperationTranslateSchema.OldOutBodyStruct.value)
                                        'NewOutBodyStruct' = $($OperationTranslateSchema.NewOutBodyStruct)
                                    }

                                    $result | Add-Member `
                                        -MemberType NoteProperty `
                                        -Name $element.key `
                                        -Value (ConvertFrom-DeprecatedBodyCommon $translationSchema ($element.value))
                                }

                                # return
                                $result
                            }
                        }
                    }
                }

                if ($null -eq $newStructProps -and $null -ne $oldStructProps) {
                    # Old Operation Presents Simple Type as a Structure
                    foreach ($element in $outputObject) {
                        $noteProperties = $element | Get-Member -MemberType NoteProperty
                        if ($null -ne $noteProperties -and $noteProperties.Count -eq 1) {
                            # Value Wrapper Pattern

                            # return
                            $element.$($noteProperties[0].Name)
                        }

                        if ($null -ne $noteProperties -and `
                                $noteProperties.Count -eq 2 -and `
                                $noteProperties[0].Name -eq 'key' -and `
                                $noteProperties[1].Name -eq 'value') {
                            # Map to Array Pattern
                            $result = New-Object PSCustomObject
                            $result | Add-Member -MemberType NoteProperty -Name $element.key -Value $element.Value
                            # return
                            $result
                        }
                    }
                }

                if ($null -eq $newStructProps -and $null -eq $oldStructProps) {
                    # If the OperationOutputObject is an array, using foreach will result in
                    # returning only the first element of the array, instead of the whole array.
                    if ($OperationOutputObject -is [array]) {
                        # return the whole array and use the comma syntax in the case of array with only one element
                        , $OperationOutputObject
                    } else {
                        # return the current object only
                        $outputObject
                    }
                }
            }
        }
    }
}

function ConvertTo-DeprecatedBodyCommon {
    # Input body translation is always new -> old direction
    param(
        [Parameter()]
        [PSCustomObject]
        $OperationTranslateSchema,

        [Parameter()]
        [PSCustomObject]
        $OperationInputObject
    )
    if ($OperationInputObject -is [array] -and $OperationInputObject.Count -eq 0) {
        return (New-Object PSCustomObject)
    }


    $result = $null
    if ($OperationInputObject -is [array]) {
        $result = @()
    }

    foreach ($inputObject in $OperationInputObject) {
        $singleObjectResult = $null
        if (-not $OperationTranslateSchema.OldInBodyStruct -and -not $OperationTranslateSchema.NewInBodyStruct) {
            # No Translation Needed
            $singleObjectResult = $inputObject
        }

        if (-not $OperationTranslateSchema.OldInBodyStruct -and $OperationTranslateSchema.NewInBodyStruct) {
            # Translation Impossible
            # return and let the server to fail
            $singleObjectResult = $inputObject
        }

        if ($OperationTranslateSchema.OldInBodyStruct -and -not $OperationTranslateSchema.NewInBodyStruct) {
            # Old Operation Presents Simple Type as a Structure
            $oldSchemaProperties = $OperationTranslateSchema.OldInBodyStruct | Get-Member -MemberType NoteProperty
            if ($null -ne $oldSchemaProperties -and $oldSchemaProperties.Count -eq 1) {
                # Value Wrapper Pattern

                foreach ($element in $inputObject) {
                    if ($element -is [PSCustomObject] -and ($element | Get-Member -MemberType NoteProperty).Count -eq 0) {
                        # empty PSCustom Object is converted to empty array
                        # return
                        $singleObjectResult = @()
                    }
                    else {
                        $resultObject = New-Object PSCustomObject
                        $resultObject | Add-Member -MemberType NoteProperty -Name $oldSchemaProperties[0].Name -Value $element
                        # return
                        $singleObjectResult = $resultObject
                    }
                }
            }

            if ($null -ne $oldSchemaProperties -and `
                    $oldSchemaProperties.Count -eq 2 -and `
                    $oldSchemaProperties[0].Name -eq 'key' -and `
                    $oldSchemaProperties[1].Name -eq 'value') {
                # Map to Array Pattern
                foreach ($element in $outputObject) {
                    if ($element -is [PSCustomObject] -and ($element | Get-Member -MemberType NoteProperty).Count -eq 0) {
                        # empty PSCustom Object is converted to empty array
                        # return
                        $singleObjectResult = @()
                    }
                    else {
                        $resultObject = New-Object PSCustomObject
                        $resultObject | Add-Member -MemberType NoteProperty -Name 'key' -Value $element.key
                        $resultObject | Add-Member -MemberType NoteProperty -Name 'value' -Value $element.Value
                        # return
                        $singleObjectResult = $resultObject
                    }
                }
            }
        }

        if ($OperationTranslateSchema.OldInBodyStruct -and $OperationTranslateSchema.NewInBodyStruct) {
            # Structure to Structure Translation
            $oldStructProps = $OperationTranslateSchema.OldInBodyStruct | Get-Member -MemberType NoteProperty
            $newStructProps = $OperationTranslateSchema.NewInBodyStruct | Get-Member -MemberType NoteProperty
            if ($null -ne $newStructProps -and $null -ne $oldStructProps) {
                <#
                    In the deprecated vSphere APIs, the 'client_token' is in the body
                    and in the new vSphere APIs, the 'client_token' is moved to the header parameters.
                    There're 10 vSphere APIs using the 'client_token' and in each the 'client_token' is the
                    first element. So we need to remove it from the body so that the translation algorithm can
                    work as expected - either we're left with matching Structures or the Wrapper Pattern occurs.
                #>
                if ($oldStructProps[0].Name -eq 'client_token') {
                    $oldStructProps = $oldStructProps[1..($oldStructProps.Length - 1)]
                }

                if ($newStructProps[0].Name -eq $oldStructProps[0].Name) {
                    # Structures match no translation needed
                    # Traverse and Translate each property

                    $resultObject = New-Object PSCustomObject

                    foreach ($prop in $oldStructProps) {
                        # Assuming the New Structure has all the properties the old one has
                        # In case the new one has more they won't be translated
                        $translationSchema = [PSCustomObject]@{
                            'OldInBodyStruct' = $($OperationTranslateSchema.OldInBodyStruct.$($prop.Name))
                            'NewInBodyStruct' = $($OperationTranslateSchema.NewInBodyStruct.$($prop.Name))
                        }

                        $translatedValue = (ConvertTo-DeprecatedBodyCommon $translationSchema $inputObject.($prop.Name))

                        if ($null -ne $translatedValue) {
                            $resultObject | Add-Member `
                                -MemberType NoteProperty `
                                -Name $prop.Name `
                                -Value $translatedValue
                        }
                    }

                    # return
                    $singleObjectResult = $resultObject
                }
                else {
                    if ($oldStructProps.Count -eq 1) {
                        # Spec Wrapper Pattern
                        $translationSchema = [PSCustomObject]@{
                            'OldInBodyStruct' = $($OperationTranslateSchema.OldInBodyStruct.$($oldStructProps[0].Name))
                            'NewInBodyStruct' = $($OperationTranslateSchema.NewInBodyStruct)
                        }


                        $translatedValue = (ConvertTo-DeprecatedBodyCommon $translationSchema $inputObject)
                        $resultObject = New-Object PSCustomObject
                        $resultObject | Add-Member `
                            -MemberType NoteProperty `
                            -Name $oldStructProps[0].Name `
                            -Value $translatedValue

                        # return
                        $singleObjectResult = $resultObject
                    }

                    if ($oldStructProps.Count -eq 2 -and `
                            $oldStructProps[0].Name -eq 'key' -and `
                            $oldStructProps[1].Name -eq 'value') {
                        # Array to Map pattern

                        # Handle Empty array
                        if ($inputObject -is [PSCustomObject] -and ($inputObject | Get-Member -MemberType NoteProperty).Count -eq 0) {
                            # empty PSObject is converted to empty array
                            # return
                            $singleObjectResult = @()
                        }
                        else {
                            $singleObjectResult = @()
                            foreach ($element in $inputObject) {
                                $notePropertyMemebers = $element | Get-Member -MemberType NoteProperty
                                if ($notePropertyMemebers.Count -ne 1) {
                                    throw "Input object array to map cannot be translated because element has more than one key note property"
                                }

                                # Note property name is mapped to the 'key' property of the old structure
                                # Note property value is mapped to the 'value' property of the old structure
                                $translationSchema = [PSCustomObject]@{
                                    'OldInBodyStruct' = $($OperationTranslateSchema.OldInBodyStruct.value)
                                    'NewInBodyStruct' = $($OperationTranslateSchema.NewInBodyStruct)
                                }
                                $resultObject = New-Object PSCustomObject
                                $resultObject | Add-Member -MemberType NoteProperty -Name 'key' -Value $notePropertyMemebers[0].Name
                                $resultObject | Add-Member -MemberType NoteProperty -Name 'value' -Value (ConvertTo-DeprecatedBodyCommon $translationSchema ($element.$($notePropertyMemebers[0].Name)))
                                # return
                                $singleObjectResult += $resultObject
                            }
                        }
                    }
                }
            }

            if ($null -eq $newStructProps -and $null -ne $oldStructProps) {
                # Old Operation Presents Simple Type as a Structure
                foreach ($element in $inputObject) {
                    $noteProperties = $element | Get-Member -MemberType NoteProperty
                    if ($noteProperties.Count -eq 1) {
                        # Query Input Array Parameter Pattern
                        $resultObject = [PSCustomObject] @{
                            $noteProperties[0].Name = $element.($noteProperties[0].Name)
                        }

                        $resultObject
                    } elseif ($oldStructProps.Count -eq 1) {
                        # Spec Wrapper Pattern
                        $resultObject = New-Object PSCustomObject
                        $resultObject | Add-Member `
                            -MemberType NoteProperty `
                            -Name $oldStructProps[0].Name `
                            -Value $element

                        # return
                        $singleObjectResult = $resultObject
                    }

                }
            }

            if ($null -eq $newStructProps -and $null -eq $oldStructProps) {
                # return
                $singleObjectResult = $inputObject
            }
        }

        if ($result -is [array]) {
            $result += $singleObjectResult
        } else {
            $result = $singleObjectResult
        }
    }

    # return converted result
    if ($result -is [array] -and $result.Count -eq 1) {
        return , $result
    } else {
        return $result
    }
}

function Convert-StructureDefitionToArrayDefinition {
    <#
    .SYNOPSIS
    Converts structure definition from translation scheme to array definition

    .DESCRIPTION
    The convertor is for the purpose of translating body structure defined in the translation schema to query parameters definition,

    .PARAMETER DataStructureDefinition
    PSCustomObject that represents the InBody definition of a translation schema for an API operation
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [PSCustomObject]
        $DataStructureDefinition,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [ref]$StructureObject
    )

    $newStructureObject =New-Object PSCustomObject

    foreach ($dsDef in $DataStructureDefinition) {
        $dsDef | Get-Member -MemberType NoteProperty | Foreach-Object {
            if ($dsDef.$($_.Name) -is [PSCustomObject]) {
                # For some APIs multiple structures are converted list of query params
                # We assume there are no nested structures in the query params
                # The modst complext case is assumed to be
                #  {
                #      'loc_spec': {
                #            'locaiton': 'string'
                #      }
                #      'filter_spec': {
                #        'max_result': 'integer'
                #      }
                #   }
                #
                # which is converted to @(locaiton, max_result) query parameters
                #
                $parentPropertyName = $_.Name
                $dsDef.$($_.Name) | Get-Member -MemberType NoteProperty | Foreach-Object {
                    $newStructureObject | Add-Member -MemberType NoteProperty -Name "$($parentPropertyName).$($_.Name)" -Value $($StructureObject.Value.$parentPropertyName.$($_.Name))
                    # result
                    "$($parentPropertyName).$($_.Name)"
                }
            } else {
                $newStructureObject | Add-Member -MemberType NoteProperty -Name $($_.Name) -Value $($StructureObject.Value.$($_.Name))
                # result
                $_.Name
            }
        }
    }

    $StructureObject.Value = $newStructureObject
}

function ConvertTo-DeprecatedQueryParamCommon {
    # Converts Query Param object from new -> old direction
    param(
        [Parameter()]
        [PSCustomObject]
        $OperationTranslateSchema,

        [Parameter()]
        [PSCustomObject]
        $OperationQueryInputObject
    )


    if ($null -ne $OperationTranslateSchema.OldInQueryParams -and `
            $null -ne $OperationTranslateSchema.NewInQueryParams -and `
            $OperationQueryInputObject -is [PSCustomObject]) {

        $resultObject = New-Object PSCustomObject

        $newQueryParamDefinition = $null

        if ($OperationTranslateSchema.NewInQueryParams -isnot [array] -and `
            $OperationTranslateSchema.NewInQueryParams -is [PSCustomObject]) {

            $newQueryParamDefinition = (Convert-StructureDefitionToArrayDefinition -DataStructureDefinition $OperationTranslateSchema.NewInQueryParams -StructureObject ([ref]$OperationQueryInputObject))
        } else {
            $newQueryParamDefinition = $OperationTranslateSchema.NewInQueryParams
        }

        foreach ($newQueryParam in $newQueryParamDefinition) {
            foreach ($oldQueryParam in $OperationTranslateSchema.OldInQueryParams) {
                $value = $($OperationQueryInputObject."$newQueryParam")
                if ($null -ne $value) {
                    $propName = $newQueryParam
                    if ($oldQueryParam -eq $newQueryParam) {
                        # leave it as-is
                        $resultObject | Add-Member -MemberType NoteProperty -Name $propName -Value $value
                    }
                    elseif ($oldQueryParam.EndsWith(".$newQueryParam")) {
                        # Use the old property name
                        $propName = $oldQueryParam
                        $resultObject | Add-Member -MemberType NoteProperty -Name $propName -Value $value
                    }
                }
            }
        }

        # return
        $resultObject
    }
    else {
        # The conversion is not possible
        $OperationQueryInputObject
    }
}
# SIG # Begin signature block
# MIIrIAYJKoZIhvcNAQcCoIIrETCCKw0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD0Tpo0XunmJgOu
# mDH1INfpGRqAXwvlDMEjyO1Q3s6bAaCCDdowggawMIIEmKADAgECAhAIrUCyYNKc
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
# tKncUjJ1xAAtAExGdCh6VD2U5iYxghycMIIcmAIBATB9MGkxCzAJBgNVBAYTAlVT
# MRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1
# c3RlZCBHNCBDb2RlIFNpZ25pbmcgUlNBNDA5NiBTSEEzODQgMjAyMSBDQTECEA7G
# 8rJ2oUagfQ5tk1e14QgwDQYJYIZIAWUDBAIBBQCggZYwGQYJKoZIhvcNAQkDMQwG
# CisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwKgYKKwYB
# BAGCNwIBDDEcMBqhGIAWaHR0cDovL3d3dy52bXdhcmUuY29tLzAvBgkqhkiG9w0B
# CQQxIgQgPuMrXr2cbM+K38HUa/TQaqCVh+Td8cvz28+/CTF09DswDQYJKoZIhvcN
# AQEBBQAEggGAZ0rNxAJAxBDNjDolsfP06Fn59mbv5Q86LRogLiC+NjXAffle9tQQ
# Q1VCphfUmLCh9gp3xHjEAwense8j383MDc1IbGOXTnwuBjDIhVjsJTFMGL60qdMh
# ssoWOkqdCYdwRH/yPgiasmazSjzU8YgR0Y0faGjxhqPRR+KqKvcxyzx391ddnoc0
# fRw5gY+qcou54IbgUnZaAheWm0euP1GjedTPcFQZLZH3ksik765V7R3+Q4OpBxkB
# ff5r7BrdSXgCc0kjCb0/1JbDUObiTivZ1aPytk1nkgpuVML+r3x3ogNJqlsDZKcJ
# XhGaF4hh3J9p3xElZscH3rXFM+ewVSHnR+D7XQ8TrvUR+9i7Bn/UyIwD1KWljFSH
# Am4RnmGc4ajosqccWjz0DseJOrvq2haw4dvOUIX+juIePrMs+/1VozJpvnCnbeVw
# iohu1LAg4Ubg+DyRMoM+WKCiMqk0v1Ea1VmDOHU3A+TseEEB0x6lWANIJ5K6c5He
# VLTsyjTn3tiloYIZ1zCCGdMGCisGAQQBgjcDAwExghnDMIIZvwYJKoZIhvcNAQcC
# oIIZsDCCGawCAQMxDzANBglghkgBZQMEAgEFADCB3AYLKoZIhvcNAQkQAQSggcwE
# gckwgcYCAQEGCSsGAQQBoDICAzAxMA0GCWCGSAFlAwQCAQUABCAcJOqPuFjie2Jl
# SEBhoSs4eWzSwyLu/1aQ6J6LV5Rk4gIUSeJfmBtpLm9e51XgqU+yNIiqK9wYDzIw
# MjEwOTI0MTYxMTE0WjADAgEBoFekVTBTMQswCQYDVQQGEwJCRTEZMBcGA1UECgwQ
# R2xvYmFsU2lnbiBudi1zYTEpMCcGA1UEAwwgR2xvYmFsc2lnbiBUU0EgZm9yIEFk
# dmFuY2VkIC0gRzSgghVkMIIGVTCCBD2gAwIBAgIQAQBGaVCmBKnZcOgd0k1BnzAN
# BgkqhkiG9w0BAQsFADBbMQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xvYmFsU2ln
# biBudi1zYTExMC8GA1UEAxMoR2xvYmFsU2lnbiBUaW1lc3RhbXBpbmcgQ0EgLSBT
# SEEzODQgLSBHNDAeFw0yMTA1MjcwOTU1MjNaFw0zMjA2MjgwOTU1MjJaMFMxCzAJ
# BgNVBAYTAkJFMRkwFwYDVQQKDBBHbG9iYWxTaWduIG52LXNhMSkwJwYDVQQDDCBH
# bG9iYWxzaWduIFRTQSBmb3IgQWR2YW5jZWQgLSBHNDCCAaIwDQYJKoZIhvcNAQEB
# BQADggGPADCCAYoCggGBAN8waZh7lw1uo1S0OV9kWXUEIv5OaW/oF3R0pX1RGA5G
# IB9oLrrlZdbJ0pGh7KT3Veqq7TvM+2KbhEKSejJM+fTyHPiY0bkxgSWtrVZnMqb+
# hzLzXMMtYvFNiQw3tH/rKuNgi29sPTHy7cldgJspnVXg4sT/6naTGB5sqat7yR4S
# YdXA56Dm+JApMyy4v25ast3HB0PRO9swC7R4w+zq8aJUz2CTOMz3ZEP1zwgEFnDI
# tNsO1AqKCNy7k8EdbvKMnOshNZ7/j7ywfsKEOH7mnWR6JqDxILG84dgqJZ0YUuRt
# 1EwwCnjMLUaO7VcLP3mVUKcDsDODMrdAnvS0kpcTDFC3nqq0QU4LmInM+8QhRJAy
# jkjyLEsMF+SEV1umrPuXg/mNZFTC7GpDHs8KdpKyEL/t1qMgD7XRMI4aQLE259CO
# ePMTwC8LiJA7CGHjD61Hsw5UcJV/oEPUWsbdF5+UywCHaA7hrpPuLHIEGzIXkEvX
# K4AlBR/lM/TowGgqeReg7wIDAQABo4IBmzCCAZcwDgYDVR0PAQH/BAQDAgeAMBYG
# A1UdJQEB/wQMMAoGCCsGAQUFBwMIMB0GA1UdDgQWBBSufnCBeCAUKa3yePhZANnM
# piQCjjBMBgNVHSAERTBDMEEGCSsGAQQBoDIBHjA0MDIGCCsGAQUFBwIBFiZodHRw
# czovL3d3dy5nbG9iYWxzaWduLmNvbS9yZXBvc2l0b3J5LzAJBgNVHRMEAjAAMIGQ
# BggrBgEFBQcBAQSBgzCBgDA5BggrBgEFBQcwAYYtaHR0cDovL29jc3AuZ2xvYmFs
# c2lnbi5jb20vY2EvZ3N0c2FjYXNoYTM4NGc0MEMGCCsGAQUFBzAChjdodHRwOi8v
# c2VjdXJlLmdsb2JhbHNpZ24uY29tL2NhY2VydC9nc3RzYWNhc2hhMzg0ZzQuY3J0
# MB8GA1UdIwQYMBaAFOoWxmnn48tXRTkzpPBAvtDDvWWWMEEGA1UdHwQ6MDgwNqA0
# oDKGMGh0dHA6Ly9jcmwuZ2xvYmFsc2lnbi5jb20vY2EvZ3N0c2FjYXNoYTM4NGc0
# LmNybDANBgkqhkiG9w0BAQsFAAOCAgEAf2Lo+tl3L0Jvaw/X3UVZPPR1egDsvfZv
# DiNtLTNCchRPRJSBveuMAohMrH/HXc23xCSau5kBaApa6kVh07As132gF+5dgPEa
# 4uf8sd8dMgQoDzaE1wlGLbZ+wEAVIhp5YWeXthKP0E9mLC5UKlgGrJlO/XWtVCYK
# aP+SJ/g8uRltMIEmTIUs83Pcj+DlymRKe0cRTNqi1Lfx5FF65jmwIQcZ4PCMuXFw
# fZHtNJ+LMZ4NxMY+Nitm1sBB1bIjSSLTvl+JNoxa1sVQqj8OTlQJtv4Nkdlx2J82
# PDSOiYO35PNmSs43kItdeuo+o+MHBz2UGRSe+rFnS+u2srcIb5KWRV1M7g5ZWotm
# c2FFNkqGzmNDGW4GOglGOZB0xnMLXkLRzS8ibCQnpwICUZKNAbRdhcf4w0F13WSM
# 8vOY7um3hwmnvQoTMDdiH1nnKXJ3aXV4kLDNHDpcahCGcvcAsjKXWXieTvizZv2v
# K/yJtnWilAo3khNBdd31Pzqup6i0QtPZnFES8vJ61ivsnkwl2W2ckfQfAU9Ix+yP
# +Vuq7PpcEXJgruw3cZS+XEmJTClt81c7GgBXvL6QLkJhgtXf/wCBlnwBVZO4YmTo
# BoarVUpvM8Xz2lgFjd0B9TxVIYX+ezV5xX+y+9itvZ35VQokZHRhiiuXNl9WvfLX
# 4Ox8/fnrktQwggZZMIIEQaADAgECAg0B7BySQN79LkBdfEd0MA0GCSqGSIb3DQEB
# DAUAMEwxIDAeBgNVBAsTF0dsb2JhbFNpZ24gUm9vdCBDQSAtIFI2MRMwEQYDVQQK
# EwpHbG9iYWxTaWduMRMwEQYDVQQDEwpHbG9iYWxTaWduMB4XDTE4MDYyMDAwMDAw
# MFoXDTM0MTIxMDAwMDAwMFowWzELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2Jh
# bFNpZ24gbnYtc2ExMTAvBgNVBAMTKEdsb2JhbFNpZ24gVGltZXN0YW1waW5nIENB
# IC0gU0hBMzg0IC0gRzQwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDw
# AuIwI/rgG+GadLOvdYNfqUdSx2E6Y3w5I3ltdPwx5HQSGZb6zidiW64HiifuV6PE
# Ne2zNMeswwzrgGZt0ShKwSy7uXDycq6M95laXXauv0SofEEkjo+6xU//NkGrpy39
# eE5DiP6TGRfZ7jHPvIo7bmrEiPDul/bc8xigS5kcDoenJuGIyaDlmeKe9JxMP11b
# 7Lbv0mXPRQtUPbFUUweLmW64VJmKqDGSO/J6ffwOWN+BauGwbB5lgirUIceU/kKW
# O/ELsX9/RpgOhz16ZevRVqkuvftYPbWF+lOZTVt07XJLog2CNxkM0KvqWsHvD9WZ
# uT/0TzXxnA/TNxNS2SU07Zbv+GfqCL6PSXr/kLHU9ykV1/kNXdaHQx50xHAotIB7
# vSqbu4ThDqxvDbm19m1W/oodCT4kDmcmx/yyDaCUsLKUzHvmZ/6mWLLU2EESwVX9
# bpHFu7FMCEue1EIGbxsY1TbqZK7O/fUF5uJm0A4FIayxEQYjGeT7BTRE6giunUln
# EYuC5a1ahqdm/TMDAd6ZJflxbumcXQJMYDzPAo8B/XLukvGnEt5CEk3sqSbldwKs
# DlcMCdFhniaI/MiyTdtk8EWfusE/VKPYdgKVbGqNyiJc9gwE4yn6S7Ac0zd0hNkd
# Zqs0c48efXxeltY9GbCX6oxQkW2vV4Z+EDcdaxoU3wIDAQABo4IBKTCCASUwDgYD
# VR0PAQH/BAQDAgGGMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYEFOoWxmnn
# 48tXRTkzpPBAvtDDvWWWMB8GA1UdIwQYMBaAFK5sBaOTE+Ki5+LXHNbH8H/IZ1Og
# MD4GCCsGAQUFBwEBBDIwMDAuBggrBgEFBQcwAYYiaHR0cDovL29jc3AyLmdsb2Jh
# bHNpZ24uY29tL3Jvb3RyNjA2BgNVHR8ELzAtMCugKaAnhiVodHRwOi8vY3JsLmds
# b2JhbHNpZ24uY29tL3Jvb3QtcjYuY3JsMEcGA1UdIARAMD4wPAYEVR0gADA0MDIG
# CCsGAQUFBwIBFiZodHRwczovL3d3dy5nbG9iYWxzaWduLmNvbS9yZXBvc2l0b3J5
# LzANBgkqhkiG9w0BAQwFAAOCAgEAf+KI2VdnK0JfgacJC7rEuygYVtZMv9sbB3DG
# +wsJrQA6YDMfOcYWaxlASSUIHuSb99akDY8elvKGohfeQb9P4byrze7AI4zGhf5L
# FST5GETsH8KkrNCyz+zCVmUdvX/23oLIt59h07VGSJiXAmd6FpVK22LG0LMCzDRI
# RVXd7OlKn14U7XIQcXZw0g+W8+o3V5SRGK/cjZk4GVjCqaF+om4VJuq0+X8q5+dI
# ZGkv0pqhcvb3JEt0Wn1yhjWzAlcfi5z8u6xM3vreU0yD/RKxtklVT3WdrG9KyC5q
# ucqIwxIwTrIIc59eodaZzul9S5YszBZrGM3kWTeGCSziRdayzW6CdaXajR63Wy+I
# Lj198fKRMAWcznt8oMWsr1EG8BHHHTDFUVZg6HyVPSLj1QokUyeXgPpIiScseeI8
# 5Zse46qEgok+wEr1If5iEO0dMPz2zOpIJ3yLdUJ/a8vzpWuVHwRYNAqJ7YJQ5NF7
# qMnmvkiqK1XZjbclIA4bUaDUY6qD6mxyYUrJ+kPExlfFnbY8sIuwuRwx773vFNgU
# QGwgHcIt6AvGjW2MtnHtUiH+PvafnzkarqzSL3ogsfSsqh3iLRSd+pZqHcY8yvPZ
# HL9TTaRHWXyVxENB+SXiLBB+gfkNlKd98rUJ9dhgckBQlSDUQ0S++qCV5yBZtnjG
# pGqqIpswggVHMIIEL6ADAgECAg0B8kBCQM79ItvpbHH8MA0GCSqGSIb3DQEBDAUA
# MEwxIDAeBgNVBAsTF0dsb2JhbFNpZ24gUm9vdCBDQSAtIFIzMRMwEQYDVQQKEwpH
# bG9iYWxTaWduMRMwEQYDVQQDEwpHbG9iYWxTaWduMB4XDTE5MDIyMDAwMDAwMFoX
# DTI5MDMxODEwMDAwMFowTDEgMB4GA1UECxMXR2xvYmFsU2lnbiBSb290IENBIC0g
# UjYxEzARBgNVBAoTCkdsb2JhbFNpZ24xEzARBgNVBAMTCkdsb2JhbFNpZ24wggIi
# MA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCVB+hzymb57BTKezz3DQjxtEUL
# LIK0SMbrWzyug7hBkjMUpG9/6SrMxrCIa8W2idHGsv8UzlEUIexK3RtaxtaH7k06
# FQbtZGYLkoDKRN5zlE7zp4l/T3hjCMgSUG1CZi9NuXkoTVIaihqAtxmBDn7Eirxk
# TCEcQ2jXPTyKxbJm1ZCatzEGxb7ibTIGph75ueuqo7i/voJjUNDwGInf5A959eqi
# HyrScC5757yTu21T4kh8jBAHOP9msndhfuDqjDyqtKT285VKEgdt/Yyyic/QoGF3
# yFh0sNQjOvddOsqi250J3l1ELZDxgc1Xkvp+vFAEYzTfa5MYvms2sjnkrCQ2t/Dv
# thwTV5O23rL44oW3c6K4NapF8uCdNqFvVIrxclZuLojFUUJEFZTuo8U4lptOTloL
# R/MGNkl3MLxxN+Wm7CEIdfzmYRY/d9XZkZeECmzUAk10wBTt/Tn7g/JeFKEEsAvp
# /u6P4W4LsgizYWYJarEGOmWWWcDwNf3J2iiNGhGHcIEKqJp1HZ46hgUAntuA1iX5
# 3AWeJ1lMdjlb6vmlodiDD9H/3zAR+YXPM0j1ym1kFCx6WE/TSwhJxZVkGmMOeT31
# s4zKWK2cQkV5bg6HGVxUsWW2v4yb3BPpDW+4LtxnbsmLEbWEFIoAGXCDeZGXkdQa
# J783HjIH2BRjPChMrwIDAQABo4IBJjCCASIwDgYDVR0PAQH/BAQDAgEGMA8GA1Ud
# EwEB/wQFMAMBAf8wHQYDVR0OBBYEFK5sBaOTE+Ki5+LXHNbH8H/IZ1OgMB8GA1Ud
# IwQYMBaAFI/wS3+oLkUkrk1Q+mOai97i3Ru8MD4GCCsGAQUFBwEBBDIwMDAuBggr
# BgEFBQcwAYYiaHR0cDovL29jc3AyLmdsb2JhbHNpZ24uY29tL3Jvb3RyMzA2BgNV
# HR8ELzAtMCugKaAnhiVodHRwOi8vY3JsLmdsb2JhbHNpZ24uY29tL3Jvb3QtcjMu
# Y3JsMEcGA1UdIARAMD4wPAYEVR0gADA0MDIGCCsGAQUFBwIBFiZodHRwczovL3d3
# dy5nbG9iYWxzaWduLmNvbS9yZXBvc2l0b3J5LzANBgkqhkiG9w0BAQwFAAOCAQEA
# SaxexYPzWsthKk2XShUpn+QUkKoJ+cR6nzUYigozFW1yhyJOQT9tCp4YrtviX/yV
# 0SyYFDuOwfA2WXnzjYHPdPYYpOThaM/vf2VZQunKVTm808Um7nE4+tchAw+3Ttlb
# YGpDtH0J0GBh3artAF5OMh7gsmyePLLCu5jTkHZqaa0a3KiJ2lhP0sKLMkrOVPs4
# 6TsHC3UKEdsLfCUn8awmzxFT5tzG4mE1MvTO3YPjGTrrwmijcgDIJDxOuFM8sRer
# 5jUs+dNCKeZfYAOsQmGmsVdqM0LfNTGGyj43K9rE2iT1ThLytrm3R+q7IK1hFreg
# M+Mtiae8szwBfyMagAk06TCCA18wggJHoAMCAQICCwQAAAAAASFYUwiiMA0GCSqG
# SIb3DQEBCwUAMEwxIDAeBgNVBAsTF0dsb2JhbFNpZ24gUm9vdCBDQSAtIFIzMRMw
# EQYDVQQKEwpHbG9iYWxTaWduMRMwEQYDVQQDEwpHbG9iYWxTaWduMB4XDTA5MDMx
# ODEwMDAwMFoXDTI5MDMxODEwMDAwMFowTDEgMB4GA1UECxMXR2xvYmFsU2lnbiBS
# b290IENBIC0gUjMxEzARBgNVBAoTCkdsb2JhbFNpZ24xEzARBgNVBAMTCkdsb2Jh
# bFNpZ24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDMJXaQeQZ4Ihb1
# wIO2hMoonv0FdhHFrYhy/EYCQ8eyip0EXyTLLkvhYIJG4VKrDIFHcGzdZNHr9Syj
# D4I9DCuul9e2FIYQebs7E4B3jAjhSdJqYi8fXvqWaN+JJ5U4nwbXPsnLJlkNc96w
# yOkmDoMVxu9bi9IEYMpJpij2aTv2y8gokeWdimFXN6x0FNx04Druci8unPvQu7/1
# PQDhBjPogiuuU6Y6FnOM3UEOIDrAtKeh6bJPkC4yYOlXy7kEkmho5TgmYHWyn3f/
# kRTvriBJ/K1AFUjRAjFhGV64l++td7dkmnq/X8ET75ti+w1s4FRpFqkD2m7pg5Nx
# dsZphYIXAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMBAf8EBTADAQH/
# MB0GA1UdDgQWBBSP8Et/qC5FJK5NUPpjmove4t0bvDANBgkqhkiG9w0BAQsFAAOC
# AQEAS0DbwFCq/sgM7/eWVEVJu5YACUGssxOGhigHM8pr5nS5ugAtrqQK0/Xx8Q+K
# v3NnSoPHRHt44K9ubG8DKY4zOUXDjuS5V2yq/BKW7FPGLeQkbLmUY/vcU2hnVj6D
# uM81IcPJaP7O2sJTqsyQiunwXUaMld16WCgaLx3ezQA3QY/tRG3XUyiXfvNnBB4V
# 14qWtNPeTCekTBtzc3b0F5nCH3oO4y0IrQocLP88q1UOD5F+NuvDV0m+4S4tfGCL
# w0FREyOdzvcya5QBqJnnLDMfOjsl0oZAzjsshnjJYS8Uuu7bVW/fhO4FCU29KNhy
# ztNiUGUe65KXgzHZs7XKR1g/XzGCA00wggNJAgEBMG8wWzELMAkGA1UEBhMCQkUx
# GTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExMTAvBgNVBAMTKEdsb2JhbFNpZ24g
# VGltZXN0YW1waW5nIENBIC0gU0hBMzg0IC0gRzQCEAEARmlQpgSp2XDoHdJNQZ8w
# DQYJYIZIAWUDBAIBBQCgggEvMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAt
# BgkqhkiG9w0BCTQxIDAeMA0GCWCGSAFlAwQCAQUAoQ0GCSqGSIb3DQEBCwUAMC8G
# CSqGSIb3DQEJBDEiBCCKwkN1sOPmz24zv2m1dpb30Xirm9Bz9vkV/fL4rFAueDCB
# sAYLKoZIhvcNAQkQAi8xgaAwgZ0wgZowgZcEIBPW6cQg/21OJ1RyjGjneIJlZGfb
# mhkPgWWX9n+2zMb5MHMwX6RdMFsxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9i
# YWxTaWduIG52LXNhMTEwLwYDVQQDEyhHbG9iYWxTaWduIFRpbWVzdGFtcGluZyBD
# QSAtIFNIQTM4NCAtIEc0AhABAEZpUKYEqdlw6B3STUGfMA0GCSqGSIb3DQEBCwUA
# BIIBgIv343712WmuRfrN9uhezwgczcyKIlUqxStC2FuAtqy4aKehpa82y6gL/0tP
# lbtdy97ZaLk13M9xaD2xthAR6/B4fvscF6XSb11qAYL7JW2w2hT+zWyUrWUHF9yY
# Iyt6Qto4ZTXI5+Qr8ldNEQ7Oiv/sPBSVkcUrJ1WFOAotmO5TC1xqpkmkI9YPDKEO
# DYF3HTtOEtze9YofFT+Wf3pcn61Xu+loolsL8rgFfcCsfTXPJkJ54Bb3vrVLa9Z1
# 5SkVD611Rh0u4WUmuOuACvEvRQqvBlrPVX4nvOzMYf5hwBB5jnQh8ANk8s+Tz3+9
# yqUicKRqKMoFRI7mau7/FWxqGa1lhihsr2dgvQbDfzXQs2nZlAFbH8WsJ1El5viH
# DBkEqNsk7I3TLR2h4lzg2wKAaxgAyv2RcpQs3USRtEv0oqQmXNjE9Vx0D7ol4xJU
# i3nzO5v1rwVHe/+tyc/2j5l+wpvP/Uo9npbTvV29UN8pO10t+Tq+cw6yg8kfhlkR
# CgEg1A==
# SIG # End signature block
