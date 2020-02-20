#!/usr/bin/perl

# DEVIP;HNAME;CLASS;... =TSIF=

use Socket;
use Net::Telnet::Cisco;
use Data::Dumper;
use PWA;

@HLIST = qw/
L-XX-DI-1902
L-XX-DI-1901
L-XX-AC-1906
L-XX-AC-1907
L-XX-AC-1904
L-XX-AC-1905
L-XX-AC-1902
L-XX-AC-1903
L-XX-AC-1901
/; 



foreach $HNAME (@HLIST) {

  $dev=Net::Telnet::Cisco->new(Host=>$HNAME,);
  $dev->login(pwaLogin("user"),pwaPassword("user"));
  if( $DAT = gethostbyname($HNAME)) {
    $DEVIP = inet_ntoa($DAT);
  } else { $DEVIP=""; }

  @OUTA=$dev->cmd("show cdp nei detail | include Device ID|IP address|Platform|Interface");
  @OUTA= map { "${DEVIP};${HNAME};RAW_CDP;" . $_ } @OUTA;

  @OUTB=$dev->cmd("show int status");
  @OUTB= map { "${DEVIP};${HNAME};RAW_IFSTAT;" . $_ } @OUTB;

  $dev->close();

  print (@OUTA,@OUTB);
}

print "# done.\n";


