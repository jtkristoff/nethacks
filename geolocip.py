#!/usr/bin/env python3

import argparse
import fileinput
import geoip2.database
import sys

maxmind_cc_db   = '/etc/GeoLite2-Country.mmdb'
maxmind_city_db = '/etc/GeoLite2-City.mmdb'

parser = argparse.ArgumentParser()
parser.add_argument('-i')   # IP address argument, otherwise read stdin
args = parser.parse_args()

def geoloc(ipaddr):
    with geoip2.database.Reader(maxmind_cc_db) as reader:
        try:
            response = reader.country(ipaddr)
            cc = response.country.iso_code
        except:
            cc = '-'

    with geoip2.database.Reader(maxmind_city_db) as reader:
        try:
            response = reader.city(ipaddr)
            city = response.city.name
            lat  = response.location.latitude
            long = response.location.longitude
        except:
            city = '-'
            lat = '-'
            long = '-'

    return lat, long, cc, city

def writeinfo(ipaddr, lat, long, cc, city):
    if ':' in ipaddr:
        sys.stdout.write("%-37s  |  %s  |  %s  |  %s  |  %s\n"
            % (ipaddr,lat,long,cc,city))
    else:
        sys.stdout.write("%-15s  |  %s  |  %s  |  %s  |  %s\n"
            % (ipaddr,lat,long,cc,city))
    return

if args.i:
    lat, long, cc, city = geoloc(args.i)
    writeinfo(args.i, lat, long, cc, city)
else:
    for line in fileinput.input():
        ipaddr = line.rstrip()
        lat, long, cc, city = geoloc(ipaddr)
        writeinfo(ipaddr, lat, long, cc, city)

sys.exit(0)
