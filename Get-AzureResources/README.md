# Get-AzureResourceList
Get-AzureResourceList

Short manual how to grab Resource Data from Subscription - online version

1. Open PowerShell for your subscription.
   Easiest way is to open https://shell.azure.com website.
   
   **Remember to choose PowerShell version instead of Cli**

2. Go to Home Directory

```powershell
cd $HOME_DIR
```

3. Invoke download script from github and save it locally

```powershell
Invoke-WebRequest -Uri https://raw.githubusercontent.com/ChrisPolewiak/azure-toolkit/master/Get-AzureResources/Get-AzureResourcesList_online.ps1 -OutFile 'Get-AzureResourceList_online.ps1'
```

4. Run script

```powershell
./Get-AzureResourceList_online.ps1
```

5. Download your report in CSV format. You will found it on your Storage Account in File Share. Details about them will be reported.

