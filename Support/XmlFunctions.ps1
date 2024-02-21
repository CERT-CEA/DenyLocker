####################################################################################################
# Xml stuff
####################################################################################################
function WriteXml {
    Param(
        [Parameter(Mandatory = $true)] [string] $binDir,
        [Parameter(Mandatory = $true)] $GPO,
        [Parameter(Mandatory = $true)] $xmlOutFile,
        [Parameter(Mandatory = $true)] $applockerXml   
    )
    # Write the XML created by CreateRule to a file

    #Read the xml template
    $xDocument = [xml](Get-Content $applockerXml)

    # Get the gpo name and its rules
    $gpoName = $GPO.Name
    $rules = $GPO.Value

    $msg = "Building Applocker GPO policy '{0}' to '{1}'" -f $gpoName, $xmlOutFile
    Write-Host $msg
    
    # Iterate over every EXE, MSI and SCRIPT rules
    foreach ($placeholder in $placeholders.Keys) {
        GenerateXmlRule -xDocument $xDocument -placeholderKey $placeholder -binDir $binDir -rules $rules[0].$placeholder
    }

    Write-Debug $xDocument.OuterXml

    # Save the applocker policy generated
    try {
        $masterPolicy = [Microsoft.Security.ApplicationId.PolicyManagement.PolicyModel.AppLockerPolicy]::FromXml($xDocument.OuterXml)
        SaveAppLockerPolicyAsUnicodeXml -ALPolicy $masterPolicy -xmlFilename $xmlOutFile
    } catch [System.Management.Automation.MethodInvocationException] {
        $msg = "The restulting xml file {0} is not valid. See the error below" -f $xmlOutFile
        Write-Warning $msg
        throw $_
    }
}

function GenerateXmlRule {
    Param(
        [Parameter(Mandatory = $true)] $xDocument,
        [Parameter(Mandatory = $true)] [ValidateScript( { $_ -in $placeholders.Keys } )] [string] $placeholderKey,
        [Parameter(Mandatory = $true)] [string] $binDir,
        [Parameter(Mandatory = $true)] [AllowEmptyCollection()] [array] $rules
    )
    # Create the resulting xml for a given rule
    
    $count_rules = ($rules|Measure-Object).Count
    if ($count_rules -gt 0) {
        $msg = "Building ruleCollection '{0}' rules" -f $placeholderKey
        Write-Host $msg
    } else {
        $msg = "No rules defined for {0}" -f $placeholderKey
        Write-Debug $msg
    }

    # Let's create an XML child
    $xPlaceholder = $xDocument.SelectNodes("//"+$placeholders.Item($placeholderKey))[0]
    $xPlaceholderParentNode = $xPlaceholder.ParentNode

    foreach ($rule in $rules) {

        CheckJsonRule -placeholderKey $placeholderKey -binDir $binDir -rule $rule

        if ($placeholderKey -like "*PRODUCT*" -and (Test-Path -PathType leaf -Path $(Join-Path -Path $binDir -ChildPath $rule.filepath))) {
            # Get the publisher of the file
            $file = Get-ChildItem -LiteralPath $binDir $rule.filepath
            $publisher = (Get-AppLockerFileInformation $file.FullName).Publisher
        }
    
        # the rule may not have a publisher if it is not signed
        if ($null -eq $publisher)
        {
            if ($placeholderKey -like "*PRODUCT*") {
                $msg = "Unable to build '{0}' rule based on signature for file '{1}' in '{2}' directory" -f $rule.action, $rule.filepath, $binDir
                Write-Warning $msg
            }
            $fileRule = CreateFilePathRule -xDocument $xDocument -rule $rule
            # Create a FilePathCondition element
            # <FilePathCondition FilePath="ngrok">
            $fileCondition = CreateFilePathCondition -xDocument $xDocument -directory $binDir -rule $rule
        }
        else
        {
            $fileRule = CreateFilePublisherRule -xDocument $xDocument -publisher $publisher -rule $rule
            # Create a FilePublisherCondition element   
            # <FilePublisherCondition BinaryName="*" ProductName="*" PublisherName="O=DROPBOX, INC, L=SAN FRANCISCO, S=CALIFORNIA, C=US">
            $fileCondition = CreateFilePublisherCondition -xDocument $xDocument -publisher $publisher -directory $binDir -rule $rule    
       
        }

        # If the binary is to be placed in an applocker exception
        # the structure in "else" is not required
        if ($rule.isException) {
            $xPlaceholderParentNode.AppendChild($fileCondition) | Out-Null
        } else {
            $fileRule.SetAttribute("Action", $rule.action)
            $fileRule.SetAttribute("UserOrGroupSid", $rule.UserOrGroupSid)
            $fileRule.SetAttribute("Id", ([guid]::NewGuid()).Guid)
            # Create a Conditions element
            # <Conditions>
            $condition = $xDocument.CreateElement("Conditions")
            $condition.AppendChild($fileCondition) | Out-Null
            $fileRule.AppendChild($condition) | Out-Null
            # Add the publisher condition where the placeholder is
            $xPlaceholderParentNode.AppendChild($fileRule) | Out-Null
        }
    }     
    # Remove placeholder elements
    $xPlaceholderParentNode.RemoveChild($xPlaceholder) | Out-Null   
}

function ExportXmlRule {
    Param(
        [Parameter(Mandatory = $true)] [string] $jsonConfigPath
    )
    # Export rules to csv anc Excel
    $configData = ReadJson $jsonConfigPath
    foreach ($GPO in $configData.PSObject.Properties) {
        $gpoName = $GPO.Name
        $xmlOutFile = Join-Path -Path $outDir -ChildPath ((Get-Date -Format "yyyyMMdd")+"_$gpoName.xml")
        
        $msg = "** EXPORTING RULES '{0}' TO EXCEL **" -f $xmlOutFile
        Write-Host $msg
        # SaveWorkbook : saves workbook to same directory as input 
        # file with same file name and default Excel file extension
        & $ps1_ExportPolicyToExcel -AppLockerXml $xmlOutFile -SaveWorkbook
    }
}