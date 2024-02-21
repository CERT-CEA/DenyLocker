<#
    .SYNOPSIS
    Ce script génère un fichier xml de règles Applocker.
    Les règles autorise tout sauf la liste de logiciels présents dans différents dossiers
    
    .PARAMETER configFile
    Nom du fichier json contenant les binaires et la règle à leur appliquer

    .PARAMETER xmlTemplateFile
    Nom du fichier xml utilisé comme template

    .PARAMETER binDir
    Dossier contenant les binaires définies dans configFile

    .PARAMETER outDir
    Dossier dans lequel les xml Applocker seront écrits

    .PARAMETER testRules
    Test les règles générés

    .PARAMETER createRules
    Génère les règles

    .PARAMETER exportRules
    Exporte les règles XML sous excel

    .NOTES
    (c) Florian MARTIN 2023
    version 1.0

    TODO
    Example
    .\CEALocker.ps1 
    Fichier de sortie par défaut : yyyyMMdd_cealocker.xml
    .\CEALocker.ps1
    Pour ne pas tester les règles générées :
    .\CEALocker.ps1 -testRules $false
    Pour tester un xml de règles : 
    .\CEALocker.ps1 -xmlOutFile example.xml -createRules $false -exportRules $false -testRules $true

#>

Param(
    [Parameter(Mandatory=$False)][string]$configFile="CEA-config.json",
    [Parameter(Mandatory=$False)][string]$xmlTemplateFile="Support/template.xml",
    [Parameter(Mandatory=$False)][string]$binDir="binaries",
    [Parameter(Mandatory=$False)][string]$outDir="output",
    [Parameter(Mandatory=$False)][bool]$createRules=$true,
    [Parameter(Mandatory=$False)][bool]$exportRules=$true,
    [Parameter(Mandatory=$False)][bool]$testRules=$true
    )

$ErrorActionPreference="Stop"
$rootDir = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
# Dot-source the config file.
. $rootDir\Support\Config.ps1
. $rootDir\Support\Init.ps1
. $rootDir\Support\SupportFunctions.ps1

function CreateFilePublisherCondition {
    Param(
        [Parameter(Mandatory = $true)] $xDocument,
        [Parameter(Mandatory = $true)] $publisher,
        [Parameter(Mandatory = $true)] [string] $directory,
        [Parameter(Mandatory = $true)] $rule
    )
    # Create a FilePublisherCondition element
    # <FilePublisherCondition PublisherName="O=MULLVAD VPN AB, L=GÖTEBORG, C=SE" ProductName="MULLVAD VPN" BinaryName="*">
    # <BinaryVersionRange LowSection="*" HighSection="*" />
    # This XML is used between <Exceptions> OR <FilePublisherRule>

    $filePublisherCondition = $xDocument.CreateElement("FilePublisherCondition")   
    if ($publisher.ProductName) {
        $msg = "Building '{0}' rule for group '{1}' for product '{2}' in '{3}' directory" -f $rule.action, $rule.UserOrGroup, $publisher.ProductName, $directory
    } else {
        $msg = "Building '{0}' rule for group '{1}' for filename '{2}' in '{3}' directory" -f $rule.action, $rule.UserOrGroup, $rule.filepath, $directory
    }
    Write-Host $msg -ForegroundColor Green

    $filePublisherCondition.SetAttribute("PublisherName", $publisher.PublisherName)
    
    if ($rule.ruleProduct -eq $true -and $publisher.ProductName) {
        $filePublisherCondition.SetAttribute("ProductName", $publisher.ProductName)
    } else {
        $filePublisherCondition.SetAttribute("ProductName", "*" )
    }

    if ($rule.ruleBinary -eq $true -and $publisher.BinaryName) {
        $filePublisherCondition.SetAttribute("BinaryName", $publisher.binarytodeny)
    } else {
        $filePublisherCondition.SetAttribute("BinaryName", "*" )
    }
    
    # Set version number range to "any"
    $elemVerRange = $xDocument.CreateElement("BinaryVersionRange")
    $elemVerRange.SetAttribute("LowSection", "*")
    $elemVerRange.SetAttribute("HighSection", "*")
    # Add the version range to the publisher condition
    $filePublisherCondition.AppendChild($elemVerRange) | Out-Null
    Return $filePublisherCondition
}

function CreateFilePathCondition {
    Param(
        [Parameter(Mandatory = $true)] $xDocument,
        [Parameter(Mandatory = $true)] [string] $directory,
        [Parameter(Mandatory = $true)] $rule
    )
    # Create a FilePathCondition element
    # <FilePathCondition Path="ngrok*.exe" />
    # This XML is used between <Exceptions> OR <FilePathRule>
    $filePathCondition = $xDocument.CreateElement("FilePathCondition")  
    if ($rule -like "*PRODUCT*") {
        $filename_wc = "*{0}*.exe" -f $rule.filepath.split('.')[0]
        $filePathCondition.SetAttribute("Path", $filename_wc)
        $msg = "Building '{0}' rule for group '{1}' for software '{2}' in '{3}' based on filename" -f $rule.action, $rule.UserOrGroup, $rule.filepath, $directory
        Write-Warning $msg
    
    } else {
        $filePathCondition.SetAttribute("Path", $rule.filepath)
        $msg = "Building '{0}' rule for group '{1}' for path '{2}'" -f $rule.action, $rule.UserOrGroup, $rule.filepath
        Write-Host $msg -ForegroundColor Green
    }  

    Return $filePathCondition
}

