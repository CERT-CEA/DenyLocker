$supportDir = [System.IO.Path]::Combine($rootDir, "Support")
$defRulesXml = [System.IO.Path]::Combine($supportDir, "template.xml")

$ps1_ExportPolicyToCSV = [System.IO.Path]::Combine($supportDir, "ExportPolicy-ToCsv.ps1")
$ps1_ExportPolicyToExcel = [System.IO.Path]::Combine($supportDir, "ExportPolicy-ToExcel.ps1")

$placeholders = @{"EXE DENY" = "PLACEHOLDER_EXETODENY"; 
                "EXE ALLOW" = "PLACEHOLDER_EXETOALLOW";
                "EXE EXCEPTION" = "PLACEHOLDER_EXETODENY_EXCEPTION" ; 
                "MSI DENY" = "PLACEHOLDER_MSITODENY"; 
                "MSI ALLOW" = "PLACEHOLDER_MSITOALLOW";
                "MSI EXCEPTION" = "PLACEHOLDER_MSITODENY_EXCEPTION" ;}

$applockerRuleCollection = ('Exe','Script','MSI','Dll','Appx')