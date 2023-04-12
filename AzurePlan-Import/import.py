# Import, extract and calculate billing in AzurePlan subscriptions from Excel and CSV files
# 
# Written By: Chris Polewiak
# Website:	https://github.com/ChrisPolewiak/azure-toolkit/tree/master/AzurePlan-Import

# Change Log
# V1.00, 2022-07-15 - Initial public version
# V1.01, 2022-11-21 - Add CSV Support
# v1.02, 2023-04-12 - Add HTML output and add parser for input arguments

import sys
import argparse
import AzurePlan

parser = argparse.ArgumentParser(prog='import.py',
                                 description='Import, extract and calculate billing in AzurePlan subscriptions from Excel and CSV files',
                                 epilog='Source: https://github.com/ChrisPolewiak/azure-toolkit/tree/master/AzurePlan-Import',
                                 formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument('-i', '--input', required=True, help='input file in CSV or Excel format')
parser.add_argument('-f', '--format', required=False, help='output format: txt or html', default='txt')
args = parser.parse_args()

if ( args.input ):
    filepath = args.input

    print (filepath)
    report = AzurePlan.Import( filepath )
    billing = AzurePlan.Calculate( report )

    if ( args.format == 'html' ):
        AzurePlan.ReportHTML( billing )
    else:
        AzurePlan.ReportTXT( billing )
