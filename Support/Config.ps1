$supportDir = [System.IO.Path]::Combine($rootDir, "Support")

$ps1_ExportPolicyToCSV = [System.IO.Path]::Combine($supportDir, "ExportPolicy-ToCsv.ps1")
$ps1_ExportPolicyToExcel = [System.IO.Path]::Combine($supportDir, "ExportPolicy-ToExcel.ps1")

$placeholders = @{"EXE PRODUCT DENY" = "PLACEHOLDER_EXE_PRODUCT_DENY"; 
                "EXE PRODUCT ALLOW" = "PLACEHOLDER_EXE_PRODUCT_ALLOW";
                "EXE PRODUCT DENY EXCEPTION" = "PLACEHOLDER_EXE_PRODUCT_DENY_EXCEPTION" ;

                "EXE PATH DENY" = "PLACEHOLDER_EXE_PATH_DENY"; 
                "EXE PATH ALLOW" = "PLACEHOLDER_EXE_PATH_ALLOW"; 
                "EXE PATH DENY EXCEPTION" = "PLACEHOLDER_EXE_PATH_DENY_EXCEPTION";

                "MSI PRODUCT DENY" = "PLACEHOLDER_MSI_PRODUCT_DENY"; 
                "MSI PRODUCT ALLOW" = "PLACEHOLDER_MSI_PRODUCT_ALLOW";
                "MSI PRODUCT DENY EXCEPTION" = "PLACEHOLDER_MSI_PRODUCT_DENY_EXCEPTION" ;

                "MSI PATH DENY" = "PLACEHOLDER_MSI_PATH_DENY"; 
                "MSI PATH ALLOW" = "PLACEHOLDER_MSI_PATH_ALLOW";
                "MSI PATH DENY EXCEPTION" = "PLACEHOLDER_MSI_PATH_DENY_EXCEPTION" ;

                "SCRIPT PATH DENY" = "PLACEHOLDER_SCRIPT_PATH_DENY";
                "SCRIPT PATH ALLOW" = "PLACEHOLDER_SCRIPT_PATH_ALLOW";
                "SCRIPT PATH DENY EXCEPTION" = "PLACEHOLDER_SCRIPT_PATH_DENY_EXCEPTION";}

$applockerRuleCollection = ('Exe','Script','MSI','Dll','Appx')