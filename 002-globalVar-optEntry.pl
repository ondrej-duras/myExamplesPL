#!/usr/bin/perl

our $MANUAL = <<'__MANUAL__';

Problem:
  Niekedy potrebujeme nazov premennej pre ucely
  zapisania do konfiguracneho suboru, ale
  zaroven by sme prijali, keby premenna existovala
  pod rovnakym menom ako globalna premenna.

  Zaroven cheli by sme zabezpecit vstup hodnoty
  premennej, gramaticke osetreneie hodnoty a tiez
  vyplnenie defaultnej hodnoty v pripade, ze
  pouzivatel zada prazdny retazec.


__MANUAL__

use Data::Dumper;

our $HCONFIG = {};
our $TCONFIG = "";

sub dotWidth($$) {
  my($TEXT,$WIDTH)=@_;
  $TEXT =~ s/\s+$//;
  my $LEN =length $TEXT;
  my $DOTS=$WIDTH - $LEN - 1;
  my $PAT=""; for (my $I=0;$I<$DOTS;$I++) { $PAT .="."; }
  $TEXT = "${TEXT} ${PAT}";
  $TEXT =~ s/\. \.\./\.\.\.\./;
  return $TEXT;
}

sub spaceWidth($$) {
  my($TEXT,$WIDTH)=@_;
  $TEXT =~ s/\s+$//;
  $TEXT = sprintf("%-${WIDTH}s",$TEXT);
  return $TEXT;
}

sub passInt($) {
  my $INT=shift;
  if($INT =~ /^[0-9]+$/) { return 1; }
  print "#! Warning: Interger expected !\n";
  return 0;
}

sub passIPv4($) {
  my $IP=shift;
  foreach $OCT (split(/\./,$IP,4)) {
    unless($OCT =~ /^[0-9]+$/) { 
      print "#! Warning: IPv4 address expected !\n";
      return 0; 
    }
    $OCT=int($OCT); 
    if(($OCT<0) or ($OCT>255)) { 
      print "#! Warning: IPv4 address expected !\n";
      return 0; 
    }
  }
  return 1;
}

sub firstValid($$) {
  my ($A,$B)=@_;
  my $RETURN;
  if($A) { $RETURN=$A; }
  elsif($B) { $RETURN=$B; }
  else { $RETURN=""; }
  print "#: ${RETURN}\n";
  return $RETURN;
}

sub optEntry($$;$$) {
  my($VAR_NAME,$VAR_PROMPT,$VAR_DEFAULT,$VAR_CHECK)=@_;   # Nazov globalnej premennej ako retazec, vyzva, def.hodnota, procedura kontroly
  if(($VAR_PROMPT =~ /%/) and (length sprintf("%s",$VAR_DEFAULT))) {
    $VAR_PROMPT =~ s/%/${VAR_DEFAULT}/;
  } 
  $VAR_PROMPT = dotWidth($VAR_PROMPT,50);
  my  $DAT;
  my $PASS = 0;
  while(not $PASS) {
     print "${VAR_PROMPT} : ";              # Zobrazime vyzvu pre zadanie hodnoty premennej (volanej retazcom)
     $DAT = <STDIN>; chomp $DAT; # Hodnotu naplnime zo standartneho vstupu a odstrihneme EOL.
     $DAT =~ s/^\s+//; $DAT =~ s/\s+$//; # odstrihnutie prazdnych znakov zo zaciatku a konca retazca hodnoty
     if((not length($DAT)) and (length sprintf("%s",$VAR_DEFAULT))) {
       $DAT=$VAR_DEFAULT;
       print "${VAR_PROMPT} : ${DAT}\n";
     }
     if(exists(&$VAR_CHECK))
       { $PASS=&$VAR_CHECK($DAT); }
     elsif(length($DAT)) { $PASS=1; }
  }
  eval("our \$${VAR_NAME};");     # Deklarovanie glovalnej premennej ("volanej retazcom")        #<<
  $$VAR_NAME = $DAT;              # Naplnenie globalnej premennej hodnotou ("volanej retazcom")  #<<

  $HCONFIG->{$VAR_NAME} = $DAT;   # Naplnenie konfuguracneho aosc.pola klucom a hodnotou
  $TCONFIG .= "#=form " . spaceWidth(${VAR_NAME},15) . " : ${VAR_PROMPT} : ${DAT}\n";
}

sub view() {
  print "Globalne premenne:\n";
  print "ABC ... ${ABC}\n";
  print "XYZ ... ${XYZ}\n";
  print "INT ... ${INT}\n";
  print "XIP ... ${XIP}\n";
}

optEntry("ABC","Enter ABC ....... ");
optEntry("XYZ","Enter XYZ .....   ");
optEntry("INT","Enter number (def %)...",10,"passInt");
optEntry("XIP","Enter IP address (def %) ...",firstValid(undef,"1.1.1.1"),"passIPv4");
view();

# len vypis            [ref.premennych],[mena.premennych]
print Data::Dumper->Dump([$HCONFIG],["HCONFIG"]);
print $TCONFIG;
# print Dumper $CONFIG; ...funguje tiez ($VAR1=...)


# --- end ---

