#!/usr/bin/perl -T
use strict;
use warnings;
$| = 1;

# $Id: pcapsum.pl,v 1.6 2015/04/28 18:55:08 jtk Exp $

use Getopt::Std;
use Net::Pcap;
use NetPacket::ARP qw(:ALL);
use NetPacket::Ethernet qw(:ALL);
use NetPacket::ICMP qw(:ALL);
use NetPacket::IGMP qw(:ALL);
use NetPacket::IP qw(:ALL);
use NetPacket::TCP qw(:ALL);
use NetPacket::UDP qw(:ALL);
use Net::DNS;
use Readonly;
use Switch;

Readonly my $DISABLED          => 0;
Readonly my $ENABLED           => 1;
Readonly my $READ_ALL_PKTS     => -1;
Readonly my $DEFAULT_LIST_SIZE => 10;
Readonly my $UNKNOWN_ERROR     => -1;
Readonly my $PROGRAM_NAME      => 'pcapsum';
Readonly my $PROGRAM_AUTHOR    => 'John Kristoff <jtk@cymru.com>';
Readonly my $PROGRAM_URL       => 'http://www.cymru.com/jtk/code/';
Readonly my ($PROGRAM_VERSION) => '$Revision: 1.6 $'
                                      =~ m{ [\$] Revision: \s+ (\S+) }xms;

Readonly my $USAGE => <<"END_USAGE";
Usage: $0 [ -bu ] [ -c count]
          [ -m max_list_size ] pcap_file
Options:
    -c    : exit after reading 'count' packets
    -b    : disable big list hashes (reduces memory requirements)
    -m    : output no more than 'max_list_size' entries in lists
    -u    : UTC timestamps
END_USAGE

if ( scalar @ARGV < 1 ) {
    die $USAGE;
}

getopts( 'bc:m:u', \ my %opts );

my $big_lists           = $opts{b} ? $DISABLED : $ENABLED;
my $pkts_to_read        = $opts{c} || $READ_ALL_PKTS;
my $max_list_size       = $opts{m} || $DEFAULT_LIST_SIZE;
my $utc_time            = $opts{u} || $DISABLED;

my %pcap_stat = ();

my $file = $ARGV[0];
my $io_error;
my $pcap = pcap_open_offline( $file, \$io_error )
           || dienice( __LINE__,  "Can't read $file: $io_error" );

my $datalink_type = pcap_datalink($pcap);
pcap_loop( $pcap, $pkts_to_read, \&process_pcap, $datalink_type );
pcap_close($pcap);

process_stats();

exit;

### sub-routines

sub process_pcap {
    my ( $type, $header, $raw ) = @_;

    my $type_name = pcap_datalink_val_to_name($type);
    my $timestamp = $header->{tv_sec};

    if ( !$pcap_stat{start_time} || $timestamp < $pcap_stat{start_time} ) {
        $pcap_stat{start_time} = $timestamp;
    }
    if ( !$pcap_stat{stop_time} || $timestamp > $pcap_stat{stop_time} ) {
        $pcap_stat{stop_time} = $timestamp;
    }

    $pcap_stat{pkts}++;

    switch($type) {
        case DLT_EN10MB    { parse_enet($raw); }
        else               { warn "No parser for datalink: $type_name\n"; }
    }

    return;
}

sub parse_enet {
    my $pkt       = NetPacket::Ethernet->decode(shift);
    my $payload   = $pkt->{data};

    switch( $pkt->{type} ) {
        case ETH_TYPE_IP        { $pcap_stat{enet}{type}{IP}++; }
        case ETH_TYPE_ARP       { $pcap_stat{enet}{type}{ARP}++; }
        case ETH_TYPE_APPLETALK { $pcap_stat{enet}{type}{ATALK}++; }
        case ETH_TYPE_SNMP      { $pcap_stat{enet}{type}{SNMP}++; }
        case ETH_TYPE_IPv6      { $pcap_stat{enet}{type}{IPv6}++; }
        case ETH_TYPE_PPP       { $pcap_stat{enet}{type}{PPP}++; }
        else                    { $pcap_stat{enet}{type}{other}++; }
    }

    # currently we only have an IPv4 handler
    switch( $pkt->{type} ) {
        case ETH_TYPE_IP        { parse_ip($payload); }
        else                    {}
    }

    return;
}

