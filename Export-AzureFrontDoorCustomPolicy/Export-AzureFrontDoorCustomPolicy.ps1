<#

.SYNOPSIS
Export-AzureFrontDoorCustomPolicy.ps1 - Export custom policy rules from Azure FrontDoor WAF

.DESCRIPTION
Script for prepare script to import policy rules from Azure FrontDoor WAF
Before use please configure parameters in PAREMETERS section

.NOTES
Written By: Chris Polewiak
Website:	http://blog.polewiak.pl

.EXAMPLE
Export-AzureFrontDoorCustomPolicy.ps1 > import.ps1

Change Log
V1.00, 08/12/2022 - Initial version
#>


<###################
# PARAMETERS
#>

# Subscription ID - from which you will export your WAF Custom Rules
$subscription_id = "";

# Source Resource-Group - from which you will export your WAF Custom Rules
$source_resource_group = ""

# Target Resource-Group - to which you will export your WAF Custom Rules (will be added to the generated script)
$target_resource_group = ""

# Source Frontdoor WAF Policy Name - from which you will export your WAF Custom Rules
$source_fdwafpolicy = ""

# Source Frontdoor WAF Policy Name - to which you will export your WAF Custom Rules (will be added to the generated script)
$target_fdwafpolicy = ""


<###################
# CODE
#>

# Please remember to login first to the Azure :)
# az login
az account set --subscription $subscription_id

# Export Custom Rule Policy and convert to JSON
$wafdata = $(az network front-door waf-policy rule list -g $source_resource_group --policy-name $source_fdwafpolicy --out json ) | ConvertFrom-Json

# prepare header for import script file
$azcmds  = "# Import Azure WAF Policy`n"
$azcmds += "`$resource_group = `"" + $target_resource_group + "`";`n";
$azcmds += "`$fdwafpolicy = `"" + $target_fdwafpolicy + "`";`n";
$azcmds += "`n";

# az command to clear cache from defered mode
$azcmds += "az cache purge`n";
$azcmds += "`n";

if ($wafdata -ne '')
{
  # loop for each rule
  foreach( $rule in $wafdata )
  {
    $rule_disabled = ""
    if ($rule.enabledState -eq 'Enabled') {
      $rule_disabled = 'false'
    } else {
      $rule_disabled = 'true'
    }
    $azcmds += "`n"
    $azcmds += "echo `"Import "+$rule.name+" into "+$fdwafpolicy+" Policy`"`n"

    # az command to create waf-policy rule
    $azcmds += "az network front-door waf-policy rule create ``
  --action " + $rule.action + " ``
  --name "+$rule.name+" ``
  --policy-name `$fdwafpolicy ``
  --priority "+$rule.priority+" ``
  --resource-group `$resource_group ``
  --rule-type "+$rule.ruleType+" ``
  --disabled "+$rule_disabled+" ``
  --rate-limit-duration "+$rule.rateLimitDurationInMinutes+" ``
  --rate-limit-threshold "+$rule.rateLimitThreshold+" ``
  --defer`n"

    # loop for each condition in rule
    foreach( $condition in $rule.matchConditions )
    {
      if( $($condition.transforms).Count -gt 0 ) {
        $arg_transforms = "--transforms " + $($condition.transforms -join " ") + " ``"
      }
      else {
        $arg_transforms = " ``"
      }

      # az command to create match-condition
      $azcmds += "
az network front-door waf-policy rule match-condition add ``
  --match-variable "+$condition.matchVariable+" ``
  --operator "+$condition.operator+" ``
  --values "+$($condition.matchValue -join " ")+" ``
  --name "+$rule.name+" ``
  --negate "+$condition.negateCondition+" ``
  --policy-name `$fdwafpolicy ``
  $arg_transforms
  --resource-group `$resource_group`n"
    }
  }
}

# print script
$azcmds