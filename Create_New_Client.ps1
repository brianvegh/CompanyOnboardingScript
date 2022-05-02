# Global Boolean to Require Input Between Each Grouo
$REQUIRE_INPUT_BETWEEN_GROUPS = $true

###REQUIRED MODULES:
###Import-Module activedirectory
###Install-Module -Name ExchangeOnlineManagement
###Install-Module -Name Az.Resources -RequiredVersion 3.5.0
###Install-Module MicrosoftTeams



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
#function - return current date formatted MM/DD/YYYY
function Get-DateFormatted {
	$date = Get-Date -Format "MM/dd/yyyy"
	$date
}
#function - ask if user wants to exit program
function Check-ifExit {
	$continue = Read-Host "Enter any key to continue. Enter X to exit"
	if ('x' -ieq $continue){
	Write-Output "X pressed. Goodbye"
	exit
	}
}
#function - connect to ExchangeOnline, AzureAD and MicrosoftTeams
function Connect-Microsoft-Services {
	#Connecting to Microsoft ExchangeOnline
	Write-Output "Connecting to Microsoft ExchangeOnline (Connect-ExchangeOnline)"
	Connect-ExchangeOnline
	Write-Output "ExchangeOnline connection established."
	#Connecting to Microsoft AzureAD
	Write-Output "Connecting to Microsoft AzurePowershell (ConnectAZAccount)"
	Connect-AzAccount
	Write-Output "AzurePowershell connection established."
	#Connecting to Microsoft Teams
	Write-Output "Connecting to Microsoft Teams (Connect-MicrosoftTeams)"
	Connect-MicrosoftTeams	
	Write-Output "MicrosoftTeams connection established."
}

#run function to connect Microsoft Services
Connect-Microsoft-Services
	
#get csv filename from user
$filename = Read-Host "Please enter the .csv filename (just name, not `".csv`"). Leave blank to select with dialog box. May require pressing enter multiple times"
if (!$filename) {$filename = Get-FileName}
else {$filename = $filename+".csv"
}
Read-Host "`nSelected File: $filename.`nPress enter to confirm."

#Store the data from the CSV in the $ADOU variable. 
$DATA_SPREADSHEET = Import-csv $filename


#START MAIN FOR LOOP
#Loop through each row containing user details in the CSV file
foreach ($ROW in $DATA_SPREADSHEET) 
{	
	#Read data from each field in each row and assign the data to a variable as below
	$name = $ROW.name -replace "[`#,+`"\<>;,]" 		#Active Directory Name (removes unwanted character)
	$path = $ROW.path		#AD path ex: "OU=COM_OU,DC=COMPANYDC,DC=Com"
	$displayName = $ROW.displayName -replace "[.,]"		#O365 Group Name
	$alias = $ROW."alias(emailAddress)"		#O36 Group primary email before the @ symbol(no spaces)
	$alias = $alias -replace "[`#,.``'+`"\<>;,&`\s]" #remove & symbols, spaces, commas, periods, apostrophes
	#review variables to confirm correct
	Write-Output "`$name = $name`n`$path = $path `n`$displayName = $displayName `n`$alias = $alias"
	Read-Host "Create Group(s)?"

	#START Active Directory nested OU & Security Group Creation
	#Active Directory Account will be created in the OU provided by the $OU variable read from the CSV file
	New-ADOrganizationalUnit `
	-Name $name `
	-path $path `
	-ProtectedFromAccidentalDeletion $True
	#Active Directory Create new Security Group
	$secGroupName = $name+" - COMPANY"
	$secGroupName = $secGroupName -replace "[`#,'+`"\<>;,]"
	$path2="OU="+$name+",OU=COM_OU,DC=COMPANYDC,DC=com"
	Write-Output $path2
	New-ADGroup `
	-Name $secGroupName `
	-SamAccountName $secGroupName `
	-GroupCategory Security `
	-GroupScope Global `
	-DisplayName $secGroupName `
	-Path $path2 `
	-Description "Created on 1/8/2022"
	#END AD and sec group creation
	
	#START set variables for O365 and Teams
	Set-PSDebug -Trace 1
	$primarySmtpAddress = $alias+"@COPMPANY1.com"
	$emailAddresses = "SMTP:"+$primarySmtpAddress
	$accessType = "Private"
	$autoSubscribeNewMembers = $true 
	$requireSenderAuthenticationEnabled = $false	#allow revieve from outside senders
	$members = $row.members_commaDelimited -split ","  #split line based on commas
    $dateFormatted= Get-DateFormatted
	$notes = $name+", "+$dateFormatted	#descriptiom
	$owner = "ADMINUSER@COMPANY1.com" 
	Set-PSDebug -Trace 0
	#END set variables for O365 and Teams

	#START create O365 group
	 New-UnifiedGroup `
	-DisplayName $displayName `
	-Alias $alias `
	-EmailAddresses $emailAddresses `
	-PrimarySmtpAddress $primarySmtpAddress `
	-AccessType $accessType `
	-AutoSubscribeNewMembers $autoSubscribeNewMembers `
	-RequireSenderAuthenticationEnabled $requireSenderAuthenticationEnabled `
	-Members $members `
	-Notes $notes `
	-Owner $owner 
	#END create O365 Group
	
	#START create a Team for the group just created
	$counter=0
	$continueLoop=$true
	while ($continueLoop){	
		$displayName = "$displayName"
		$azureGroupId = Get-AzADGroup -DisplayName $displayName
		$azureGroupId = $azureGroupId.Id		
		if ($counter -eq 5) {
			Write-Output "$displayName rteam creation failure - Azure Group ID generation timeout."
			continue
		}
		if ($azureGroupId) {
			New-Team -Group $azureGroupId	#Create the team after GUID is not empty
			Read-Host "Confirm Teams Creation for current group $displayName - $azureGroupId"
			$continueLoop=$false
		} else {
			Write-Output "Group ID not ready yet. Retrying in three seconds `(attempt $counter/5`)"
			Start-Sleep -Seconds 3
		}
		$counter++
	}
	
	#END O365 GROUP CREATION


#loop to exit if desired
if ($REQUIRE_INPUT_BETWEEN_GROUPS) {Check-ifExit}
}#END MAIN FOR LOOP


