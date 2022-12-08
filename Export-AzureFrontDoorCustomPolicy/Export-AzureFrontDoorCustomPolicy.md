# Export-AzureFrontDoorCustomPolicy

Script for prepare script to import policy rules from Azure FrontDoor WAF
Before use please configure parameters in PAREMETERS section

1. Edit parameters in script
   - $subscription_id - Subscription ID - from which you will export your WAF Custom Rules
   - $source_resource_group - Source Resource-Group - from which you will export your WAF Custom Rules
   - $target_resource_group - Target Resource-Group - to which you will export your WAF Custom Rules (will be added to the generated script)
   - $source_fdwafpolicy - Source Frontdoor WAF Policy Name - from which you will export your WAF Custom Rules
   - $target_fdwafpolicy - Target Frontdoor WAF Policy Name - to which you will export your WAF Custom Rules (will be added to the generated script)

2. Run script and save output to new file (ps1)

3. Review newly created file

4. Run new file (will import all WAF Custom fules)

