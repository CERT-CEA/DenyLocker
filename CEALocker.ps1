<#
    .SYNOPSIS
    Ce script génère un fichier xml de règles Applocker.
    Les règles autorise tout sauf la liste de logiciels présents dans différents dossiers
    
    .PARAMETER configFile
    Nom du fichier json contenant les binaires et la règle à leur appliquer

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
    [Parameter(Mandatory=$False)][bool]$testRules=$true,
    [Parameter(Mandatory=$False)][string]$configFile="CEA-config.json",
    [Parameter(Mandatory=$False)][bool]$createRules=$true,
    [Parameter(Mandatory=$False)][bool]$exportRules=$true,
    [Parameter(Mandatory=$False)][string]$binDir="Binaries",
    [Parameter(Mandatory=$False)][string]$outDir="output"
    )

$ErrorActionPreference="Stop"
$rootDir = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
# Dot-source the config file.
. $rootDir\Support\Config.ps1
. $rootDir\Support\Init.ps1
. $rootDir\Support\SupportFunctions.ps1

# Code from AaronLocker
function SaveXmlDocAsUnicode([System.Xml.XmlDocument] $xmlDoc, [string] $xmlFilename)
{
    $xws = [System.Xml.XmlWriterSettings]::new()
    $xws.Encoding = [System.Text.Encoding]::Unicode
    $xws.Indent = $true
    $xw = [System.Xml.XmlWriter]::Create($xmlFilename, $xws)
    $xmlDoc.Save($xw)
    $xw.Close()
}

