if (! (Test-Path (Join-Path -Path $rootDir -ChildPath $configFile))) {
    $msg = "Config file {0} does not exist" -f $(Join-Path -Path $rootDir -ChildPath $configFile)
    Write-Error $msg
}

if (! (Test-Path (Join-Path -Path $rootDir -ChildPath $binDir))) {
    $msg = "{0} directory does not exist. Create it and feel it with the binaries used in the config file" -f $(Join-Path -Path $rootDir -ChildPath $binDir)
    Write-Error $msg
}

if (! (Test-Path (Join-Path -Path $rootDir -ChildPath $outDir))) {
    mkdir (Join-Path -Path $rootDir -ChildPath $outDir)
}

if (-not [System.IO.Path]::IsPathRooted("$jsonConfigPath")) {
    $jsonConfigPath = Join-Path -Path $rootDir -ChildPath $jsonConfigPath
}
if (-not [System.IO.Path]::IsPathRooted("$xmlTemplateFile")) {
    $xmlTemplateFile = Join-Path -Path $rootDir -ChildPath $xmlTemplateFile
}
if (-not [System.IO.Path]::IsPathRooted("$binDir")) {
    $binDir = Join-Path -Path $rootDir -ChildPath $binDir
}
if (-not [System.IO.Path]::IsPathRooted("$outDir")) {
    $outDir = Join-Path -Path $rootDir -ChildPath $outDir
}


