#!/usr/bin/perl

use Socket;
use Net::Ping;

@HLIST=qw/
10.8.110.170
10.8.110.173
/;


$ssh=Net::Ping->new("tcp",2);
$ssh->port_number(22);
$tel=Net::Ping->new("tcp",2);
$tel->port_number(23);
$web=Net::Ping->new("tcp",2);
$web->port_number(80);
$sec=Net::Ping->new("tcp",2);
$sec->port_number(443);
$icmp=Net::Ping->new("icmp");

#open $FH,"<","hlist.txt" or die "No 'hlist.txt' found !\n";
#while ($HNAME=<$FH>) {
foreach $HNAME (@HLIST) {
  #chomp $HNAME;
  #next if $HNAME=~/^\s*$/;
  #next if $HNAME=~/^\s*#/;

  #$HNAME=~s/\s+//g;
  #if(my $BINIP=gethostbyname($HNAME)) {
  #  $DEVIP=inet_ntoa($BINIP);
  #} else { $DEVIP=""; }
  $DEVIP=$HNAME;

  if($ssh->ping($HNAME))  { print "${HNAME}(${DEVIP}) via SSH\n"; }
  if($tel->ping($HNAME))  { print "${HNAME}(${DEVIP}) via Telnet\n"; }
  if($web->ping($HNAME))  { print "${HNAME}(${DEVIP}) via HTTP\n"; }
  if($sec->ping($HNAME))  { print "${HNAME}(${DEVIP}) via HTTPS\n"; }
  if($icmp->ping($HNAME)) { print "${HNAME}(${DEVIP}) via ICMP\n"; }
  
}
#close $FH;
print "#done\.\n";

