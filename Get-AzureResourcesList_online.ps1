<#

.SYNOPSIS
Get-AzureResourceList_online.ps1 - Report list of all resources with SKU or VM Size

.DESCRIPTION
Script for prepare report of all resources in selected subscription
Run using Azure PowerShell online


.NOTES
Written By: Chris Polewiak
Website:	http://blog.polewiak.pl

Change Log
V1.00, 15/05/2018 - Initial version
V1.01, 28/07/2018 - Repoting SKU parameters
V1.02, 07/07/2020 - Fix reporting SKU, Add reporting VM Disk size

#>

$SubscriptionID = $(Get-AzureRmContext).Subscription.Id

# Define Report File
$ReportFile = $( $(Get-CloudDrive).MountPoint + '\AzureResourcesExport-' + $(Get-Date -format 'yyyy-MM-dd-HHmmss') + '.csv' )

Class AzureResource
{
	[string]$Subscription
	[string]$ResourceType
	[string]$ResourceGroup
	[string]$Location
	[string]$Name
    [string]$SKUName
    [string]$SKUCapacity
    [string]$DiskSize
	[string]$ResourceId
}

$report = @()
$AzureResources = Get-AzureRmResource
Foreach( $ResourceItem in $AzureResources)
{
    $reportItem = New-Object AzureResource
    $reportItem.Subscription = $SubscriptionID
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

$report | ConvertTo-Csv -NoTypeInformation | Out-File $ReportFile
