using module VMware.PowerCLI.Sdk.Types
using module VMware.PowerCLI.VCenter.Types.CertificateManagement
using namespace VMware.VimAutomation.ViCore.Types.V1
using namespace VMware.VimAutomation.ViCore.Types.V1.Inventory
using namespace System.Security.Cryptography
using namespace System.Security.Cryptography.X509Certificates
using namespace VMware.VimAutomation.Sdk.Util10Ps.BaseCmdlet

. (Join-Path $PSScriptRoot "../utils/ConvertTo-Pem.ps1")
. (Join-Path $PSScriptRoot "../utils/Report-CommandUsage.ps1")
. (Join-Path $PSScriptRoot "../utils/ConvertTo-PemCertificate.ps1")
. (Join-Path $PSScriptRoot "../utils/Connection.ps1")

<#
.SYNOPSIS

This cmdlet sets a machine SSL certificate to a vCenter Server instance or a connected ESXi host.

.DESCRIPTION

This cmdlet sets a machine SSL certificate to a vCenter Server instance or a connected ESXi host.

By default, the certificate is set to the vCenter Server instance. If you want to set the certificate to a specific ESXi host, you must use the VMHost parameter.

The result from the command is the updated vCenter Server or ESXi entity with the certificate that was set.

To use this cmdlet, you must connect to vCenter Server through the Connect-VIServer cmdlet.

IMPORTANT: When you change the machine SSL certificate of a vCenter Server system, a restart is triggered.

.PARAMETER VMHost

Specifies the ESXi host to which you want to set a machine SSL certificate.

.PARAMETER PemCertificate

Specifies a certificate in PEM format to be set as the machine SSL certificate to a vCenter Server instance or an ESXi host.

.PARAMETER X509Certificate

Specifies a certificate as an X509Certificate object to be set as the machine SSL certificate to a vCenter Server instance or an ESXi host.


.PARAMETER PemKey

Specifies the private key in PEM format of the certificate that you want to set to a vCenter Server system.

.PARAMETER Key

Specifies the private key as AsymmetricAlgorithm type of the certificate that you want to set.

Note: To use this parameter, you must have PowerShell version 7.1 or later.


.EXAMPLE
PS C:\> $certificatePem = Get-Content cert.pem -Raw
PS C:\> Set-VIMachineCertificate -PemCertificate $certificatePem

Sets the certificate from the cert.pem file to the vCenter Server system.


.EXAMPLE
PS C:\> $certificatePem = Get-Content cert.pem -Raw
PS C:\> Set-VIMachineCertificate -PemCertificate $certificatePem -VMHost 'MyHost'

Sets the certificate from the cert.pem file to the 'MyHost' ESXi host.


.OUTPUTS

The updated ViMachineCertificateInfo object

.LINK

https://developer.vmware.com/docs/powercli/latest/vmware.powercli.vcenter/commands/set-vimachinecertificate


