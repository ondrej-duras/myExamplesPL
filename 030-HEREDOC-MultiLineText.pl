#!/usr/bin/perl

# Viacriadkove textove premenne - Templaty
# ... vygooglis ako "HEREDOC" hodnoty

$PREMENNA="ahoj ahoj ahoj";

# interpolovany - to znamena, ze premenne vo vnutri 
# su nahradene hodnotami
$VZOR1 = <<_VZOR1_;
Tento text ma viac riadkov
a obsahuje aj premenne
Napriklad ${PREMENNA}
sa tu moze 
---
_VZOR1_

# toto je taktiez interpolovany vzor
# len je to inak napisane - s uvodzovkami
$VZOR2 = <<"_VZOR2_";
Tento text ma viac riadkov
a obsahuje aj premenne
Napriklad ${PREMENNA}
sa tu moze 
---
_VZOR2_

# a toto je neinterpolovany text
# cize premenne v nom niesu prekladane na ich hodnoty
$VZOR3 = <<'_VZOR3_';
Tento text ma viac riadkov
a obsahuje aj premenne
Napriklad ${PREMENNA}
sa tu nemoze.
Toto sa pouziva na dlhe predlohy obsahujuce
vela riadiacich znakov v povodnom zneni,
hlavne dolarov
---
_VZOR3_


print $VZOR1;
print $VZOR2;
print $VZOR3;

# --- end ---

