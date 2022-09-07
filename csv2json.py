#!/usr/bin/env python3

# convert a CSV w/ header to line-by-line JSON
# based on: https://pythonexamples.org/python-csv-to-json/

import argparse
import csv
import json
import sys

def csv_to_json(csvFilePath, jsonFilePath):
    jsonArray = []
      
    #read csv file
    try:
        csvf = open(csvFilePath, 'r', encoding='utf-8')
        csvDictReader = csv.DictReader(csvf)
    except:
        sys.stderr.write('Unable to open %s for reading\n' % (csvFilePath))
        sys.exit(1)

    #open json file
    try:
        jsonf = open(jsonFilePath, 'w', encoding='utf-8')
    except:
        sys.stderr.write('Unable to open %s for writing\n' % (jsonFilePath))
        sys.exit(1)

    result = []
    for row in csvDictReader:
        jsonString = json.dumps(row)
        result.append(json.dumps(row))

    jsonf.write('\n'.join(result))

parser = argparse.ArgumentParser()
parser.add_argument('-c')   # CSV file
parser.add_argument("-j")   # JSON file
args = parser.parse_args()

if not args.c or not args.j:
    sys.stderr.write("-c csvfile and -j jsonfile parameters required\n")
    sys.exit(1)

csv_to_json(args.c, args.j)
