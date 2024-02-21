<#
    .SYNOPSIS
    Ce script génère un fichier xml de règles Applocker.
    Les règles autorise tout sauf la liste de logiciels présents dans différents dossiers
    
    .PARAMETER jsonConfigPath
    Nom du fichier json contenant les binaires et la règle à leur appliquer

    .PARAMETER xmlTemplateFile
    Nom du fichier xml utilisé comme template

    .PARAMETER binDir
    Dossier contenant les binaires définies dans jsonConfigPath

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
    [Parameter(Mandatory=$False)][string]$jsonConfigPath="CEA-config.json",
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

# Check arguments
. $rootDir\Support\Init.ps1

# Import required functions
. $rootDir\Support\CheckFunctions.ps1
. $rootDir\Support\CreateRuleFunctions.ps1
. $rootDir\Support\JsonFunctions.ps1
. $rootDir\Support\SupportFunctions.ps1
. $rootDir\Support\TestFunctions.ps1
. $rootDir\Support\XmlFunctions.ps1
function GenerateApplockerXml {
    Param(
        [Parameter(Mandatory = $true)] [string] $binDir,
        [Parameter(Mandatory = $true)] [string] $jsonConfigPath,
        [Parameter(Mandatory = $true)] [string] $xmlTemplateFile,
        [Parameter(Mandatory = $true)] [string] $outDir
    )
    # Main function
    # Create the rules according to createRules option

    $configData = ReadJson $jsonConfigPath
    foreach ($GPO in $configData.PSObject.Properties) {
        $gpoName = $GPO.Name
        $xmlOutFile = Join-Path -Path $outDir -ChildPath ((Get-Date -Format "yyyyMMdd")+"_$gpoName.xml")
        WriteXml -GPO $GPO -binDir $binDir -xmlOutFile $xmlOutFile -applockerXml $xmlTemplateFile
    }
}

if ($createRules) {
    CheckXmlTemplate -xmlpath $xmlTemplateFile -binDir $binDir -outDir $outDir
    CheckBinDirectory -binDir $binDir -jsonConfigPath $jsonConfigPath
    GenerateApplockerXml -jsonConfigPath $jsonConfigPath -binDir $binDir -xmlTemplateFile $xmlTemplateFile -outDir $outDir
} else {
    $msg = "createRule option is at {0} so the rules defined in {1} won't be used" -f $createRules, $jsonConfigPath
}

if ($testRules) {
    TestXmlRule -binDir $binDir -jsonConfigPath $jsonConfigPath
}

if ($exportRules) {
    ExportXmlRule -jsonConfigPath $jsonConfigPath
}