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
        print("------------------------------------------------------------")
        print(report)
        print("------------------------------------------------------------")
    else:
        report = AzurePlan.ReportTXT( billing )
        print(report)

