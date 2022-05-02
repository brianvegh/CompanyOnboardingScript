##########################################
# Created by Brian Vegh, 2/2022. Cheers! #
##########################################
#Connect to Mic. Exchange if user enters "Connect", otherwise assume connection in place in session
$connect = Read-Host "On initial run in this powershell window type `"connect`" to connect to exchange. `n" `
				 "After initial run session will already be connected; press Enter to continue."
if ($connect -eq "connect") {
	Write-Output "Connecting to Microsoft ExchangeOnline (Connect-ExchangeOnline)"
	Connect-ExchangeOnline
	Write-Output "ExchangeOnline connection established."
}


#FUNCTIONS
	#function to list and choose AD Group
	function MyGet-GroupNameAD {
			param(
				[Parameter(Mandatory)]
				[string]$target_or_source, 	#source group or target group
				[Parameter(Mandatory)]
				[string]$searchString #search string
			)	
			
		while ($true) {
			$groups = get-adgroup -filter "name -like '*$searchString*'"
			$groupCounter = 0
			# collect an array of PsCustomObjects in variable $allGroups
			foreach ($group in $groups) {
				$groupCounter++   # increment the counter
				$currentName=$group.name
				Write-Host ( '[ '+($groupCounter)+' ]  ' +$currentName) |out-host
			}
			if ($groups) {
			$selection= Read-Host "Enter the group number of your choice (Defaults to 1)"
			if (!$selection) {
				$selection = 1
			}
			if ($groupCounter -ne 1) {
				$returnName=$groups[$selection-1].name
			} else {
				$returnName = $currentName
			}
			Write-Host "$target_or_source Selected: $returnName"
			return $returnName
			} else {
				Write-Host "No search Results"
				$searchString = Read-Host "Enter new $target_or_source searh String:"
			}
		}
	}

	#function to list and choose O365 Group from search input
	function MyGet-GroupNameO365 {
			param(
				[Parameter(Mandatory)]
				[string]$target_or_source, 	#source group or target group
				[Parameter(Mandatory)]
				[string]$searchString #search string
			)

		while ($true) {
			out-host		
			$groups = Get-UnifiedGroup -Filter "DisplayName -like '*$searchString*'"
			$groupCounter = 0
			# collect an array of PsCustomObjects in variable $allGroups
			foreach ($group in $groups) {			
				$groupCounter++   # increment the counter
				$currentName=$group.DisplayName	
				Write-Host ( '[ '+($groupCounter)+' ]  ' +$currentName) | out-host			
			}
			if ($groups) {		
				$selection= Read-Host "Enter the group number of your choice (Defaults to 1)"
				if (!$selection) {
					$selection = 1
				}		
				if ($groupCounter -ne 1) {
					$returnName=$groups[$selection-1].DisplayName
				} else {
					$returnName = $currentName
				}		
				$currentName=$groups[$selection-1].DisplayName
				Write-Host "$target_or_source Selected: $returnName"	
				return $returnName 
			} else {
				Write-Host "No search Results"
				$searchString = Read-Host "Enter new $target_or_source searh String:"
			}
		}
	}

$continueLoop=$true
$firstIteration=$true

#START MAIN PROGRAM LOOP
While ($continueLoop) {

	#Get user input, source group and target group for AD Group
	$targetSearchString = Read-Host "Active Directory TARGET: enter search string (Defaults to previous loop AD TARGET search string)"
	if ((!$targetSearchString) -and (!($firstIteration))) {
		$targetSearchString = $previousTargetSearchString
	}
	$previousTargetSearchString = $targetSearchString	
	$targetGroupName = (MyGet-GroupNameAD "Target Group Name" ($targetSearchString))
	
	$sourceSearchString = Read-Host "Active Directory SOURCE: enter search string (Defaults to previous loop AD SOURCE search string)"
	if ((!$sourceSearchString) -and (!($firstIteration))) {
			$sourceSearchString = $previousSourceSearchString 			
		}
	$previousSourceSearchString = $sourceSearchString
	$sourceGroupName = (MyGet-GroupNameAD "Source Group Name" ($sourceSearchString))

	#Review and confirm entries
	$sourceGroup = Get-ADGroup -Filter "Name -like '$sourceGroupName'"
	$targetGroup = Get-ADGroup -Filter "Name -like '$targetGroupName'"
	Write-Output "`n---------------------------------------------------------------------------------`n"
	Write-Output "Confirmation: Target Group Name = $targetGroupName"
	Write-Output "Confirmation: Target AD Location = $targetGroup"
	Write-Output "Confirmation: Source Group Name = $sourceGroupName"
	Write-Output "Confirmation: Source AD Location = $sourceGroup"
	Read-Host "Press any key to confirm"
	#copy AD security group membership
	Get-ADGroupMember -Identity $sourceGroup | ForEach-Object {Add-ADGroupMember -Identity $targetGroup -Members $_.distinguishedName}
	Write-Output "AD Security Group membership copy COMPLETE"

	#Get user input, source group and target group for O365
	$newTargetSearchString = Read-Host "O365 TARGET: enter search string (Defaults to previous target search string)"
		if (!$newTargetSearchString) {
			$newTargetSearchString = $targetSearchString 
		}
	$targetGroupName = (MyGet-GroupNameO365 "Target Group Name" ($newTargetSearchString))
	$newSourceSearchString = Read-Host "O365 SOURCE: enter search string (Defaults to previous search search string)"
		if (!$newSourceSearchString) {
			$newSourceSearchString = $sourceSearchString 
		}
	$sourceGroupName = (MyGet-GroupNameO365 "Source Group Name" ($newSourceSearchString))

	Write-Output "`n---------------------------------------------------------------------------------`n"
	Write-Output "O365 Confirmation: Target Group Name = $targetGroupName"
	Write-Output "O365 Confirmation: Source Group Name = $sourceGroupName"
	Read-Host "Press any key to confirm"
	
	#copy o365 group/teams
	$users = (Get-UnifiedGroupLinks -Identity "$sourceGroupName" -LinkType "Members").PrimarySmtpAddress
	foreach ($item in $users) {
		Add-UnifiedGroupLinks -Identity "$targetGroupName" -LinkType "Members" -Links $item
		Write-Output "$item added to $targetGroupName"
	}
	Write-Output "O365 GROUP membership copy - COMPLETE"

	#check if user needs to copy more memberships
	$continueLoop = Read-Host "######################`n " `
							"Would you like exit (y/n)`n" `
							"######################"
	if ($continueLoop -like 'y*') {
		$continueLoop=$false
	} else {
		$continueLoop = $true
		$firstIteration=$false
		while ((Read-Host "enter the letter z to confirm repeat program") -ne "z") {}			
	}

}#end main while loop

