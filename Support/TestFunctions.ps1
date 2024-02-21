function TestXmlRule {
    Param(
        [Parameter(Mandatory = $true)] [string] $binDir,
        [Parameter(Mandatory = $true)] [string] $jsonConfigPath
    )
    # Test applocker rules generated to ensure they are applied as intended

    $PolicyDecision = @{"Allow" = "Allowed"; "Deny" = "Denied"}

    $configData = ReadJson $jsonConfigPath
    foreach ($GPO in $configData.PSObject.Properties) {
        $gpoName = $GPO.Name
        $xmlOutFile = Join-Path -Path $outDir -ChildPath ((Get-Date -Format "yyyyMMdd")+"_$gpoName.xml")

        $count_rules = 0
        foreach ($placeholder in $placeholders.Keys) {
            $count_rules += ($GPO.Value[0].$placeholder|Measure-Object).Count
        }

        if ($testRules -and $count_rules -gt 0) {
            $msg = "** TESTING RULES from '{0}' **" -f $xmlOutFile
            Write-Host $msg
        
            foreach ($placeholderKey in $placeholders.Keys) {
            # Iterate over every EXE, MSI and SCRIPT rules
                foreach ($rule in $GPO.Value[0].$placeholderKey) {

                    if ($placeholderKey -like "*PRODUCT*") {
                        # Does the file exist
                        if (Test-Path -PathType leaf -Path $(Join-Path -Path $binDir -ChildPath $rule.filepath)) {
                            $testresult = Get-ChildItem -LiteralPath $binDir $rule.filepath |Convert-Path | Test-AppLockerPolicy -XmlPolicy $xmlOutFile -User $rule.UserOrGroupSid
                            # Checking Appocker result
                            if ($testresult.PolicyDecision -ne $PolicyDecision.Item($rule.action) -and -not $rule.isException) {
                                $msg = "'{0}' is '{1}' for '{2}' and should be ''{3}''" -f $testresult.FilePath, $testresult.PolicyDecision, $rule.UserOrGroup, $rule.action
                                Write-Host $msg -ForegroundColor Red
                            } elseif ($rule.isException) {
                                $msg = "'{0}' is '{1}' for '{2}' due to an exception" -f $testresult.FilePath, $testresult.PolicyDecision, $rule.UserOrGroup, $testresult.MatchingRule
                                Write-Host $msg -ForegroundColor Green
                            } else {
                                $msg = "'{0}' is '{1}' for '{2}' by ''{3}''" -f $testresult.FilePath, $testresult.PolicyDecision, $rule.UserOrGroup, $testresult.MatchingRule
                                Write-Host $msg -ForegroundColor Green
                            }
                        } else {
                            $msg = "file {0} could not be found in {1} directory, so it cannot be tested" -f $rule.filepath, $binDir
                            Write-Warning $msg
                        }
                    } elseif ($placeholderKey -like "*PATH*") {
                        $msg = "Not testing {0} rules based on PATH" -f $placeholderKey
                        Write-Warning $msg
                    } else {
                        $msg = "Invalid rule name {0}" -f $placeholderKey
                        Write-Warning $msg
                    }
                }
            }
        }
    }        
}