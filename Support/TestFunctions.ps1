function TestXmlRule {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $BinDir,
        [Parameter(Mandatory = $true)] [string] $JsonConfigFile,
        [Parameter(Mandatory = $False)] $GpoToTest,
        [Parameter(Mandatory = $False)] $XmlToTest
    )
    # Test applocker Rules generated to ensure they are applied as intended by JsonConfigFile

    $ConfigData = ReadJson $JsonConfigFile
    
    foreach ($Gpo in $ConfigData.PSObject.Properties) {
        $GpoName = $Gpo.Name

        if ($GpoToTest) {
            TestRuleAgainstGpo -BinDir $BinDir -JsonConfigFile $JsonConfigFile -GpoToTest $GpoToTest
        } elseif ($XmlToTest) {
            TestRuleAgainstXml -BinDir $BinDir -JsonConfigFile $JsonConfigFile -Xml $XmlToTest
        } else {
            $XmlOutFile = Join-Path -Path $OutDir -ChildPath ((Get-Date -Format "yyyyMMdd")+"_$GpoName.xml") 
            TestRuleAgainstXml -BinDir $BinDir -JsonConfigFile $JsonConfigFile -Xml $XmlOutFile
        }
    }
}

function TestRuleAgainstXml {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $BinDir,
        [Parameter(Mandatory = $true)] [string] $JsonConfigFile,
        [Parameter(Mandatory = $true)] [string] $Xml
    )
    $PolicyDecision = @{"Allow" = "Allowed"; "Deny" = "Denied"}

    $CountRules = 0
    foreach ($Placeholder in $Placeholders.Keys) {
        $CountRules += ($Gpo.Value[0].$Placeholder|Measure-Object).Count
    }

    if ($CountRules -gt 0) {
        $Msg = "** TESTING RULES from '{0}' **" -f $Xml
        Write-Verbose $Msg

        foreach ($PlaceholderKey in $Placeholders.Keys) {
        # Iterate over every EXE, MSI and SCRIPT Rules
            foreach ($Rule in $Gpo.Value[0].$PlaceholderKey) {

                if ($PlaceholderKey -like "*PRODUCT*") {
                    # Does the file exist
                    if (Test-Path -PathType leaf -Path $(Join-Path -Path $BinDir -ChildPath $Rule.Filepath)) {
                        try {
                            $TestResult = Get-ChildItem -LiteralPath $BinDir $Rule.Filepath |Convert-Path | Test-AppLockerPolicy -XmlPolicy $Xml -User $Rule.UserOrGroupSid
                        } catch [Microsoft.Security.ApplicationId.PolicyManagement.TestFileAllowedException] {
                            $Msg = "Test failed for file {0} and group {1} with SID {2}" -f $Rule.FilePath, $Rule.UserOrGroup, $Rule.UserOrGroupSid
                            Write-Host $Msg -ForegroundColor Red
                            continue
                        }
                        # Checking Appocker result
                        if ($TestResult.PolicyDecision -ne $PolicyDecision.Item($Rule.Action)) {
                            if ($Rule.isException -and $TestResult.PolicyDecision -eq "DeniedByDefault") {
                                $Msg = "'{0}' is '{1}' for '{2}' due to an exception" -f $TestResult.FilePath, $TestResult.PolicyDecision, $Rule.UserOrGroup
                                if ($Verbose) {
                                     Write-Host $Msg -ForegroundColor Green
                                }
                            } else {
                                $Msg = "'{0}' is '{1}' for '{2}' and should be ''{3}''" -f $TestResult.FilePath, $TestResult.PolicyDecision, $Rule.UserOrGroup, $Rule.Action
                                Write-Host $Msg -ForegroundColor Red
                            }
                        } else {
                            $Msg = "'{0}' is '{1}' for '{2}' by ''{3}''" -f $TestResult.FilePath, $TestResult.PolicyDecision, $Rule.UserOrGroup, $TestResult.MatchingRule
                            if ($Verbose) {
                                Write-Host $Msg -ForegroundColor Green
                            }
                        }
                    } else {
                        $Msg = "file {0} could not be found in {1} directory, so it cannot be tested" -f $Rule.Filepath, $BinDir
                        Write-Warning $Msg
                    }
                } elseif ($PlaceholderKey -like "*PATH*") {
                    $Msg = "Not testing {0} Rules based on PATH : {1}" -f $PlaceholderKey, $Rule.Filepath
                    if ($Verbose) {
                        Write-Warning $Msg
                    }
                } else {
                    $Msg = "Invalid Rule name {0}" -f $PlaceholderKey
                    Write-Warning $Msg
                }
            }
        }
    }
}

