$rootDir = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)

if (! (Test-Path $binariesDir)) {
    mkdir $binariesDir
}

foreach ($rule in $rules) {
    if (! (Test-Path $rule.directory)) {
        mkdir $rule.directory
    }
}
