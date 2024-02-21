if (! (Test-Path (Join-Path -Path $rootDir -ChildPath $configFile))) {
    $msg = "Config file {0} does not exist" -f $(Join-Path -Path $rootDir -ChildPath $configFile)
    Write-Error $msg
}

if (! (Test-Path (Join-Path -Path $rootDir -ChildPath $binDir))) {
    $msg = "{0} directory does not exist" -f $(Join-Path -Path $rootDir -ChildPath $binDir)
    Write-Error $msg
}

if (! (Test-Path (Join-Path -Path $rootDir -ChildPath $binDir))) {
    mkdir (Join-Path -Path $rootDir -ChildPath $binDir)
}

if (! (Test-Path (Join-Path -Path $rootDir -ChildPath $outDir))) {
    mkdir (Join-Path -Path $rootDir -ChildPath $outDir)
}


