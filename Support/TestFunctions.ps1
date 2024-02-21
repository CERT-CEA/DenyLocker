function TestXmlRule {
    Param(
        [Parameter(Mandatory = $true)] [string] $BinDir,
        [Parameter(Mandatory = $true)] [string] $JsonConfigFile
    )
    # Test applocker Rules generated to ensure they are applied as intended

    $PolicyDecision = @{"Allow" = "Allowed"; "Deny" = "Denied"}

    $ConfigData = ReadJson $JsonConfigFile
    foreach ($Gpo in $ConfigData.PSObject.Properties) {
        $GpoName = $Gpo.Name
        $XmlOutFile = Join-Path -Path $OutDir -ChildPath ((Get-Date -Format "yyyyMMdd")+"_$GpoName.xml")

        $CountRules = 0
        foreach ($Placeholder in $Placeholders.Keys) {
            $CountRules += ($Gpo.Value[0].$Placeholder|Measure-Object).Count
        }

        if ($TestRules -and $CountRules -gt 0) {
            $Msg = "** TESTING RULES from '{0}' **" -f $XmlOutFile
            Write-Host $Msg
        
            foreach ($PlaceholderKey in $Placeholders.Keys) {
            # Iterate over every EXE, MSI and SCRIPT Rules
                foreach ($Rule in $Gpo.Value[0].$PlaceholderKey) {

                    if ($PlaceholderKey -like "*PRODUCT*") {
                        # Does the file exist
                        if (Test-Path -PathType leaf -Path $(Join-Path -Path $BinDir -ChildPath $Rule.Filepath)) {
                            $TestResult = Get-ChildItem -LiteralPath $BinDir $Rule.Filepath |Convert-Path | Test-AppLockerPolicy -XmlPolicy $XmlOutFile -User $Rule.UserOrGroupSid
                            # Checking Appocker result
                            if ($TestResult.PolicyDecision -ne $PolicyDecision.Item($Rule.Action) -and -not $Rule.isException) {
                                $Msg = "'{0}' is '{1}' for '{2}' and should be ''{3}''" -f $TestResult.FilePath, $TestResult.PolicyDecision, $Rule.UserOrGroup, $Rule.Action
                                Write-Host $Msg -ForegroundColor Red
                            } elseif ($Rule.isException) {
                                $Msg = "'{0}' is '{1}' for '{2}' due to an exception" -f $TestResult.FilePath, $TestResult.PolicyDecision, $Rule.UserOrGroup, $TestResult.MatchingRule
                                Write-Host $Msg -ForegroundColor Green
                            } else {
                                $Msg = "'{0}' is '{1}' for '{2}' by ''{3}''" -f $TestResult.FilePath, $TestResult.PolicyDecision, $Rule.UserOrGroup, $TestResult.MatchingRule
                                Write-Host $Msg -ForegroundColor Green
                            }
                        } else {
                            $Msg = "file {0} could not be found in {1} directory, so it cannot be tested" -f $Rule.Filepath, $BinDir
                            Write-Warning $Msg
                        }
                    } elseif ($PlaceholderKey -like "*PATH*") {
                        $Msg = "Not testing {0} Rules based on PATH" -f $PlaceholderKey
                        Write-Warning $Msg
                    } else {
                        $Msg = "Invalid Rule name {0}" -f $PlaceholderKey
                        Write-Warning $Msg
                    }
                }
            }
        }
    }        
}