sub parse_ip {
    my $pkt     = NetPacket::IP->decode(shift);
    my $payload = $pkt->{data};

    $pcap_stat{ip}{pkts}++;

    if ($big_lists) {
        $pcap_stat{ip}{srcaddr}{ $pkt->{src_ip} }++;
        $pcap_stat{ip}{dstaddr}{ $pkt->{dest_ip} }++;
    }

    switch( $pkt->{len} ) {
        case { $_[0] <= 64   }   { $pcap_stat{ip}{length}{'<=64'  }++; }
        case { $_[0] <= 128  }   { $pcap_stat{ip}{length}{'<=128' }++; }
        case { $_[0] <= 512  }   { $pcap_stat{ip}{length}{'<=512' }++; }
        case { $_[0] <= 1024 }   { $pcap_stat{ip}{length}{'<=1024'}++; }
        case { $_[0] <= 1500 }   { $pcap_stat{ip}{length}{'<=1500'}++; }
        else                     { $pcap_stat{ip}{length}{'>1500' }++; }
    }

    switch( $pkt->{proto} ) {
        case IP_PROTO_ICMP    { $pcap_stat{ip}{proto}{ICMP}++;
                                parse_icmp($payload); }
        case IP_PROTO_IGMP    { $pcap_stat{ip}{proto}{IGMP}++;
                                parse_igmp($payload); }
        case IP_PROTO_TCP     { $pcap_stat{ip}{proto}{TCP}++;
                                parse_tcp($payload); }
        case IP_PROTO_UDP     { $pcap_stat{ip}{proto}{UDP}++;
                                parse_udp($payload); }
        else                  { $pcap_stat{ip}{proto}{other}++; }
    }

    return;
}

sub parse_icmp {
    my $pkt = NetPacket::ICMP->decode(shift);

    $pcap_stat{icmp}{pkts}++;

    switch( $pkt->{type} ) {
        case ICMP_ECHOREPLY      { $pcap_stat{icmp}{type}{echo_reply}++; }
        case ICMP_UNREACH        { $pcap_stat{icmp}{type}{unreachable}++; }
        case ICMP_SOURCEQUENCH   { $pcap_stat{icmp}{type}{source_quench}++; }
        case ICMP_REDIRECT       { $pcap_stat{icmp}{type}{redirect}++; }
        case ICMP_ECHO           { $pcap_stat{icmp}{type}{echo}++; }
        case ICMP_ROUTERADVERT   { $pcap_stat{icmp}{type}{router_advert}++; }
        case ICMP_ROUTERSOLICIT  { $pcap_stat{icmp}{type}{router_solicit}++; }
        case ICMP_TIMXCEED       { $pcap_stat{icmp}{type}{time_exceeded}++; }
        case ICMP_PARAMPROB      { $pcap_stat{icmp}{type}{parameter_prob}++; }
        case ICMP_TSTAMP         { $pcap_stat{icmp}{type}{timestamp}++; }
        case ICMP_TSTAMPREPLY    { $pcap_stat{icmp}{type}{tstamp_reply}++; }
        case ICMP_IREQ           { $pcap_stat{icmp}{type}{info_request}++; }
        case ICMP_IREQREPLY      { $pcap_stat{icmp}{type}{info_reply}++; }
        case ICMP_MASKREQ        { $pcap_stat{icmp}{type}{mask_request}++; }
        case ICMP_MASKREPLY      { $pcap_stat{icmp}{type}{mask_reply}++; }
        else                     { $pcap_stat{icmp}{type}{other}++; }
    }

    return;
}

