# Import, extract and calculate billing in AzurePlan subscriptions from Excel and CSV files
# 
# Written By: Chris Polewiak
# Website:	https://github.com/ChrisPolewiak/azure-toolkit/tree/master/AzurePlan-Import

# Change Log
# V1.00, 2022-07-15 - Initial public version
# V1.01, 2022-11-21 - Add CSV Support
# v1.02, 2023-04-12 - Add HTML output and add parser for input arguments
# v2.00, 2023-04-27 - Remove Excel support, Add HTTP server using Flesk

import sys
import argparse
import AzurePlan

parser = argparse.ArgumentParser(prog='import.py',
                                 description='Import, extract and calculate billing in AzurePlan subscriptions from CSV files',
                                 epilog='Source: https://github.com/ChrisPolewiak/azure-toolkit/tree/master/AzurePlan-Import',
                                 formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument('-i', '--input', required=True, help='input file in CSV or Excel format')
parser.add_argument('-o', '--output', required=False, help='output format: txt or json', default='txt')
args = parser.parse_args()

if ( args.input ):
    filepath = args.input

    report = AzurePlan.Import( filepath )
    billing = AzurePlan.Calculate( report )

    if ( args.output == 'json' ):
        report = AzurePlan.ReportJSON( billing )
    else:
        report = AzurePlan.ReportTXT( billing )
    print("------------------------------------------------------------")
    print(report)
    print("------------------------------------------------------------")

