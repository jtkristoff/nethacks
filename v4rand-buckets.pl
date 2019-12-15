#!/usr/bin/perl
use strict;
use warnings;
$|=1;

# $0 - randomize all IPv4 addresses into file buckets
#
# then do something like:
#   for each in `ls genaddrs.*`
#   do
#       shuf -o $each.rand $each
#   done
#   cat *.rand >> randaddrs

use Cwd;
use Getopt::Std;
use Net::Patricia;

use constant MAXBUCKETS => 512;
use constant WORKDIR    => Cwd::cwd();
use constant FILEPREFIX => 'genaddrs';
use constant MAXADDRS   => 4294967295;

getopts('b:c:d:e:p:s:', \my %opts);

my $max_buckets = $opts{b} || MAXBUCKETS;
my @buckets  = [ 0 .. $max_buckets - 1 ];

$opts{s} || die "Missing starting IP address";
$opts{s} =~ m{ \A \d{1,3} (?: [.] \d{1,3} ){3} \Z }xms
            || die "Starting address invalid\n";

$opts{e} || die "Missing ending IP address";
$opts{e} =~ m{ \A \d{1,3} (?: [.] \d{1,3} ){3} \Z }xms
            || die "Ending address invalid\n";

my $workdir    = $opts{d} || WORKDIR;
my $fileprefix = $opts{p} || FILEPREFIX;

# good source of bogons:
#   https://www.team-cymru.org/Services/Bogons/fullbogons-ipv4.txt
my $pt_bogon;
my @bogons;
if ( $opts{c} ) {
    $pt_bogon = new Net::Patricia;
    parse_config( $opts{c} );
}

# convert dotted decimal IPv4 address to integer
my @sbytes = split /\./, $opts{s};
my $saddr_int = unpack( 'N', pack('C4', @sbytes) );

# verify IPv4 interger is in range
if( $saddr_int lt 0 || $saddr_int > MAXADDRS ) {
    die "Starting address out of range\n";
}

# convert dotted decimal IPv4 address to integer
my @ebytes = split /\./, $opts{e};
my $eaddr_int = unpack( 'N', pack('C4', @ebytes) );

# verify IPv4 interger is in range
if( $eaddr_int lt 0 || $eaddr_int > MAXADDRS ) {
    die "Ending address out of range\n";
}

# char numeric value for buckets
# for first name char use lower case of a-z0-9 then an _ for all others?
# do diff on these chunks?

for my $i ( 0 .. $max_buckets - 1 ) {
    $buckets[$i] = return_fh();
}

# open files
for my $i ( 0 .. $max_buckets - 1 ) {
    my $filename = "$workdir/$fileprefix.$i";
    open( $buckets[$i], '>',  $filename )
        or die "Can't open $filename: $!\n";
}

# NOTE: can't use range operator with bigints, e.g.
#       for my $int ($first_ip_int .. $last_ip_int) {
#       see: http://www.perlmonks.org/?node_id=762554
ADDR:
for ( my $int = $saddr_int; $int <= $eaddr_int; $int++ ) {
    my $addr = join( '.', reverse unpack('C4', pack('I', $int) ));
    if ( scalar @bogons > 0 ) {
        next ADDR if $pt_bogon->match_string($addr);
    }
    print { $buckets[int( rand($max_buckets) )] } "$addr\n";
}

for my $i ( 0 .. $max_buckets - 1 ) {
    close( $buckets[$i] )
        or die "Can't close $buckets[$i]: $!\n";
}

# get a local file handle
sub return_fh{
    local *FH;
    return *FH;
}

# parse a file that should contain one IPv4 dotted decimail per line
sub parse_config {
    my $filename = shift;

    open( my $CONFIG_FILE, '<', $filename )
        or die "Unable to open $filename: $!\n";

    LINE:
    while (defined (my $line=<$CONFIG_FILE>) ) {
        chomp $line;

        # skip blank lines or comments
        next LINE if $line =~ m{ \A \s* (?: [#] [.]* )? \Z }xms;
        # remove leading spaces
        $line =~ s{ \A \s* }{}xms;
        # remove trailing spaces
        $line =~ s{ \s* \Z }{}xms;

        # skip anything that doesn't look like a CIDR block, compact is OK
        next LINE if $line !~ m{
                                 \A
                                 \d{1,3} (?: [.] \d{1,3} ){1,3} [/] \d{1,2}
                                 \Z
                               }xms;

        # push CIDR block onto bogon array
        $pt_bogon->add_string($line);
    }
}
