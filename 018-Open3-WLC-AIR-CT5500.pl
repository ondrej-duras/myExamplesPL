#!/usr/bin/perl

our $VERSION = 2020.040101;
our $MANUAL  = <<__MANUAL__;
NAME: WLC-HELLO - Cisco Wireless Lan Controller - access example
FILE: wlc-hello.pl

DESCRIPTION:
  ... xwlc shows details


USAGE:
  wlc-hello.pl --run

PARAMETERS:
  --run  - running in produnction mode
  --test - running in test mode
  --help - this page

SEE ALSO:
  https://github.com/ondrej-duras/

VERSION: ${VERSION}
__MANUAL__
 


use Socket;
use IPC::Open3;
use Data::Dumper;
use PWA;

our $MODE_DEBUG = ".*";

sub xdebug($) {
  my $MSG=shift;
  return unless $MODE_DEBUG;
  print $MSG;
}

sub xchomp(@) {
  my @ARRAY=@_;

  return map { $A=$_;
               chomp $A;
               sprintf("%s",$A);
             } @ARRAY;
}

sub xresolve($;$) {
  my ($PAR1,$PAR2)=@_;
  my ($DEVIP,$HNAME);

  # handling input parameters
  if(length($PAR2)) {
   ($DEVIP,$HNAME) = ($PAR1,$PAR2);
   xdebug "#: '${PAR1}' '${PAR2}' '${DEVIP}' '${HNAME}'\n";
  } else {
    if($PAR1 =~ /^[0-9]+(\.[0-9]+){3}$/) {
     $DEVIP=$PAR1; $HNAME='';
    } else {
     $HNAME=$PAR1; $DEVIP='';
    }
  }

  # resolving IP from FQDN via DNS
  unless($DEVIP) {
    $HNAME = uc $HNAME;
    if( my $DAT = gethostbyname($HNAME)) {
       $DEVIP = inet_ntoa($DAT);
     } else { $DEVIP=""; }
    xdebug "#: HNAME '${HNAME}' -> DEVIP '${DEVIP}'\n";
  }

  # resolving FQDN based on PTR of DEVIP via DNS
  unless($HNAME) {
    my $DAT=inet_aton($DEVIP);
    $FQDN=gethostbyaddr($DAT,AF_INET);
    $HNAME = $FQDN;
    $HNAME =~ s/\..*//;
    $HNAME = uc $HNAME;
    xdebug "#: DEVIP '${DEVIP}' -> FQDN '${FQDN}' -> HNAME '${HNAME}'\n";
  }
  return ($DEVIP,$HNAME);
}

sub xcommand($$$;$) {
  my ($HOST,$CLASS,$COMMAND,$TYPE)=@_;
  my ($DEVIP,$HNAME) = xresolve($HOST);
  my ($pid,$fh_in,$fh_out,$fh_err);
  my @OUTE; # errors
  my @OUTA; # output

  # Connecting to Device
  print "HNAME ${HNAME} (${DEVIP})  connect\n";
  #use IPC::Open2;
  #$pid=open2($fh_out,$fh_in,"sshpass -p " .pwaPassword("user")." ssh -tt "
  $pid=open3($fh_in,$fh_out,$fh_err,"sshpass -p " .pwaPassword("user")." ssh -tt "
           . " -o StrictHostKeyChecking=no"
           . " -o PubKeyAuthentication=no"
           . " -l ".pwaLogin("user")." ${DEVIP}");
  unless($pid) {
    print STDERR "#! ERROR: ${HNAME}($DEVIP) connection failed !\n";
    next;
  }

  # Operation on Device
  sleep(2);
  if($TYPE eq "no-more") {
    print $fh_in "${COMMAND}\n";
    print $fh_in "exit\n";
    print $fh_in "exit\n";
    print $fh_in "exit\n";
  } else { # generic TYPE
    print $fh_in "terminal length 0\n";
    print $fh_in "${COMMAND}\n";
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
  #@OUTA = grep { !/^\s*\*via/} @OUTA;
  #@OUTA = grep { !/^'/} @OUTA;
  #@OUTA = grep { !/^\s*$/} @OUTA;
  #$VRF  = "GRT";
  if( scalar(@OUTA) ) {
    @OUTA = map { $A=$_;
                  chomp $A;
                  $A = "${DEVIP};${HNAME};${CLASS};${A}\n";
                  sprintf("%s",$A);
                } @OUTA;
  } else { @OUTA=(); }
  close $fh_out;

  # Dispatching PID from list of processes and writing outputs
  waitpid($pid,0);

  push @OUTA,@OUTE; # join OUTE(errors) at the end of OUTA(output)
  return @OUTA;

}

sub xwlc($$$;$) {
  my ($HOST,$CLASS,$COMMAND,$TYPE)=@_;
  my ($DEVIP,$HNAME) = xresolve($HOST);
  my ($pid,$fh_in,$fh_out,$fh_err);
  my @OUTE; # errors
  my @OUTA; # output

  unless($HNAME) { $HNAME=$DEVIP; }

  # Connecting to Device
  print "HNAME ${HNAME} (${DEVIP})  connect\n";
  #use IPC::Open2;
  #$pid=open2($fh_out,$fh_in,"sshpass -p " .pwaPassword("wifi")." ssh -tt "
  $pid=open3($fh_in,$fh_out,$fh_err," ssh -tt "
           . " -o StrictHostKeyChecking=no"
           . " -o PubKeyAuthentication=no"
           . " -l ".pwaLogin("wifi")." ${DEVIP}");
  unless($pid) {
    print STDERR "#! ERROR: ${HNAME}($DEVIP) connection failed !\n";
    next;
  }

  # Operation on Device
  sleep(2);
  print $fh_in pwaLogin("wifi") ."\n";
  print $fh_in pwaPassword("wifi") ."\n";
  print $fh_in "config paging disable\n";
  print $fh_in "${COMMAND}\n";
  print $fh_in "logout\n";
  print $fh_in "n\n";
  print $fh_in "n\n";
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
  #@OUTA = grep { !/^\s*\*via/} @OUTA;
  #@OUTA = grep { !/^'/} @OUTA;
  #@OUTA = grep { !/^\s*$/} @OUTA;
  #$VRF  = "GRT";
  if( scalar(@OUTA) ) {
    @OUTA = map { $A=$_;
                  chomp $A;
                  $A = "${DEVIP};${HNAME};${CLASS};${A}\n";
                  sprintf("%s",$A);
                } @OUTA;
  } else { @OUTA=(); }
  close $fh_out;

  # Dispatching PID from list of processes and writing outputs
  waitpid($pid,0);

  push @OUTA,@OUTE; # join OUTE(errors) at the end of OUTA(output)
  return @OUTA;

}


#print Dumper xresolve('','q-005-xx-rs-70');
#print Dumper xresolve('10.1.1.1','');
#print Dumper xresolve('q-005-xx-rs-70');
#print Dumper xresolve('10.2.1.1');
#print Dumper xchomp xcommand('q-005-xx-rs-70','IF_UPLINKS',"show ip int brief vrf all");
#print xcommand('q-005-xx-rs-70','RAW_IF_FOREIGN','show running interface | section nel997\.');
#print xcommand('q-005-xx-rr-70','RAW_IF_LOCAL','show startup | section interface nel97\.');
#print xcommand('q-005-xx-rs-70','RAW_RT_FOREIGN','show ip route vrf all');
#print xcommand('q-005-xx-rr-70','RAW_RT_LOCAL','show ip route vrf *');



print xwlc('10.1.1.1','RAW_AP_SUMMARY','show ap summary');
#> update prepare for profile WIFI

# --- end ---



