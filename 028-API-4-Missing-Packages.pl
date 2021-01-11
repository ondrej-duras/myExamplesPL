#!/usr/bin/perl
# 20210111, Ondrej DURAS (dury)

our $VERSION = 2021.011101;
our $MANUAL = <<__MANUAL__;
NAME: 028 Riesenie ak chybaju balicky
FILE: 028-API-4-Missing-Packages.pl

POPIS:
 Priklad jednoducheho polymorfyzmu na zaklade
 ne/dostupnosti balicka v instancii PERLu
 Ak je balicek pritomny, tak ho v plnom rozsahu vyuzijeme.
 Ak pritomny nieje, tak pouzijeme "zaslepku" - funkciu, ktora
 nas iba upozorni, co v pripade, ze funciu naozaj chceme vyuzivat.

 Na co je toto dobre ???
 A)
 Povedzme, ze v 90% pripadoch pouzivame jednoduchu "vanilkovu"
 konfiguraciu systemu a vystacime si s sshExec bez pridavnych kniznic.
 ... chceme aby to chodilo co najjednoduchsie.

 B)
 V zostavajucich 10% pripadov mame obsirnejsiu instalaciu systemu
 a chceme nasledne vyuzit aj obsirnejsie funkcie. ...napriklad aj telExec
 ... chceme vyuzit tu istu kniznicu, ktoru pouzivame v pripade A),
 avsak chceme mat moznost vyuzit aj obsirnejsie funkcie.

 ... alebo inak: Vyuzivame kniznicu na jednoduchom systeme cele roky
 s jeho vanilkovou konfiguraciou a najpouzivanejsimi funkciami.
 S casom poziadavky pribudaju a chceme vyuzit rozsirene funkcie kniznice.
 ... zavolanim "zaslepkovej funcie" nas kniznica upozorni na 
 chybajucu zavislost - dalsiu kniznicu, chybajucu v programovacom jazyku.
 Ovsem az ked ju naozaj potrebujeme.
 Po doinstalovani pozadovanej kniznice sa zaslepkova funkcia nahradi 
 ostrou funciou a my tak mozme vyuzivat rozsirene moznosti.

 Preco to bolo zavedene:
 Takto by mohlo byt mozne schovat zakladnu funkcionalitu PWA do kniznice TSIF.
 TSIF by tak bolo mozne rozsirit aj bez pribalenia konkretnej PWA kniznice.
 Alebo napriklad funkcnost TSIF kniznice by mohla byt zachovana aj v prostrediach,
 kde nieje instalovana Net::Telnet::Cisco ...s obmedzenim len pre protokol SSH.
__MANUAL__

# Vnutorne deklaracie
sub noCisco($);
sub okCisco($);
our $telExecDef=\&noCisco;

# manualne nastavenie dostupnosti - gramaticka ukazka
sub redefine($) {  
  my $par=shift;
  if($par) { $telExecDef=\&okCisco; }
  else     { $telExecDef=\&noCisco; }
}

# nastavenie dostupmosti ostrej alebo zaslepkovej funkcie
# na zaklade dostupnosti balicka Net::Telnet::Cisco v instalacii PERLu
sub initCisco() {
  if(eval("use Net::Telnet::Cisco; 1;")) { 
    $telExecDef=\&okCisco; 
    print "Cisco loaded.\n";
  } else {
    $telExecDef=\&noCisco; 
    print "Cisco missing.\n";
  }
}

# zaslepkova funkcia
sub noCisco($) {
  my $text=shift;
  print "------: ${text}\n";
  print "------: cpan install Net::Telnet::Cisco :-)\n";
}

# ostra funkcia, vyuzivajuca balicek Net::Telnet::Cisco
# volatelna iba v pripade pritomnosti balicka
sub okCisco($) {
  my $text=shift;
  print "Telnet: ${text}\n";
  $dev = Net::Telnet::Cisco->new(Host=>"localhost", Port=>80);
  $dev->close();
}

# funkcia exportovana do API ( @ISA=qw/ .... telExec .... /; ... )
# tato funkcia vykona iba jedine volanie vhodnej funkcie na ktoru ukazuje premenna.
# odovzda jej vsetky agrumenty prevzate od volatela (@ ... @_)
# po skonceni volania  vrati volatelovi celu navratovu hodnotu vratenu volanou vhodnou funkciou
sub telExec(@) {
  return &$telExecDef(@_);
}

initCisco();
telExec("to localhost:80");


# redefine(1);
# &$telExecDef("Hello with Cisco !");
# telExec("Hello Cisco");
# 
# redefine(0);
# &$telExecDef("Hello without Cisco !");
# telExec("Hello NO-Cisco");


# --- end ---

