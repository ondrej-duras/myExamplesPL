#!/usr/bin/perl
# ROUTES.pl
# 20200317, Ing. Ondrej DURAS (dury), CAPT. ret. 
# DEVIP;HNAME;CLASS;... =TSIF=
# collecting switchport descriptions from all switches.
# File needs a very simple qlist.txt Host_File
# where a hostname is followed by generic or no-more word
# generic - terminal length 0 - works
# no-more - terminal length 0 - works for ... privileged only.

# That gets all routes from datacenter for traffic spliting purposes.
# ordered by Karol
# written in cov quarantine
#
use Socket;
use IPC::Open3;
use Data::Dumper;
use PWA;

$VERSION=2020.031701;

# feeding a hostlist
@HLIST=();
open $FH,"<","qlist.txt" or die "No qlist.txt found !\n";
while($LINE=<$FH>) {
  chomp $LINE;
  next if $LINE=~/^\s*$/;
  next if $LINE=~/^\s*#/;
  ($HNAME,$TYPE) = split(/\s+/,$LINE,2);
  next unless $TYPE=~/generic|no-more/;
  next unless $HNAME=~/-RS-/;
  push @HLIST,$HNAME;
  push @HLIST,$TYPE;
}
close $FH;


open $FH,">","ROUTES.csv";
$IX=0; $CT=scalar(@HLIST);
while($IX < $CT) {
  $HNAME = $HLIST[$IX++];
  $TYPE  = $HLIST[$IX++];

  #print "${HNAME} is ${TYPE} of ${IX}\n";
  #next;

  # resolving IP from FQDN via DNS
  if( my $DAT = gethostbyname($HNAME)) {
     $DEVIP = inet_ntoa($DAT);
   } else { $DEVIP=""; }

  # Connecting to Device
  print "HNAME ${HNAME} (${DEVIP})  connect\n";
  #use IPC::Open2;
  #$pid=open2($fh_out,$fh_in,"sshpass -p " .pwaPassword("user")." ssh -tt "
  $pid=open3($fh_in,$fh_out,$fh_err,"sshpass -p " .pwaPassword("user")." ssh -tt "
           . " -o StrictHostKeyChecking=no"
           . " -o PubKeyAuthentication=no"
           . " -l ".pwaLogin("user")." ${HNAME}");
  unless($pid) {
    print STDERR "ERROR: ${HNAME} connection failed !\n";
    next;
  }

  # Operation on Device
  sleep(2);
  if($TYPE eq "no-more") {
    print $fh_in "show ip route vrf all | no-more\n";
    print $fh_in "exit\n";
    print $fh_in "exit\n";
    print $fh_in "exit\n";
  } else { # generic TYPE
    print $fh_in "terminal length 0\n";
    print $fh_in "show ip route vrf all\n";
    print $fh_in "exit\n";
    print $fh_in "exit\n";
    print $fh_in "exit\n";
  }
  close $fh_in;


  # Handling potential Errors
  @OUTE=<$fh_err>;
  if( scalar(@OUTE) ) {
    @OUTE =~ map { $A=$_; 
                   $A =~ s/^/${DEVIP};${HNAME};ERR;${A}/;
                   sprintf("%s\n",$A);
                 } @OUTE;
  } else { @OUTE=(); }
  close $fh_err;


  # Handling Output from Device
  @OUTA=<$fh_out>;
  @OUTA = grep { !/^\s*\*via/} @OUTA;
  @OUTA = grep { !/^'/} @OUTA;
  @OUTA = grep { !/^\s*$/} @OUTA;
  $VRF  = "GRT";
  @OUTA = map { my $L=$_ ; 
                $L =~ s/\s+/ /g;
                $L =~ s/, .*//;
                if($L=~/^[0-9]/) {
                  sprintf("%s\n","${DEVIP};${HNAME};ROUTE;${VRF};${L}"); 
                } elsif ($L=~/^IP/) {
                  $L=~s/^[^"]*"//; # in front of quote
                  $L=~s/"\s*$//;   # behind of quote
                  $VRF=$L;
                  sprintf("%s\n","${DEVIP};${HNAME};ROUTE_VRF;${L}"); 
                }
              } @OUTA;
  close $fh_out;

  # Dispatching PID from list of processes and writing outputs
  waitpid($pid,0);
  print $FH @OUTE;
  print $FH @OUTA;
}
close $FH;
print "#done.\n";

# --- end ---

