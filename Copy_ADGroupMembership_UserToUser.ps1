#pass in list of "Get-ADUser -Identity $usernames" for source and targets
param ($sourceUsernames, $targetUsernames)
function CopyADGroupMembership($sourceUserames, $targetUsernames){
	foreach ($sourceUsername in $sourceUsernames){
		$CopyFromUser = Get-ADUser $sourceUsername -prop MemberOf
		foreach ($targetUsername in $targetUsernames) {		
			$CopyToUser = Get-ADUser $targetUsername -prop MemberOf
			$CopyFromUser.MemberOf | Where{$CopyToUser.MemberOf -notcontains $_} |  Add-ADGroupMember -Members $CopyToUser
		}
	}
}
CopyADGroupMembership $sourceUsernames $targetUsernames