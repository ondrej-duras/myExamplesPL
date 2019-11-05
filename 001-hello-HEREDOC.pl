#!/usr/bin/perl

our $HELLOX = "ABC_HELLO_VALUE_ABC";

our $HELLO2 = <<"__TEXT__";
Toto je zaciatok textu.
premenna ${HELLOX}
Toto je koniec textu.
__TEXT__

 
our $HELLO3 = <<'__TEXT__';
Toto je zaciatok textu.
premenna ${HELLOX}
Toto je koniec textu.
__TEXT__

print $HELLO2;
print "---\n";
print $HELLO3;

# -- end ---

