function CheckXmlTemplate {
    Param(
        [Parameter(Mandatory = $true)] [string] $xmlpath,
        [Parameter(Mandatory = $true)] [string] $binDir,
        [Parameter(Mandatory = $true)] [string] $outDir
    )
    # Check template file

    $msg = "Checking that the template file {0} is valid" -f $xmlpath
    Write-Host $msg

    # Check that the file exists
    if (-not (Test-Path $xmlpath)) {
        $msg = "XML template file {0} could not be found" -f $xmlpath
        Write-Error $msg
    }

    # Check that all placeholder are in the template
    $xDocument = [xml](Get-Content $xmlpath)
    foreach ($placeholderKey in $placeholders.Keys) {
        $x = $xDocument.SelectNodes("//"+$placeholders.Item($placeholderKey))
        if ($x.Count -eq 0) {
            $msg = "Placeholder {0} could not be found in {1}" -f $placeholders.Item($placeholderKey), $xmlpath
            Write-Error $msg
        }
    }

    try {
        $EmptyJsonConfigPath = "Support\empty.json"
        GenerateApplockerXml -jsonConfigPath $EmptyJsonConfigPath -binDir $binDir -xmlTemplateFile $xmlpath -outDir $outDir

        $xmlOutFile = Join-Path -Path $outDir -ChildPath ((Get-Date -Format "yyyyMMdd")+"_empty.xml")
        Remove-Item -Path $xmlOutFile
    } catch [System.Management.Automation.MethodInvocationException] {
        $msg = "Template file {0} is not valid" -f $xmlpath
        Write-Warning $msg
        throw $_
    }
}

function CheckJsonRule {
    Param(
        [Parameter(Mandatory = $true)] [ValidateScript( { $_ -in $placeholders.Keys } )] [string] $placeholderKey,
        [Parameter(Mandatory = $true)] [string] $binDir,
        [Parameter(Mandatory = $true)] $rule
    )
    # Verify som attributes of a given rule
    # Display a warning if 

    if ($placeholderKey -like "*PRODUCT*") {
        if (-not (Test-Path -PathType leaf -Path $(Join-Path -Path $binDir -ChildPath $rule.filepath))) {
            $msg = "file '{0}' could not be found in '{1}', download it or fix the json config file" -f $rule.filepath, $binDir
            Write-Warning $msg
        }
        if ($rule.rulePublisher -ne $true -and $rule.rulePublisher -ne $false) {
            $msg = "Invalid rulePublisher value {0} for {1}, must be true or false." -f $rule.rulePublisher, $rule.filepath
            Write-Warning $msg
            throw
        }
    
        if ($rule.ruleProduct -ne $true -and $rule.ruleProduct -ne $false) {
            $msg = "Invalid ruleProduct value {0} for {1}, must be true or false" -f $rule.ruleProduct, $rule.ruleProduct
            Write-Warning $msg 
            throw
        }
    
        if ($rule.ruleBinary -ne $true -and $rule.ruleBinary -ne $false) {
            $msg = "Invalid ruleBinary value {0} for {1}, must be true or false" -f $rule.ruleBinary, $rule.filepath
            Write-Warning $msg 
            throw
        }
        
    }

    if ($placeholderKey -like "*EXCEPTION*") {
        if ($rule.isException -ne $true -and $rule.isException -ne $false) {
            $msg = "Invalid isException value {0} for {1}, must be true or false" -f $rule.isException, $rule.filepath
            Write-Warning $msg 
            throw
        }
    }
    
    if (-not ($rule.UserOrGroupSID -match "S-[0-9-]+" )) {
        $msg = "Invalid group SID : {0}" -f $rule.UserOrGroupSID
        Write-Warning $msg
        throw 
    }

    if ($rule.action -ne "Allow" -and $rule.action -ne "Deny") {
        $msg = "Invalid action value {0} for {1}, must be Allow or Deny" -f $rule.action, $rule.filepath
        Write-Warning $msg 
        throw
    }    
}

function CheckBinDirectory {
    Param(
        [Parameter(Mandatory = $true)] [string] $binDir,
        [Parameter(Mandatory = $true)] [string] $jsonConfigPath
    )
    # Check that every file in $binDir folder is concerned by at least one rule in $jsonConfigPath
    $msg = "Checking that every file in {0} folder is concerned by at least one rule in {1}" -f $binDir, $jsonConfigPath
    Write-Host $msg
    Get-ChildItem -LiteralPath $binDir | ForEach-Object {
        $fileIsInConfig = Select-String -Path $jsonConfigPath -Pattern $_.Name
        if ($null -eq $fileIsInConfig) {
            $msg = "File '{0}' does not appear in '{1}' config file and won't therefore be concerned by any applocker rule defined there" -f $_.Name, $jsonConfigPath
            Write-Warning $msg
        }
    }
}