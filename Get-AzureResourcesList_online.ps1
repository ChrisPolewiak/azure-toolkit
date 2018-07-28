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

#>

# Define Report File
$ReportFile = $( $(Get-CloudDrive).MountPoint + '\AzureResourcesExport' + $(Get-Date -format 'yyyy-MM-dd-HHmmss') + '.csv' )

Class AzureResource
{
	[string]$Subscription
	[string]$ResourceType
	[string]$ResourceId
	[string]$ResourceGroup
	[string]$Location
	[string]$Name
	[string]$ServiceName
	[string]$Size
	[string]$SKU
}

$AzureARM_VM = Get-AzureRmVM
#$AzureASM_VM = Get-AzureVM

$report = @()
$AzureResources = Get-AzureRmResource
Foreach( $ResourceItem in $AzureResources)
{
    $reportItem = New-Object AzureResource
    $reportItem.Subscription = $ResourceItem.SubscriptionId
    $reportItem.ResourceType = $ResourceItem.ResourceType
    $reportItem.Location = $ResourceItem.Location
    $reportItem.ResourceId = $ResourceItem.ResourceId
    $reportItem.ResourceGroup = $ResourceItem.ResourceGroupName
    $reportItem.Name = $ResourceItem.Name
    $reportItem.SKU = $ResourceItem.Sku

    # Get size for RM Machines
    if($ResourceItem.ResourceType -eq 'Microsoft.Compute/virtualMachines')
    {
        $vm = $AzureARM_VM | Where-Object { $_.Name -eq $ResourceItem.Name }
        $reportItem.Size = $vm.HardwareProfile.VmSize
    }

    # Get size for Classic Machines
    if($ResourceItem.ResourceType -eq 'Microsoft.ClassicCompute/virtualMachines')
    {
        $vm = $AzureARM_VM | Where-Object { $_.Name -eq $ResourceItem.Name }
        $reportItem.Size = $vm.InstanceSize
    }

    $report += $reportItem
}

$report | ConvertTo-Csv | Out-File $ReportFile
