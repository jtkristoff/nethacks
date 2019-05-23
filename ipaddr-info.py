#!/usr/bin/env python3

import dns.resolver
import dns.reversename
import fileinput
import sys

def get_tc_ptr_name(addr):
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
    Return comma-delimited string of origin ASNs given an IPv4 or IPv6 address
    """

    qname = get_tc_ptr_name(addr)

    try:
        answer = dns.resolver.query(qname, rdtype='TXT', rdclass='IN')
    except:
        # TODO: send this to stderr, log, or use traceback.format_exc()
        return 'NA'

    asns = set()
    for rdata in answer:
        # https://www.cymru.com/jtk/blog/2010/08/10/#parsing-tcbgp-mapping
        #   "49152 [...] | 192.0.2.0/24 | AA | registry | 1970-01-01"
        #   [...]
        # parse each TXT line, extract one or more ASNs per line
        rdatatxt = rdata.strings
        for line in rdatatxt:
            line = line.decode()
            asnlist = line.split('|', 1)[0].split()
            asns.update(asnlist)

    # remove duplicate ASNs
    return ','.join(asns)

def ptr_answer(addr):
    """
    Return rdata or 'NA' if no answer
    """

    qname = dns.reversename.from_address(addr)
    try:
        # only gets one answer, probably good enough for our purposes
        answer = str(dns.resolver.query(qname, "PTR")[0])
    except:
        return 'NA'

    return answer

for line in fileinput.input():
    ipaddr = line.rstrip()
    asn = get_asn(ipaddr)
    rdata = ptr_answer(ipaddr)

    if ':' in ipaddr:
        sys.stdout.write("%-37s  |  %10s  |  %s\n" % (ipaddr,asn,rdata))
    else:
        sys.stdout.write("%-15s  |  %10s  |  %s\n" % (ipaddr,asn,rdata))

sys.exit(0)