# as of NetPacket 0.41.1, no IGMPv2 support, so this is pretty useless :-(
sub parse_igmp {
    my $pkt = NetPacket::IGMP->decode(shift);

    $pcap_stat{igmp}{pkts}++;

    switch( $pkt->{type} ) {
        case IGMP_MSG_HOST_MQUERY   { $pcap_stat{igmp}{type}{query}++; }
        case IGMP_MSG_HOST_MREPORT  { $pcap_stat{igmp}{type}{report}++; }
        else                        { $pcap_stat{igmp}{type}{other}++; }
    }

    switch( $pkt->{group_addr} ) {
        case IGMP_IP_NO_HOSTS    { $pcap_stat{igmp}{grpaddr}{no_hosts}++; }
        case IGMP_IP_ALL_HOSTS   { $pcap_stat{igmp}{grpaddr}{all_hosts}++; }
        case IGMP_IP_ALL_ROUTERS { $pcap_stat{igmp}{grpaddr}{all_rtrs}++; }
        else                     { $pcap_stat{igmp}{grpaddr}{other}++; }
    }

    return;
}

sub parse_tcp {
    my $pkt       = NetPacket::TCP->decode(shift);
    my $payload   = $pkt->{data};

    $pcap_stat{tcp}{pkts}++;
    $pcap_stat{tcp}{src_port}{ $pkt->{src_port} }++;
    $pcap_stat{tcp}{dst_port}{ $pkt->{dest_port} }++;

    switch( $pkt->{flags} ) {
        case { $_[0] & FIN }  { $pcap_stat{tcp}{flags}{FIN}++; next; }
        case { $_[0] & SYN }  { $pcap_stat{tcp}{flags}{SYN}++; next; }
        case { $_[0] & RST }  { $pcap_stat{tcp}{flags}{RST}++; next; }
        case { $_[0] & PSH }  { $pcap_stat{tcp}{flags}{PSH}++; next; }
        case { $_[0] & ACK }  { $pcap_stat{tcp}{flags}{ACK}++; next; }
        case { $_[0] & URG }  { $pcap_stat{tcp}{flags}{URG}++; next; }
        case { $_[0] & ECE }  { $pcap_stat{tcp}{flags}{ECE}++; next; }
        case { $_[0] & CWR }  { $pcap_stat{tcp}{flags}{CWR}++; next; }
    }
 
    if ( $pkt->{dest_port} == 53 || $pkt->{src_port} == 53 ) {
        parse_dns( $payload );
    }

    return;
}

sub parse_udp {
    my $pkt     = NetPacket::UDP->decode(shift);
    my $payload = $pkt->{data};

    $pcap_stat{udp}{pkts}++;
    $pcap_stat{udp}{src_port}{ $pkt->{src_port} }++;
    $pcap_stat{udp}{dst_port}{ $pkt->{dest_port} }++;

    if ( $pkt->{dest_port} == 53 || $pkt->{src_port} == 53 ) {
        parse_dns( $payload );
    }

    return;
}

sub parse_dns { 
    my $pkt = shift;
    my $dns = Net::DNS::Packet->new(\$pkt);

    return if !defined $dns;

    my $header    = $dns->header;
    my @questions = $dns->question;

    $pcap_stat{dns}{pkts}++;
    $pcap_stat{dns}{opcode}{ $header->opcode }++;
    $pcap_stat{dns}{rcode}{ $header->rcode }++;

    $pcap_stat{dns}{aa}++ if $header->aa;
    $pcap_stat{dns}{ra}++ if $header->ra;
    $pcap_stat{dns}{rd}++ if $header->rd;
    $pcap_stat{dns}{tc}++ if $header->tc;
    $pcap_stat{dns}{cd}++ if $header->cd;
    $pcap_stat{dns}{ad}++ if $header->ad;
    $pcap_stat{dns}{qr}++ if $header->qr;
    $pcap_stat{dns}{qu}++ if !$header->qr;

    if ($big_lists) {
        for my $question (@questions) {
            $pcap_stat{dns}{qname}{ $question->qname }++;
            $pcap_stat{dns}{qtype}{ $question->qtype }++;
        }
    }

    return;
}

