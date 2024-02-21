$rootDir = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
# Dot-source the config file.
. $rootDir\Config.ps1

foreach ($rule in $rules) {

    if (! (Test-Path $rule.directory)) {
        mkdir $rule.directory
    }
}
