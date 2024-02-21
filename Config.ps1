$defRulesXml = [System.IO.Path]::Combine($rootDir, "template.xml")
$rulesFileEnforceNew = [System.IO.Path]::Combine($rootDir, $OutFile)

$everyonePublisherToDenyDir = [System.IO.Path]::Combine($rootDir, "everyonePublisherToDenyTest")
$everyoneProductToDenyDir = [System.IO.Path]::Combine($rootDir, "everyoneProductToDenyTest")
$everyoneBinaryToDenyDir = [System.IO.Path]::Combine($rootDir, "everyoneBinaryToDenyTest")

$adminProductToDenyDir = [System.IO.Path]::Combine($rootDir, "adminProductToDenyTest")

$anyProductToDenyExceptionDir = [System.IO.Path]::Combine($rootDir, "anyProductToDenyExceptionTest")

# Génére les paramètres de la règle de blocage pour chaque dossier
# everyonePublisherToDeny : bloque tous les exécutables du publisher du binaire pour Everyone
# everyoneProductToDeny : bloque seulement le produit donné pour Everyone
# everyoneBinaryToDeny : inutilisé
# adminProductToDeny : bloque seulement le binaire donné pour les membres du groupe Administrators
# anyProductToDenyException : bloque seulement le produit donné pour Everyone, mais le produit peut être autorisé dans une règle Allow par ailleurs

$everyonePublisherToDenyRule = New-Object PSObject
$everyonePublisherToDenyRule |Add-Member Noteproperty denyPublisher $true
$everyonePublisherToDenyRule |Add-Member Noteproperty directory $everyonePublisherToDenyDir
$everyonePublisherToDenyRule |Add-Member Noteproperty action "Deny"
$everyonePublisherToDenyRule |Add-Member Noteproperty UserOrGroupSid "S-1-1-0"
$everyonePublisherToDenyRule |Add-Member Noteproperty UserOrGroup "Everyone"

$everyoneProductToDenyRule = New-Object PSObject
$everyoneProductToDenyRule |Add-Member Noteproperty denyPublisher $true
$everyoneProductToDenyRule |Add-Member Noteproperty denyProduct $true
$everyoneProductToDenyRule |Add-Member Noteproperty directory $everyoneProductToDenyDir
$everyoneProductToDenyRule |Add-Member Noteproperty action "Deny"
$everyoneProductToDenyRule |Add-Member Noteproperty UserOrGroupSid "S-1-1-0"
$everyoneProductToDenyRule |Add-Member Noteproperty UserOrGroup "Everyone"

$everyoneBinaryToDenyRule = New-Object PSObject
$everyoneBinaryToDenyRule |Add-Member Noteproperty denyPublisher $true
$everyoneBinaryToDenyRule |Add-Member Noteproperty denyProduct $true
$everyoneBinaryToDenyRule |Add-Member Noteproperty denyBinary $true
$everyoneBinaryToDenyRule |Add-Member Noteproperty directory $everyoneBinaryToDenyDir
$everyoneBinaryToDenyRule |Add-Member Noteproperty action "Deny"
$everyoneBinaryToDenyRule |Add-Member Noteproperty UserOrGroupSid "S-1-1-0"
$everyoneBinaryToDenyRule |Add-Member Noteproperty UserOrGroup "Everyone"

$adminProductToDenyRule = New-Object PSObject
$adminProductToDenyRule |Add-Member Noteproperty denyPublisher $true
$adminProductToDenyRule |Add-Member Noteproperty denyProduct $true
$adminProductToDenyRule |Add-Member Noteproperty directory $adminProductToDenyDir
$adminProductToDenyRule |Add-Member Noteproperty action "Deny"
$adminProductToDenyRule |Add-Member Noteproperty UserOrGroupSid "S-1-5-32-544"
$adminProductToDenyRule |Add-Member Noteproperty UserOrGroup "Administrators"

$allowExceptDenyRule  = New-Object PSObject
$allowExceptDenyRule  |Add-Member Noteproperty directory $anyProductToDenyExceptionDir
$allowExceptDenyRule  |Add-Member Noteproperty action "Allow"
$allowExceptDenyRule  |Add-Member Noteproperty UserOrGroupSid "S-1-1-0"
$allowExceptDenyRule  |Add-Member Noteproperty UserOrGroup "Everyone"

$denyRules = ($everyonePublisherToDenyRule, $everyoneProductToDenyRule, $everyoneBinaryToDenyRule, 
                        $adminProductToDenyRule)