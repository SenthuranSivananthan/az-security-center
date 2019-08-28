$AADTenantId = "----- GUID ------"

$SubscriptionIds = @(
    "SUB1-GUID", "SUB2-GUID"
)

$AccessToken = ""
$Account = Login-AzAccount

foreach($Token in $Account.Context.TokenCache.ReadItems())
{
    if ($Token.TenantId -eq $AADTenantId)
    {
        $AccessToken = $Token.AccessToken
    }
}

$Headers = @{
    "Authorization" = "Bearer $AccessToken"
}

foreach ($SubscriptionId in $SubscriptionIds)
{
    $ComplianceUri = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.Security/regulatoryComplianceStandards?api-version=2019-01-01-preview"
    $ComplianceResponse = Invoke-WebRequest -Headers $Headers -Uri $ComplianceUri
    $Compliances = $ComplianceResponse.Content | ConvertFrom-Json

    $Output = [System.Collections.ArrayList]@()

    foreach ($Compliance in $Compliances.value)
    {
        $ComplianceName = $Compliance.name

        $ComplianceStandardsUri =  "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.Security/regulatoryComplianceStandards/$ComplianceName/regulatoryComplianceControls?api-version=2019-01-01-preview"  
        $ComplianceStandardsResponse = Invoke-WebRequest -Headers $Headers -Uri $ComplianceStandardsUri
        $ComplianceStandards = $ComplianceStandardsResponse.Content | ConvertFrom-Json

        Write-Host "Downloading $ComplianceName assessment information for" $SubscriptionId

        foreach ($ComplianceStandard in $ComplianceStandards.value)
        {
            $StandardName = $ComplianceStandard.name 
            $State = $ComplianceStandard.properties.state
            $Description = $ComplianceStandard.properties.description

            if ($State -ne "Unsupported")
            {
                $ComplianceAsssessmentUri = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.Security/regulatoryComplianceStandards/$ComplianceName/regulatoryComplianceControls/$StandardName/regulatoryComplianceAssessments?api-version=2019-01-01-preview"
                $ComplianceAsssessmentResponse = Invoke-WebRequest -Headers $Headers -Uri $ComplianceAsssessmentUri

                $ComplianceAsssessments = $ComplianceAsssessmentResponse.Content | ConvertFrom-Json

                foreach ($ComplianceAsssessment in $ComplianceAsssessments.value)
                {
                    $item = New-Object PSObject
                    $item | Add-Member NoteProperty Compliance ($ComplianceName)
                    $item | Add-Member NoteProperty Control ($StandardName)
                    $item | Add-Member NoteProperty ControlDescription ($ComplianceStandard.properties.description)
                    $item | Add-Member NoteProperty Asssessment ($ComplianceAsssessment.properties.description)
                    $item | Add-Member NoteProperty Status ($ComplianceAsssessment.properties.state)
                    $item | Add-Member NoteProperty TotalResources ($ComplianceAsssessment.properties.passedResources + $ComplianceAsssessment.properties.failedResources + $ComplianceAsssessment.properties.skippedResources)
                    $item | Add-Member NoteProperty PassedResources ($ComplianceAsssessment.properties.passedResources)
                    $item | Add-Member NoteProperty FailedResources ($ComplianceAsssessment.properties.failedResources)
                    $item | Add-Member NoteProperty SkippedResources ($ComplianceAsssessment.properties.skippedResources)

                    $Output.Add($item)
                }
            }
        }
    }

    $Output | ConvertTo-Csv | Out-File -FilePath  "Compliance-$SubscriptionId.csv"
}
