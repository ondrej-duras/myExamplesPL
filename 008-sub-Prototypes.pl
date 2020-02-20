#!/usr/bin/perl

use Data::Dumper;

# ... volitelny parameter volany hodnotou / typ hash
sub hello1($;%) {
  my ($TEXT,%SETUP)=@_;
  if($SETUP{"ZACIATOK"} eq "ano" ) { print "Zaciatok.\n"; }
  print "Hello World with '${TEXT}' !\n";
  if($SETUP{"KONIEC"} eq "ano") { print "Koniec.\n"; }
  $SETUP{"HELLO"}="hello";
}

# ... volitelny parameter volany odkazom / typ hash
# obsah hashu mozme menit, avsak nemozno zadat
# parameter ako nepomenovany parameter (ako v pripade hello1.
# Parameter musi byt niekde deklarovany a inicializovany
# a pri volani fcie si to perl interne premeni na smernik
sub hello2($;\%) {
  my($TEXT,$SETUP)=@_;
  if($SETUP->{"ZACIATOK"} eq "ano") { print "ZACIATOK.\n"; }
  print "${TEXT}...\n";
  if($SETUP->{"KONIEC"} eq "ano") { print "KONIEC.\n"; }
  $SETUP->{"HELLO"}="hello";
}

%AHOJ=("ZACIATOK"=>"ano","KONIEC"=>"ano");

hello1("Ahoj 1");
hello1("Ahoj 2",ZACIATOK=>"ano",KONIEC=>"nie");
hello1('Ahoj 3',KONIEC=>"ano",ZACIATOK=>"ano");
hello1("Ahoj 4",ZACIATOK=>"nie",KONIEC=>"ano");
hello1("Ahoj 5",%AHOJ);
print Data::Dumper->Dump([\%AHOJ],["AHOJ"]);

hello2("Ahoj a1");
# hello2("Ahoj a2","ZACIATOK"=>"ano","KONIEC"=>"ano"); << toto nefunguje, 
# lebo musi to byt premenna aj jej obsah musi byt mozne zmenit
hello2("Ahoj a3",%AHOJ);
print Data::Dumper->Dump([\%AHOJ],["AHOJ"]);

# volitelny parameter volany hodnotou
sub hello3(;@) {
  my(@DATA)=@_;

  print "List: ";
  foreach my $I (@DATA) {
    print "${I} ";
  }
  print "\n";
  unshift @DATA,99;
  push    @DATA,99;
}

# volitejny parameter pole, volany odkazom
sub hello4(;\@) {
  my($DATA)=@_;
  print "List: ";
  foreach my $I (@$DATA) {
    print "${I} ";
  }
  print "\n";
  if(scalar @$DATA) {
    my $X=$DATA->[0];
    print "First: ${X}\n";
  }
  unshift @$DATA,99;
  push    @$DATA,99;

}

@CISLA=(1,2,3,4,5,6,7);
hello3();
hello3(1,2,3);
hello3(@CISLA);
print Data::Dumper->Dump([\@CISLA],["CISLA"]);
# hello4(1,2,3,4); << toto nefunguje
# hello4(@[1,2,3,4]); << a ani tento ojeb nefunguje, pole musi 
# byt deklarovane a inicializovane, a pri jeho pouziti perl
# premeni parameter na smernik, miesto hodnoty
hello4(@CISLA);
print Data::Dumper->Dump([\@CISLA],["CISLA"]);


# --- end ---


