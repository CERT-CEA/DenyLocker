$defRulesXml = [System.IO.Path]::Combine($rootDir, "template.xml")
$rulesFileEnforceNew = [System.IO.Path]::Combine($rootDir, "output.xml")

$publisherToDeny = [System.IO.Path]::Combine($rootDir, "publishertodenytest")
$productToDeny = [System.IO.Path]::Combine($rootDir, "producttodenytest")
$binaryToDeny = [System.IO.Path]::Combine($rootDir, "binarytodeny")

$exeToDenyDirectories = ($publisherToDeny, $productToDeny, $binaryToDeny)