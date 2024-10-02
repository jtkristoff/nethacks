# nethacks

(mostly) Network tools and hacks

* [asnames.sh](asnames.sh) fetch ASN to AS name mapping file from RIPE
* [asn-dump.py](asn-dump.py) all prefixes originated by an ASN
* [bind-query-report.pl](bind-query-report.pl) BIND query log report
* [bogons.sh](bogons.sh) Overly elaborate script to help automate fetching TC full bogon lists
* [compactaddrs.pl](compactaddrs.pl) aggregates contiguous IPv4/IPv6 addresses into prefixes
* [csv2json.py](csv2json.py) converts CSV (header required) to compact JSON
* [enumerate-cidr.pl](enumerate-cidr.pl) enumerate all IP addresses in a CIDR prefix
* [gpg-ring-check.sh](gpg-ring-check.sh) examine a GnuPG public key ring for expiring, expired, revoked keys
* [geolocip.py](geolocip.py) map IP addresses to MaxMind geolocation
* [ipaddr-info.py](ipaddr-info.py) map IP addresses to BGP ASN with PTR name
* [ipaddr-info-tc.py](ipaddr-info-tc.py) map IP addressesto BGP ASN with PTR name (TC remote lookup version)
* [mresolv-jtk](mresolv-jtk) fork of Net::DNS demo/mresolv, see code for changes
* [nobogons.pl](nobogons.pl) IPv4/IPv6 address prefixes via STDIN, remove bogons, back to STDOUT
* [priority-decode.pl](priority-decode.pl) Juniper-specific syslog priority decoder
* [pubsuffic.sh](pubsuffix.sh) Overly elaborate script to automate fetching the PSL
* [random-ipv4addrs.go](random-ipv4addrs.go) Go implementation by Brett Lykins
* [random-ipv4addrs.pl](random-ipv4addrs.pl) generates a random list of IPv4 addresses to STDOUT, 10 million by default
* [random-ipv4addrs.py](random-ipv4addrs.py) rough, simpler equivalent of the Perl version
* [randomize-lines.pl](randomize-lines.pl) randomize lines in a file
* [refresh-pyasn-dat.sh](refresh-pyasn-dat.sh) fetch latest RIB data for PyASN
* [pcapr.sh](pcapr.sh) capture traffic and write pcap files at regular intervals
* [pcapsum.pl](pcapsum.pl) libpcap packet summarization tool
* [prr-asn.py](prr-asn.py) map IP addresses to origin ASN with pyasn and RIPE's asn.txt
* [secure-junos-mcast.html](secure-junos-mcast.html) Lenny's Junos secure multicast template
* [tc-asn.pl](tc-asn.pl) map IP addresses to origin ASN with Cymru's address mapping service (original Perl version)
* [tc-asn.py](tc-asn.py) map IP addresses to origin ASN with Cymru's address mapping service (Python version)
* [v4rand-buckets.pl](v4rand-buckets.pl) randomize all IPv4 addresses into file buckets
