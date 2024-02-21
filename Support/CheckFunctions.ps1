function CheckXmlTemplate {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $XmlPath,
        [Parameter(Mandatory = $true)] [string] $BinDir,
        [Parameter(Mandatory = $true)] [string] $OutDir
    )
    # Check template file

    $Msg = "Checking that the template file {0} is valid" -f $XmlPath
    Write-Host $Msg

    # Check that the file exists
    if (-not (Test-Path $XmlPath)) {
        $Msg = "XML template file {0} could not be found" -f $XmlPath
        Write-Error $Msg
    }

    # Check that all placeholder are in the template
    $xDocument = [xml](Get-Content $XmlPath)
    foreach ($PlaceholderKey in $Placeholders.Keys) {
        $x = $xDocument.SelectNodes("//"+$Placeholders.Item($PlaceholderKey))
        if ($x.Count -eq 0) {
            $Msg = "Placeholder {0} could not be found in {1}" -f $Placeholders.Item($PlaceholderKey), $XmlPath
            Write-Error $Msg
        }
    }

    try {
        $EmptyJsonConfigFile = "Support\empty.json"
        GenerateApplockerXml -JsonConfigFile $EmptyJsonConfigFile -BinDir $BinDir -xmlTemplateFile $XmlPath -OutDir $OutDir

        $XmlOutFile = Join-Path -Path $OutDir -ChildPath ((Get-Date -Format "yyyyMMdd")+"_empty.xml")
        Remove-Item -Path $XmlOutFile
    } catch [System.Management.Automation.MethodInvocationException] {
        $Msg = "Template file {0} is not valid" -f $XmlPath
        Write-Warning $Msg
        throw $_
    }
}

function CheckJsonRule {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [ValidateScript( { $_ -in $Placeholders.Keys } )] [string] $PlaceholderKey,
        [Parameter(Mandatory = $true)] [string] $BinDir,
        [Parameter(Mandatory = $true)] $Rule
    )
    # Verify som attributes of a given Rule
    # Display a warning if

    if ($PlaceholderKey -like "*PRODUCT*") {
        if (-not (Test-Path -PathType leaf -Path $(Join-Path -Path $BinDir -ChildPath $Rule.FilePath))) {
            $Msg = "file '{0}' could not be found in '{1}', download it or fix the json config file" -f $Rule.FilePath, $BinDir
            Write-Warning $Msg
        }
        if ($Rule.RulePublisher -ne $true -and $Rule.RulePublisher -ne $false) {
            $Msg = "Invalid RulePublisher value {0} for {1}, must be true or false." -f $Rule.RulePublisher, $Rule.FilePath
            Write-Warning $Msg
            throw
        }

        if ($Rule.RuleProduct -ne $true -and $Rule.RuleProduct -ne $false) {
            $Msg = "Invalid RuleProduct value {0} for {1}, must be true or false" -f $Rule.RuleProduct, $Rule.RuleProduct
            Write-Warning $Msg
            throw
        }

        if ($Rule.RuleBinary -ne $true -and $Rule.RuleBinary -ne $false) {
            $Msg = "Invalid RuleBinary value {0} for {1}, must be true or false" -f $Rule.RuleBinary, $Rule.FilePath
            Write-Warning $Msg
            throw
        }

    }

    if ($PlaceholderKey -like "*EXCEPTION*") {
        if ($Rule.IsException -ne $true -and $Rule.IsException -ne $false) {
            $Msg = "Invalid IsException value {0} for {1}, must be true or false" -f $Rule.IsException, $Rule.FilePath
            Write-Warning $Msg
            throw
        }
    }

    if (-not ($Rule.UserOrGroupSID -match "S-[0-9-]+" )) {
        $Msg = "Invalid group SID : {0}" -f $Rule.UserOrGroupSID
        Write-Warning $Msg
        throw
    }

    if ($Rule.action -ne "Allow" -and $Rule.action -ne "Deny") {
        $Msg = "Invalid action value {0} for {1}, must be Allow or Deny" -f $Rule.action, $Rule.FilePath
        Write-Warning $Msg
        throw
    }
}

function CheckBinDirectory {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $BinDir,
        [Parameter(Mandatory = $true)] [string] $JsonConfigFile
    )
    # Check that every file in $BinDir folder is concerned by at least one Rule in $JsonConfigFile
    $Msg = "Checking that every file in {0} folder is concerned by at least one Rule in {1}" -f $BinDir, $JsonConfigFile
    Write-Host $Msg
    Get-ChildItem -LiteralPath $BinDir | ForEach-Object {
        $FileIsInConfig = Select-String -Path $JsonConfigFile -Pattern $_.Name
        if ($null -eq $FileIsInConfig) {
            $Msg = "File '{0}' does not appear in '{1}' config file and won't therefore be concerned by any applocker Rule defined there" -f $_.Name, $JsonConfigFile
            Write-Warning $Msg
        }
    }
}