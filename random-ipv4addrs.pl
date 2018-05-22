#!/usr/bin/perl -T
use strict;
use warnings;
$|=1;

# $Id: random-ipv4addrs.pl,v 1.2 2012/07/26 20:23:28 jtk Exp $
# generate a set of random IPv4 addresses

use Getopt::Std;

use constant DEFAULT_COUNT  => 10**7;
use constant MAX_V4_INT     => 2**32;

getopts( 'c:', \my %opts );

my $addr_count = $opts{c} || DEFAULT_COUNT;
if ( $addr_count !~ m{ \A \d+ \Z }xms ) {
    die "count($addr_count): must be an integer";
}

while ( $addr_count-- ) {
    my $addr = int( rand MAX_V4_INT );

    # this runs faster than multiple shifts or using Socket/pack calls
    my $fourth_octet = $addr & 0xff;
    $addr >>= 8;
    my $third_octet = $addr & 0xff;
    $addr >>= 8;
    my $second_octet = $addr & 0xff;
    $addr >>= 8;
    my $first_octet = $addr;

    print "$first_octet.$second_octet.$third_octet.$fourth_octet\n";
};
