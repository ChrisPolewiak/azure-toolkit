<#

.SYNOPSIS
Get-AzureResourceList_online.ps1 - Report list of all resources with SKU or VM Size

.DESCRIPTION
Script for prepare report of all resources in selected subscription
Run using Azure PowerShell online


.NOTES
Written By: Chris Polewiak
Website:	http://blog.polewiak.pl
Verification of the possibility of relocation based on the script from Tom FitzMacken (thanks)
https://github.com/tfitzmac/resource-capabilities/blob/master/move-support-resources.csv

Change Log
V1.00, 15/05/2018 - Initial version
V1.01, 28/07/2018 - Repoting SKU parameters
V1.02, 07/07/2020 - Fix reporting SKU, Add reporting VM Disk size
V1.03, 29/09/2020 - Tag added whether the resource can be moved to different resource group or a subscription
V1.04, 07/02/2022 - Add additional functions to get SKU sizes from resources
#>

$SubscriptionID = $(Get-AzContext).Subscription.Id

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
	[string]$MoveToSubscription
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
$AzureResources = Get-AzResource
Foreach( $ResourceItem in $AzureResources)
{
    $reportItem = New-Object AzureResource
    $reportItem.Subscription = $SubscriptionID
    $reportItem.MoveToResourceGroup = $ResourceCapabilitiesData[ $ResourceItem.ResourceType ].MoveToResourceGroup
    $reportItem.MoveToSubscription = $ResourceCapabilitiesData[ $ResourceItem.ResourceType ].MoveToSubscription
    $reportItem.ResourceType = $ResourceItem.ResourceType
    $reportItem.ResourceGroup = $ResourceItem.ResourceGroupName
    $reportItem.Location = $ResourceItem.Location
    $reportItem.Name = $ResourceItem.Name

    if ( $null -ne $ResourceItem.Sku )
    {
        $reportItem.SkuName = $($ResourceItem.Sku).Name
        $reportItem.SkuCapacity = $($ResourceItem.Sku).Capacity
    }

    # Get additional SKU Data
    switch( $ResourceItem.ResourceType )
    {
        'Microsoft.Automation/automationAccounts' {
            $resourceData = Get-AzAutomationAccount -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name
            $reportItem.SkuName = $resourceData.Plan
        }
        'Microsoft.Logic/workflows' {
            $resourceData = Get-AzLogicApp -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name
            $reportItem.SkuName = $resourceData.PlanType
        }
        'Microsoft.Compute/disks' {
            $resourceData = Get-AzDisk -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -DiskName $ResourceItem.Name
            $reportItem.DiskSize = $resourceData.DiskSizeGB
        }
        'Microsoft.KeyVault/vaults' {
            $resourceData = Get-AzKeyVault -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -VaultName $ResourceItem.Name
            $reportItem.SkuName = $resourceData.SKU
        }
        'Microsoft.Compute/virtualMachines' {
            $resourceData = Get-AzVM -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name
            $reportItem.SkuName = $resourceData.HardwareProfile.VmSize
        }
        'Microsoft.SqlVirtualMachine/SqlVirtualMachines' {
            $resourceData = Get-AzVM -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name
            $reportItem.SkuName = $resourceData.HardwareProfile.VmSize
        }
    }

    $reportItem.ResourceId = $ResourceItem.ResourceId

    $report += $reportItem
}

Write-Output '- Output Report'

$report | ConvertTo-Csv -NoTypeInformation | Out-File $ReportFile

Write-Output $('- Your report is completed' )
Write-Output $('   Storage Account: ' + $(Get-CloudDrive).Name )
Write-Output $('    FileShare Name: ' + $(Get-CloudDrive).FileShareName )
Write-Output $('         File Name: ' + $ReportFileName )

