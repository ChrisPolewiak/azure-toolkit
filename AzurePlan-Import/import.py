import pandas as pd
import json
import sys
import re
from datetime import date, timedelta
import warnings
warnings.simplefilter("ignore")

if ( sys.argv[1] ):
    filepath = sys.argv[1]
else:
    print ('import.py -i <inputfile>')
    sys.exit()

# Import data from Excel from selected columns
data = pd.read_excel (filepath, engine="openpyxl")
df = pd.DataFrame(data, columns= ['CustomerId', 'CustomerName', 'CustomerDomainName', 'SubscriptionId', 'EntitlementDescription', 'UnitPrice', 'EffectiveUnitPrice', 'Quantity', 'PCToBCExchangeRate', 'PartnerEarnedCreditPercentage', 'ChargeStartDate', 'ChargeEndDate'])
data_dict = df.to_dict('records')

billing={'meta':{'StartDate':''}, 'data':{}}
for line in data_dict:

    # Set Report Dates
    if billing['meta']['StartDate']=='':
        billing['meta']['StartDate'] = str( line['ChargeStartDate'] )[0:4] + '-' + str( line['ChargeStartDate'] )[8:10] + '-' + str( line['ChargeStartDate'] )[5:7]
        billing['meta']['EndDate'] = str( line['ChargeEndDate'] )[0:4] + '-' + str( line['ChargeEndDate'] )[8:10] + '-' + str( line['ChargeEndDate'] )[5:7]

    # Calculate Billing per Customer
    CustomerId = line['CustomerId']
    SubscriptionId = line['SubscriptionId']
    # Do not analyse empty lines
    if not pd.isna( CustomerId ) and not pd.isna( SubscriptionId ):
        # Create new array for new Customer
        if not CustomerId in billing['data']:
            billing['data'][CustomerId]={'CustomerName':'', 'CustomerCost':0, 'PartnerCost':0}
        billing['data'][CustomerId]['CustomerName'] = line['CustomerName']
        billing['data'][CustomerId]['CustomerDomainName'] = line['CustomerDomainName']
        billing['data'][CustomerId]['CustomerCost'] = billing['data'][CustomerId]['CustomerCost'] + ( line['UnitPrice'] * line['Quantity'] * line['PCToBCExchangeRate'] )
        billing['data'][CustomerId]['PartnerCost'] = billing['data'][CustomerId]['PartnerCost'] + ( line['EffectiveUnitPrice'] * line['Quantity'] * line['PCToBCExchangeRate'] )

# Create final report
report = 'Azure Plan usage for period ' + billing['meta']['StartDate'] + ' - ' + billing['meta']['EndDate'] + '\n'
for CustomerId in billing['data']:
    report += '\n'
    report += 'Customer Name: ' + str(billing['data'][CustomerId]['CustomerName']) + '\n'
    report += '    Tenant id: ' + str(CustomerId) + '\n'
    report += '  Domain name: ' + str(billing['data'][CustomerId]['CustomerDomainName']) + '\n'
    report += '               -----------------------------------\n'
    report += 'Customer cost: ' + str( '{:.2f}'.format( billing['data'][CustomerId]['CustomerCost'] )) + ' EUR\n'
    report += ' Partner cost: ' + str( '{:.2f}'.format( billing['data'][CustomerId]['PartnerCost'] )) + ' EUR\n'

print("------------------------------------------------------------")
print(report)
print("------------------------------------------------------------")

#print('\n\n')
#print(json.dumps(billing, indent=4, sort_keys=True))