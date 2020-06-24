#!/usr/bin/perl -T
use strict;
use warnings;

# decode the Juniper-specific syslog priority values
#
# https://www.juniper.net/documentation/en_US/junos/topics/reference/general/syslog-facilities-severity-levels.html

$| = 1;

# juniper-specific localX priorities
my @facilities = qw(
    kernel
    user
    mail
    daemon
    authorization
    syslog
    printer
    news
    uucp
    clock
    authorization-private
    ftp
    ntp
    security
    console
    clock
    local0 
    local1/dfc
    local2/external
    local3/firewall
    local4/pfe
    local5/conflict-log
    local6/change-log
    local7/interactive-commands
);

my @severities = qw(
    emergency
    alert
    critical
    error
    warning
    notice
    info
    debug
);

while ( defined(my $line=<>) ) {
    chomp $line;
    $line =~ s{ \A \s* }{}xms;
    $line =~ s{ \s* \z }{}xms;

    next if $line !~ m{ \A (\d{1,3}) \z }xms;

    my $pri = $1;

    next if $pri > 191;

    my $facility = int( $pri / 8 );
    my $severity = $pri % 8;

    print "priority $pri -> facility: $facilities[$facility] ($facility), severity: $severities[$severity] ($severity)\n";
}
