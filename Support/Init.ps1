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