function CreateFilePublisherRule {
    Param(
        [Parameter(Mandatory = $true)] $xDocument,
        [Parameter(Mandatory = $true)] $publisher,
        [Parameter(Mandatory = $true)] $rule
    )
    # Create a FilePublisherRule element
    # <FilePublisherRule Action="Deny" UserOrGroupSid="S-1-1-0" Description="" Name="DropBox">
    #   <Conditions>
    #      ...
    #   </Conditions>
    # </FilePublisherRule>
    $fileRule = $xDocument.CreateElement("FilePublisherRule")

    if ($publisher.ProductName) {
        $fileRule.SetAttribute("Description", $rule.action + " " + $rule.UserOrGroup + " " + $publisher.ProductName)
        $fileRule.SetAttribute("Name", $rule.action + " " + $rule.UserOrGroup + " " + $publisher.ProductName)
    } else {
        $fileRule.SetAttribute("Description", $rule.action + " " + $rule.UserOrGroup + " " + $rule.filepath)
        $fileRule.SetAttribute("Name", $rule.action + " " + $rule.UserOrGroup + " " + $rule.filepath)
    }
    Return $fileRule
}

function CreateFilePathRule {
    Param(
        [Parameter(Mandatory = $true)] $xDocument,
        [Parameter(Mandatory = $true)] $rule
    )
    # Create a FilePathRule element
    # <FilePathRule Action="Deny" UserOrGroupSid="S-1-1-0" Description="" Name="DropBox">
    #      ...
    # </FilePathRule>
    $fileRule = $xDocument.CreateElement("FilePathRule")
    $fileRule.SetAttribute("Description", $rule.action + " " + $rule.UserOrGroup + " " + $rule.filepath)
    $fileRule.SetAttribute("Name", $rule.action + " " + $rule.UserOrGroup + " " + $rule.filepath)
    Return $fileRule
}

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

function WriteXml {
    Param(
        [Parameter(Mandatory = $true)] [string] $binDir,
        [Parameter(Mandatory = $true)] $GPO,
        [Parameter(Mandatory = $true)] $xmlOutFile,
        [Parameter(Mandatory = $true)] $applockerXml   
    )
    # Write the XML created by CreateRule to a file

    #Read the xml template
    $xDocument = [xml](Get-Content $applockerXml)

    # Get the gpo name and its rules
    $gpoName = $GPO.Name
    $rules = $GPO.Value

    $msg = "Building Applocker GPO policy '{0}' to '{1}'" -f $gpoName, $xmlOutFile
    Write-Host $msg
    
    # Iterate over every EXE, MSI and SCRIPT rules
    foreach ($placeholder in $placeholders.Keys) {
        GenerateXmlRule -xDocument $xDocument -placeholderKey $placeholder -binDir $binDir -rules $rules[0].$placeholder
    }

    Write-Debug $xDocument.OuterXml

    # Save the applocker policy generated
    try {
        $masterPolicy = [Microsoft.Security.ApplicationId.PolicyManagement.PolicyModel.AppLockerPolicy]::FromXml($xDocument.OuterXml)
        SaveAppLockerPolicyAsUnicodeXml -ALPolicy $masterPolicy -xmlFilename $xmlOutFile
    } catch [System.Management.Automation.MethodInvocationException] {
        $msg = "The restulting xml file {0} is not valid. See the error below" -f $xmlOutFile
        Write-Warning $msg
        throw $_
    }
}

