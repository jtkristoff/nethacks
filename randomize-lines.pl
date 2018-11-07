#!/usr/bin/perl -wT
use strict;
$|=1;

# randomize lines in a file, adapted from the Perl Cookbook

sub fys {
    my $array=shift;
    my $i;
    for ( $i=@$array; --$i; ) {
        my $j = int rand ($i+1);
        next if $i == $j;
        @$array[$i,$j]=@$array[$j,$i];
    }
}

my @lines = ();

while ( defined(my $input = <>)) {
    chomp $input;
    push(@lines, $input);
}

fys(\@lines);
foreach(@lines) {
    print "$_\n";
}
