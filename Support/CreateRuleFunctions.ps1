
function CreateFilePublisherCondition {
    Param(
        [Parameter(Mandatory = $true)] $xDocument,
        [Parameter(Mandatory = $true)] $publisher,
        [Parameter(Mandatory = $true)] [string] $directory,
        [Parameter(Mandatory = $true)] $rule
    )
    # Create a FilePublisherCondition element
    # <FilePublisherCondition PublisherName="O=MULLVAD VPN AB, L=GÖTEBORG, C=SE" ProductName="MULLVAD VPN" BinaryName="*">
    # <BinaryVersionRange LowSection="*" HighSection="*" />
    # This XML is used between <Exceptions> OR <FilePublisherRule>

    $filePublisherCondition = $xDocument.CreateElement("FilePublisherCondition")   
    if ($publisher.ProductName) {
        $msg = "Building '{0}' rule for group '{1}' for product '{2}' in '{3}' directory" -f $rule.action, $rule.UserOrGroup, $publisher.ProductName, $directory
    } else {
        $msg = "Building '{0}' rule for group '{1}' for filename '{2}' in '{3}' directory" -f $rule.action, $rule.UserOrGroup, $rule.filepath, $directory
    }
    Write-Host $msg -ForegroundColor Green

    $filePublisherCondition.SetAttribute("PublisherName", $publisher.PublisherName)
    
    if ($rule.ruleProduct -eq $true -and $publisher.ProductName) {
        $filePublisherCondition.SetAttribute("ProductName", $publisher.ProductName)
    } else {
        $filePublisherCondition.SetAttribute("ProductName", "*" )
    }

    if ($rule.ruleBinary -eq $true -and $publisher.BinaryName) {
        $filePublisherCondition.SetAttribute("BinaryName", $publisher.binarytodeny)
    } else {
        $filePublisherCondition.SetAttribute("BinaryName", "*" )
    }
    
    # Set version number range to "any"
    $elemVerRange = $xDocument.CreateElement("BinaryVersionRange")
    $elemVerRange.SetAttribute("LowSection", "*")
    $elemVerRange.SetAttribute("HighSection", "*")
    # Add the version range to the publisher condition
    $filePublisherCondition.AppendChild($elemVerRange) | Out-Null
    Return $filePublisherCondition
}

function CreateFilePathCondition {
    Param(
        [Parameter(Mandatory = $true)] $xDocument,
        [Parameter(Mandatory = $true)] [string] $directory,
        [Parameter(Mandatory = $true)] $rule
    )
    # Create a FilePathCondition element
    # <FilePathCondition Path="ngrok*.exe" />
    # This XML is used between <Exceptions> OR <FilePathRule>
    $filePathCondition = $xDocument.CreateElement("FilePathCondition")  
    if ($rule -like "*PRODUCT*") {
        $filename_wc = "*{0}*.exe" -f $rule.filepath.split('.')[0]
        $filePathCondition.SetAttribute("Path", $filename_wc)
        $msg = "Building '{0}' rule for group '{1}' for software '{2}' in '{3}' based on filename" -f $rule.action, $rule.UserOrGroup, $rule.filepath, $directory
        Write-Warning $msg
    
    } else {
        $filePathCondition.SetAttribute("Path", $rule.filepath)
        $msg = "Building '{0}' rule for group '{1}' for path '{2}'" -f $rule.action, $rule.UserOrGroup, $rule.filepath
        Write-Host $msg -ForegroundColor Green
    }  

    Return $filePathCondition
}

function CreateFilePublisherRule {
    Param(
        [Parameter(Mandatory = $true)] $xDocument,
        [Parameter(Mandatory = $true)] $publisher,
        [Parameter(Mandatory = $true)] $rule
    )
    # Create a FilePublisherRule element
    # <FilePublisherRule Action="Deny" UserOrGroupSid="S-1-1-0" Description="" Name="DropBox">
    #   <Conditions>
    #      ...
    #   </Conditions>
    # </FilePublisherRule>
    $fileRule = $xDocument.CreateElement("FilePublisherRule")

    if ($publisher.ProductName) {
        $fileRule.SetAttribute("Description", $rule.action + " " + $rule.UserOrGroup + " " + $publisher.ProductName)
        $fileRule.SetAttribute("Name", $rule.action + " " + $rule.UserOrGroup + " " + $publisher.ProductName)
    } else {
        $fileRule.SetAttribute("Description", $rule.action + " " + $rule.UserOrGroup + " " + $rule.filepath)
        $fileRule.SetAttribute("Name", $rule.action + " " + $rule.UserOrGroup + " " + $rule.filepath)
    }
    Return $fileRule
}

function CreateFilePathRule {
    Param(
        [Parameter(Mandatory = $true)] $xDocument,
        [Parameter(Mandatory = $true)] $rule
    )
    # Create a FilePathRule element
    # <FilePathRule Action="Deny" UserOrGroupSid="S-1-1-0" Description="" Name="DropBox">
    #      ...
    # </FilePathRule>
    $fileRule = $xDocument.CreateElement("FilePathRule")
    $fileRule.SetAttribute("Description", $rule.action + " " + $rule.UserOrGroup + " " + $rule.filepath)
    $fileRule.SetAttribute("Name", $rule.action + " " + $rule.UserOrGroup + " " + $rule.filepath)
    Return $fileRule
}