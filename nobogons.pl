#!/usr/bin/perl -T
use strict;
use warnings;

# WARNING: this code does not surpress less specific prefixes containing bogons (e.g. 0.0.0.0/0).

use English;
use Net::Patricia;
use Getopt::Std;

$OUTPUT_AUTOFLUSH = 1;

use constant SUCCESS => 0;
use constant FAILURE => 1;

my $pt_bogon = new Net::Patricia;

getopts( 'c:q', \ my %opts );

my @bogons;
if ( $opts{c} ) {
    # try: http://www.team-cymru.org/Services/Bogons/fullbogons-ipv4.txt
    parse_config( $opts{c} );
}
else {
    # current as of 2017-02-26
    @bogons = qw(
        0.0.0.0/8
        10.0.0.0/8
        100.64.0.0/10
        127.0.0.0/8
        169.254.0.0/16
        172.16.0.0/12
        192.0.0.0/24
        192.0.2.0/24
        192.168.0.0/16
        198.18.0.0/15
        198.51.100.0/24
        203.0.113.0/24
        224.0.0.0/3
    );
    for (@bogons) {
        $pt_bogon->add_string($_);
    }
}

# (-q) quick - no input verification
# input is a per line, left-aligned, IPv4 dotted decimal w/ optional slash-notation mask
if ( $opts{q} ) {
    while ( defined(my $line=<>) ) {
        chomp $line;

        # bogon check
        next if $pt_bogon->match_string($line);

        # not a bogon, print it out
        print "$line\n";
    }
}
# default with input validation, slower
else {
    while ( defined(my $line=<>) ) {
        chomp $line;

        # valid IPv4 dotted decimal check
        rm_lead_trail_whitespace(\$line);
        next if ! valid_v4prefix($line);

        # bogon check
        next if $pt_bogon->match_string($line);

        # not a bogon, print it out
        print "$line\n";
    }
}

# remove leading and trailing whitespace from a string
sub rm_lead_trail_whitespace {
    my $string_ref = shift || return;
    $$string_ref =~ s{ \A \s* }{}xms;
    $$string_ref =~ s{ \s* \Z }{}xms;
    return;
}

# IPv4 octet and address range check
sub valid_v4addr {
    my $addr = shift;

    # weak IPv4 address format check
    return FAILURE if $addr !~ m{ \A \d{1,3} (?: [.] \d{1,3} ){3} \Z }xms;

    # each octet should be 0 to 255
    my @bytes = split /\./, $addr;
    for my $byte (@bytes) {
        return FAILURE if $byte > 255;
    }

    my $int = unpack( 'N', pack('C4', @bytes) );
    return FAILURE if $int > 4294967295; # 255.255.255.255 = int 4294967295

    return SUCCESS;
}

# IPv4 prefix format check
sub valid_v4prefix {
    my $prefix = shift;

    # in the off chance the delimter is the trailing character
    return FAILURE if $prefix =~ m{ [/] \Z }xms;

    my ( $addr, $mask )  = split /\//, $prefix;

    return FAILURE if ! valid_v4addr($addr);

    # unspecified mask is OK, trated as a /32
    return SUCCESS if !defined($mask);

    return FAILURE if $mask !~ m{ \A \d{1,2} \Z }xms;

    return FAILURE if $mask < 0 || $mask > 32;

    return SUCCESS;
}

# parse a file that should contain one IPv4 dotted decimail per line
sub parse_config {
    my $filename = shift;

    open( my $CONFIG_FILE, '<', $filename)
        or  die "Unable to open $filename: $!\n";

    while (defined (my $line=<$CONFIG_FILE>) ) {
        chomp $line;

        rm_lead_trail_whitespace(\$line);
        next if ! valid_v4prefix($line);

        # push CIDR block onto bogon array
        $pt_bogon->add_string($line);
    }
}