function GenerateXmlRule {
    Param(
        [Parameter(Mandatory = $true)] $xDocument,
        [Parameter(Mandatory = $true)] [ValidateScript( { $_ -in $placeholders.Keys } )] [string] $placeholderKey,
        [Parameter(Mandatory = $true)] [string] $binDir,
        [Parameter(Mandatory = $true)] [AllowEmptyCollection()] [array] $rules
    )
    # Create the resulting xml for a given rule
    
    $count_rules = ($rules|Measure-Object).Count
    if ($count_rules -gt 0) {
        $msg = "Building ruleCollection '{0}' rules" -f $placeholderKey
        Write-Host $msg
    } else {
        $msg = "No rules defined for {0}" -f $placeholderKey
        Write-Debug $msg
    }

    # Let's create an XML child
    $xPlaceholder = $xDocument.SelectNodes("//"+$placeholders.Item($placeholderKey))[0]
    $xPlaceholderParentNode = $xPlaceholder.ParentNode

    foreach ($rule in $rules) {

        CheckJsonRule -placeholderKey $placeholderKey -binDir $binDir -rule $rule

        if ($placeholderKey -like "*PRODUCT*" -and (Test-Path -PathType leaf -Path $(Join-Path -Path $binDir -ChildPath $rule.filepath))) {
            # Get the publisher of the file
            $file = Get-ChildItem -LiteralPath $binDir $rule.filepath
            $publisher = (Get-AppLockerFileInformation $file.FullName).Publisher
        }
    
        # the rule may not have a publisher if it is not signed
        if ($null -eq $publisher)
        {
            if ($placeholderKey -like "*PRODUCT*") {
                $msg = "Unable to build '{0}' rule based on signature for file '{1}' in '{2}' directory" -f $rule.action, $rule.filepath, $binDir
                Write-Warning $msg
            }
            $fileRule = CreateFilePathRule -xDocument $xDocument -rule $rule
            # Create a FilePathCondition element
            # <FilePathCondition FilePath="ngrok">
            $fileCondition = CreateFilePathCondition -xDocument $xDocument -directory $binDir -rule $rule
        }
        else
        {
            $fileRule = CreateFilePublisherRule -xDocument $xDocument -publisher $publisher -rule $rule
            # Create a FilePublisherCondition element   
            # <FilePublisherCondition BinaryName="*" ProductName="*" PublisherName="O=DROPBOX, INC, L=SAN FRANCISCO, S=CALIFORNIA, C=US">
            $fileCondition = CreateFilePublisherCondition -xDocument $xDocument -publisher $publisher -directory $binDir -rule $rule    
       
        }

        # If the binary is to be placed in an applocker exception
        # the structure in "else" is not required
        if ($rule.isException) {
            $xPlaceholderParentNode.AppendChild($fileCondition) | Out-Null
        } else {
            $fileRule.SetAttribute("Action", $rule.action)
            $fileRule.SetAttribute("UserOrGroupSid", $rule.UserOrGroupSid)
            $fileRule.SetAttribute("Id", ([guid]::NewGuid()).Guid)
            # Create a Conditions element
            # <Conditions>
            $condition = $xDocument.CreateElement("Conditions")
            $condition.AppendChild($fileCondition) | Out-Null
            $fileRule.AppendChild($condition) | Out-Null
            # Add the publisher condition where the placeholder is
            $xPlaceholderParentNode.AppendChild($fileRule) | Out-Null
        }
    }     
    # Remove placeholder elements
    $xPlaceholderParentNode.RemoveChild($xPlaceholder) | Out-Null   
}

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
                        if (Test-Path -PathType leaf -Path $(Join-Path -Path $binDir -ChildPath $rule.filepath)) {
                            $testresult = Get-ChildItem -LiteralPath $binDir $rule.filepath |Convert-Path | Test-AppLockerPolicy -XmlPolicy $xmlOutFile -User $rule.UserOrGroupSid
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

function ExportXmlRule {
    Param(
        [Parameter(Mandatory = $true)] [string] $jsonConfigPath
    )
    # Export rules to csv anc Excel
    $configData = ReadJson $jsonConfigPath
    foreach ($GPO in $configData.PSObject.Properties) {
        $gpoName = $GPO.Name
        $xmlOutFile = Join-Path -Path $outDir -ChildPath ((Get-Date -Format "yyyyMMdd")+"_$gpoName.xml")
        
        $msg = "** EXPORTING RULES '{0}' TO EXCEL **" -f $xmlOutFile
        Write-Host $msg
        # SaveWorkbook : saves workbook to same directory as input 
        # file with same file name and default Excel file extension
        & $ps1_ExportPolicyToExcel -AppLockerXml $xmlOutFile -SaveWorkbook
    }
}

function GenerateApplockerXml {
    Param(
        [Parameter(Mandatory = $true)] [string] $binDir,
        [Parameter(Mandatory = $true)] [string] $jsonConfigPath,
        [Parameter(Mandatory = $true)] [string] $xmlTemplateFile,
        [Parameter(Mandatory = $true)] [string] $outDir
    )
    # Main function
    # Parse the config file
    # Create the rules according to createRules, testRules and exportRules options

    CheckBinDirectory -binDir $binDir -jsonConfigPath $jsonConfigPath

    $configData = ReadJson $jsonConfigPath
    foreach ($GPO in $configData.PSObject.Properties) {
        $gpoName = $GPO.Name
        $xmlOutFile = Join-Path -Path $outDir -ChildPath ((Get-Date -Format "yyyyMMdd")+"_$gpoName.xml")

        WriteXml -GPO $GPO -binDir $binDir -xmlOutFile $xmlOutFile -applockerXml $xmlTemplateFile

        $count_rules = 0
        foreach ($placeholder in $placeholders.Keys) {
            $count_rules += ($GPO.Value[0].$placeholder|Measure-Object).Count
        }
    }
}

if ($createRules) {
    CheckXmlTemplate -xmlpath $xmlTemplateFile -binDir $binDir -outDir $outDir
    GenerateApplockerXml -jsonConfigPath $configFile -binDir $binDir -xmlTemplateFile $xmlTemplateFile -outDir $outDir
} else {
    $msg = "createRule option is at {0} so the rules defined in {1} won't be used" -f $createRules, $jsonConfigPath
}

if ($testRules) {
    TestXmlRule -binDir $binDir -jsonConfigPath $configFile
}

if ($exportRules) {
    ExportXmlRule -jsonConfigPath $configFile
}