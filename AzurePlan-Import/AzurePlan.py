import pandas as pd
import json
import re
import csv
from datetime import date, timedelta
import warnings
warnings.simplefilter("ignore")

# Import data
def Import( filepath ):
    if (filepath.endswith('.xlsx') or filepath.endswith('.xls') ):
        report = ImportFromExcel( filepath )
    elif (filepath.endswith('.csv') ):
        report = ImportFromCSV( filepath )
    return report

# Import data from Excel
def ImportFromExcel( filepath ):
    report = []
    data = pd.read_excel (filepath, engine="openpyxl")
    df = pd.DataFrame(data)
    data_dict = df.to_dict('records')
    for line in data_dict:
        report.append(line);
    return report

# Import data from CSV
def ImportFromCSV( filepath ):
    report = []
    with open(filepath, newline='') as csvfile:
        reader = csv.DictReader(csvfile, delimiter=';')
        for line in reader:
            report.append(line);
    return report

# Calculate billing data
def Calculate( report ):
    billing={'meta':{'StartDate':''}, 'data':{}}
    for line in report:
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

            billing['data'][CustomerId]['CustomerCost'] = billing['data'][CustomerId]['CustomerCost'] + ( float(line['UnitPrice'].replace(',','.')) * float(line['Quantity'].replace(',','.')) * float(line['PCToBCExchangeRate'].replace(',','.')) )
            billing['data'][CustomerId]['PartnerCost'] = billing['data'][CustomerId]['PartnerCost'] + ( float(line['EffectiveUnitPrice'].replace(',','.')) * float(line['Quantity'].replace(',','.')) * float(line['PCToBCExchangeRate'].replace(',','.')) )
    return billing

# Create final report
def ReportTXT( billing ):
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
