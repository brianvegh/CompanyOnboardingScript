#Connects 3CX to Microsoft Teams Enterprise Audio
$email = Read-Host "Enter the User's primary email address"
$checkTelephoneNumber = $true
while ($checkTelephoneNumber){
	$telephone = Read-Host "Enter the User's DID phone nubmer. `"+1`" followed by 10 digit number (+12224448888)."
	if (($telephone.length -ne 12)) {		
		if ($telephone[0] -ne '+') {
			Write-Output "Invalid DID Format"
			Continue			
		}
		if ($telephone[1] -ne '1') {
			Write-Output "Invalid DID Format"
			Continue
			}
		Write-Output "Invalid DID length"
	} else {
		$checkTelephoneNumber=$false
	}
}
$extension = Read-Host "Enter the User's phone extension"
Write-Output "`n`nEmail = $email`nTelephone = $telephone`nExtenstion = $extension"
Read-Host "Press any key to confirm"
Write-Output "Connecting to Microsoft Teams. This may take up to 30 seconds. A Microsoft ign-In dialog box will appear."
Connect-MicrosoftTeams
Set-CsUser `
-Identity $email `
-OnPremLineURI "tel:$telephone;ext=$extension" `
-EnterpriseVoiceEnabled $true `
-HostedVoiceMail $true
$users_ids = @($email)
New-CsBatchPolicyAssignmentOperation -PolicyType TenantDialPlan `
-PolicyName "3CX Dial Plan" -Identity $users_ids -OperationName "Batch assign dial plan"
New-CsBatchPolicyAssignmentOperation -PolicyType OnlineVoiceRoutingPolicy `
-PolicyName "3CX Voice Route Policy" -Identity $users_ids -OperationName "Batch assign voice routing"
New-CsBatchPolicyAssignmentOperation -PolicyType TeamsCallingPolicy `
-PolicyName "3CX Calling Policy" -Identity $users_ids -OperationName "Batch assign calling policy"
Write-Output "`nSuccess - Process Complete"