function TestRuleAgainstGPO {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $BinDir,
        [Parameter(Mandatory = $true)] [string] $JsonConfigFile,
        [Parameter(Mandatory = $true)] $GpoToTest
    )

    $PolicyDecision = @{"Allow" = "Allowed"; "Deny" = "Denied"}

    if ($GpoToTest -eq "Effective") {
        $GPOPolicyObject = Get-AppLockerPolicy -Effective
    } else {
        $DomainName = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name
        $DomainDN = ([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().PdcRoleOwner.Partitions)[0]
        $GPOApplocker = "LDAP://{0}/CN={{{1}}},CN=Policies,CN=System,{2}" -f $DomainName, $(Get-GPO $GpoToTest).Id, $DomainDN
        $GPOPolicyObject = Get-AppLockerPolicy -Ldap $GPOApplocker -Domain
    }
    $CountRules = 0
    foreach ($Placeholder in $Placeholders.Keys) {
        $CountRules += ($Gpo.Value[0].$Placeholder|Measure-Object).Count
    }   

    if ($CountRules -gt 0) {
        $Msg = "** TESTING RULES from '{0}' **" -f $GpoToTest
        Write-Verbose $Msg

        foreach ($PlaceholderKey in $Placeholders.Keys) {
        # Iterate over every EXE, MSI and SCRIPT Rules
            foreach ($Rule in $Gpo.Value[0].$PlaceholderKey) {

                if ($PlaceholderKey -like "*PRODUCT*") {
                    # Does the file exist
                    if (Test-Path -PathType leaf -Path $(Join-Path -Path $BinDir -ChildPath $Rule.Filepath)) {
                        $TestResult = Get-ChildItem -LiteralPath $BinDir $Rule.Filepath | Convert-Path | Test-AppLockerPolicy -PolicyObject $GPOPolicyObject -User $Rule.UserOrGroupSid
                        # Checking Appocker result
                        if ($TestResult.PolicyDecision -ne $PolicyDecision.Item($Rule.Action)) {
                            if ($Rule.isException -and $TestResult.PolicyDecision -eq "DeniedByDefault") {
                                $Msg = "'{0}' is '{1}' for '{2}' due to an exception" -f $TestResult.FilePath, $TestResult.PolicyDecision, $Rule.UserOrGroup
                                if ($Verbose) {
                                    Write-Host $Msg -ForegroundColor Green
                                }
                            } else {
                                $Msg = "'{0}' is '{1}' for '{2}' and should be '{3}'" -f $TestResult.FilePath, $TestResult.PolicyDecision, $Rule.UserOrGroup, $Rule.Action
                                Write-Host $Msg -ForegroundColor Red
                            }
                        } else {
                            if ($Rule.isException) {
                                $Msg = "'{0}' is '{1}' for '{2}' by '{3}' and should not be '{4}'" -f $TestResult.FilePath, $TestResult.PolicyDecision, $Rule.UserOrGroup, $TestResult.MatchingRule, $Rule.Action
                                Write-Host $Msg -ForegroundColor Red
                            } else {
                                $Msg = "'{0}' is '{1}' for '{2}' by '{3}'" -f $TestResult.FilePath, $TestResult.PolicyDecision, $Rule.UserOrGroup, $TestResult.MatchingRule
                                if ($Verbose) {
                                    Write-Host $Msg -ForegroundColor Green
                                }
                            }
                        }
                    } else {
                        $Msg = "file {0} could not be found in {1} directory, so it cannot be tested" -f $Rule.Filepath, $BinDir
                        Write-Warning $Msg
                    }
                } elseif ($PlaceholderKey -like "*PATH*") {
                    $Msg = "Not testing {0} Rules based on PATH : {1}" -f $PlaceholderKey, $Rule.Filepath
                    if ($Verbose) {
                        Write-Warning $Msg
                    }
                } else {
                    $Msg = "Invalid Rule name {0}" -f $PlaceholderKey
                    Write-Warning $Msg
                }
            }
        }
    }
}
