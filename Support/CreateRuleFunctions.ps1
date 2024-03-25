
function CreateFilePublisherCondition {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] $xDocument,
        [Parameter(Mandatory = $true)] $Publisher,
        [Parameter(Mandatory = $true)] [string] $Directory,
        [Parameter(Mandatory = $true)] $Rule
    )
    # Create a FilePublisherCondition element
    # <FilePublisherCondition PublisherName="O=MULLVAD VPN AB, L=GÖTEBORG, C=SE" ProductName="MULLVAD VPN" BinaryName="*">
    # <BinaryVersionRange LowSection="*" HighSection="*" />
    # This XML is used between <Exceptions> OR <FilePublisherRule>

    $FilePublisherCondition = $xDocument.CreateElement("FilePublisherCondition")
    if ($Rule.isException) {
        if ($Publisher.ProductName) {
            $Msg = "Building 'AllowExcept {1}' Rule for product '{2}' currently in '{3}' Directory" -f $Rule.Action, $Rule.UserOrGroup, $Publisher.ProductName, $Directory
        } else {
            $Msg = "Building 'AllowExcept {1}' Rule for filename '{2}' currently in '{3}' Directory" -f $Rule.Action, $Rule.UserOrGroup, $Rule.Filepath, $Directory
        }
    } else {
        if ($Publisher.ProductName) {
            $Msg = "Building '{0}' Rule for group '{1}' for product '{2}' currently in '{3}' Directory" -f $Rule.Action, $Rule.UserOrGroup, $Publisher.ProductName, $Directory
        } else {
            $Msg = "Building '{0}' Rule for group '{1}' for filename '{2}' currently in '{3}' Directory" -f $Rule.Action, $Rule.UserOrGroup, $Rule.Filepath, $Directory
        }
    }
    Write-Verbose $Msg

    $FilePublisherCondition.SetAttribute("PublisherName", $Publisher.PublisherName)

    if ($Rule.RuleProduct -eq $true -and $Publisher.ProductName) {
        $FilePublisherCondition.SetAttribute("ProductName", $Publisher.ProductName)
    } else {
        $FilePublisherCondition.SetAttribute("ProductName", "*" )
    }

    if ($Rule.RuleBinary -eq $true -and $Publisher.BinaryName) {
        $FilePublisherCondition.SetAttribute("BinaryName", $Publisher.BinaryToDeny)
    } else {
        $FilePublisherCondition.SetAttribute("BinaryName", "*" )
    }

    # Set version number range to "any"
    $ElemVerRange = $xDocument.CreateElement("BinaryVersionRange")
    $ElemVerRange.SetAttribute("LowSection", "*")
    $ElemVerRange.SetAttribute("HighSection", "*")
    # Add the version range to the Publisher condition
    $FilePublisherCondition.AppendChild($ElemVerRange) | Out-Null
    Return $FilePublisherCondition
}

function CreateFilePathCondition {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] $xDocument,
        [Parameter(Mandatory = $true)] [string] $Directory,
        [Parameter(Mandatory = $true)] $Rule
    )
    # Create a FilePathCondition element
    # <FilePathCondition Path="ngrok*.exe" />
    # This XML is used between <Exceptions> OR <FilePathRule>
    $FilePathCondition = $xDocument.CreateElement("FilePathCondition")
    if ($Rule -like "*PRODUCT*") {
        $FilenameWildcard = "*{0}*.exe" -f $Rule.Filepath.split('.')[0]
        $FilePathCondition.SetAttribute("Path", $FilenameWildcard)
        if ($Rule.isException) {
            $Msg = "Building 'AllowExcept {1}' Rule for software '{2}' in '{3}' based on filename" -f $Rule.Action, $Rule.UserOrGroup, $Rule.Filepath, $Directory
        } else {
            $Msg = "Building '{0}' Rule for group '{1}' for software '{2}' in '{3}' based on filename" -f $Rule.Action, $Rule.UserOrGroup, $Rule.Filepath, $Directory
        }
        if ($Verbose) {
            Write-Warning $Msg
        }

    } else {
        $FilePathCondition.SetAttribute("Path", $Rule.Filepath)
        if ($Rule.isException) {
            $Msg = "Building 'AllowExcept {1}' Rule for path '{2}'" -f $Rule.Action, $Rule.UserOrGroup, $Rule.Filepath
        } else {
            $Msg = "Building '{0}' Rule for group '{1}' for path '{2}'" -f $Rule.Action, $Rule.UserOrGroup, $Rule.Filepath
        }
        Write-Verbose $Msg
    }

    Return $FilePathCondition
}

function CreateFilePublisherRule {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] $xDocument,
        [Parameter(Mandatory = $true)] $Publisher,
        [Parameter(Mandatory = $true)] $Rule
    )
    # Create a FilePublisherRule element
    # <FilePublisherRule Action="Deny" UserOrGroupSid="S-1-1-0" Description="" Name="DropBox">
    #   <Conditions>
    #      ...
    #   </Conditions>
    # </FilePublisherRule>
    $FileRule = $xDocument.CreateElement("FilePublisherRule")

    if ($Publisher.ProductName) {
        $FileRule.SetAttribute("Description", $Rule.Action + " " + $Rule.UserOrGroup + " " + $Publisher.ProductName)
        $FileRule.SetAttribute("Name", $Rule.Action + " " + $Rule.UserOrGroup + " " + $Publisher.ProductName)
    } else {
        $FileRule.SetAttribute("Description", $Rule.Action + " " + $Rule.UserOrGroup + " " + $Rule.Filepath)
        $FileRule.SetAttribute("Name", $Rule.Action + " " + $Rule.UserOrGroup + " " + $Rule.Filepath)
    }
    Return $FileRule
}

function CreateFilePathRule {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] $xDocument,
        [Parameter(Mandatory = $true)] $Rule
    )
    # Create a FilePathRule element
    # <FilePathRule Action="Deny" UserOrGroupSid="S-1-1-0" Description="" Name="DropBox">
    #      ...
    # </FilePathRule>
    $FileRule = $xDocument.CreateElement("FilePathRule")
    $FileRule.SetAttribute("Description", $Rule.Action + " " + $Rule.UserOrGroup + " " + $Rule.Filepath)
    $FileRule.SetAttribute("Name", $Rule.Action + " " + $Rule.UserOrGroup + " " + $Rule.Filepath)
    Return $FileRule
}