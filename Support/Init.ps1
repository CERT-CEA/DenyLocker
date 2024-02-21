if (! (Test-Path (Join-Path -Path $RootDir -ChildPath $JsonConfigFile))) {
    $Msg = "Config file {0} does not exist" -f $(Join-Path -Path $RootDir -ChildPath $JsonConfigFile)
    Write-Error $Msg
}

if (! (Test-Path (Join-Path -Path $RootDir -ChildPath $BinDir))) {
    $Msg = "{0} directory does not exist. Create it and feel it with the binaries used in the config file" -f $(Join-Path -Path $RootDir -ChildPath $BinDir)
    Write-Error $Msg
}

if (! (Test-Path (Join-Path -Path $RootDir -ChildPath $OutDir))) {
    mkdir (Join-Path -Path $RootDir -ChildPath $OutDir)
}

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


