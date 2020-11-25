#!/usr/bin/perl
# 20201118, Ing. Ondrej DURAS (dury)
# following transform Cisco router/switch config into "grep-friendly" form.
# Provide similary formated  output 
# to juniper "show config | display set" or f5 " show running one-line"
#
# It's good for config comparision of just migrated boxes.
#
#=vim high Comment ctermfg=brown

=pod
DECLARATION:
  $SINLINE_CONF = singleLinedConfig($MULTILINE_CONF);

DESCRIPTION:
 Following "Structured/multilined/viac-riadkovany"
 vlan 111
   name XXX_YYY
 vlan 222
   name AAA_BBB

 changes to "siglelined/jedno-riadkovany" configuration file
 vlan 111
 vlan 111; name XXX_YYY
 vlan 222
 vlan 222; name AAA_BBB

 Benefit of single-lined config for analysis / post-0implementation checkout:
 Efect of configuration line "name AAA_BBB" depends on its position in config file.
 It is not the same whether conf line follows the vlan 111 or vlan 222 line.
 Well that relates to structured configuration.
 But the conf.line "vlan 111; name XXX_YYY" is position independent.
=cut


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
  my ($PAD,$TEXT);
  #while(my $LINE=<STDIN>) {
  foreach my $LINE (split("\n",$CONFIG)) {
    next if $LINE =~/^\s*$/;
    #my ($PAD,$TEXT) = pad($LINE);
    ($PAD,$TEXT) = $LINE =~ /^(\s*)(.*)/;
    $PAD = length($PAD);
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

