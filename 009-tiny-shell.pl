#!/usr/bin/perl

use Data::Dumper; 

sub data();
sub interpreter($$);


data();
interpreter($DATA,join(" ",@ARGV));


sub interpreter($$) {
  my ($BASE,$COMMAND)=@_;
  $COMMAND =~ s/^\s+//;
  $COMMAND =~ s/\s+$//;
  $COMMAND =~ s/\s+/ /g;
  if($COMMAND =~ /^#/) { return; }

  my $FFLAG=0;
  foreach my $IX (@$BASE) {
    my $PATTERN = $IX->[0];
    next unless $COMMAND =~ /^${PATTERN}$/;
    $IX->[1]($COMMAND,$IX);
    print "PATTERN : ${PATTERN}\n";
    print $COMMAND ." >> " . Dumper($IX);
    $FFLAG=1; last;
  }
  warn "Syntax error '${COMMAND}'" unless $FFLAG;
}

sub ffox($$) {
  my($COMMAND,$LINE)=@_;
  my $FFOX='start "C:\opt\ffox\firefox.exe"';
  my $NOTE = $LINE->[3];
  my $URL  = $LINE->[2];
  print "firefox ${URL}\n${NOTE}\n";
  system("${FFOX} \"${URL}\"")
}

sub cmd($$) {
  my($COMMAND,$LINE)=@_;
  my $NOTE = $LINE->[3];
  my $CMD  = $LINE->[2];
  print "${CMD}\n${NOTE}\n";
  system("${CMD}")
}

sub data() {
our $DATA=[
["ffox any","ffox","file:///c:/usr/html/index.html","firefox home page"],
["ffox wlc","ffox","file:///c:/usr/html/wlc.html","Wireless Lan Controllers"],
["say hello","cmd","echo hello","Len tak zo srandy"]
];
}
# --- end ---

