# Overview
Deploying Applocker in AllowList is a struggle. But it provides so much value with its log, it would be absurd not to use it. That's why we developped DenyLocker.
DenyLocker is designed to make the creation and maintenance of Applocker rules in DenyList as easy and practical as possible. It only involves a few Powershell scripts.

The main goal is to block virus, not a sneak red-teamer by :
- blocking forbidden sofware in your company (Tor, remote access software etc.)
- blocking any execution on removable device, ISO etc.
- logging every EXE, MSI, SCRIPT AND MSIX execution 

# Requirements
Powershell ActiveDirectory Module if you don't want to manually enter every object SID in your json file. Their SID can be automatically resolved based on their name.

## Rules architecture
Let's say you want the following policy :
- App1 and App2 are forbidden, except for some security groups : GroupA and GroupB
- App3 is forbidden, with no exception

We would need 4 rules :
- Rule 1 : Denies App3 execution for Everyone
- Rule 2 : Allows Everyone to execution anything, execept App1 and App2
- Rule 3 : Allows GroupA to execution App1
- Rule 4 : Allows GroupB to execution App2

Some rules to clarify the preceding one :
- Rule 5 : Rule 1 is applied before this rule, because Deny rules are applied before Allow rules. App3 can not be executed by anyone.
- Rule 6 : Implicit Applocker Deny Rule. Any user not a member of GroupA and B can not execute App1 and App2.

The result is :
| Rule number   | RuleName             | Policy        | App           | Group         | Exception     |
| ------------- | -------------------- | ------------- | ------------- | ------------- | ------------- |
| 1             | Block Everyone App3  | Deny          | App3          | Everyone      |               |
| 2             | Allow Everyone Any   | Allow         | *             | Everyone      | App1, App2    |
| 3             | Allow GroupA App1    | Allow         | App1          | GroupA        |               |
| 4             | Allow GroupB App2    | Allow         | App2          | GroupB        |               |
| 5             | Allow Everyone App3  | Allow         | App3          | Everyone      |               |
| 6             | Implicit Deny Rule   | Deny          | *             | *             |               |

## Usage
DenyLocker will build a valid Applocker XML file from a json config file :

```powershell
PS > .\DenyLocker.ps1  -CreateRules -TestRules -ExportRules -JsonConfigFile .\config.json -Verbose
…
Building Applocker Gpo policy 'GPOApplocker' to 'C:\Users\github\Documents\DenyLocker\output\20240202_GPOApplocker.xml'
…
Building RuleCollection 'EXE PRODUCT DENY EXCEPTION' Rule
Building 'Allow' Rule for group 'AllowFirefox' for product 'FIREFOX' in 'C:\Users\github\Documents\DenyLocker\binaries' Directory
```

The resulting rules will be tested :
```powershell
** TESTING RULES from 'C:\Users\github\Documents\DenyLocker\output\20240202_GPOApplocker.xml'
…
'C:\Users\github\Documents\DenyLocker\binaries\Firefox.exe' is 'Allowed' for 'AllowFirefox' by ''Allow AllowFirefox FIREFOX''
'C:\Users\github\Documents\DenyLocker\binaries\Firefox.exe' is 'DeniedByDefault' for 'Everyone' due to an exception
…
```

And saved as an xlsx :
```powershell
** EXPORTING RULES 'C:\Users\github\Documents\DenyLocker\output\20240202_GPOApplocker.xml' TO EXCEL **
Populating tab "20240202_GPOApplocker"...
Saving workbook as "C:\Users\github\Documents\DenyLocker\output\20240202_GPOApplocker.xlsx"...
```

### Import the rules in a GPO

Replace ATTACKRANGE.LOCAL with your domain :
```powershell
PS > $GPOApplocker="LDAP://ATTACKRANGE.LOCAL/CN={{{0}}},CN=Policies,CN=System,DC=attackrange,DC=local" -f $(Get-GPO "GPOApplocker").Id
PS > Set-AppLockerPolicy -XmlPolicy '.\20240202_GPOApplocker.xml' -Ldap $GPOApplocker
```

## Config

The config fields are explained in the `readme-config.json` file. You can use `Support/empty.json` to start your conf from scratch. Check also `example-config.json` for some more examples.

