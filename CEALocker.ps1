<#
    .SYNOPSIS
    Ce script génère un fichier xml de règles Applocker.
    Les règles autorise tout sauf la liste de logiciels présents dans différents dossiers
    
    .PARAMETER OutFile
    Fichier de sortie json de la configuration sysmon

    .NOTES
    (c) Florian MARTIN 2022
    version 1.0

    Example
    .\CEALocker.ps1 -OutFile output.xml

#>

Param([Parameter(Mandatory=$False)][string]$OutFile=(Get-Date -Format "yyyyMMdd")+"_cealocker.xml")

$rootDir = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
# Dot-source the config file.
. $rootDir\Config.ps1
. $rootDir\Init.ps1
$xDocument = [xml](Get-Content $defRulesXml)
function SaveXmlDocAsUnicode([System.Xml.XmlDocument] $xmlDoc, [string] $xmlFilename)
{
    $xws = [System.Xml.XmlWriterSettings]::new()
    $xws.Encoding = [System.Text.Encoding]::Unicode
    $xws.Indent = $true
    $xw = [System.Xml.XmlWriter]::Create($xmlFilename, $xws)
    $xmlDoc.Save($xw)
    $xw.Close()
}

function SaveAppLockerPolicyAsUnicodeXml([Microsoft.Security.ApplicationId.PolicyManagement.PolicyModel.AppLockerPolicy]$ALPolicy, [string]$xmlFilename)
{
    SaveXmlDocAsUnicode -xmlDoc ([xml]($ALPolicy.ToXml())) -xmlFilename $xmlFilename
}

function CreateFilePublisherCondition($xDocument, $publisher, $filename, $rule) {
    $filePublisherCondition = $xDocument.CreateElement("FilePublisherCondition")   
    if ($publisher.ProductName) {
        $msg = "Building {0} rule for group {1} for {2} IN {3}" -f $rule.action, $rule.UserOrGroup, $publisher.ProductName, $rule.directory
    } else {
        $msg = "Building {0} rule for group {1} for {2} IN {3}" -f $rule.action, $rule.UserOrGroup, $filename, $rule.directory
    }
    Write-Host $msg -ForegroundColor Green

    $filePublisherCondition.SetAttribute("PublisherName", $publisher.PublisherName)
    
    if ($rule.denyProduct -and $publisher.ProductName) {
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

function CreateFilePathCondition($xDocument, $filename, $rule) {
    $filePathCondition = $xDocument.CreateElement("FilePathCondition")   
    $filePathCondition.SetAttribute("Path", $filename+"*.exe")
    $msg = "Building {0} rule for group {1} for {2} IN {3} based on filename" -f $rule.action, $rule.UserOrGroup, $filename, $rule.directory
    Write-Warning $msg
    Return $filePathCondition
}

foreach ($rule in $denyRules) {

    Get-ChildItem $rule.directory -File | ForEach-Object {

        $publisher = (Get-AppLockerFileInformation $_.FullName).Publisher
        $filename = $_.Name.split('.')[0]

        $xDenyPlaceholder = $xDocument.SelectNodes("//PLACEHOLDER_EXETODENY")[0]
        $xDeny = $xDenyPlaceholder.ParentNode
    
        if ($null -eq $publisher)
        {
            Write-Warning "UNABLE TO BUILD DENYLIST RULE BASED ON SIGNATURE FOR $_"
            # Create a FilePathRule element
            # <FilePathRule Action="Deny" UserOrGroupSid="S-1-1-0" Description="" Name="DropBox">
            $fileRule = $xDocument.CreateElement("FilePathRule")
            $fileRule.SetAttribute("Description", $filename)
            $fileRule.SetAttribute("Name", $rule.action + " " + $rule.UserOrGroup + " " + $filename)

            # Create a FilePathCondition element
            # <FilePathCondition FilePath="ngrok">
            $fileCondition = CreateFilePathCondition $xDocument $filename $rule
        }
        else
        {
            # Create a FilePublisherRule element
            # <FilePublisherRule Action="Deny" UserOrGroupSid="S-1-1-0" Description="" Name="DropBox">
            $fileRule = $xDocument.CreateElement("FilePublisherRule")

            if ($publisher.ProductName) {
                $fileRule.SetAttribute("Description", $publisher.ProductName)
                $fileRule.SetAttribute("Name", $rule.action + " " + $rule.UserOrGroup + " " + $publisher.ProductName)
            } else {
                $fileRule.SetAttribute("Description", $filename)
                $fileRule.SetAttribute("Name", $rule.action + " " + $rule.UserOrGroup + " " + $filename)
            }

            # Create a FilePublisherCondition element
            # <FilePublisherCondition BinaryName="*" ProductName="*" PublisherName="O=DROPBOX, INC, L=SAN FRANCISCO, S=CALIFORNIA, C=US">
            $fileCondition = CreateFilePublisherCondition $xDocument $publisher $filename $rule
        }

        $fileRule.SetAttribute("Action", $rule.action)
        $fileRule.SetAttribute("UserOrGroupSid", $rule.UserOrGroupSid)
        $fileRule.SetAttribute("Id", ([guid]::NewGuid()).Guid)

        # Create a Conditions element
        # <Conditions>
        $condition = $xDocument.CreateElement("Conditions")

        $condition.AppendChild($fileCondition) | Out-Null
        $fileRule.AppendChild($condition) | Out-Null
        # Add the publisher condition where the placeholder is
        $xDeny.AppendChild($fileRule) | Out-Null
    }

}

$xAllowExceptPlaceholder = $xDocument.SelectNodes("//PLACEHOLDER_EXETODENY_EXCEPTION")[0]
$xAllowExcept = $xAllowExceptPlaceholder.ParentNode

# Remove the placeholder element
$xDeny.RemoveChild($xDenyPlaceholder) | Out-Null
$xAllowExcept.RemoveChild($xAllowExceptPlaceholder) | Out-Null

Write-Host $xDocument.OuterXml

$masterPolicy = [Microsoft.Security.ApplicationId.PolicyManagement.PolicyModel.AppLockerPolicy]::FromXml($xDocument.OuterXml)

SaveAppLockerPolicyAsUnicodeXml -ALPolicy $masterPolicy -xmlFilename $rulesFileEnforceNew