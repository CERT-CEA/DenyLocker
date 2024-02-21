<#
    .SYNOPSIS
    Ce script génère un fichier xml de règles Applocker.
    Les règles autorise tout sauf la liste de logiciels présents dans différents dossiers
    
    .PARAMETER OutFile
    Nom du fichier de sortie xml Applocker voulu

    .NOTES
    (c) Florian MARTIN 2023
    version 1.0

    Example
    .\CEALocker.ps1 -OutFile example.xml
    Fichier de sortie par défaut : yyyyMMdd_cealocker.xml
    .\CEALocker.ps1

#>

Param([Parameter(Mandatory=$False)][string]$OutFile=(Get-Date -Format "yyyyMMdd")+"_cealocker.xml")

$rootDir = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
# Dot-source the config file.
. $rootDir\Config.ps1
. $rootDir\Init.ps1
$xDocument = [xml](Get-Content $defRulesXml)

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
        [Parameter(Mandatory = $true)] [string] $filename,
        [Parameter(Mandatory = $true)] $rule
    )
    # Create a FilePublisherCondition element
    # <FilePublisherCondition PublisherName="O=MULLVAD VPN AB, L=GÖTEBORG, C=SE" ProductName="MULLVAD VPN" BinaryName="*">
    # <BinaryVersionRange LowSection="*" HighSection="*" />
    # This XML is used between <Exceptions> OR <FilePublisherRule>

    $filePublisherCondition = $xDocument.CreateElement("FilePublisherCondition")   
    if ($publisher.ProductName) {
        $msg = "Building {0} rule for group {1} for {2} IN {3}" -f $rule.action, $rule.UserOrGroup, $publisher.ProductName, $rule.directory
    } else {
        $msg = "Building {0} rule for group {1} for {2} IN {3}" -f $rule.action, $rule.UserOrGroup, $filename, $rule.directory
    }
    Write-Host $msg -ForegroundColor Green

    $filePublisherCondition.SetAttribute("PublisherName", $publisher.PublisherName)
    
    if ($rule.ruleProduct -and $publisher.ProductName) {
        $filePublisherCondition.SetAttribute("ProductName", $publisher.ProductName)
    } else {
        $filePublisherCondition.SetAttribute("ProductName", "*" )
    }

    if ($rule.denyBinary -and $publisher.BinaryName) {
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
        [Parameter(Mandatory = $true)] [string] $filename,
        [Parameter(Mandatory = $true)] $rule
    )
    # Create a FilePathCondition element
    # <FilePathCondition Path="ngrok*.exe" />
    # This XML is used between <Exceptions> OR <FilePathRule>
    $filePathCondition = $xDocument.CreateElement("FilePathCondition")   
    $filePathCondition.SetAttribute("Path", $filename+"*.exe")
    $msg = "Building {0} rule for group {1} for software {2} IN {3} based on filename" -f $rule.action, $rule.UserOrGroup, $filename, $rule.directory
    Write-Warning $msg
    Return $filePathCondition
}

function CreateFilePublisherRule {
    Param(
        [Parameter(Mandatory = $true)] $xDocument,
        [Parameter(Mandatory = $true)] $publisher,
        [Parameter(Mandatory = $true)] [string] $filename,
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
        $fileRule.SetAttribute("Description", $publisher.ProductName)
        $fileRule.SetAttribute("Name", $rule.action + " " + $rule.UserOrGroup + " " + $publisher.ProductName)
    } else {
        $fileRule.SetAttribute("Description", $filename)
        $fileRule.SetAttribute("Name", $rule.action + " " + $rule.UserOrGroup + " " + $filename)
    }
    Return $fileRule
}

function CreateFilePathRule {
    Param(
        [Parameter(Mandatory = $true)] $xDocument,
        [Parameter(Mandatory = $true)] [string] $filename,
        [Parameter(Mandatory = $true)] $rule
    )
    # Create a FilePathRule element
    # <FilePathRule Action="Deny" UserOrGroupSid="S-1-1-0" Description="" Name="DropBox">
    #      ...
    # </FilePathRule>
    $fileRule = $xDocument.CreateElement("FilePathRule")
    $fileRule.SetAttribute("Description", $filename)
    $fileRule.SetAttribute("Name", $rule.action + " " + $rule.UserOrGroup + " " + $filename)
    Return $fileRule
}

