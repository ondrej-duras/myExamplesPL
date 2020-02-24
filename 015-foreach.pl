#!/usr/bin/perl

# A Simple way how to work with hostlist

@HELLO=qw/
Q-001-TT-RS-75 nx9k
Q-001-TT-LW-21 c3750
Q-001-TT-RS-50 nx7k
/;

$IX=0; $CT=scalar(@HELLO);
while($IX < $CT) {
  $HNAME=$HELLO[$IX++];
  $TYPE=$HELLO[$IX++];
  print "Device ${HNAME} is ${TYPE}\n";

}

