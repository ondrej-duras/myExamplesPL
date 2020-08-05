#!/usr/bin/perl
# COLLECT LAN TOPOLOGY
# 20200805, Ondrej DURAS (dury)


# DEVIP;HNAME;CLASS;... =TSIF=

use Socket;
use Net::Telnet::Cisco;
use Data::Dumper;
use PWA;

$VERSION = 2020.080501;
$MANUAL  = <<__MANUAL__;
NAME: LAN TOPOLOGY COLLECTOR
FILE: lan-tolopogy.pl

DESCRIPTION:
  Very sipmple, telnet based,
  LAN topology data collector.
  It collects data into TSIF file.

USAGE:
  lan-topology.pl --test  # reduced hostlist / TST-TOPOLOGY-RAW.csv
  lan-topology.pl --prod  # full hostlist / LAN-TOPOLOGY-RAW.csv

SEE ALSO:
  https://gitlab.com/ondrej-duras/

VERSION: ${VERSION}
__MANUAL__


if ($ARGV[0] =~ /^-+t/) {
  $FNAME = "TST-TOPOLOGY-RAW.csv";
  if ( -f  "TST-HOSTLIST.txt") {
    open my $fh,"<","TST-HOSTLIST.txt";
    $HLIST=join("",<$fh>);
    close $fh;
    print "TST-HOSTLIST.txt loaded.\n";
  } else {
  $HLIST = <<__HLIST__;
    XY-DI-02 c9300
    XY-AC-01 c3750
__HLIST__
  }
} elsif($ARGV[0] =~ /^-+p/) {
  $FNAME = "LAN-TOPOLOGY-RAW.csv";
  if ( -f  "LAN-HOSTLIST.txt") {
    open my $fh,"<","LAN-HOSTLIST.txt";
    $HLIST=join("",<$fh>);
    close $fh;
    print "LAN-HOSTLIST.txt loaded.\n";
  } else {
  $HLIST = <<__HLIST__;
    XY-CO-01 n9504
    XY-CO-02 n5k  
    XY-DI-01 n7010
    XY-DI-02 n9380
    XY-AC-02 c9300
    XY-AC-03 c9200
    XY-AC-04 c3750
    XY-AC-05 c2950
__HLIST__
  }
} else {
  print $MANUAL;
  exit;
}


open($fh,">",$FNAME);
print "File ${FNAME} ... opened.\n";

foreach my $ITEM (split(/\n/,$HLIST)) {
  next if $ITEM=~/^\s*$/;
  next if $ITEM=~/^\s*#/;
  $ITEM =~s/^\s+//;
  my ($HNAME,$TYPE) = split(/\s+/,$ITEM);

  print sprintf("%-17s ",$HNAME);
  @OUTX=();
  
  if( $DAT = gethostbyname($HNAME)) {
    $DEVIP = inet_ntoa($DAT);
  } else { $DEVIP=""; }
  print sprintf("%-15s ",$DEVIP);

  $dev=Net::Telnet::Cisco->new(Host=>$HNAME,Timeout=>20);
  $dev->login(pwaLogin("user"),pwaPassword("user"));
  print "${TYPE} ";
  $dev->cmd("terminal length 0"); print ".";

  if ($TYPE =~ /c9300|c3750/) {
    @OUTA = $dev->cmd("show cdp nei detail | include Device ID|IP address|Platform|Interface"); print ".";
    @OUTX = (@OUTX, map { "${DEVIP};${HNAME};RAW_CDP;" . $_ } @OUTA); print ".";
  }

  if ($TYPE =~ /c9300|c3750/) {
    @OUTA = $dev->cmd("show int desc"); print ".";
    @OUTX = (@OUTX, map { "${DEVIP};${HNAME};RAW_DESC;" . $_ } @OUTA); print ".";
  }

  if ($TYPE =~ /c9300|c3750/) {
    @OUTA = $dev->cmd("show mac address-table dynamic | include ^ +[0-9]"); print ".";
    @OUTX = (@OUTX, map { "${DEVIP};${HNAME};RAW_MAC;" . $_ } @OUTA); print ".";
  }

  $dev->close(); print ".";

  print $fh (@OUTX);
  #print $fh (@OUTC);
  print " ok.\n";
  
}
close $fh;
print "# done.\n";

# --- end ---
