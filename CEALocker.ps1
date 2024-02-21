<#
.SYNOPSIS

.DESCRIPTION

#>

$rootDir = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
# Dot-source the config file.
. $rootDir\Config.ps1
$xDocument = [xml](Get-Content $defRulesXml)

# Génére les paramètres de la règle de blocage pour chaque dossier
# publishertodeny : bloque tous les exécutables du publisher du binaire
# productToDeny : bloque seulement le binaire donné
# binaryToDeny : inutilisé
$exeToDenyRules = @{}
$exeToDenyDirectories | ForEach-Object {
    if (! (Test-Path $_)) {
        mkdir $_
    }
    $exeRule = New-Object PSObject
    $exeRule |Add-Member Noteproperty DenyPublisher $true
    if ($_.Contains("producttodeny")) {
        $exeRule |Add-Member Noteproperty DenyProduct $true
    }
    if ($_.Contains("binarytodeny")) {
        $exeRule |Add-Member Noteproperty DenyBinary $true
    }
    $exeToDenyRules.Add($_, $exeRule)
}

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

foreach ($exeToDenyRule in $exeToDenyRules.GetEnumerator()) {

    $dir = $exeToDenyRule.Key
    $rule = $exeToDenyRule.Value

    Get-ChildItem $dir | ForEach-Object {

        $publisher = (Get-AppLockerFileInformation $_.FullName).Publisher

        $xPlaceholder = $xDocument.SelectNodes("//PLACEHOLDER_EXETODENY")[0]
        $xExcepts = $xPlaceholder.ParentNode
    
        # Create a FilePublisherRule element
        # <FilePublisherRule Action="Deny" UserOrGroupSid="S-1-1-0" Description="" Name="DropBox">
        $FilePublisherRule = $xDocument.CreateElement("FilePublisherRule")
        $FilePublisherRule.SetAttribute("Action", "Deny")
        $FilePublisherRule.SetAttribute("UserOrGroupSid", "S-1-1-0")
        $FilePublisherRule.SetAttribute("Id", ([guid]::NewGuid()).Guid)
        
        # Create a Conditions element
        # <Conditions>
        $Condition = $xDocument.CreateElement("Conditions")

        # Create a FilePublisherCondition element
        # <FilePublisherCondition BinaryName="*" ProductName="*" PublisherName="O=DROPBOX, INC, L=SAN FRANCISCO, S=CALIFORNIA, C=US">
        $FilePublisherCondition = $xDocument.CreateElement("FilePublisherCondition")   

        if ($null -eq $publisher)
        {
            Write-Warning "UNABLE TO BUILD DENYLIST RULE BASED ON SIGNATURE FOR $_"
            $Filename = $_.Name.split('.')[0]
            $FilePublisherRule.SetAttribute("Description", $Filename)
            $FilePublisherRule.SetAttribute("Name", $Filename)
            $FilePublisherCondition.SetAttribute("BinaryName", $Filename)
            $msg = "Building denylist for {0} IN {1}" -f $Filename, $dir
            Write-Warning $msg
        }
        else
        {
            $msg = "Building denylist for {0} IN {1}" -f $publisher.ProductName, $dir
            Write-Host $msg -ForegroundColor Green

            $FilePublisherRule.SetAttribute("Description", $publisher.ProductName)
            $FilePublisherRule.SetAttribute("Name", $publisher.ProductName)
            $FilePublisherCondition.SetAttribute("PublisherName", $publisher.PublisherName)
            
            if ($rule.DenyProduct) {
                $FilePublisherCondition.SetAttribute("ProductName", $publisher.ProductName)
            } else {
                $FilePublisherCondition.SetAttribute("ProductName", "*" )
            }

            if ($rule.DenyBinary) {
                $FilePublisherCondition.SetAttribute("BinaryName", $publisher.binarytodeny)
            } else {
                $FilePublisherCondition.SetAttribute("BinaryName", "*" )
            }
            
            # Set version number range to "any"
            $elemVerRange = $xDocument.CreateElement("BinaryVersionRange")
            $elemVerRange.SetAttribute("LowSection", "*")
            $elemVerRange.SetAttribute("HighSection", "*")
            # Add the version range to the publisher condition
            $FilePublisherCondition.AppendChild($elemVerRange) | Out-Null
            $Condition.AppendChild($FilePublisherCondition) | Out-Null
            $FilePublisherRule.AppendChild($Condition)
            # Add the publisher condition where the placeholder is
            $xExcepts.AppendChild($FilePublisherRule) | Out-Null
        }
    }

}



# Remove the placeholder element
$xExcepts.RemoveChild($xPlaceholder) | Out-Null

Write-Host $xDocument.OuterXml

$masterPolicy = [Microsoft.Security.ApplicationId.PolicyManagement.PolicyModel.AppLockerPolicy]::FromXml($xDocument.OuterXml)

SaveAppLockerPolicyAsUnicodeXml -ALPolicy $masterPolicy -xmlFilename $rulesFileEnforceNew