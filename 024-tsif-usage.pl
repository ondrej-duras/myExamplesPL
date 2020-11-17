#!/usr/bin/perl
# 20201117, Ing. Ondrej DURAS Capt. (Ret.) (dury)

use TSIF;

$RL_C3750 = <<__RAW__;
##!cisco
RAW_C3750_IF_DESC; show int description | include ^(Gi|Te|Fa|Vl|Po)
RAW_C3750_VLAN_DESC; show vlan brief | include ^[0-9]
__RAW__


$BASE = {
 "RAW_C3750_IF_DESC" => sub {
   my($DEVIP,$HNAME,$CLASS,$LINE) = @_;
   $CLASS="IF_DESC";
   $LINE =~ s/up/enabled/;
   $LINE =~ s/admin down/disabled/;
   my($IF,$ENA,$CON,$DESC) = split(/\s+/,$LINE,4);
   return "${DEVIP};${HNAME};${CLASS};${IF};${ENA};${CON};${DESC}\n";
 },
 "RAW_C3750_VLAN_DESC" => sub {
   my($DEVIP,$HNAME,$CLASS,$LINE) = @_;
   my($ID,$NAME,$STATE);
   $CLASS="VLAN_DESC";
   $ID   = substr($LINE, 0,4);  $ID   =~ s/\s+//g;
   $NAME = substr($LINE, 5,32); $NAME =~ s/\s+//g;
   $STATE= substr($LINE,38,9);  $STATE=~ s/\s+//g;
   return "${DEVIP};${HNAME};${CLASS};${ID};${NAME};${STATE};-na-;-na-\n";
 }
};

#--- -------------------------------- --------- -------------------------------


$RAW = sshExec("LAB-XXX-97","user",rawList2Cmd($RL_C3750));
print $RAW;
print "# ---\n";

$CSV = raw2Csv($RAW);
print $CSV;
print "# ---\n";

$INSTANT = raw2Instant($RAW,$BASE);
print $INSTANT;
print "# ---\n";


