#!/usr/bin/env python3

# sample code using pyasn and RIPE's ASN to AS name mapping file
# Also see: <https://dataplane.org/jtk/blog/2020/12/addr-to-as-mapping/>
# WARNING: not a complete, robust service interface, see blog for details

import argparse
import fileinput
import pyasn
import re
import sys

parser = argparse.ArgumentParser()
parser.add_argument('-a', default='pyasn.dat')  # pyasn .dat file
parser.add_argument('-n', default='asn.txt')    # RIPE asn.txt file
#
# to combine argparse and fileinput from stdin:
#   https://gist.github.com/martinth/ed991fb8cdcac3dfadf7
#
parser.add_argument('files', metavar='FILE', nargs='*', help='files to read, if empty, stdin is used')
args = parser.parse_args()

# load pyasn .dat file into radix tree and provide lookup function
try:
    asndb = pyasn.pyasn(args.a)
except:
    sys.stderr.write("Failed to import pyasn .dat file: %s\n" % (args.a))
    sys.exit(1)

# open https://ftp.ripe.net/ripe/asnames/asn.txt for reading
try:
    ripe_asn_txt = open(args.n, 'r')
except:
    sys.stderr.write('Unable to open %s for reading\n' % (args.n))
    sys.exit(1)

asnames = {}  # init the ASN to AS name mapping dictionary

# build the ASN to AS name mapping dictionary
for line in ripe_asn_txt:
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
    asnames[int(asn)] = name[:30]

ripe_asn_txt.close()

# do the IP addr to AS mapping and send to stdout
for line in fileinput.input(files=args.files):
    ipaddr = line.strip()

    asn = asndb.lookup(ipaddr)
    if asn[0] == None:
        asn = "NA"
        asname = "NA"
    else:
        asn = asn[0]
        try:
            asname = asnames[asn]
        except:
            asname = "NA"

    if ':' in ipaddr:
        sys.stdout.write("%-37s  |  %10s  |  %s\n" % (ipaddr,str(asn),asname))
    else:
        sys.stdout.write("%-15s  |  %10s  |  %s\n" % (ipaddr,str(asn),asname))

sys.exit(0)
