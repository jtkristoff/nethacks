#!/usr/bin/perl -T
use strict;
use warnings;

$| = 1;

use Net::IP;

my $netblock = new Net::IP($ARGV[0]) || die;
do {
    print $netblock->ip(), "\n";
} while (++$netblock);
