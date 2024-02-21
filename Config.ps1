$defRulesXml = [System.IO.Path]::Combine($rootDir, "template.xml")
$rulesFileEnforceNew = [System.IO.Path]::Combine($rootDir, $OutFile)

$everyoneProductToDenyDir = [System.IO.Path]::Combine($rootDir, "everyoneProductToDeny")
$everyoneBinaryToDenyDir = [System.IO.Path]::Combine($rootDir, "everyoneBinaryToDeny")

$adminProductToDenyDir = [System.IO.Path]::Combine($rootDir, "adminProductToDeny")

$anyProductToDenyExceptionDir = [System.IO.Path]::Combine($rootDir, "anyProductToDenyException")

$placeholders = @{"EXE DENY" = "PLACEHOLDER_EXETODENY"; "MSI DENY" = "PLACEHOLDER_MSITODENY"; "EXE EXCEPTION" = "PLACEHOLDER_EXETODENY_EXCEPTION"}

$applockerRuleCollection = ('Exe','Script','MSI','Dll','Appx')

# Génére les paramètres de la règle de blocage pour chaque dossier
# everyoneProductToDeny : bloque le publishier et le produit pour Everyone
# everyoneBinaryToDeny : inutilisé
# adminProductToDeny : bloque seulement le binaire donné pour les membres du groupe Administrators
# anyProductToDenyException : bloque seulement le produit donné pour Everyone, mais le produit peut être autorisé dans une règle Allow par ailleurs

$everyoneProductToDenyRule = New-Object PSObject
$everyoneProductToDenyRule |Add-Member Noteproperty rulePublisher $true
$everyoneProductToDenyRule |Add-Member Noteproperty ruleProduct $true
$everyoneProductToDenyRule |Add-Member Noteproperty directory $everyoneProductToDenyDir
$everyoneProductToDenyRule |Add-Member Noteproperty action "Deny"
$everyoneProductToDenyRule |Add-Member Noteproperty UserOrGroupSid "S-1-1-0"
$everyoneProductToDenyRule |Add-Member Noteproperty UserOrGroup "Everyone"

$everyoneBinaryToDenyRule = New-Object PSObject
$everyoneBinaryToDenyRule |Add-Member Noteproperty rulePublisher $true
$everyoneBinaryToDenyRule |Add-Member Noteproperty ruleProduct $true
$everyoneBinaryToDenyRule |Add-Member Noteproperty denyBinary $true
$everyoneBinaryToDenyRule |Add-Member Noteproperty directory $everyoneBinaryToDenyDir
$everyoneBinaryToDenyRule |Add-Member Noteproperty action "Deny"
$everyoneBinaryToDenyRule |Add-Member Noteproperty UserOrGroupSid "S-1-1-0"
$everyoneBinaryToDenyRule |Add-Member Noteproperty UserOrGroup "Everyone"

$adminProductToDenyRule = New-Object PSObject
$adminProductToDenyRule |Add-Member Noteproperty rulePublisher $true
$adminProductToDenyRule |Add-Member Noteproperty ruleProduct $true
$adminProductToDenyRule |Add-Member Noteproperty directory $adminProductToDenyDir
$adminProductToDenyRule |Add-Member Noteproperty action "Deny"
$adminProductToDenyRule |Add-Member Noteproperty UserOrGroupSid "S-1-5-32-544"
$adminProductToDenyRule |Add-Member Noteproperty UserOrGroup "Administrators"

$allowExceptDenyRule  = New-Object PSObject
$allowExceptDenyRule |Add-Member Noteproperty rulePublisher $true
$allowExceptDenyRule |Add-Member Noteproperty ruleProduct $true
$allowExceptDenyRule  |Add-Member Noteproperty directory $anyProductToDenyExceptionDir
$allowExceptDenyRule  |Add-Member Noteproperty action "Allow"
$allowExceptDenyRule  |Add-Member Noteproperty UserOrGroupSid "S-1-1-0"
$allowExceptDenyRule  |Add-Member Noteproperty UserOrGroup "Everyone"

$denyRules = ($everyoneProductToDenyRule, $everyoneBinaryToDenyRule, 
                        $adminProductToDenyRule)