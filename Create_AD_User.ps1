$LINE_BREAK_DASHES="`n-------------------------------------------------------------------------------------`n"
#Copy AD User COMPANY->*New Staff to create new user

#required: FirstName, Last Name, Job Title, password, email address, 
#Mobile Phone number, DID Phone Number, Extension number

#connect pnp online - only do once, not in loop
$connect = Read-Host "On initial run in this powershell window type `"connect`" to connect to Microsoft Services. `n" `
				 "After initial run session will already be connected; press Enter to continue."
if ($connect -eq "connect") {
	Write-Output "Connecting to Microsoft SharepointOnline (Connect-Connect-PnPOnline)"
	Connect-PnPOnline -Url "https://COMPANY-admin.sharepoint.com" -DeviceLogin -LaunchBrowser
	Connect-Pnponline -url "https://COMPANY.sharepoint.com/sites/COMPANY-SPECIFIC-URL/" -useweblogin
	Write-Output "SharepointOnline connection established."	
	Write-Output "Connecting to Microsoft Teams. This may take up to 30 seconds. A Microsoft Sign-In dialog box will appear."
	Connect-MicrosoftTeams
	Write-Output "Microsoft Teams connection established."
}


#get csv filename from user
#function - getfilename via dialog box
function Get-FileName {	
		$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
		# InitialDirectory = [Environment]::GetFolderPath('Desktop') 
		Filter = 'CSV (*.csv)|*.csv'			
	}	
	$null = $OpenFileDialog.ShowDialog()
	$filename = $OpenFileDialog.filename	
    $filename
}
$filename = Read-Host "Please enter the .csv filename (just name, not `".csv`"). Leave blank to select with dialog box. May require pressing enter multiple times"
if (!$filename) {$filename = Get-FileName}
else {$filename = $filename+".csv"
}
Read-Host "`nSelected File: $filename.`nPress enter to confirm."
Write-Output "$LINE_BREAK_DASHES $LINE_BREAK_DASHES"

#Store the data from the CSV in the $ADOU variable. 
$DATA_SPREADSHEET = Import-csv $filename

foreach ($ROW in $DATA_SPREADSHEET) 
{
	#3CX Premptive Instructions, while creating CSV File
	Write-Output "IN 3CX, Create the user at the predetermined extension and assign the predetermined DID number.`n
	UNDER THE 'USERS' PANEL, CLICK THE 'GROUPS' OPTION, SELECT THE APPROPRIATE GROUP (their domain), AND ADD THE NEWLY CREATED USER TO THAT GROUP.`n"
	Read-Host "$LINE_BREAK_DASHES Press enter when complete"
	
	#paramater variables
	$templateUsername="nstaff"	
	$firstName=$ROW."First Name"
	$lastName=$ROW."Last Name"
	$userDomain=$ROW."Domain after @ symbol"
	$userDomain = "@$userDomain"
	$jobTitle=$ROW."Job Title"
	$telephoneDID = $ROW."Telephone DID (ex 1234567890)"
	$telephoneMobile=$ROW."Telephone Mobile"
	$extension=$ROW.Extension
	$password =$ROW.Password
	$securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force

	#generated variables
	$fullName = "$firstName $lastName"
	$newUsername = ($firstName[0]+$lastName).ToLower()
	$primaryEmail=$newUsername+$userDomain.ToLower()

	#get New Staff user template
	$templateUser = Get-ADUser -Identity $templateUsername 
	#create new user
	New-ADUser -SAMAccountName $newUsername  -Instance $templateUser `
	-DisplayName $fullName -Name $fullName -UserPrincipalName $primaryEmail `
	-AccountPassword $securePassword -GivenName $firstName -Surname $lastName `
	-Enabled $true -emailAddress $primaryEmail

	#move to correct OU
	switch ($userDomain) { #switch determine correct OU
		"@COMPANY1.com"{$ou="COMPANY1" $codeTwoGroupEmail="codetwo_enabled@COMPANY1.com"}
		"@COMPANY2.com"{$ou="COMPANY2" $codeTwoGroupEmail="codetwo_enabled@COMPANY2.com"}
		"@COMPANY3.com"{$ou="COMPANY3" $codeTwoGroupEmail="codetwo_enabled@COMPANY3.com"}
		"@COMPANY4.com"{$ou="COMPANY4" $codeTwoGroupEmail="codetwo_enabled@COMPANY4.com"}
		Default {$ou="COMPANY1"}
	}
	$newUser = Get-ADUser $newUsername -Properties *
	Move-ADObject -Identity $newUser.DistinguishedName -TargetPath "OU=$ou,DC=COMPANY,DC=com"
	
	#Copy AD Sec Group Membership from template to new user
	####.\Copy_AD_Group_Membership.ps1 $newUsername $templateUsername  ##Legacy, previously in other file
	$sourceUsername=$templateUsername
	$targetUsername=$newUsername
	foreach ($sourceUsername in $sourceUsernames){
		$CopyFromUser = Get-ADUser $sourceUsername -prop MemberOf
		foreach ($targetUsername in $targetUsernames) {		
			$CopyToUser = Get-ADUser $targetUsername -prop MemberOf
			$CopyFromUser.MemberOf | Where{$CopyToUser.MemberOf -notcontains $_} |  Add-ADGroupMember -Members $CopyToUser
		}
	}
	$createRDPandUpdateList = Read-Host "Enter 'no' to SKIP generating .rdp file and adding user info to 'Employee Tracker - Server Users' list."
	if (!($createRDPandUpdateList[0] -eq 'n')) {
		$createRDPandUpdateList=$true	
		#change CWD to scrip location 
		Push-Location $PSScriptRoot	
		#Generate RPD profile
		$content = Get-Content -Path 'Overture_RDS_REQUIRED-TEMPLATE.rdp'
		$newContent = $content -replace 'ADMIN', "$newUsername"
		$rdpFilename="Overture_RDS_$newUsername.rdp"
		$newContent | Set-Content -Path $rdpFilename
		#attach new RDP file to list user entry on Sharepoint; upload
		$attachments=@("$PSScriptRoot\$rdpFilename")
		function writeAttachment($item, $fileWithPath) {
			$ctx=Get-PnPContext
			$memoryStream = New-Object IO.FileStream($fileWithPath,[System.IO.FileMode]::Open)
			$fileName = Split-Path $fileWithPath -Leaf
			$attachInfo = New-Object -TypeName Microsoft.SharePoint.Client.AttachmentCreationInformation
			$attachInfo.FileName = $fileName
			$attachInfo.ContentStream = $memoryStream
			$attFile = $item.attachmentFiles.add($attachInfo)
			$ctx.load($attFile)
			$ctx.ExecuteQuery()
		}
		$items=Add-PnPListItem -List "Employee Tracker"
		$newListItem = Set-PnPListItem -Identity $Items.Id -List "Employee Tracker" `
		-Values @{"Title" = $firstName; `
			"field_1"=$lastName; "field_3"=$newUsername; "field_4"=$password; `
			"field_6"=$primaryEmail; "Ext"=$extension; "field_2"=$ou;"DID"=$telephoneDID; `
			"Created"=Get-Date
		}
		#Write-host " " $attachments[$a]
		writeAttachment -item $items -fileWithPath $attachments
		#return to previous CDW
		Pop-Location
		Write-host "RDP File Generated; User added to 'Employee Tracker - Server Users' list "
	}

	#add user to Supported Staff sec group
	Add-ADGroupMember -Identity "COMPANY_SEC_GROUP" -Members $newUsername

	#add proxy addresses if in LWI
	$newUser = Get-ADUser $newUsername -Properties *
	if ($ou -eq "COMPANY1")	{
		Set-ADUser $newUser -Add @{Proxyaddresses="smtp:"+$newUsername+"@COMPANY.onmicrosoft.com"}
		Set-ADUser $newUser -Add @{Proxyaddresses="SMTP:$primaryEmail"}
	}
	#add DID phone number if included in input
	if ($telephoneDID) {
		Set-ADUser $newUser -Add @{telephonenumber="+1$telephoneDID"}
		$homephone = $telephoneDID.insert(6,'.').insert(3,'.')
		Set-ADUser $newUser -HomePhone $homephone
	}
	if ($telephoneMobile) {
		$mobileNumber = $telephoneMobile.insert(6,'.').insert(3,'.')
		Set-ADUser $newUser -MobilePhone $mobileNumber
	}
	if ($extension) {
		Set-ADUser $newUser -Fax $extension
	}
	if ($jobTitle) {
		Set-ADUser $newUser -Title "$jobTitle"
		Set-ADUser $newUser -Description "$jobTitle"
	}
	
	
	#Confirm user creation
	Write-Output "$firstName $lastName ($emailAddress) user created in AD and O365" 
	if ($createRDPandUpdateList){
		Write-Output "$firstName $lastName ($emailAddress) added to 'COMPANY_LIST' list in 'COMPANY_SHAREPOINT_TEAMS_SITE"
		Write-Output "User's RDP file is now attached to their employee info in that list on Teams, and also located in the same directory as this script. $LINE_BREAK_DASHES"
	}		
	Write-Output "Apply the O365 license as/if indicated in the ticket. Standarp-Ops is 'COMPANY_SPECIFIC' license, MICROSOFT TEAMS STANDARD, MICROSOFT AUIDO CONFERENCING"
	Write-Output "Add users to any explicit AD security groups,O365 Groups, Shared Mailboxes, Dist. Lists etc. requested in ticket $LINE_BREAK_DASHES"	
	
}#END MAIN FOR LOOP


