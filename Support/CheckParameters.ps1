##### Root the filepath #####
if (-not [System.IO.Path]::IsPathRooted("$JsonConfigFile")) {
    $JsonConfigFile = Join-Path -Path $RootDir -ChildPath $JsonConfigFile
}

if (-not [System.IO.Path]::IsPathRooted("$XmlTemplateFile")) {
    $XmlTemplateFile = Join-Path -Path $RootDir -ChildPath $XmlTemplateFile
}

if (-not [System.IO.Path]::IsPathRooted("$BinDir")) {
    $BinDir = Join-Path -Path $RootDir -ChildPath $BinDir
}

if (-not [System.IO.Path]::IsPathRooted("$OutDir")) {
    $OutDir = Join-Path -Path $RootDir -ChildPath $OutDir
}

if (-not [System.IO.Path]::IsPathRooted("$XmlToTest")) {
    $XmlToTest = Join-Path -Path $RootDir -ChildPath $XmlToTest
}

##### Check that files exist #####
if (!(Test-Path $JsonConfigFile)) {
    $Msg = "Config file {0} does not exist" -f $JsonConfigFile
    Write-Error $Msg
}

if (!(Test-Path $BinDir)) {
    $Msg = "{0} directory does not exist. Create it and feel it with the binaries used in the config file" -f  $BinDir
    Write-Error $Msg
}

if (!(Test-Path $XmlTemplateFile)) {
    $Msg = "{0} xml template does not exist." -f $XmlTemplateFile
    Write-Error $Msg
}

# OutDir is created if it does not exist
if (!(Test-Path $OutDir)) {
    if ($Verbose.IsPresent) {
        $Msg = "Creating output directory {0}" -f $OutDir
        Write-Host $Msg
    }
    mkdir $OutDir
}

if (!(Test-Path $XmlToTest)) {
    $Msg = "{0} xml does not exist." -f $XmlToTests
    Write-Error $Msg
}

##### Check that ActiveDirectory powershell module is installed #####

if ($ResolveSID.IsPresent -and -not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    $Msg = "ActiveDirectory powershell module is not installed. Please install it or provide the necessary SID in {0} and do not use the ResolveSID option" -f $JsonConfigFile
    Write-Error $Msg
}

##### Check that the GpoToTest exists #####

if ($GpoToTest -and $GpoToTest -ne "Effective") {
    try {
        Get-GPO $GpoToTest
    } catch [System.ArgumentException] {
        $Msg = "GPO {0} does not exist." -f $GpoToTest
        Write-Error $Msg
    } catch [System.Management.Automation.CommandNotFoundException] {
        $Msg = "ActiveDirectory powershell module is not installed."
        Write-Error $Msg
    }
}

##### GpoToTest and XmlToTest parameters can not be used at the same time #####

if ($GpoToTest -and $XmlToTest) {
    $Msg = "You can only supply one of the option : GpoToTest or XmlToTest, not both."
    Write-Error $Msg
}


