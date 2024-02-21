####################################################################################################
# Json stuff
####################################################################################################
function ReadJson {
    Param(
        [Parameter(Mandatory = $true)] [string] $FilePath
    )
    try {
        $jsonContent = Get-Content -Raw -Path $FilePath
        $ConfigData = $jsonContent | ConvertFrom-Json
        $ConfigData
    } catch [System.ArgumentException] {
        $_.Exception.GetType().FullName
        $Msg = "'{0}' is not a valid json file" -f $FilePath
        Write-Error $Msg
    }
}