####################################################################################################
# Xml stuff
####################################################################################################
function WriteXml {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $BinDir,
        [Parameter(Mandatory = $true)] $Gpo,
        [Parameter(Mandatory = $true)] $XmlOutFile,
        [Parameter(Mandatory = $true)] $ApplockerXml
    )
    # Write the XML created by CreateRule to a File

    #Read the xml template
    $xDocument = [xml](Get-Content $ApplockerXml)

    # Get the gpo name and its Rules
    $GpoName = $Gpo.Name
    $Rules = $Gpo.Value
    $Msg = "Building Applocker Gpo policy '{0}' to '{1}'" -f $GpoName, $XmlOutFile
    Write-Verbose $Msg

    # Iterate over every EXE, MSI and SCRIPT Rules
    foreach ($Placeholder in $Placeholders.Keys) {
        GenerateXmlRule -xDocument $xDocument -PlaceholderKey $Placeholder -BinDir $BinDir -Rules $Rules[0].$Placeholder
    }

    Write-Debug $xDocument.OuterXml

    # Save the applocker policy generated
    try {
        $MasterPolicy = [Microsoft.Security.ApplicationId.PolicyManagement.PolicyModel.AppLockerPolicy]::FromXml($xDocument.OuterXml)
        SaveAppLockerPolicyAsUnicodeXml -ALPolicy $MasterPolicy -xmlFilename $XmlOutFile
    } catch [System.Management.Automation.MethodInvocationException] {
        $Msg = "The restulting xml File {0} is not valid. See the error below" -f $XmlOutFile
        Write-Warning $Msg
        throw $_
    }
}

function GenerateXmlRule {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] $xDocument,
        [Parameter(Mandatory = $true)] [ValidateScript( { $_ -in $Placeholders.Keys } )] [string] $PlaceholderKey,
        [Parameter(Mandatory = $true)] [string] $BinDir,
        [Parameter(Mandatory = $true)] [AllowEmptyCollection()] [array] $Rules
    )
    # Create the resulting xml for a given Rule

    $CountRules = ($Rules|Measure-Object).Count
    if ($CountRules -gt 0) {
        $Msg = "Building RuleCollection '{0}' Rules" -f $PlaceholderKey
        Write-Verbose $Msg
    } else {
        $Msg = "No Rules defined for {0}" -f $PlaceholderKey
        Write-Verbose $Msg
    }

    # Let's create an XML child
    $xPlaceholder = $xDocument.SelectNodes("//"+$Placeholders.Item($PlaceholderKey))[0]
    $xPlaceholderParentNode = $xPlaceholder.ParentNode

    foreach ($Rule in $Rules) {

        CheckJsonRule -PlaceholderKey $PlaceholderKey -BinDir $BinDir -Rule $Rule

        if ($PlaceholderKey -like "*PRODUCT*" -and (Test-Path -PathType leaf -Path $(Join-Path -Path $BinDir -ChildPath $Rule.Filepath))) {
            # Get the Publisher of the File
            $File = Get-ChildItem -LiteralPath $BinDir $Rule.Filepath
            $Publisher = (Get-AppLockerFileInformation $File.FullName).Publisher
        }

        # the Rule may not have a Publisher if it is not signed
        if ($null -eq $Publisher)
        {
            if ($PlaceholderKey -like "*PRODUCT*") {
                $Msg = "Unable to build '{0}' Rule based on signature for File '{1}' in '{2}' directory" -f $Rule.Action, $Rule.Filepath, $BinDir
                Write-Warning $Msg
            }
            $FileRule = CreateFilePathRule -xDocument $xDocument -Rule $Rule
            # Create a FilePathCondition element
            # <FilePathCondition FilePath="ngrok">
            $FileCondition = CreateFilePathCondition -xDocument $xDocument -directory $BinDir -Rule $Rule
        }
        else
        {
            $FileRule = CreateFilePublisherRule -xDocument $xDocument -Publisher $Publisher -Rule $Rule
            # Create a FilePublisherCondition element
            # <FilePublisherCondition BinaryName="*" ProductName="*" PublisherName="O=DROPBOX, INC, L=SAN FRANCISCO, S=CALIFORNIA, C=US">
            $FileCondition = CreateFilePublisherCondition -xDocument $xDocument -Publisher $Publisher -directory $BinDir -Rule $Rule

        }

        # If the binary is to be placed in an applocker exception
        # the structure in "else" is not required
        if ($Rule.isException) {
            $xPlaceholderParentNode.AppendChild($FileCondition) | Out-Null
        } else {
            $FileRule.SetAttribute("Action", $Rule.Action)
            $FileRule.SetAttribute("UserOrGroupSid", $Rule.UserOrGroupSid)
            $FileRule.SetAttribute("Id", ([guid]::NewGuid()).Guid)
            # Create a Conditions element
            # <Conditions>
            $Condition = $xDocument.CreateElement("Conditions")
            $Condition.AppendChild($FileCondition) | Out-Null
            $FileRule.AppendChild($Condition) | Out-Null
            # Add the Publisher Condition where the Placeholder is
            $xPlaceholderParentNode.AppendChild($FileRule) | Out-Null
        }
    }
    # Remove Placeholder elements
    $xPlaceholderParentNode.RemoveChild($xPlaceholder) | Out-Null
}

function ExportXmlRule {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $JsonConfigFile
    )
    # Export Rules to csv anc Excel
    $ConfigData = ReadJson $JsonConfigFile
    foreach ($Gpo in $ConfigData.PSObject.Properties) {
        $GpoName = $Gpo.Name
        $XmlOutFile = Join-Path -Path $OutDir -ChildPath ((Get-Date -Format "yyyyMMdd")+"_$GpoName.xml")
        $Msg = "** EXPORTING RULES '{0}' TO EXCEL **" -f $XmlOutFile
        Write-Verbose $Msg
        # SaveWorkbook : saves workbook to same directory as input
        # File with same File name and default Excel File extension
        & $ps1_ExportPolicyToExcel -AppLockerXml $XmlOutFile -SaveWorkbook
    }
}