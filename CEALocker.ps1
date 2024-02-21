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

    .PARAMETER CreateRules
    Génère les règles

    .PARAMETER ExportRules
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
    .\CEALocker.ps1 -TestRules $false
    Pour tester un xml de règles : 
    .\CEALocker.ps1 -XmlOutFile example.xml -CreateRules $false -ExportRules $false -TestRules $true

#>

Param(
    [Parameter(Mandatory=$False)][string]$JsonConfigFile="CEA-config.json",
    [Parameter(Mandatory=$False)][string]$XmlTemplateFile="Support/template.xml",
    [Parameter(Mandatory=$False)][string]$BinDir="binaries",
    [Parameter(Mandatory=$False)][string]$OutDir="output",
    [Parameter(Mandatory=$False)][bool]$CreateRules=$true,
    [Parameter(Mandatory=$False)][bool]$ExportRules=$true,
    [Parameter(Mandatory=$False)][bool]$TestRules=$true
    )

$ErrorActionPreference="Stop"
$RootDir = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
# Dot-source the config file.
. $RootDir\Support\Config.ps1

# Check arguments
. $RootDir\Support\Init.ps1

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

if ($CreateRules) {
    CheckXmlTemplate -xmlpath $XmlTemplateFile -BinDir $BinDir -OutDir $OutDir
    CheckBinDirectory -BinDir $BinDir -JsonConfigFile $JsonConfigFile
    GenerateApplockerXml -JsonConfigFile $JsonConfigFile -BinDir $BinDir -XmlTemplateFile $XmlTemplateFile -OutDir $OutDir
} else {
    $Msg = "createRule option is at {0} so the rules defined in {1} won't be used" -f $CreateRules, $JsonConfigFile
    Write-Warning $Msg
}

if ($TestRules) {
    TestXmlRule -BinDir $BinDir -JsonConfigFile $JsonConfigFile
}

if ($ExportRules) {
    ExportXmlRule -JsonConfigFile $JsonConfigFile
}