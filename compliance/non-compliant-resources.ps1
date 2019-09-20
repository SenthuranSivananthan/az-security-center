$ManagementGroupName = "Work"
$PolicyName = "e56962a6-4747-49cd-b67b-bf8b01975c4c"

$NonCompliantResources = Get-AzPolicyState `
    -ManagementGroupName $ManagementGroupName `
    -Filter "PolicyDefinitionName eq '$PolicyName' and IsCompliant eq false"

$NonCompliantResources | Select SubscriptionId, ResourceGroup, ResourceId
