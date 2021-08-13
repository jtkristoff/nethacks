#!/usr/bin/perl -T
use strict;
use warnings;

# compactaddrs - aggregate addr blocks

use NetAddr::IP qw( Compact :lower );
use Net::IP qw (:PROC);

my @v4blocks;
my @v6blocks;

while( defined(my $line=<>) ) {
    chomp $line;

    if ( $line =~ /:/ ) {
        push @v6blocks, NetAddr::IP->new($line);
    }
    else {
        push @v4blocks, NetAddr::IP->new($line);
    }
}

if ( scalar @v4blocks > 0 ) {
#    print "# IPv4 aggregate prefixes\n";

    my @aggregates = Compact(@v4blocks);
    for my $prefix (@aggregates) {
        print "$prefix\n";
    }
}

if ( scalar @v6blocks > 0 ) {
#    print " #IPv6 aggregate prefixes\n";

    my @aggregates = Compact(@v6blocks);
    for my $prefix (@aggregates) {
	my ($net6, $mask6) = split /\//, $prefix, 2;
        print lc(ip_compress_address($net6, $mask6)),"/$mask6\n";
    }
}

#print "\n";