The following list can be configured (Apply to MSI and SCRIPT as well):
* `EXE|MSI|SCRIPT PRODUCT DENY` : EXE/MSI/SCRIPT file added will be denied for the group you specify, based on their signature
* `EXE|MSI|SCRIPT PRODUCT ALLOW` : EXE/MSI/SCRIPT file added will be allowed for the group you specify, based on their signature
* `EXE|MSI|SCRIPT PRODUCT DENY WITH EXCEPTION` : EXE/MSI/SCRIPT filepath added will be denied if you do not specify an allow rule in `EXE|MSI|SCRIPT PRODUCT ALLOW`
* `EXE|MSI|SCRIPT PATH ALLOW` : EXE/MSI/SCRIPT file added will be denied for the group you specify, based on their filepath
* `EXE|MSI|SCRIPT PATH DENY` : EXE/MSI/SCRIPT file added will be allowed for the group you specify, based on their filepath
* `EXE|MSI|SCRIPT PATH DENY WITH EXCEPTION` : EXE/MSI/SCRIPT filepath added will be denied if you do not specify an allow rule in `EXE|MSI|SCRIPT PATH ALLOW`

Some fields are mandatory :
* `FilePath`: filepath to the file you want to allow or block.
* `UserOrGroup`: Name of the user or group that should be allowed or denied to execute FilePath.
* `UserOrGroupSID`: SID of the user or group that should be allowed or denied to execute FilePath.
* `RulePublisher`: Only for `* PRODUCT DENY` rules. True if filepath should be allowed/denied based on their Publisher.
* `RuleProduct`: Only for `* PRODUCT DENY` rules. True if filepath should be allowed/denied based on their ProductName.
* `RuleBinary`: Only for `* PRODUCT DENY` rules. True if filepath should be allowed/denied based on their BinaryName.
* `Action`: Possible value : Allow or Deny.
* `isException`: Only for `* PATH DENY WITH EXCEPTION` rules. Possible value : True.

### example-config.json
This config files defines 2 GPO :
* ApplockerGPO
* ApplockerGPOAdminDenyInternet

You can note that the two GPO have the same path exceptions in `EXE|MSI|SCRIPT PATH DENY WITH EXCEPTION`. That way they can both be applied without cancelling each other. See the explanation in the Advices below.

ApplockerGPO goals :
- Allow anything except some well known problematic directories, removable drives (%HOT%) and CD/DVD/ISO (%REMOVABLE%).
- Deny the execution of some sofware with no exception : Brave, TorBrower, commercial VPN...
- Deny the execution of some sofware with some exception : Wireguard, TeamViewer, firefox...

ApplockerGPOAdminDenyInternet goals :
- Deny Administrators to execute anything related to internet : outlook, web browsers

## Advices

### Do not define multiple `Allow Everyone any except` rules
Allow rules are applied simultaneously, but the exception they define do not block their execution. Therefore, multiple rules "Allow Everyone any except" could cancel each other.
Let's have 2 rules:
- Rule 1 : Allow Everyone any except App1
- Rule 2 : Allow Everyone any except App2
Rule 1 wants to block App1 using the implicit rule. But rule 2 allow any except App2, therefore it allow App1.
Same thing with Rule2, App2 should be denied but Rule1 allows it.

This case could happen when using multiple GPO since Applocker rules are added to each other, not replaced.

| Rule number   | RuleName             | Policy        | App           | Group         | Exception     |
| ------------- | -------------------- | ------------- | ------------- | ------------- | ------------- |
| 1             | Allow Everyone Any   | Allow         | *             | Everyone      | App1          |
| 2             | Allow Everyone Any   | Allow         | *             | Everyone      | App2          |

### Be careful with allow rules on PATH
Let's have 2 rules:
- Rule 1 : Allow Everyone %PROGRAMFILES%
- Rule 2 : Allow Everyone any except App2

If App2 is installed in %PROGRAMFILES%, which is quite common, its execution will be allowed by Rule 1.

| Rule number   | RuleName                      | Policy        | App           | Group         | Exception     |
| ------------- | ----------------------------- | ------------- | ------------- | ------------- | ------------- |
| 1             | Allow Everyone PROGRAMFILES   | Allow         | *             | Everyone      |           |
| 2             | Allow Everyone Any            | Allow         | *             | Everyone      | App2          |

### Rule names
Rule names appear in the field RuleName of your event log. So don't choose them too long.

# Credits
AaronLocker : https://github.com/microsoft/AaronLocker