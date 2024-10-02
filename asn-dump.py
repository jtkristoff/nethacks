#!/usr/bin/env python3

import argparse
import fileinput
import pyasn
import re
import sys

# init mapping tables and run-time caches
ascountries = {}
asnames     = {}
ptr_cache   = {}

parser = argparse.ArgumentParser()
parser.add_argument('-a', default='/etc/pyasn.dat')  # pyasn .dat file
parser.add_argument('-n', default='/etc/asn.txt')    # RIPE asn.txt file
parser.add_argument('-i')   # individual ASN argument, otherwise read stdin
args = parser.parse_args()

# Expects https://pypi.org/project/pyasn/ module formatted .dat file
try:
    asndb = pyasn.pyasn(args.a)
except:
    sys.stderr.write("Failed to import pyasn .dat file: %s\n" % (args.a))
    sys.exit(1)

# Expects a local copy of https://ftp.ripe.net/ripe/asnames/asn.txt
try:
    ripe_asn_txt = open(args.n, 'r')
except:
    sys.stderr.write('Unable to open %s for reading\n' % (args.n))
    sys.exit(1)

# build the ASN to AS name mapping dictionary
for line in ripe_asn_txt:
    # country code is in the last two chars
    cc = line.strip()[-2:]

    # remove trailing country code field, e.g. ", CC"
    line = re.sub( r",\s+[A-Z]{2}\Z", "", line.strip() )

    # skip if string is empty
    if not line:
        continue

    try:
        # split on the first whitespace
        asn, name = line.split(None, 1)
    except:
        # skip if unexpected input
        continue

    # make sure first field is only digits
    if asn.isdigit() == False:
        continue

    # create dictionary entry, limit AS name to 30 chars
    ascountries[int(asn)] = cc
    asnames[int(asn)]     = name[:30]

ripe_asn_txt.close()

def asn2name(asn):
    try:
        asname = asnames[asn]
    except:
        asname = "-"
    return asname

def asn2country(asn):
    try:
        country = ascountries[asn]
    except:
        country = "-"
    return country

def asninfo(asn):
    # TODO: verify ASN string exists and is sane
    cc       = asn2country(asn)
    asname   = asn2name(asn)
    prefixes = asndb.get_as_prefixes(asn)
    return cc, asname, prefixes

def writeinfo(asn, prefix, cc, asname):
    if ':' in prefix:
        sys.stdout.write("%-6s  |  %-30s  |  %s  |  %s\n"
            % (asn,asname,cc,prefix))
    else:
        sys.stdout.write("%-6s  |  %-30s  |  %s  |  %s\n"
            % (asn,asname,cc,prefix))
    return

if args.i:
    asn = re.sub( r"\AAS\s+", "", args.i, flags=re.I )
    cc, asname, prefixes = asninfo(int(asn))
    if prefixes is None:
        pass
    else: 
        for prefix in prefixes:
            writeinfo(asn, prefix, cc, asname)
else:
    for line in fileinput.input():
        asn = re.sub( r"\AAS\s+", "", line.rstrip(), flags=re.I )
        cc, asname, prefixes = asninfo(int(asn))
        if prefixes is None:
            continue
        else:
            for prefix in prefixes:
                writeinfo(asn, prefix, cc, asname)