# Code from AaronLocker
function SaveAppLockerPolicyAsUnicodeXml([Microsoft.Security.ApplicationId.PolicyManagement.PolicyModel.AppLockerPolicy]$ALPolicy, [string]$xmlFilename)
{
    SaveXmlDocAsUnicode -xmlDoc ([xml]($ALPolicy.ToXml())) -xmlFilename $xmlFilename
}

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
        $msg = "Building {0} rule for group {1} for product {2} in {3} directory" -f $rule.action, $rule.UserOrGroup, $publisher.ProductName, $directory
    } else {
        $msg = "Building {0} rule for group {1} for filename {2} in {3} directory" -f $rule.action, $rule.UserOrGroup, $rule.filename, $directory
    }
    Write-Host $msg -ForegroundColor Green

    $filePublisherCondition.SetAttribute("PublisherName", $publisher.PublisherName)
    
    if ($rule.ruleProduct -and $publisher.ProductName) {
        $filePublisherCondition.SetAttribute("ProductName", $publisher.ProductName)
    } else {
        $filePublisherCondition.SetAttribute("ProductName", "*" )
    }

    if ($rule.ruleBinary -and $publisher.BinaryName) {
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
    $filePathCondition.SetAttribute("Path", "*"+$rule.filename+"*.exe")
    $msg = "Building {0} rule for group {1} for software {2} in {3} based on filename" -f $rule.action, $rule.UserOrGroup, $rule.filename, $directory
    Write-Warning $msg
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
        $fileRule.SetAttribute("Description", $rule.action + " " + $rule.UserOrGroup + " " + $rule.filename)
        $fileRule.SetAttribute("Name", $rule.action + " " + $rule.UserOrGroup + " " + $rule.filename)
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
    $fileRule.SetAttribute("Description", $rule.action + " " + $rule.UserOrGroup + " " + $rule.filename)
    $fileRule.SetAttribute("Name", $rule.action + " " + $rule.UserOrGroup + " " + $rule.filename)
    Return $fileRule
}
function TestRule {

    Param(
        [Parameter(Mandatory = $true)] [ValidateScript( { $_ -in $applockerRuleCollection } )] [string] $ruleCollection,
        [Parameter(Mandatory = $true)] [array] $rules,
        [Parameter(Mandatory = $true)] $applockerPolicy
    )

    $PolicyDecision = @{"Allow" = "Allowed"; "Deny" = "Denied"}

    foreach ($rule in $rules) {
        Get-ChildItem $rule.directory -File | ForEach-Object {
            $testresult = ($_  |Convert-Path| Test-AppLockerPolicy -XmlPolicy $applockerPolicy -User $rule.UserOrGroupSid)
            if ($testresult.PolicyDecision -ne $PolicyDecision.Item($rule.action) -and -not $rule.isException) {
                $msg = "'{0}' is {1} for {2} and should be '{3}'" -f $testresult.FilePath, $testresult.PolicyDecision, $rule.UserOrGroup, $rule.action
                Write-Host $msg -ForegroundColor Red
            } else {
                $msg = "'{0}' is {1} for {2} by '{3}'" -f $testresult.FilePath, $testresult.PolicyDecision, $rule.UserOrGroup, $testresult.MatchingRule
                Write-Host $msg -ForegroundColor Green
            }
            
        }
    }

}
function CreateGPORules {

    Param(
        [Parameter(Mandatory = $true)] $xDocument,
        [Parameter(Mandatory = $true)] [ValidateScript( { $_ -in $placeholders.Keys } )] [string] $placeholderKey,
        [Parameter(Mandatory = $true)] [string] $binariesDirectory,
        [Parameter(Mandatory = $true)] [AllowEmptyCollection()] [array] $rules
    )
    $msg = "Building ruleCollection '{0}' rules" -f $placeholderKey
    Write-Host $msg -ForegroundColor Green

    # Let's create an XML child
    $xPlaceholder = $xDocument.SelectNodes("//"+$placeholders.Item($placeholderKey))[0]
    $xPlaceholderParentNode = $xPlaceholder.ParentNode

    foreach ($binary in $rules) {

        if (-not (Test-Path -Path $(Join-Path -Path $binariesDirectory -ChildPath $binary.filename))) {
            $msg = "{0} could not be found in {1}, download it or fix the json config file" -f $binary.filename, $binariesDirectory
            Write-Warning $msg
        } 
        else 
        {
            $file = Get-ChildItem -LiteralPath $binariesDirectory $binary.filename
    
            $publisher = (Get-AppLockerFileInformation $file.FullName).Publisher
        
            if ($null -eq $publisher)
            {
                $msg = "Unable to build {0} rule based on signature for file {1} in {2} directory" -f $binary.action, $binary.filename, $binariesDirectory
                Write-Warning $msg
                $fileRule = CreateFilePathRule $xDocument $binary
                # Create a FilePathCondition element
                # <FilePathCondition FilePath="ngrok">
                $fileCondition = CreateFilePathCondition $xDocument $binariesDirectory $binary
            }
            else
            {
                $fileRule = CreateFilePublisherRule $xDocument $publisher $binary
                # Create a FilePublisherCondition element   
                # <FilePublisherCondition BinaryName="*" ProductName="*" PublisherName="O=DROPBOX, INC, L=SAN FRANCISCO, S=CALIFORNIA, C=US">
                $fileCondition = CreateFilePublisherCondition $xDocument $publisher $binariesDirectory $binary
            }

            if ($binary.isException) {
                $xPlaceholderParentNode.AppendChild($fileCondition) | Out-Null
            } else {
                $fileRule.SetAttribute("Action", $binary.action)
                $fileRule.SetAttribute("UserOrGroupSid", $binary.UserOrGroupSid)
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
    }     
    # Remove placeholder elements
    $xPlaceholderParentNode.RemoveChild($xPlaceholder) | Out-Null   
}

if ($createRules) {

    try {
        $jsonContent = Get-Content -Raw -Path $configFile
        $configData = $jsonContent | ConvertFrom-Json
    } catch [System.ArgumentException] {
        $_.Exception.GetType().FullName
        $msg = "{0} is not a valid json file" -f $configFile
        Write-Error $msg
    }

    foreach ($GPO in $configData.PSObject.Properties) {

        $xDocument = [xml](Get-Content $defRulesXml)
        $gpoName = $GPO.Name
        $rules = $GPO.Value
        $xmlOutFile = Join-Path -Path $outDir -ChildPath ((Get-Date -Format "yyyyMMdd")+"_$gpoName.xml")

        $msg = "Building Applocker GPO policy {0} to {1}" -f $gpoName, $xmlOutFile
        Write-Host $msg

        CreateGPORules $xDocument "EXE DENY" $binDir $rules[0].'EXE DENY'
        CreateGPORules $xDocument "EXE ALLOW" $binDir $rules[0].'EXE ALLOW'
        CreateGPORules $xDocument "EXE EXCEPTION" $binDir $rules[0].'EXE EXCEPTION'
        CreateGPORules $xDocument "MSI DENY" $binDir $rules[0].'MSI DENY'
        CreateGPORules $xDocument "MSI ALLOW" $binDir $rules[0].'MSI ALLOW'
        CreateGPORules $xDocument "MSI EXCEPTION" $binDir $rules[0].'MSI EXCEPTION'

        Write-Debug $xDocument.OuterXml

        try {
            $rulesFileEnforceNew = $xmlOutFile
            $masterPolicy = [Microsoft.Security.ApplicationId.PolicyManagement.PolicyModel.AppLockerPolicy]::FromXml($xDocument.OuterXml)
            SaveAppLockerPolicyAsUnicodeXml -ALPolicy $masterPolicy -xmlFilename $rulesFileEnforceNew
        } catch [System.Management.Automation.MethodInvocationException] {
            throw $_
            exit 1
        }
        <#
        if ($testRules) {
            $msg = "TESTING RULES from {0}" -f $xmlOutFile
            Write-Host $msg
            TestRule "Exe" $denyRules $xmlOutFile
            TestRule "Exe" $allowExceptDenyRule $xmlOutFile
        }
        #>
    
        if ($exportRules) {
            $msg = "EXPORTING RULES {0} TO EXCEL" -f $xmlOutFile
            & $ps1_ExportPolicyToExcel -AppLockerXML $xmlOutFile
        }

        }
}

<#

if ($createRules) {
    $msg = "BUILDING RULES TO {0}" -f $xmlOutFile
    Write-Host $msg
    CreateRule $xDocument "Exe" $denyRules "EXE DENY"
    CreateRule $xDocument "Msi" $denyRules "MSI DENY"
    CreateRule $xDocument "Exe" $allowExceptDenyRule "EXE EXCEPTION"
    CreateRule $xDocument "Exe" $everyonePublisherToAllowRule "EXE ALLOW"

    Write-Debug $xDocument.OuterXml

    try {
        $masterPolicy = [Microsoft.Security.ApplicationId.PolicyManagement.PolicyModel.AppLockerPolicy]::FromXml($xDocument.OuterXml)
        SaveAppLockerPolicyAsUnicodeXml -ALPolicy $masterPolicy -xmlFilename $rulesFileEnforceNew
    } catch [System.Management.Automation.MethodInvocationException] {
        throw $_
        exit 1
    }
}

#>