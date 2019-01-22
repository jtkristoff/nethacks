#!/usr/bin/python

import dns.resolver
import dns.reversename
import fileinput
import re
import sys

def get_ptr_name(addr):
    """
    Return a Cymru BGP lookup PTR name given an IPv4 or IPv6 address
    """

    # use library to get reverse name
    name = dns.reversename.from_address(addr).to_text(omit_final_dot=True)
    # remove in-addr.arpa or ip6.arpa suffix
    name = name.rsplit('.', 2)[0]

    # append v4 or v6 suffix depending on ip version
    if ':' in addr:
        name += '.origin6.asn.cymru.com.'
    else:
        name += '.origin.asn.cymru.com.'

    return name

def get_asn(addr):
    """
    Return a list of origin ASNs given an IPv4 or IPv6 address
    """

    qname = get_ptr_name(addr)

    try:
        answer = dns.resolver.query(qname, rdtype='TXT', rdclass='IN')
    except:
        # TODO: send this to stderr, log, or use traceback.format_exc()
        return ['NA']

    asns = []
    for rdata in answer:
        # https://www.cymru.com/jtk/blog/2010/08/10/#parsing-tcbgp-mapping
        #   "49152 [...] | 192.0.2.0/24 | AA | registry | 1970-01-01"
        #   [...]
        # parse each TXT line, extract one or more ASNs per line
        rdatatxt = rdata.strings
        for line in rdatatxt:
            asnstr = [x.strip() for x in line.split('|')]
            asnlist = asnstr[0].split()
            asns.extend(asnlist)

    # remove duplicate ASNs, then return the list
    asns = list(set(asns))
    return asns

# expect IP addrs, one per line
for line in fileinput.input():
    line = line.rstrip()

    asns = get_asn(line)
    for asn in asns:
        sys.stdout.write('%-10s | %s\n' % (asn, line))