sub process_stats {

    print_header();

    if ( defined $pcap_stat{pkts} ) {
        print_summary();
        print_enet();
    }

    if ( defined $pcap_stat{ip}{pkts} ) {
        print_ip();
    }

    if ( defined $pcap_stat{icmp}{pkts} ) {
        print_icmp();
    }

    if ( defined $pcap_stat{igmp}{pkts} ) {
        print_igmp();
    }

    if ( defined $pcap_stat{tcp}{pkts} ) {
        print_tcp();
    }

    if ( defined $pcap_stat{udp}{pkts} ) {
        print_udp();
    }

    if ( defined $pcap_stat{dns}{pkts} ) {
        print_dns();
    }

    return;
}

sub print_header {
    print "# $PROGRAM_NAME $PROGRAM_VERSION\n";
    print "# $PROGRAM_AUTHOR | $PROGRAM_URL\n";

    print "\n";

    return;
}

sub print_summary {
    my ($start_time, $stop_time);

    print "# Summary\n";
    print "Frames: $pcap_stat{pkts}\n";

    if ( $utc_time ) {
        $start_time = gmtime( $pcap_stat{start_time} );
        $stop_time  = gmtime( $pcap_stat{stop_time} );
    } else {
        $start_time = localtime( $pcap_stat{start_time} );
        $stop_time  = localtime( $pcap_stat{stop_time} );
    }
    print "Start time: $start_time\n";
    print "Stop time: $stop_time\n";

    print "\n";

    return;
}

sub print_enet {
    my $value;       # generic hash value placeholder in for loops
    my $list_counter = 0;
    my %type         = %{ $pcap_stat{enet}{type} };

    print "# Ethernet Types\n";

    ETYPE:
    for $value ( sort {$type{$b} - $type{$a}} keys %type ) {
        $list_counter++;
        printf "%-6s\t%s\n", $value, $type{$value};
        last ETYPE if $list_counter == $max_list_size;
    }

    print "\n";

    return;
}

sub print_ip {
    my $value;       # generic hash value placeholder in for loops
    my $list_counter = 0;
    my %length       = %{ $pcap_stat{ip}{length} };
    my %proto        = %{ $pcap_stat{ip}{proto} };

    # set length to zero if undef, because gaps in output may be confusing
    $length{'<=64'  } ||= 0;
    $length{'<=128' } ||= 0;
    $length{'<=512' } ||= 0;
    $length{'<=1024'} ||= 0;
    $length{'<=1500'} ||= 0;
    $length{'>1500' } ||= 0;

    print "# Internet Protocol\n";
    print "IP datagrams: $pcap_stat{ip}{pkts}\n";

    if ($big_lists) {
        my %srcaddr = %{ $pcap_stat{ip}{srcaddr} };

        print "# Source IP addresses\n";

        SRCADDR:
        for $value ( sort {$srcaddr{$b} - $srcaddr{$a}} keys %srcaddr ) {
            $list_counter++;
            printf "%-15s\t\t%s\n", $value, $srcaddr{$value};
            last SRCADDR if $list_counter == $max_list_size;
        }

        $list_counter = 0;
    }

    if ($big_lists) {
        my %dstaddr      = %{ $pcap_stat{ip}{dstaddr} };

        print "# Destination IP addresses\n";

        DSTADDR:
        for $value ( sort {$dstaddr{$b} - $dstaddr{$a}} keys %dstaddr ) {
            $list_counter++;
            printf "%-15s\t\t%s\n", $value, $dstaddr{$value};
            last DSTADDR if $list_counter == $max_list_size;
        }

        $list_counter = 0;
    }

    print "# IP total datagram lengths\n";

    LENGTH:
    for $value ( sort {$length{$b} - $length{$a}} keys %length ) {
        $list_counter++;
        printf "%-8s\t%s\n", $value, $length{$value};
        last LENGTH if $list_counter == $max_list_size;
    }

    $list_counter = 0;

    print "# IP protocols\n";

    PROTO:
    for $value ( sort {$proto{$b} - $proto{$a}} keys %proto ) {
        $list_counter++;
        printf "%-7s\t%s\n", $value, $proto{$value};
        last PROTO if $list_counter == $max_list_size;
    }

    print "\n";

    return;
}

