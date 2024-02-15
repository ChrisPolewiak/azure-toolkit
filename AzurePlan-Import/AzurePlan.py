import pandas as pd
import json
import re
import csv
import locale
import datetime
from datetime import date, timedelta, datetime
import warnings
warnings.simplefilter("ignore")
locale.setlocale(locale.LC_ALL, 'en_US.UTF-8')

# Import data
def Import( filepath ):
    if (filepath.endswith('.csv') ):
        report = ImportFromCSV( filepath )
    return report


# Import data from CSV
def ImportFromCSV( filepath ):
    report = []
    with open(filepath, 'r', newline='') as csvfile:
        reader = csv.DictReader(csvfile, delimiter=';')
        for line in reader:
            if line == '\r\n' or line == '\n' or line == '':
                continue
            report.append(line)
    return report


# Calculate billing data
def Calculate( report ):
    billing={
        'meta':{
            'StartDate':'',
            'EndDate':''
            },
        'data':{
            'customers':{},
        }
    }
    subs={}
    for line in report:

        # Set Report Dates
        if billing['meta']['StartDate']=='':
            billing['meta']['StartDate'] = datetime.strptime( str(line['ChargeStartDate']), '%Y-%m-%d %H:%M:%S')
        if billing['meta']['EndDate']=='':
            billing['meta']['EndDate'] = datetime.strptime( str(line['ChargeEndDate']), '%Y-%m-%d %H:%M:%S')

        # Calculate Billing per Customer
        CustomerId = line['CustomerId']
        SubscriptionId = line['SubscriptionId']

        subs[SubscriptionId]=1

        # Do not analyse empty lines
        if not pd.isna( CustomerId ) and not pd.isna( SubscriptionId ):

            # Create new array for new Customer
            if not CustomerId in billing['data']['customers']:
                billing['data']['customers'][CustomerId]={
                    'CustomerName': line['CustomerName'],
                    'CustomerDomainName': line['CustomerDomainName'],
                    'CustomerCountry': line['CustomerCountry'],
                    'CustomerCost': float(),
                    'PartnerCost': float(),
                    'subscriptions':{}
                }

                if not SubscriptionId in billing['data']['customers'][CustomerId]['subscriptions']:
                    billing['data']['customers'][CustomerId]['subscriptions'][SubscriptionId]={
                        'SubscriptionName': line['SubscriptionDescription'],
                        'CustomerCost': float(),
                        'PartnerCost': float()
                    }

            UnitPrice = float( line['UnitPrice'].replace(',','.'))
            Quantity = float( line['Quantity'].replace(',','.'))
            PCToBCExchangeRate = float( line['PCToBCExchangeRate'].replace(',','.'))
            EffectiveUnitPrice = float( line['EffectiveUnitPrice'].replace(',','.'))
            CustomerCost = UnitPrice * Quantity * PCToBCExchangeRate
            PartnerCost = EffectiveUnitPrice * Quantity * PCToBCExchangeRate

            billing['data']['customers'][CustomerId]['subscriptions'][SubscriptionId]['CustomerCost'] = billing['data']['customers'][CustomerId]['subscriptions'][SubscriptionId]['CustomerCost'] + CustomerCost
            billing['data']['customers'][CustomerId]['subscriptions'][SubscriptionId]['PartnerCost']  = billing['data']['customers'][CustomerId]['subscriptions'][SubscriptionId]['PartnerCost'] + PartnerCost
            billing['data']['customers'][CustomerId]['CustomerCost'] = billing['data']['customers'][CustomerId]['CustomerCost'] + CustomerCost
            billing['data']['customers'][CustomerId]['PartnerCost']  = billing['data']['customers'][CustomerId]['PartnerCost'] + PartnerCost
            
#            print(
#                    'Customer:', CustomerId, 'Sub:', SubscriptionId, 
#                    'UnitPrice:', UnitPrice,'\tQty:', Quantity,'\tPCT:', PCToBCExchangeRate, '\tEffective:', EffectiveUnitPrice,
#                    '\tCustomer:', CustomerCost,
#                    '\tCCostS:', round(billing['data']['customers'][CustomerId]['subscriptions'][SubscriptionId]['CustomerCost'],2),
#                    '\tCCost:', round(billing['data']['customers'][CustomerId]['CustomerCost'],2),
#                    '\tPartner:', PartnerCost,
#                    '\tPCostS:', round(billing['data']['customers'][CustomerId]['subscriptions'][SubscriptionId]['PartnerCost'],2),
#                    '\tPCost:', round(billing['data']['customers'][CustomerId]['PartnerCost'],2))

#    for CustomerId in billing['data']:
#        print(CustomerId)
#        billing['data']['customers'][CustomerId]['subscriptions'][SubscriptionId]['CustomerCostSubscription'] = round( billing['data']['customers'][CustomerId]['subscriptions'][SubscriptionId]['CustomerCostFloat'], 2)
#        billing['data']['customers'][CustomerId]['subscriptions'][SubscriptionId]['PartnerCostSubscription'] = round( billing['data']['customers'][CustomerId]['subscriptions'][SubscriptionId]['PartnerCostFloat'], 2)

#    print(billing['data'][CustomerId]['CustomerCost'],billing['data'][CustomerId]['PartnerCost'])

    print('\n')
    print(subs)

    return billing

# Create TXT report
def ReportTXT( billing ):
    report = '=====================================================================================================\n'
    report += 'Azure Plan usage for period ' + str(billing['meta']['StartDate'].strftime('%Y-%m-%d')) + ' - ' + str(billing['meta']['EndDate'].strftime('%Y-%m-%d')) + '\n'
    report += '=====================================================================================================\n'
    for CustomerId in billing['data']['customers']:
        report += '\n\n'
        report += 'Customer Name: ' + str(billing['data']['customers'][CustomerId]['CustomerName']) + '\n'
        report += '    Tenant id: ' + str(CustomerId) + '\n'
        report += '  Domain name: ' + str(billing['data']['customers'][CustomerId]['CustomerDomainName']) + '\n'
        report += '-----------------------------------------------------------------------------------------------------\n'
        report += 'SubscriptionId                       | Name                           | Customer Cost | Partner Cost \n'
        report += '-----------------------------------------------------------------------------------------------------\n'
        for SubscriptionId in billing['data']['customers'][CustomerId]['subscriptions']:
            report += str(SubscriptionId) + ' | '
            report += '{:30s}'.format(billing['data']['customers'][CustomerId]['subscriptions'][SubscriptionId]['SubscriptionName']) + ' | '
            report += '{:9.2f}'.format( billing['data']['customers'][CustomerId]['subscriptions'][SubscriptionId]['CustomerCost'] ) + ' EUR | '
            report += '{:9.2f}'.format( billing['data']['customers'][CustomerId]['subscriptions'][SubscriptionId]['PartnerCost'] ) + ' EUR\n'
        report += '-----------------------------------------------------------------------------------------------------\n'
        report += '                                                                Total | '
        report += '{:9.2f}'.format( billing['data']['customers'][CustomerId]['CustomerCost'] ) + ' EUR | '
        report += '{:9.2f}'.format( billing['data']['customers'][CustomerId]['PartnerCost'] ) + ' EUR\n'
        report += '=====================================================================================================\n'
    return report

# Create JSON Report
def ReportJSON( billing ):
    json_object = json.dumps(billing, indent=4, sort_keys=True, default=str)
    return json_object

