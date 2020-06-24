#!/usr/bin/perl
use strict;
use warnings;

use Socket;

my %stats;

while ( defined(my $line=<>) ) {
    chomp $line;

# formatting is specific to the local environment, this is one example of how you might see it:
#
# 2019-05-07T23:55:46+00:00 ns1 named[128987]: 07-May-2019 23:55:46.519 client 192.0.2.1#54045 (foo.example.edu): view internal-in: query: foo.example.edu IN A + (10.64.22.100)

    next if $line !~ m{ \s client \s ([^\#]+) [#] \d+ \s [\(][^\)]+[\)][:] \s view \s [^:]+ [:] \s query: \s (\S+) \s IN \s (\S+) \s }xms;

    my $saddr = $1;
    my $qname = lc $2;
    my $type = $3;

    my ( undef, $ns, undef ) = split /\s+/, $line, 3;

    $stats{saddr}{$saddr}++;
    $stats{qname}{$qname}++;
    $stats{type}{$type}++;
    $stats{ns}{$ns}++;
}

my $counter;

print "# BIND query log summary statistics\n";
print "\n";

$counter =1;
printf "%-15s  %s\n", '#count', 'client query sources';
for my $saddr ( sort {$stats{saddr}{$b} - $stats{saddr}{$a}} keys %{$stats{saddr}} ) { 
    printf "%-15s  %s (%s)\n", commify($stats{saddr}{$saddr}), $saddr, get_hostname($saddr);
    last if $counter++ == 10;
}

print "\n";

$counter = 1;
printf "%-15s  %s\n", '#count', 'type';
for my $type ( sort {$stats{type}{$b} - $stats{type}{$a}} keys %{$stats{type}} ) { 
    printf "%-15s  %s\n", commify($stats{type}{$type}), $type;
    last if $counter++ == 10;
}

print "\n";

$counter = 1;
printf "%-15s  %s\n", '#count', 'qname';
for my $qname ( sort {$stats{qname}{$b} - $stats{qname}{$a}} keys %{$stats{qname}} ) { 
    printf "%-15s  %s\n", commify($stats{qname}{$qname}), $qname;
    last if $counter++ == 10;
}

print "\n";

$counter = 1;
printf "%-15s  %s\n", '#count', 'name server';
for my $ns ( sort {$stats{ns}{$b} - $stats{ns}{$a}} keys %{$stats{ns}} ) { 
    printf "%-15s  %s\n", commify($stats{ns}{$ns}), $ns;
    last if $counter++ == 10;
}

sub get_hostname{
    my $addr = shift or return 'NA';
    my $name = gethostbyaddr(inet_aton($addr), AF_INET) || '-';
    return $name;
}

# from Perl Cookbook
sub commify {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text;
}