sub print_icmp {
    my $value;       # generic hash value placeholder in for loops
    my $list_counter = 0;
    my %type         = %{ $pcap_stat{icmp}{type} };

    print "# Internet Control Message Protocol\n";
    print "ICMP messages: $pcap_stat{icmp}{pkts}\n";

    print "# ICMP types\n";

    TYPE:
    for $value ( sort {$type{$b} - $type{$a}} keys %type ) {
        $list_counter++;
        printf "%-15s\t%s\n", $value, $type{$value};
        last TYPE if $list_counter == $max_list_size;
    }

    print "\n";

    return;
}

sub print_igmp {
    my $value;       # generic hash value placeholder in for loops
    my $list_counter = 0;
    my %type         = %{ $pcap_stat{igmp}{type} };
    my %grpaddr     = %{ $pcap_stat{igmp}{grpaddr} };

    print "# Internet Group Management Protocol\n";
    print "IGMP messages: $pcap_stat{igmp}{pkts}\n";

    print "# IGMP types\n";

    TYPE:
    for $value ( sort {$type{$b} - $type{$a}} keys %type ) {
        $list_counter++;
        printf "%-7s\t%s\n", $value, $type{$value};
        last TYPE if $list_counter == $max_list_size;
    }

    $list_counter = 0;

    print "# IGMP group addresses\n";

    GROUP_ADDR:
    for $value ( sort {$grpaddr{$b} - $grpaddr{$a}} keys %grpaddr ) {
        $list_counter++;
        printf "%-17s\t%s\n", $value, $grpaddr{$value};
        last GROUP_ADDR if $list_counter == $max_list_size;
    }

    print "\n";

    return;
}

sub print_tcp {
    my $value;       # generic hash value placeholder in for loops
    my $list_counter = 0;
    my %src_port     = %{ $pcap_stat{tcp}{src_port} };
    my %dst_port     = %{ $pcap_stat{tcp}{dst_port} };
    my %flags        = %{ $pcap_stat{tcp}{flags} };

    print "# Transmission Control Protocol\n";
    print "TCP segments: $pcap_stat{tcp}{pkts}\n";

    print "# TCP source ports\n";

    SRCPORT:
    for $value ( sort {$src_port{$b} - $src_port{$a}} keys %src_port ) {
        $list_counter++;
        printf "%-7s\t%s\n", $value, $src_port{$value};
        last SRCPORT if $list_counter == $max_list_size;
    }

    $list_counter = 0;

    print "# TCP destination ports\n";

    DSTPORT:
    for $value ( sort {$dst_port{$b} - $dst_port{$a}} keys %dst_port ) {
        $list_counter++;
        printf "%-7s\t%s\n", $value, $dst_port{$value};
        last DSTPORT if $list_counter == $max_list_size;
    }

    $list_counter = 0;

    print "# TCP flags\n";

    FLAGS:
    for $value ( sort {$flags{$b} - $flags{$a}} keys %flags ) {
        $list_counter++;
        printf "%-3s\t%s\n", $value, $flags{$value};
        last FLAGS if $list_counter == $max_list_size;
    }

    print "\n";

    return;
}

