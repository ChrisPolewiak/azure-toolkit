<#

.SYNOPSIS
Get-AzureResourceList.ps1 - Report list of all resources with SKU or VM Size

.DESCRIPTION
Script for prepare report of all resources in selected subscription


.NOTES
Written By: Chris Polewiak
Website:	http://blog.polewiak.pl
Azure capabilites to move sourced from Tom FitzMacken (thanks)
https://github.com/tfitzmac/resource-capabilities/blob/master/move-support-resources.csv

Change Log
V1.00, 15/05/2018 - Initial version
V1.01, 28/07/2018 - Repoting SKU parameters
V1.02, 07/07/2020 - Fix reporting SKU, Add reporting VM Disk size
V1.03, 29/09/2020 - Add taging if resource is capable to move to different resource group or a subscription
#>

$SubscriptionID = ''

if ( ! $(Get-AzureRmContext) )
{
    # Login to Azure Teenant
    Login-AzureRmAccount

    # Select Subscription
    Select-AzureRmSubscription -SubscriptionId $SubscriptionID -TenantId $Subscription.TenantId
}

$SubscriptionID = $(Get-AzureRmContext).Subscription.Id

# Resource Move Capabilities
Write-Output '- Fetching Resource Move Capabilities Data'
$ResourceCapabilities = ConvertFrom-Csv $(Invoke-WebRequest "https://raw.githubusercontent.com/tfitzmac/resource-capabilities/master/move-support-resources.csv")
$ResourceCapabilitiesData = @{}
Foreach( $Resource in $ResourceCapabilities)
{
    $ResourceCapabilitiesData.add( $Resource.Resource, @{
        'MoveToResourceGroup' = $Resource.'Move Resource Group'
        'MoveToSubscription' = $Resource.'Move Subscription'
    })
}

# Define Report File
$ReportFileName = 'AzureResourcesExport-' + $(Get-Date -format 'yyyy-MM-dd-HHmmss') + '.csv';
$ReportFile = $( $(Get-CloudDrive).MountPoint + '\' + $ReportFileName )

Class AzureResource
{
	[string]$Subscription
	[string]$ResourceType
	[string]$MoveToResourceGroup
	[string]$MoveToSubscrition
	[string]$ResourceGroup
	[string]$Location
	[string]$Name
    [string]$SKUName
    [string]$SKUCapacity
    [string]$DiskSize
	[string]$ResourceId
}

$report = @()
Write-Output '- Get Azure Resources List'
$AzureResources = Get-AzureRmResource
Foreach( $ResourceItem in $AzureResources)
{
    $reportItem = New-Object AzureResource
    $reportItem.Subscription = $SubscriptionID
    $reportItem.MoveToResourceGroup = $ResourceCapabilitiesData[ $ResourceItem.ResourceType ].MoveToResourceGroup
    $reportItem.MoveToSubscrition = $ResourceCapabilitiesData[ $ResourceItem.ResourceType ].MoveToSubscription
    $reportItem.ResourceType = $ResourceItem.ResourceType
    $reportItem.ResourceGroup = $ResourceItem.ResourceGroupName
    $reportItem.Location = $ResourceItem.Location
    $reportItem.Name = $ResourceItem.Name

    if ( $null -ne $ResourceItem.Sku )
    {
        $reportItem.SkuName = $($ResourceItem.Sku).Name
        $reportItem.SkuCapacity = $($ResourceItem.Sku).Capacity
    }

    # Managed Disk Size
    if ( $ResourceItem.ResourceType -eq 'Microsoft.Compute/disks' ) {
        $reportDisk = Get-AzureRmDisk -ResourceGroupName $ResourceItem.ResourceGroupName -DiskName $ResourceItem.Name
        $reportItem.DiskSize = $reportDisk.DiskSizeGB
    }

    $reportItem.ResourceId = $ResourceItem.ResourceId

    $report += $reportItem
}

Write-Output '- Output Report'

$report | ConvertTo-Csv -NoTypeInformation | Out-File $ReportFile

Write-Output $('- Your report is completed' )
Write-Output $('         File Name: ' + $ReportFile )
