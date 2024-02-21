<#
    .SYNOPSIS
    Ce script génère un fichier xml de règles Applocker.
    Les règles autorise tout sauf la liste de logiciels présents dans différents dossiers

    .PARAMETER JsonConfigFile
    Nom du fichier json contenant les binaires et la règle à leur appliquer

    .PARAMETER XmlTemplateFile
    Nom du fichier xml utilisé comme template

    .PARAMETER BinDir
    Dossier contenant les binaires définies dans JsonConfigFile

    .PARAMETER OutDir
    Dossier dans lequel les xml Applocker seront écrits

    .PARAMETER TestRules
    Test les règles générés

    .PARAMETER GpoToTest
    Specify the Applocker GPO to test JsonConfigFile against

    .PARAMETER XmlToTest
    Specify the Applocker XML to test JsonConfigFile against

    .PARAMETER CreateRules
    Génère les règles

    .PARAMETER ExportRules
    Exporte les règles XML sous excel

    .PARAMETER ResolveSID
    Resolve user or group SID based on their name using the ActiveDirectory module

    .NOTES
    (c) Florian MARTIN 2023
    version 1.0

    TODO
    Example
    .\CEALocker.ps1 -CreateRules -ExportRules -TestRules -JsonConfigFile config.json
    Fichier de sortie par défaut : yyyyMMdd_cealocker.xml

#>

Param(
    [Parameter(Mandatory=$False)][string]$JsonConfigFile="config.json",
    [Parameter(Mandatory=$False)][string]$XmlTemplateFile="Support/template.xml",
    [Parameter(Mandatory=$False)][string]$BinDir="binaries",
    [Parameter(Mandatory=$False)][string]$OutDir="output",
    [Parameter(Mandatory=$False)][switch]$CreateRules,
    [Parameter(Mandatory=$False)][switch]$ExportRules,
    [Parameter(Mandatory=$False)][switch]$TestRules,
    [Parameter(Mandatory=$False)][switch]$ResolveSID,
    [Parameter(Mandatory=$False)]$GpoToTest,
    [Parameter(Mandatory=$False)]$XmlToTest,
    [Parameter(Mandatory=$False)][switch]$Verbose
    )

$ErrorActionPreference="Stop"
$RootDir = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
# Dot-source the config file.
. $RootDir\Support\Config.ps1

# Check arguments
. $RootDir\Support\CheckParameters.ps1

# Import required functions
. $RootDir\Support\CheckFunctions.ps1
. $RootDir\Support\CreateRuleFunctions.ps1
. $RootDir\Support\JsonFunctions.ps1
. $RootDir\Support\SupportFunctions.ps1
. $RootDir\Support\TestFunctions.ps1
. $RootDir\Support\XmlFunctions.ps1
function GenerateApplockerXml {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $BinDir,
        [Parameter(Mandatory = $true)] [string] $JsonConfigFile,
        [Parameter(Mandatory = $true)] [string] $XmlTemplateFile,
        [Parameter(Mandatory = $true)] [string] $OutDir
    )
    # Main function
    # Create the rules according to CreateRules option

    $ConfigData = ReadJson $JsonConfigFile
    foreach ($Gpo in $ConfigData.PSObject.Properties) {
        $gpoName = $Gpo.Name
        $XmlOutFile = Join-Path -Path $OutDir -ChildPath ((Get-Date -Format "yyyyMMdd")+"_$gpoName.xml")
        WriteXml -Gpo $Gpo -BinDir $BinDir -XmlOutFile $XmlOutFile -ApplockerXml $XmlTemplateFile
    }
}

if ($CreateRules.IsPresent) {
    CheckXmlTemplate -xmlpath $XmlTemplateFile -BinDir $BinDir -OutDir $OutDir
    CheckBinDirectory -BinDir $BinDir -JsonConfigFile $JsonConfigFile
    GenerateApplockerXml -JsonConfigFile $JsonConfigFile -BinDir $BinDir -XmlTemplateFile $XmlTemplateFile -OutDir $OutDir
} else {
    $Msg = "createRule option is at {0} so the rules defined in {1} won't be used" -f $CreateRules, $JsonConfigFile
    Write-Warning $Msg
}

if ($TestRules.IsPresent) {
    if ($GpoToTest) {
        TestXmlRule -BinDir $BinDir -JsonConfigFile $JsonConfigFile -GpoToTest $GpoToTest
    } elseif ($XmlToTest) {
        TestXmlRule -BinDir $BinDir -JsonConfigFile $JsonConfigFile -XmlToTest $XmlToTest
    } else {
        TestXmlRule -BinDir $BinDir -JsonConfigFile $JsonConfigFile
    }
} elseif ($Verbose) {
    Write-Hosting "Testing is disabled"
}

if ($ExportRules.IsPresent) {
    ExportXmlRule -JsonConfigFile $JsonConfigFile
}

#TODO : paramètre UserOrGroup obligatoire dans la conf json des exceptions
# refaire example-config, UserOrGroup est nécessaire pour les tests
# résoudre SID et nom des objets, vérifier qu'ils sont égaux
# résoudre le SID du groupe à partir du nom du groupe
# Ecrire le README