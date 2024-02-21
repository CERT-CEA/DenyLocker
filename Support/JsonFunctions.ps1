####################################################################################################
# Json stuff
####################################################################################################
function ReadJson {
    Param(
        [Parameter(Mandatory = $true)] [string] $filepath
    )
    try {
        $jsonContent = Get-Content -Raw -Path $filepath
        $configData = $jsonContent | ConvertFrom-Json
        $configData
    } catch [System.ArgumentException] {
        $_.Exception.GetType().FullName
        $msg = "'{0}' is not a valid json file" -f $configFile
        Write-Error $msg
    }
}