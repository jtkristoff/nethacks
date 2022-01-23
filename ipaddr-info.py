#!/usr/bin/env python3

import argparse
import dns.resolver
import dns.reversename
import fileinput
import pyasn
import re
import sys

# init mapping tables and run-time caches
asnames   = {}
ptr_cache = {}

def ptr_answer(addr):
    """
    Return rdata or 'NA' if no answer
    """

    qname = dns.reversename.from_address(addr)
    try:
        # only gets one answer, probably good enough for our purposes
        answer = str(dns.resolver.resolve(qname, "PTR")[0])
    except:
        return 'NA'

    return answer

parser = argparse.ArgumentParser()
parser.add_argument('-a', default='/etc/pyasn.dat')  # pyasn .dat file
parser.add_argument('-n', default='/etc/asn.txt')    # RIPE asn.txt file
parser.add_argument('-i')   # IP address argument, otherwise read stdin
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

def addrinfo(ipaddr):
    asmap = asndb.lookup(ipaddr)
    if asmap[0] == None:
        asn = "NA"
        prefix = "NA"
        asname = "NA"
    else:
        asn = asmap[0]
        prefix = asmap[1]
        try:
            asname = asnames[asn]
        except:
            asname = "NA"
    try:
        rdata = ptr_cache[ipaddr]
    except:
        rdata = ptr_answer(ipaddr)
        ptr_cache[ipaddr] = rdata
    return prefix, asn, asname, rdata 

def writeinfo(ipaddr, prefix, asn, asname, rdata):
    if ':' in ipaddr:
        sys.stdout.write("%-37s  |  %-s  |  %6s  |  %s  |  %s\n"
            % (ipaddr,prefix,asn,asname,rdata))
    else:
        sys.stdout.write("%-15s  |  %-s  |  %6s  |  %s  |  %s\n"
            % (ipaddr,prefix,asn,asname,rdata))
    return

if args.i:
    prefix, asn, asname, rdata = addrinfo(args.i)
    writeinfo(args.i, prefix, asn, asname, rdata)
else:
    for line in fileinput.input():
        ipaddr = line.rstrip()
        prefix, asn, asname, rdata = addrinfo(ipaddr)
        writeinfo(ipaddr, prefix, asn, asname, rdata)