#>
function Set-VIMachineCertificate {
   [CmdletBinding(
      ConfirmImpact = "High",
      DefaultParameterSetName = "VCenter",
      SupportsShouldProcess = $true)]
   [OutputType([ViMachineCertificateInfo])]
   Param (
      [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0, ParameterSetName = 'VmHost')]
      [ObnArgumentTransformation([VMHost])]
      [VMHost]
      $VMHost,

      [Parameter()]
      [String]
      $PemCertificate,

      [Parameter(ParameterSetName = "VCenter")]
      [String]
      $PemKey,

      [Parameter()]
      [X509Certificate]
      $X509Certificate,

      [Parameter(ParameterSetName = "VCenter")]
      [AsymmetricAlgorithm]
      $Key,

      [Parameter()]
      [ObnArgumentTransformation([VIServer], Critical = $true)]
      [VIServer]
      $Server
   )

   Begin {
      Report-CommandUsage $MyInvocation
      
      # Handle Server obn first
      if($Server) {
         $resolvedServer = Resolve-ObjectByName -Object $Server `
             -Type ([VIServer]) `
             -OneObjectExpected

         $Server = [VIServer] $resolvedServer
      }

      $activeServer = GetActiveServer($Server)
      if (-not $VMHost) {
         ValidateApiVersionSupported -server $activeServer -major 7 -minor 0
         $apiServer = GetApiServer($activeServer)
      }

      # Collect OBN for parameter 'VMHost'
      if($VMHost) {
         $resolvedVMHost = Resolve-ObjectByName -Object $VMHost `
            -Type ([VMHost]) `
            -CollectorCmdlet 'Get-VMHost' `
            -OneObjectExpected `
            -Server $activeServer

         $VMHost = [VMHost] $resolvedVMHost
      }

      if (![string]::IsNullOrEmpty($PemCertificate) -and $X509Certificate) {
         Write-PowerCLIError `
            -ErrorObject 'Only one of the parameters PemCertificate and X509Certificate must be supplied.' `
            -Terminating
      } elseif ([string]::IsNullOrEmpty($PemCertificate) -and $X509Certificate -eq $null) {
         Write-PowerCLIError `
            -ErrorObject 'One of the parameters PemCertificate and X509Certificate must be supplied.' `
            -Terminating
      }

      if (![string]::IsNullOrEmpty($PemKey) -and $Key) {
         Write-PowerCLIError `
            -ErrorObject 'Only one of the parameters PemKey and Key must be supplied.' `
            -Terminating
      }

      if ($Key -and ($PSVersionTable.PSVersion -lt ([Version]'7.1'))) {
         Write-PowerCLIError `
            -ErrorObject 'The Key parameter is available on PowerShell 7.1 and above.' `
            -Terminating
      }

      if ($X509Certificate) {
         $PemCertificate = $X509Certificate | ConvertTo-PemCertificate
      }

      if ($Key) {
         $PemKey = ConvertTo-Pem `
            -Bytes $key.ExportPkcs8PrivateKey() `
            -Type "PRIVATE KEY"
      }
   }

   Process {
      # Validate all objects are from the same server
      if($VMHost) {
         $VMHost | ValidateSameServer -ExpectedServer $activeServer
      }

      $vcName = ''
      $vmHostName = ''
      if ($VMHost) {
         $vmHostName = $VMHost.Name
      } else {
         $vcName = $activeServer.Name
      }

      try {
         $shouldProcessDescription = Get-SetVIMachineCertificateShouldProcessMessage $PemCertificate $vcName $vmHostName
         $shouldProcessWarning = Get-SetVIMachineCertificateShouldProcessMessage $PemCertificate $vcName $vmHostName -warning
      } catch {
         Write-PowerCLIError `
            -ErrorObject $_ `
            -ErrorId "PowerCLI_SetVIMachineCertificate_UnableToGenerateConfirmMessages"
      }

      if($PSCmdlet.ShouldProcess(
         $shouldProcessDescription,
         $shouldProcessWarning,
         "Set certificate")) {

         if ($VMHost) {
            try {
               # hosts
               $certificateManager = Get-View $VMHost.ExtensionData.ConfigManager.CertificateManager -Server $activeServer

               $certificateManager.installServerCertificate($PemCertificate) | Out-Null

               $VMHost | Get-VIMachineCertificate -Server $activeServer | Write-Output
            } catch {
               Write-PowerCLIError `
                  -ErrorObject $_ `
                  -ErrorId "PowerCLI_SetVIMachineCertificate_UnableToSetESXiCertificate"
            }
         } else {
            try {
               # vc
               $initSplat = @{
                  Cert = $PemCertificate
               }

               if ($PemKey) {
                  $initSplat['Key'] = $PemKey
               }

               Initialize-CertificateManagementVcenterTlsSpec @initSplat | `
               Invoke-SetCertificateManagementTls -Server $apiServer -ErrorAction:Stop

               Get-VIMachineCertificate -VCenterOnly -Server $activeServer | Write-Output
            } catch {
               Write-PowerCLIError `
                  -ErrorObject $_ `
                  -ErrorId "PowerCLI_SetVIMachineCertificate_UnableToSetVcCertificate"
            }
         }
      }
   }
}

function Get-SetVIMachineCertificateShouldProcessMessage {
   param(
      [string]
      $pem,

      [string]
      $vcName,

      [string]
      $hostName,

      [switch]
      $warning
   )

   $sb = [System.Text.StringBuilder]::new()

   if ($warning.ToBool()) {
      $sb.Append("Are you sure you want to set ") | Out-Null
   } else {
      $sb.Append("Setting ") | Out-Null
   }

   $pem | ConvertTo-X509Certificate | % {
      $sb.Append("'") | Out-Null
      $sb.Append($_.GetNameInfo([X509NameType]::SimpleName, $false)) | Out-Null
      $sb.Append("'") | Out-Null
   }

   $sb.Append(" certificate") | Out-Null
   $sb.Append(" to") | Out-Null

   if(-not [string]::IsNullOrEmpty($vcName)) {
      $sb.Append(" vCenter Server '$vcName'") | Out-Null
   } elseif (-not [string]::IsNullOrEmpty($hostName)) {
      $sb.Append(" host '$hostName'") | Out-Null
   }

   if ($warning.ToBool()) {
      $sb.Append("?") | Out-Null
   } else {
      $sb.Append(".") | Out-Null
   }

   if (-not [string]::IsNullOrEmpty($vcName)) {
      $sb.Append(" THIS WILL RESTART THE VCENTER SERVER!") | Out-Null
   }
   
   $sb.ToString() | Write-Output
}

# SIG # Begin signature block
# MIIexwYJKoZIhvcNAQcCoIIeuDCCHrQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCuevkZwJ/WqteX
# /sbOLqwIDMO1MpjLJGM8Lh7BKpsEHaCCDdowggawMIIEmKADAgECAhAIrUCyYNKc
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
# CQQxIgQgZxQCEJb9t3KWdIsfDCEkgeWK1Tnvtpti5jnyB6O/bZQwDQYJKoZIhvcN
# AQEBBQAEggGAq1jBtkNOhGoobdKZb7C6RF65UeUkDud/Mft/TAXix1jWIlE9OOUt
# GXcxzkbVaFj/W7ndMa3J+xSTerSrIb2dkvwKyEp0ttSTg0B/F6SwSbm6o2u0W7x4
# sWrZZiQ7VIiHtASdqWX6zZT2REexeDepJxMfspBnVhhpcAEbaSmchOLux/f398wC
# BbccRj/KTiodgdhgIcqEzc8zUv56bEj54liQkpsrpwyHhNrnRrJfOoBXgvZvwiHS
# f0VC9UIsmmv3fSvfH9ou/fi9OSx9GAmA5yMXpMYIZcMxYXSpMwXocJ5iswDzyyiz
# OZex3CaVFcWuHvzBSqB4rzRog3YcDeEwU0dDspaVRuqImc9Sgw1YCDZvL9woh9e/
# cdL7xtSvumNIpBw5C4GHtyESh/2HrRK5Azm3FHBsyOEXxaU5FR4FZykeKl9gwDzN
# tJRjfrJXiUo2yYnLcD6LT/2ka2o1CGM+d8jcAXaBdkywI9M+ndJPxLjokLdQT9mj
# kWYt/Mm9iiEJoYINfjCCDXoGCisGAQQBgjcDAwExgg1qMIINZgYJKoZIhvcNAQcC
# oIINVzCCDVMCAQMxDzANBglghkgBZQMEAgEFADB4BgsqhkiG9w0BCRABBKBpBGcw
# ZQIBAQYJYIZIAYb9bAcBMDEwDQYJYIZIAWUDBAIBBQAEID/QyPxyRoPGeWyncVuw
# XKLtlZM2/37XroJ5DH0Iee0pAhEAqYY22hRPrFaf8F7lYpvHUxgPMjAyMTEyMjAx
# NjMzMDFaoIIKNzCCBP4wggPmoAMCAQICEA1CSuC+Ooj/YEAhzhQA8N0wDQYJKoZI
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
# MQ8XDTIxMTIyMDE2MzMwMVowKwYLKoZIhvcNAQkQAgwxHDAaMBgwFgQU4deCqOGR
# vu9ryhaRtaq0lKYkm/MwLwYJKoZIhvcNAQkEMSIEIBAv5+/DptIVARzXH0pUs1ev
# ElNIrQ13iMebd3woJ7TqMDcGCyqGSIb3DQEJEAIvMSgwJjAkMCIEILMQkAa8CtmD
# B5FXKeBEA0Fcg+MpK2FPJpZMjTVx7PWpMA0GCSqGSIb3DQEBAQUABIIBAK020W1/
# QwoxCRj2WpG4SKZTsGEiAT0EMOBESeM30ItrvzGoY4/JEdotfCaL8QAiIKn/JugW
# NBdel72u5pzBxsE7fB2WTKS9GEk3u01j8mJeZHlmyVOAw1xeyRxfTEvT+FwDhEQy
# TUFA29Rh5l4R5cWp1WZ4v0yDHphqB4HFMCvnpYWcMO+0CyMsWhOXyUNEj8wrB2r6
# BUrabtd/nmyXp1exqyFTRtIwsA9yz5s5X+CQt+4DTN6NOx8VVDIWc0yaMaA9nXOX
# W0CFa2ihaKt7ScF6fF04DEfinIIaAyeJa6kZtoUNczJ7yGd5qpeCxLj77aHBXZ2u
# V8r1BWxH/YPZK0I=
# SIG # End signature block
