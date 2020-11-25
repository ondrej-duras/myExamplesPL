#!/usr/bin/perl
# 20201118, Ing. Ondrej DURAS (dury)
# following transform Cisco router/switch config into "grep-friendly" form.
# Provide similary formated  output 
# to juniper "show config | display set" or f5 " show running one-line"
#
# It's good for config comparision of just migrated boxes.
#
#=vim high Comment ctermfg=brown



sub pad($) {
  my $LINE = shift;
  unless(length($LINE)) { return (0,""); }
  my ($PAD,$TEXT) = $LINE =~ /^(\s*)(.*)/;
  return (length($PAD),$TEXT);
} 

sub singleLinedConfig($) {
  my $CONFIG  = shift;
  my @STACK_L = (); # Lines
  my @STACK_P = (); # Padding
  my $STACK_C = 0;  # Counter
  my $OUTPUT  = "";
  #while(my $LINE=<STDIN>) {
  foreach my $LINE (split("\n",$CONFIG)) {
    next if $LINE =~/^\s*$/; 
    my ($PAD,$TEXT) = pad($LINE);
    my $FFLAG = 1;
    while($FFLAG) {
      unless($STACK_C) { $FFLAG=0; last; }
      unless( $PAD > $STACK_P[-1]) {
        pop @STACK_P; pop @STACK_T; $STACK_C--;
        $FFLAG=1; next;
      }
      $FFLAG = 0;
    }
    push @STACK_P,$PAD; push @STACK_T,$TEXT; $STACK_C++;
    #print join(";",@STACK_T) ."\n";
    $OUTPUT .= join(";",@STACK_T) ."\n";
  }
  return $OUTPUT;
}

print singleLinedConfig(join("",<STDIN>));

# --- end ---

