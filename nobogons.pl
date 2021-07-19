#!/usr/bin/perl -T
use strict;
use warnings;

$| = 1;

# WARNING: this code does not surpress less specific prefixes containing bogons (e.g. 0.0.0.0/0).

use Getopt::Std;
use Net::Patricia;

my $pt_bogon  = new Net::Patricia;
my $pt_bogon6 = new Net::Patricia(AF_INET6);

# -f   IPv4_bogon_list, one prefix per line (optional, default=built-in)
# -s   IPv6_bogon_list, one prefix per line (optional, default=built-in)
# -v   enable_verbose (default=disabled)

getopts( 'f:s:v', \ my %opts );

my @bogons;
if ( $opts{f} ) {
    # try: http://www.team-cymru.org/Services/Bogons/fullbogons-ipv4.txt
    import_bogons( { file => $opts{f}, pt => $pt_bogon } );
}
else {
    # current as of 2020-05-19
    @bogons = qw(
        0.0.0.0/8
        10.0.0.0/8
        100.64.0.0/10
        127.0.0.0/8
        169.254.0.0/16
        172.16.0.0/12
        192.0.0.0/24
        192.0.2.0/24
        192.18.0.0/15
        192.88.99.0/24
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

my @bogons6;
if ( $opts{s} ) {
    # try: http://www.team-cymru.org/Services/Bogons/fullbogons-ipv6.txt
    import_bogons( { file => $opts{s}, pt => $pt_bogon6 } );
}
else {
    # current as of 2020-05-19
    @bogons6 = qw(
        ::/128
        ::1/128
        ::ffff:0:0/96
        64:ff9b:1::/48
        100::/64
        2001::/32
        2001:2::/48
        2001:db8::/32
        2002::/16
    );
    for (@bogons6) {
        $pt_bogon6->add_string($_);
    }
}

while ( defined(my $line=<>) ) {
    # remove white space
    chomp $line;
    $line =~ s{ \A \s* }{}xms;
    $line =~ s{ \s* \z }{}xms;

    # IPv6?
    if ( $line =~ m{ [:] }xms ) {
        if ( $pt_bogon6->match_string($line) ) { 
            print STDERR "bogon6 detected, skipping: $line\n" if $opts{v};
            next;
        }
    }
    else {
        if ( $pt_bogon->match_string($line) ) {        
            print STDERR "bogon detected, skipping: $line\n" if $opts{v};
            next;
        }
    }

    # not a bogon, print it out
    print "$line\n";
}

# parse a file that should contain one IPv4 dotted decimail per line
sub import_bogons {
    my ($arg_ref) = @_;
    my $file      = $arg_ref->{file} or return;
    my $pt        = $arg_ref->{pt} or return;

    open( my $CONFIG_FILE, '<', $file )
        or  die "Unable to open $file: $!\n";

    while (defined (my $line=<$CONFIG_FILE>) ) {
        chomp $line;
        $line =~ s{ \A \s* }{}xms;
        $line =~ s{ \s* \z }{}xms;
        $line =~ s{ \s* [#] .* \z }{}xms;

        # skip blank lines or comments
        next if $line =~ m{ \A \s* (?: [#] .* )? \z }xms;
        
        # push CIDR block onto pt array
        $pt->add_string($line);
    }
}