#ask wether to perform AD Delta Sync
$performDeltaSync = Read-Host "Enter 'yes' to perform a Active Directory Synchronization now."
if ($performDeltaSync[0] -eq 'y') {
	Start-ADSyncSyncCycle -PolicyType Delta
}

#Final Steps
Write-Output "FINAL STEPS _ NOT COMPLETED BY THIS SCRIPT"
Read-Host "$LINE_BREAK_DASHES Press enter to continue:"
Write-Output "Log on to DUO, Perform a duo-AzureAD-sync, find the new user(s) and set to 'Bypass' "
Read-Host "$LINE_BREAK_DASHES Press enter to continue:"

#TO-DO

	#append each user to a list during main loop containing their $codeTwoGroupEmail, primary email, DID, extension.
	
	#connect to exchange-onbline and add each user to their respective Code-Two group	
		# #### TO_DO - NEEDS TO BE AUTOMATED
		# Write-Output "TO_DO: Automate this section... Ensure the user is a member of the appropriate Code-2 MAIL-ENABLED-SECURITY GROUP in O365 admin portal:`n
		# The group will have the email address `"codetwo_enabled@`" and then the coice of domains - chose the one that applies to them."
		# Read-Host "$LINE_BREAK_DASHES Press enter to continue:"
		
	#export csv fie with necessary variables (primary email, DID, extension)for later use in seperate 
	#script that will batch update Teams-3cx sync. Cannot be completed at runtime due to sync delay

	

