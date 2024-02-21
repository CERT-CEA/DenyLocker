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
    [Parameter(Mandatory=$False)][bool]$testRules=$false,
    [Parameter(Mandatory=$False)][string]$configFile="CEA-config.json",
    [Parameter(Mandatory=$False)][bool]$createRules=$true,
    [Parameter(Mandatory=$False)][bool]$exportRules=$true,
    [Parameter(Mandatory=$False)][string]$binDir="binaries",
    [Parameter(Mandatory=$False)][string]$outDir="output"
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
    
    } else {
        $filePathCondition.SetAttribute("Path", $rule.filepath)
        $msg = "Building '{0}' rule for group '{1}' for path '{2}'" -f $rule.action, $rule.UserOrGroup, $rule.filepath
    }  
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
function TestRule {

    Param(
        [Parameter(Mandatory = $true)] [ValidateScript( { $_ -in $placeholders.Keys } )] [string] $placeholderKey,
        [Parameter(Mandatory = $true)] [string] $binariesDirectory,
        [Parameter(Mandatory = $true)] [AllowEmptyCollection()] [array] $rules,
        [Parameter(Mandatory = $true)] $applockerPolicy
    )

    # Test applocker rules generated to ensure they work

    $PolicyDecision = @{"Allow" = "Allowed"; "Deny" = "Denied"}

    foreach ($binary in $rules) {

        if (-not (Test-Path -Path $(Join-Path -Path $binariesDirectory -ChildPath $binary.filepath))) {
            $msg = "'{0}' could not be found in '{1}', download it or fix the json config file" -f $binary.filepath, $binariesDirectory
            Write-Warning $msg
        } 
        else 
        {
            $testresult = Get-ChildItem -LiteralPath $binariesDirectory $binary.filepath |Convert-Path | Test-AppLockerPolicy -XmlPolicy $applockerPolicy -User $binary.UserOrGroupSid
            if ($testresult.PolicyDecision -ne $PolicyDecision.Item($binary.action) -and -not $binary.isException) {
                $msg = "'{0}' is '{1}' for '{2}' and should be ''{3}''" -f $testresult.FilePath, $testresult.PolicyDecision, $binary.UserOrGroup, $binary.action
                Write-Host $msg -ForegroundColor Red
            } else {
                $msg = "'{0}' is '{1}' for '{2}' by ''{3}''" -f $testresult.FilePath, $testresult.PolicyDecision, $binary.UserOrGroup, $testresult.MatchingRule
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

        # check if the binary exists
        if ($placeholderKey -contains "PRODUCT" -and -not (Test-Path -Path $(Join-Path -Path $binariesDirectory -ChildPath $binary.filepath))) {
            $msg = "'{0}' could not be found in '{1}', download it or fix the json config file" -f $binary.filepath, $binariesDirectory
            Write-Warning $msg
        } 
        else 
        {
            if ($placeholderKey -contains "PRODUCT") {
                # Get the publisher of the file
                $file = Get-ChildItem -LiteralPath $binariesDirectory $binary.filepath
                $publisher = (Get-AppLockerFileInformation $file.FullName).Publisher
            }
        
            # the binary may not have a publisher if it is not signed
            if ($null -eq $publisher)
            {
                if ($placeholderKey -contains "PRODUCT") {
                    $msg = "Unable to build '{0}' rule based on signature for file '{1}' in '{2}' directory" -f $binary.action, $binary.filepath, $binariesDirectory
                    Write-Warning $msg
                }
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

            # If the binary is to be placed in an applocker exception
            # the structure in "else" is not required
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

# Read the json config file
try {
    $jsonContent = Get-Content -Raw -Path $configFile
    $configData = $jsonContent | ConvertFrom-Json
} catch [System.ArgumentException] {
    $_.Exception.GetType().FullName
    $msg = "'{0}' is not a valid json file" -f $configFile
    Write-Error $msg
}

# Quick check that every file in $binDir folder is concerned by at least one rule in $configFile
Get-ChildItem -LiteralPath $binDir | ForEach-Object {
    $fileIsInConfig = Select-String -Path $configFile -Pattern $_.Name
    if ($fileIsInConfig -eq $null) {
        $msg = "File '{0}' does not appear in '{1}' config file and won't therefore be concerned by any applocker rule defined there" -f $_.Name, $configFile
        Write-Warning $msg
    }
}

foreach ($GPO in $configData.PSObject.Properties) {

    # Read the xml template
    $xDocument = [xml](Get-Content $defRulesXml)

    # Get the gpo name and its rules
    $gpoName = $GPO.Name
    $rules = $GPO.Value

    # Generate the xml output file name
    $xmlOutFile = Join-Path -Path $outDir -ChildPath ((Get-Date -Format "yyyyMMdd")+"_$gpoName.xml")

    if ($createRules) {
        $msg = "Building Applocker GPO policy '{0}' to '{1}'" -f $gpoName, $xmlOutFile
        Write-Host $msg
        
        # Iterate over every EXE, MSI and SCRIPT rules
        foreach ($placeholder in $placeholders.Keys) {
            CreateGPORules $xDocument $placeholder $binDir $rules[0].$placeholder
        }

        Write-Debug $xDocument.OuterXml

        # Save the applocker policy generated
        try {
            $masterPolicy = [Microsoft.Security.ApplicationId.PolicyManagement.PolicyModel.AppLockerPolicy]::FromXml($xDocument.OuterXml)
            SaveAppLockerPolicyAsUnicodeXml -ALPolicy $masterPolicy -xmlFilename $xmlOutFile
        } catch [System.Management.Automation.MethodInvocationException] {
            throw $_
            exit 1
        }

    }  

    if ($testRules) {
        $msg = "TESTING RULES from '{0}'" -f $xmlOutFile
        Write-Host $msg
        TestRule "EXE DENY" $binDir $rules[0].'EXE DENY' $xmlOutFile
        TestRule "EXE ALLOW" $binDir $rules[0].'EXE ALLOW' $xmlOutFile
        TestRule "EXE EXCEPTION" $binDir $rules[0].'EXE EXCEPTION' $xmlOutFile
        TestRule "MSI DENY" $binDir $rules[0].'MSI DENY' $xmlOutFile
        TestRule "MSI ALLOW" $binDir $rules[0].'MSI ALLOW' $xmlOutFile
        TestRule "MSI EXCEPTION" $binDir $rules[0].'MSI EXCEPTION' $xmlOutFile
    }

    if ($exportRules) {
        $msg = "EXPORTING RULES '{0}' TO EXCEL" -f $xmlOutFile
        # SaveWorkbook : saves workbook to same directory as input 
        # file with same file name and default Excel file extension
        & $ps1_ExportPolicyToExcel -AppLockerXML $xmlOutFile -SaveWorkbook
    }

}