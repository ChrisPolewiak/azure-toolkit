# Import, extract and calculate billing in AzurePlan subscriptions from Excel files
# 
# Written By: Chris Polewiak
# Website:	http://blog.polewiak.pl

# Change Log
# V1.00, 15/07/2022 - Initial public version
# V1.01, 21/11/2022 - Add CSV Support

import sys
import AzurePlan

if ( sys.argv[1] ):
    filepath = sys.argv[1]
    report = AzurePlan.Import( filepath )
    billing = AzurePlan.Calculate( report )
    AzurePlan.ReportTXT( billing )

else:
    print ('import.py -i <inputfile>')
    sys.exit()
