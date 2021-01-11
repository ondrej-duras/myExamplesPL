#!/usr/bin/perl
# GAF - generovanie elektronickeho odtlacku vzoru
# 20060607, kpt. Ing. Ondrej DURAS (dury) http://poznamky.net
#
## Manual ############################################################# {{{ 1

our $VERSION = 2020.122001;
our $MANUAL  = <<__MANUAL__;
NAME: Goceliak Authentication Function
FILE: gaf.pl

DESCRIPTION:
  Example, demonstrating a simple hash function.

USAGE:
  gaf [-a <keya>] [-b <keyb>] <Text_to_Hash>
  gaf --help

EXAMPLE:
  gaf -a 1999999999 -b 1234567890 Text

PARAMETERS:
  -a / -b - keys "A" and "B"
  --help  - historical notice

SEE ALSO:
  https://github.com/ondrej-duras/
  
VERSION: ${VERSION}

__MANUAL__

our $HMANUAL = <<__MANUAL__;
OPIS: 
  GAF je predurceny na ochranu autentifikacnych udajov
  pouzivanych v intranetovom/internetovom prostredi v podobe cookies.
  Je zalozena na Goceliakovej Autentifikacnej Funkcii (GAF).

PRINCIP GAF:
  Nech X je vzor, alebo predloha o ktorej sa potrebujeme presvedcit, 
  ze je pravdiva, a teda nieje pozmenena.
  Nech Y je elektronicky odtlacok vzoru, teda ciselna hodnota vypocitana
  znamym postupom avsak za pomoci neznamych argumentov (tajnych klucov).

  Kluce "A" a "B" su tajne argumenty GAF.
  Kluce "A" a "B" by mali byt nesudelitelne cisla
  volene z prostrednych styroch patin rozsahu "Y".
  Odporuca sa, aby "A" > "B".
  Zatial "A" a "B" su utajovane, vzor "X" a ochranny odtlacok "Y" mozu
  byt verejne dostupne.
  kluce "A" a "B" striktne nesmu byt rovne "0" alebo "1".

  Pozadujeme (a predpokladame, ze poziadavka je splnena) ze:
  1. Nevieme Vytvorit taky vzor Xx, ktory by bez znalosti
     klucov A a B vyprodukoval stanovenu hodnotu Y, teda ochranny odtlacok.
     GAF(X)=GAF(Xx)=Y
  2. Nevieme pozmenit znamy vzor X ziaducim sposobom tak, aby sme 
     z povodneho X, pozmenenim dostali X1 kde by platilo GAF(X)=GAF(X1)=Y.
  3. Niesme schopni v realnom case a za moznosti ziskania realneho poctu
     vzorov a odtlackov Xi a Yi pre i=0-N odhalit/vypocitat tajne kluce A a B.

POUZITIE GAF:
  GAF potom funguje tak, ze primerane doveryhodnym sposobom ziskame
  autentifikacne, pripadne autorizacne informacie od pouzivatela.
  Oznacime ich ochrannym elektronickym odtlackom, ktory poskytneme
  poskytovatelovi informacii /pouzivatelovi/ napriklad vo forme cookies.
  Nasledne, ak od pouzivatela opatovne pozadujeme autentifikacne informacie,
  tak ich pozadujeme napr. aj v otvorenej podobe, avsak vzdy k nim vyzadujeme
  aj ochranny odtlacok. Ak Pouzivatel uvadza pravdive informacie, potom uvadza
  aj pravdivy odtlacok. Ak nie, potom odtlacok nesedi. 
  
  Funkcia generujuca elektronicky odtlacok vzoru
  vzor - je predlohou, ktorej odtlacok pozadujeme
  ka   - kluc "A", 
  kb   - kluc "B",
  dig  - pracovna/ priebezna premenna - jej inicializacna hodnota moze byt 
                                        proprietarny tajomstvom implementacie
  +1   - pracovna hodnota, zabranujuca monostabilite (zaseknutiu do jednej hodnoty Y) funkcie.
  
  
STABILITA FUNKCIE:
  Pozadujeme, aby fukcia bola "pseudonahodna" a "astabilna".
  ASTABILNA funkcia nema ziadny stav "Y" taky, ktory by po pretrvaval
  niekolko iteracii za sebou. Zaroven astabilna funkcia rovnomerne vyuziva
  cely rozsah moznych hodnot "Y".
  N-STABILNA funkcia je taka, u ktorej moze nastat stav, kedy na zaklade "X" vieme predpokladat
  mnozinu "N" moznych "Y" cisel vygenerovanych funkciou GAF a to i bez znalosti "A" a "B". 
  MONOSTABILA funkcia je taka, u ktorej moze nastat aspon jeden taky stav,
  kedy sa "Y" s nadchadzajucou iteraciou uz nemeni, resp. vieme ho predpokladat bez znalosti
  "A" a "B".
 
  Standartne kluce pre transportne ucely
  Key "A" = 1999999999
  Key "B" = 1234567890
  Pre praktickepouzitie je ichnutne zmenit.

HISTORICKA POZNAMKA:
  Vyssie ide o povodny dokumentacny text z roku 2006.
  Ci bola GAF bezpecna, to ani srnka netusi, ale v case,
  ked sa pouzivala, hacknuta nebola.
  Pouzivala sa na podpis technikalii v URL linku 
  pre inicializaciu/obnovenie hesla na Vojenskej akademii.
  RNDr. Peter Goceliak bol moj oblubeny matikar na VSSSV.
__MANUAL__

####################################################################### }}} 1
## GAF Definicia ###################################################### {{{ 1

# Standartne kluce
our $GAF_KEYA=1999999999; 
our $GAF_KEYB=1234567890;

sub gaf($;$$) { 
  my($vzor,$keya,$keyb)=@_;
  unless($keya) { $keya = $GAF_KEYA; }
  unless($keyb) { $keyb = $GAF_KEYB; }
  my $dig=$keya+$keyb;
  $len=length($vzor);
  for($i=0;$i<$len;$i++)
  {
    $c=substr($vzor,$i,1);
    $z=ord($c);
    $dig=(($dig * (256 - $z)) % $keya) +$keyb +1;
    $dig=(($dig * (256 - $z)) % $keyb) +$keya +1;
    #print "[$i/$len  $c=$z $dig] \n"; 
  }
  $dig=$dig % 1000000000;
  return $dig;
}

####################################################################### }}} 1
## Main ############################################################### {{{ 1

our $TEXT = "";
unless(scalar(@ARGV)) { print $MANUAL; exit; }
while(my $ARGX = shift @ARGV) {
 if ($ARGX =~ /^-+(a|keya)/) { $GAF_KEYA = shift @ARGV; next; }
 if ($ARGX =~ /^-+(a|keyb)/) { $GAF_KEYA = shift @ARGV; next; }
 if ($ARGX =~ /^-+h/)        { print $HMANUAL; exit; }
 $TEXT = $ARGX;
}

printf("%09u\n",int(gaf($TEXT,$GAF_KEYA,$GAF_KEYB)));

####################################################################### }}} 1
# --- end ---
