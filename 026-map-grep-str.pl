#!/usr/bin/perl


print "Command-line agruments:\n";
$ARGC=@ARGV;
print "ARGC .... " . $ARGC ."\n";
print join(",",@ARGV) ."\n";



$T  = "aaa:bbb:ccc:ddd:eee";
$T .= ":fff:ggg:hhh";

($A,$B,$C)=split(/:/,$T,3);
print "${A} - ${B} - ${C}\n";

($A,$F,$G,$H) = $T =~ m/^(.*):(f+):(g+):(h+)$/;
print "${A} - ${F} - ${G} - ${H}\n";



@A=("aaaa","bbbb","cccc","dddd");
$B=[ "xxxx","yyyy","zzzz" ];
@C=(@A,@$B);
@C = map { $A=$_;  $A .= "+" } @C; 
foreach my $ITEM (@C) {
  print "${ITEM}\n";
}


%A=( "aaaa"=>1, "bbbb"=>2, "cccc"=>3, "dddd"=>4);
$B={ "xxxx"=>5, "yyyy"=>6, "zzzz"=>7 };
%C=(%A,%$B);
%C = map { $k=$_; $k => $C{$k} . $C{$k} . "\n" } keys %C;
print %C;


@A = qw( 10 11 12 57 925 923 378 54 93 );
@B = qw( ahoj cau nazdar privet zdravstvuj dosvidania ciao hello hi bye );

splice @A,2,3; # zmaze 12 57 925
print join(",",sort { $a <=> $b } @A) ."\n";
print join(",",sort { $a cmp $b } @B) ."\n";
print " a: " . join(",", grep(  /a/, @B)) ."\n";
print "!a: " . join(",", grep( !/a/, @B)) ."\n";
print "<5: " . join(",", grep { length($_) < 5 } @B) ."\n";


$T = "##! HOST=D-HOST-001 DEVIP=1.2.3.4 HNAME=H-HOST-002";
@POLE = map { $A=$_; $A =~ s/^[A-Z]+=//; $A} split(/\s+/,$T,5);
$HOST=$POLE[1]; $DEVIP=$POLE[2]; $HNAME=$POLE[3];
print "H='${HOST}' D='${DEVIP}' N='${HNAME}'\n";

@E = qw( Eth1/1 Eth1/2 Eth1/101 Eth3/21 Eth1/22 Eth1/21 Eth1/45 Eth2/101);
sub portSort($$) {
  my ($a,$b) = @_;
  my ($TA,$NA,$TB,$BN,$XX);
  ($TA,$NA) = $a =~ /(.*[^0-9])([0-9]+)$/; # test,number part
  ($TB,$NB) = $b =~ /(.*[^0-9])([0-9]+)$/;
  # print "#: (${a} -> ${TA} ${NA}) (${b} -> ${TB} ${NB})\n"; # DEBUG
  unless($XX=($TA cmp $TB)) { $XX=(int($NA) <=> int($NB)); }
  return $XX;
}

print join(",",sort { portSort($a,$b) } @E) ."\n";
print join(",",sort portSort @E) ."\n";


print "\n\nPolohy v retazcoch:\n";
$S = "01234567 abcdefgh ABCDEFGH";
print substr($S, 0, 8) ."\n";  # prvych 8 znakov
print substr($S, 9, 8) ."\n";  # 8 znakov od 10.teho
print substr($S,18) ."\n";     # od 19.znaku po koniec
print substr($S,-8) ."\n";     # poslednych 8 znakov
print index($S,"abcd") . "\n"; # vrati 9
print index($S,"ABCD") . "\n"; # vrati polohu 18
print index($S,"qxyz") . "\n"; # vrati -1, lebo sa tam retazec nenachadza

# --- end ---