function CreateRule {

    Param(
        [Parameter(Mandatory = $true)] $xDocument,
        [Parameter(Mandatory = $true)] [ValidateScript( { $_ -in $applockerRuleCollection } )] [string] $ruleCollection,
        [Parameter(Mandatory = $true)] [array] $rules,
        [Parameter(Mandatory = $true)] [ValidateScript( { $_ -in $placeholders.Keys } )] [string] $placeholderKey
    )
    $msg = "Building ruleCollection {0} {1} rules" -f $ruleCollection, $placeholderKey
    Write-Host $msg -ForegroundColor Green

    # Let's create an XML child
    $xPlaceholder = $xDocument.SelectNodes("//"+$placeholders.Item($placeholderKey))[0]
    $xPlaceholderParentNode = $xPlaceholder.ParentNode

    foreach ($rule in $rules) {

        # We want to block MSI file installation if the product has one
        if ($ruleCollection -eq "Msi") {
            $files = Get-ChildItem $rule.directory -File -Filter "*.msi"
        # But also the resulting EXE, so we want EXE AND MSI files signature
        } else {
            $files = Get-ChildItem $rule.directory -File 
        }
        $files | ForEach-Object {
    
            $publisher = (Get-AppLockerFileInformation $_.FullName).Publisher
            $filename = $_.Name.split('.')[0]
            
            if ($null -eq $publisher)
            {
                Write-Warning "UNABLE TO BUILD DENYLIST RULE BASED ON SIGNATURE FOR $_"
                $fileRule = CreateFilePathRule $xDocument $filename $rule
                # Create a FilePathCondition element
                # <FilePathCondition FilePath="ngrok">
                $fileCondition = CreateFilePathCondition $xDocument $filename $rule
            }
            else
            {
                $fileRule = CreateFilePublisherRule $xDocument $publisher $filename $rule
                # Create a FilePublisherCondition element
                # <FilePublisherCondition BinaryName="*" ProductName="*" PublisherName="O=DROPBOX, INC, L=SAN FRANCISCO, S=CALIFORNIA, C=US">
                $fileCondition = CreateFilePublisherCondition $xDocument $publisher $filename $rule
            }

            if ($rule.action -eq "Deny") {
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
            } else {
                $xPlaceholderParentNode.AppendChild($fileCondition) | Out-Null
            }
        } 
    }
    # Remove placeholder elements
    $xPlaceholderParentNode.RemoveChild($xPlaceholder) | Out-Null
}

function TestRule {

    Param(
        [Parameter(Mandatory = $true)] [ValidateScript( { $_ -in $applockerRuleCollection } )] [string] $ruleCollection,
        [Parameter(Mandatory = $true)] [array] $rules,
        [Parameter(Mandatory = $true)] $applockerPolicy
    )

    foreach ($rule in $rules) {
        Get-ChildItem $rule.directory -File | ForEach-Object {
            $_  |Convert-Path| Test-AppLockerPolicy -XmlPolicy $applockerPolicy|Select FilePath, PolicyDecision
        }
    }

}

#CreateRule $xDocument "Exe" $denyRules "EXE DENY"
#CreateRule $xDocument "Msi" $denyRules "MSI DENY"
#CreateRule $xDocument "Exe" $allowExceptDenyRule "EXE EXCEPTION"

TestRule "Exe" $denyRules $OutFile
TestRule "Exe" $allowExceptDenyRule $OutFile

Write-Debug $xDocument.OuterXml

#$masterPolicy = [Microsoft.Security.ApplicationId.PolicyManagement.PolicyModel.AppLockerPolicy]::FromXml($xDocument.OuterXml)

SaveAppLockerPolicyAsUnicodeXml -ALPolicy $masterPolicy -xmlFilename $rulesFileEnforceNew

