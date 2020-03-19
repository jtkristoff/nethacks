#!/usr/bin/perl -T
use strict;
use warnings;
$|=1;

# $Id: sample-tcbgp-mapping.pl,v 1.1 2010/08/10 16:34:28 jtk Exp $
# sample code using the Team Cymru IP address to BGP DNS-based mapping service
# Also see: <http://www.cymru.com/jtk/blog/2010/08/10/#parsing-tcbgp-mapping>
# WARNING: not a complete, robust service interface, see blog for details

use Net::DNS;
use Net::IP;

while ( defined(my $line=<>) ) {
    chomp $line;
    printf "%-11s  |  %s\n", get_asn($line) || 'NA', $line;
}

sub get_asn {
    my $address = shift || return;
    my $res     = Net::DNS::Resolver->new;
    my $qname   = get_ptr_name($address);
    my $query   = $res->send( $qname, 'TXT', 'IN' );
    my $asn;

    return if !$query;
    return if $query->header->ancount < 1;

ANSWER:
    for my $answer ( $query->answer ) {
        next ANSWER if $answer->type ne 'TXT';
        ($asn) = $answer->rdatastr =~ m{ \A ["] (\d+) }xms;
        $asn ? last ANSWER : next ANSWER;
     }

    return $asn;
}

sub get_ptr_name {
    my $addr = shift || return;

    if ( $addr =~ /:/ ) {
        $addr  = substr new Net::IP ($addr)->reverse_ip, 0, -10;
        $addr .= '.origin6.asn.cymru.com';
    }
    else {
        $addr  = join( '.', reverse split( /\./, $addr ) );
        $addr .=  '.origin.asn.cymru.com';
    }
    return $addr;
}
