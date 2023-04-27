import pandas as pd
import json
import re
import csv
import locale
import datetime
from datetime import date, timedelta, datetime
import warnings
warnings.simplefilter("ignore")
locale.setlocale(locale.LC_ALL, '')


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
    billing={'meta':{'StartDate':'', 'EndDate':''}, 'data':{}}
    for line in report:

        # Set Report Dates
        if billing['meta']['StartDate']=='':
            billing['meta']['StartDate'] = datetime.strptime( str(line['ChargeStartDate']), '%Y-%m-%d %H:%M:%S')
        if billing['meta']['EndDate']=='':
            billing['meta']['EndDate'] = datetime.strptime( str(line['ChargeEndDate']), '%Y-%m-%d %H:%M:%S')

        # Calculate Billing per Customer
        CustomerId = line['CustomerId']
        SubscriptionId = line['SubscriptionId']

        # Do not analyse empty lines
        if not pd.isna( CustomerId ) and not pd.isna( SubscriptionId ):

            # Create new array for new Customer
            if not CustomerId in billing['data']:
                billing['data'][CustomerId]={'CustomerName':'', 'CustomerCostFloat':0, 'PartnerCostFloat':0}
            billing['data'][CustomerId]['CustomerName'] = line['CustomerName']
            billing['data'][CustomerId]['CustomerDomainName'] = line['CustomerDomainName']

            if not isinstance( line['UnitPrice'], float):
                line['UnitPrice'] = locale.atof(line['UnitPrice'])
            if not isinstance( line['Quantity'], float):
                line['Quantity'] = locale.atof(line['Quantity'])
            if not isinstance( line['PCToBCExchangeRate'], float):
                line['PCToBCExchangeRate'] = locale.atof(line['PCToBCExchangeRate'])
            if not isinstance( line['EffectiveUnitPrice'], float):
                line['EffectiveUnitPrice'] = locale.atof(line['EffectiveUnitPrice'])

            billing['data'][CustomerId]['CustomerCostFloat'] = billing['data'][CustomerId]['CustomerCostFloat'] + line['UnitPrice'] * line['Quantity'] * line['PCToBCExchangeRate']
            billing['data'][CustomerId]['PartnerCostFloat'] = billing['data'][CustomerId]['PartnerCostFloat'] + line['EffectiveUnitPrice'] * line['Quantity'] * line['PCToBCExchangeRate']

        for customer in billing['data']:
            billing['data'][customer]['CustomerCost'] = round( billing['data'][customer]['CustomerCostFloat'], 2)
            billing['data'][customer]['PartnerCost'] = round( billing['data'][customer]['PartnerCostFloat'], 2)

    return billing

# Create TXT report
def ReportTXT( billing ):
    report = 'Azure Plan usage for period ' + str(billing['meta']['StartDate'].strftime('%Y-%m-%d')) + ' - ' + str(billing['meta']['EndDate'].strftime('%Y-%m-%d')) + '\n'
    for CustomerId in billing['data']:
        report += '\n'
        report += 'Customer Name: ' + str(billing['data'][CustomerId]['CustomerName']) + '\n'
        report += '    Tenant id: ' + str(CustomerId) + '\n'
        report += '  Domain name: ' + str(billing['data'][CustomerId]['CustomerDomainName']) + '\n'
        report += '               -----------------------------------\n'
        report += 'Customer cost: ' + str( '{:.2f}'.format( billing['data'][CustomerId]['CustomerCost'] )) + ' EUR\n'
        report += ' Partner cost: ' + str( '{:.2f}'.format( billing['data'][CustomerId]['PartnerCost'] )) + ' EUR\n'
    return report

# Create JSON Report
def ReportJSON( billing ):
    json_object = json.dumps(billing, indent=4, sort_keys=True, default=str)
    return json_object