sub print_udp {
    my $value;       # generic hash value placeholder in for loops
    my $list_counter = 0;
    my %src_port      = %{ $pcap_stat{udp}{src_port} };
    my %dst_port      = %{ $pcap_stat{udp}{dst_port} };

    print "# User Datagram Protocol\n";
    print "UDP messages: $pcap_stat{udp}{pkts}\n";

    print "# UDP source ports\n";

    SRCPORT:
    for $value ( sort {$src_port{$b} - $src_port{$a}} keys %src_port ) {
        $list_counter++;
        printf "%-7s\t%s\n", $value, $src_port{$value};
        last SRCPORT if $list_counter == $max_list_size;
    }

    $list_counter = 0;

    print "# UDP destination ports\n";

    DSTPORT:
    for $value ( sort {$dst_port{$b} - $dst_port{$a}} keys %dst_port ) {
        $list_counter++;
        printf "%-7s\t%s\n", $value, $dst_port{$value};
        last DSTPORT if $list_counter == $max_list_size;
    }

    print "\n";

    return;
}

sub print_dns {
    my $value;       # generic hash value placeholder in for loops
    my $list_counter = 0;
    my %opcode       = %{ $pcap_stat{dns}{opcode} };
    my %rcode        = %{ $pcap_stat{dns}{rcode} };

    # set flags to zero if undef, because gaps in output may be confusing
    $pcap_stat{dns}{aa} ||= 0;
    $pcap_stat{dns}{ra} ||= 0;
    $pcap_stat{dns}{rd} ||= 0;
    $pcap_stat{dns}{tc} ||= 0;
    $pcap_stat{dns}{cd} ||= 0;
    $pcap_stat{dns}{ad} ||= 0;
    $pcap_stat{dns}{qr} ||= 0;
    $pcap_stat{dns}{qu} ||= 0;

    print "# Domain Name System\n";
    print "DNS messages:         $pcap_stat{dns}{pkts}\n";
    print "Authoritative answer: $pcap_stat{dns}{aa}\n";
    print "Recursion available:  $pcap_stat{dns}{ra}\n";
    print "Recursion desired:    $pcap_stat{dns}{rd}\n";
    print "Truncated:            $pcap_stat{dns}{tc}\n";
    print "Checking desired:     $pcap_stat{dns}{cd}\n";
    print "Verified:             $pcap_stat{dns}{ad}\n";
    print "Query response:       $pcap_stat{dns}{qr}\n";
    print "Query:                $pcap_stat{dns}{qu}\n";

    if ($big_lists) {
        my %qname        = %{ $pcap_stat{dns}{qname} };
        print "# DNS query names\n";

        QNAME:
        for $value ( sort {$qname{$b} - $qname{$a}} keys %qname ) {
            $list_counter++;
            # qname varies widely in string length, put that in 2nd column
            printf "%-12s\t%s\n", $qname{$value}, $value;
            last QNAME if $list_counter == $max_list_size;
        }

        $list_counter = 0;

        my %qtype = %{ $pcap_stat{dns}{qtype} };
        print "# DNS query types\n";

        QTYPE:
        for $value ( sort{$qtype{$b} - $qtype{$a}} keys %qtype ) {
            $list_counter++;
            printf "%-12s\t%s\n", $qtype{$value}, $value;
            last QTYPE if $list_counter == $max_list_size;
        }

        $list_counter = 0;

        my %rcode = %{ $pcap_stat{dns}{rcode} };
        print "# DNS reply codes\n";

        RCODE:
        for $value ( sort {$rcode{$b} - $rcode{$a}} keys %rcode ) {
            $list_counter++;
            printf "%-12s\t%s\n", $rcode{$value}, $value;
            last RCODE if $list_counter == $max_list_size;
        }
    }

    print "\n";

    return;
}

sub dienice {
    my $linenum = shift || -1;
    my $message = shift || 'unspecified failure';

    die "ERROR[$linenum]: $message\n";
}
