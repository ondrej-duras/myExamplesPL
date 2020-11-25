##!/usr/bin/perl
# 20201117, Ing. Ondrej DURAS Capt. (Ret.) (dury)

package TSIF;
## MANUAL ############################################################# {{{ 1


our $VERSION = 2020.112501;
our $MANUAL  = <<__MANUAL__;
NAME: SSH / TSIF Hello variant _A
FILE: TSIF.pm

DESCRIPTION:
  Script Example/Template for accessing
  onto the Network Device.

SEE ALSO:
  https://github.com/ondrej-duras/

VERSION: ${VERSION}
__MANUAL__


####################################################################### }}} 1
## DECLARATIONs ####################################################### {{{ 1

use Socket;
use IPC::Open3;
use PWA;
use Exporter;

our @ISA = qw( Exporter PWA );
our @EXPORT = qw(
  $VERSION
  $MANUAL

  xresolve
  singleLinedConfig
  save2File
  sshExec
  rawList2Cmd
  raw2Csv
  raw2Instant

  raw4Unknown
  raw4Default
  raw4Empty  

  
  $CLASS_MARKER
  $CLASS_PREFIX
  $HOST_PREFIX
);

our $CLASS_MARKER = "##!exit logout :CLASS_ID:";
our $CLASS_PREFIX = "##! CLASS_ID=";
our  $HOST_PREFIX = "##! HOST=";


####################################################################### }}} 1
## sub xresolve ####################################################### {{{ 1

sub xresolve($;$) {
  my ($PAR1,$PAR2)=@_;
  my ($DEVIP,$HNAME);

  # handling input parameters
  if(length($PAR2)) {
   ($DEVIP,$HNAME) = ($PAR1,$PAR2);
   # xdebug "#: '${PAR1}' '${PAR2}' '${DEVIP}' '${HNAME}'\n";
  } else {
    if($PAR1 =~ /^[0-9]+(\.[0-9]+){3}$/) {
     $DEVIP=$PAR1; $HNAME='';
    } else {
     $HNAME=$PAR1; $DEVIP='';
    }
  }

  # resolving IP from FQDN via DNS
  unless($DEVIP) {
    $HNAME = uc $HNAME;
    if( my $DAT = gethostbyname($HNAME)) {
       $DEVIP = inet_ntoa($DAT);
     } else { $DEVIP=""; }
    # xdebug "#: HNAME '${HNAME}' -> DEVIP '${DEVIP}'\n";
  }

  # resolving FQDN based on PTR of DEVIP via DNS
  unless($HNAME) {
    my $DAT=inet_aton($DEVIP);
    $FQDN=gethostbyaddr($DAT,AF_INET);
    $HNAME = $FQDN;
    $HNAME =~ s/\..*//;
    $HNAME = uc $HNAME;
    # xdebug "#: DEVIP '${DEVIP}' -> FQDN '${FQDN}' -> HNAME '${HNAME}'\n";
  }
  return ($DEVIP,$HNAME);
}

####################################################################### }}} 1
## sub singleLinedConfig ############################################## {{{ 1

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

sub save2File($$) {
  my ($FNAME,$DATA) = @_;
  open(my $fh,">",$FNAME) or die "#! No File '${FNAME}' created !\n";
  print $fh $DATA;
  close $fh;
  print "#+ File '${FNAME}' written.\n";

}


####################################################################### }}} 1
## sub sshExec ######################################################## {{{ 1

sub sshExec($$$;$) {
  my($HOST,$CRED,$COMMAND,$PROMPT)=@_;
  my($pid,$fh_in,$fh_out,$fh_err);
  my($DEVIP,$HNAME);

  # prefixes for common network platforms
  if($PROMPT eq "any")   { $PROMPT = '\S+[>#$]'; }
  if($PROMPT eq "cisco") { $PROMPT = $HOST . '(-NEW)?[>#]'; }
  if($PROMPT eq "junos") { $PROMPT = '[-0-9a-z]+\@' . $HOST . '(-NEW)?[>#$]\s*'; }
  if($PROMPT eq "f5")    { $PROMPT = '[-0-9a-z]+\@\(' . $HOST . '.*\(tmos\)\s*#\s*'; }
  if($PROMPT eq "tmos")  { $PROMPT = '[-0-9a-z]+\@\(' . $HOST . '.*\(tmos\)\s*#\s*'; }
  if($PROMPT eq "bigip") { $PROMPT = '[-0-9a-z]+\@\(' . $HOST . '.*\(tmos\)\s*#\s*'; }
  unless($PROMPT) { $PROMPT = '([-0-9a-z]+\@)?' . $HOST . '(-NEW)?[>#$]\s*'; }

  # no login, no session :-) 
  unless(pwaLogin($CRED)) {
    warn "#! Warning: None credentials '${CRED}' found !\n'";
    return "";
  }

  # no host, no session
  unless($HOST) {
    warn "#! Warning: None HOST '${HOST}' found !\n";
    return "";
  }
  ($DEVIP,$HNAME) = xresolve($HOST);

  # SSH session created via pipe into command-line ssh utility
  # .... Net::SSH2 whould be better, but .......... no comment.

  $pid=open3($fh_in,$fh_out,$fh_err,
       "sshpass -p " .pwaPassword($CRED)." ssh -tt "
     . " -o StrictHostKeyChecking=no"
     . " -o PubKeyAuthentication=no"
     . " -l " .pwaLogin($CRED). " ${HOST}");
  unless($pid) {
    warn "#! Warning: SSH connection failed !\n";
    return "";
  }

  # pushing all commands into ssh utility process
  sleep(2);
  print $fh_in $COMMAND;
  close $fh_in;

  # pulling errors if any
  my @OUTE = <$fh_err>;
  close $fh_err;
  if(scalar(@OUTE)) {
    @OUTE = map { $A=$_;
                  sprintf("##! ERR=%s\n",$A);
                } @OUTE;
  }  
  
  # pulling regular output from SSH session
  my $FFLAG=0;
  my @OUTA=<$fh_out>;
  close $fh_out;
  # dispatching process from processlist (otherwise a zombie will remain)
  waitpid($pid,0);

  # transforming output into RAW preTSIF format
  #print @OUTA; # DEBUG
  @OUTA = map { $A=$_;
                chomp $A;
                $A =~ s/\x0d//g; # filters out ^M from whole line
                if($A =~ /^${PROMPT}.*${CLASS_MARKER}/) {
                  $A =~ s/^.*${CLASS_MARKER}/${CLASS_PREFIX}/;
                }
                if($A =~ /^${PROMPT}/) {
                   $FFLAG = 1; $A="#> ${A}";
                }
                unless($FFLAG) { $A=""; }
                else { $A="${A}\n"; }
                #$A="${A}\n"; 
                sprintf("%s",$A);
              } @OUTA;
  # returning output with some distinguishers and errors (preTSIF RAW format)
  return "${HOST_PREFIX}${HOST} DEVIP=${DEVIP} HNAME=${HNAME}\n" . join("",@OUTA,@OUTE);
}

####################################################################### }}} 1
## sub rawList2Cmd #################################################### {{{ 1

sub rawList2Cmd($;$) {
  my ($RAWLIST,$OPT) = @_;
  my ($CMD_HEAD,$CMD_BODY,$CMD_TAIL);
  my ($RAWCLASS,$RAWCMD);
  
  unless($OPT) { $OPT="cisco"; }
  $RAWLIST = "##!${OPT}\n" . $RAWLIST;
  foreach my $LINE (split(/\n/,$RAWLIST)) {

    #print "#: >> ${LINE}\n"; # DEBUG
    if( $LINE =~ /^[A-Z][_0-9A-Za-z-]+;/) {
      ($RAWCLASS,$RAWCMD) = split(/\s*;\s*/,$LINE,2);
      $CMD_BODY .= "${CLASS_MARKER}${RAWCLASS}\n";
      $CMD_BODY .= "${RAWCMD}\n";
      #print "#: >>> ${RAWCLASS} : ${RAWCMD} : ${LINE}\n"; # DEBUG
      next;
    }
    if($LINE =~ /^##!none\s*$/ ) { # for any unusual type 
      $CMD_HEAD = "";
      $CMD_TAIL = "";
      next;
    }
    if($LINE =~ /^##!cisco\s*$/ ) { # Cisco NX-OS and IOS 12/15,IOS XE, IOS XR
      $CMD_HEAD = "terminal length 0\n";
      $CMD_TAIL = "${CLASS_MARKER}CUT_EXIT\nexit\nexit\nexit\n";
      next;
    }
    if($LINE =~ /^##!junos\s*$/ ) { # Juniper Junos only
      $CMD_HEAD = "set cli screen-length 0\n";
      $CMD_TAIL = "${CLASS_MARKER}CUT_EXIT\nexit\nexit\nexit\n";
    }
    if($LINE =~ /^##!(f5|tmos|bigip)\s*$/ ) { # F5 TMOS BigIP 
      $CMD_HEAD = "modify cli preference pager disabled display-threshold 0\n";
      $CMD_TAIL = "${CLASS_MARKER}CUT_EXIT\nquit\nquit\nexit\n";
    }
    if($LINE =~ /^#.*$/) { next; }  # regular comment line
    if($LINE =~ /^\s*$/) { next; }  # regular empty line
    # warn "Stressing user for some syntax error :-) ${LINE}\n";

  }
  return $CMD_HEAD . $CMD_BODY . $CMD_TAIL;
}

####################################################################### }}} 1
## sub raw2Csv ######################################################## {{{ 1

# Transforms RAW Output from Device (from sshExec) into RAW_TSIF
# RAW_TSIF ... may be it will not be needed anymore, 
# as RAW output is more compact, easier for human reading and provides
# exacly the same functionality.  ...so I think, it's going to become obsolete soon.

sub raw2Csv($;$) {
  my ($INPUT_TEXT,$OPT) = @_;
  my ($HOST,$DEVIP,$HNAME) = ("","","");
  my $CLASS = "CUT_HEAD";
  my $FFLAG = 0;
  my $CLASS = "";
  my $OUTPUT_TEXT = "";

  #print $INPUT_TEXT; # DEBUG
  foreach my $LINE (split(/\n/,$INPUT_TEXT)) {
    if($LINE =~ /^#> /) { next; } # copy of command-line entry
    if($LINE =~ /^##!/) { # RAW directives
      if($LINE =~ /^##! CLASS_ID=/) {
         $CLASS=$LINE;
         $CLASS =~ s/^##! CLASS_ID=//; 
         $FFLAG = 1;
         if($CLASS =~ /^CUT_/) { $FFLAG = 0; }
         next;
      } elsif ($LINE =~ /^##!\s+HOST=(\S+)\s+DEVIP=(\S+)\s+HNAME=(\S+)\s*$/) {
         @AHOST = map { $A=$_; $A =~ s/^[A-Z]+=//; $A } split(/\s+/,$LINE,5);
         $HOST=$AHOST[1]; $DEVIP=$AHOST[2]; $HNAME=$AHOST[3];
         next;
      } elsif ($LINE =~ /^##! HOST=\S+\s*$/) {
        $HOST=$LINE;
        $HOST =~ s/^##! HOST=//; $HOST =~ s/\s+$//;
        ($DEVIP,$HNAME) = xresolve($HOST);
        next;
      }
    }
  unless($FFLAG) { next; }
  $OUTPUT_TEXT .= "${DEVIP};${HNAME};${CLASS};${LINE}\n";
  }

  return $OUTPUT_TEXT;
} 

####################################################################### }}} 1
## sub raw2Instant #################################################### {{{ 1

sub raw4Unknown($$$$) {
  my ($DEVIP,$HNAME,$CLASS,$LINE) = @_;
  return "#! Warning: UnknownClass ${DEVIP};${HNAME};${CLASS};${LINE}\n";
}
sub raw4Default($$$$) {
  my ($DEVIP,$HNAME,$CLASS,$LINE) = @_;
  return "${DEVIP};${HNAME};${CLASS};${LINE}\n";
}
sub raw4Empty($$$$) {
  my ($DEVIP,$HNAME,$CLASS,$LINE) = @_;
  return "";
}


sub raw2Instant($$;$) {
  my ($INPUT_TEXT,$TSIF_BASE,$OPT) = @_;
  my ($HOST,$DEVIP,$HNAME) = ("","","");
  my $CLASS = "CUT_HEAD";
  my $FFLAG = 0;
  my $CLASS = "";
  my $METHOD = sub {};
  my $OUTPUT_TEXT = "";
  my $DEFAULT_METHOD = \&raw4Default;

  if($OPT eq "unknown") { 
    $DEFAULT_METHOD = \&raw4Unknown;
  }

  #print $INPUT_TEXT; # DEBUG
  foreach my $LINE (split(/\n/,$INPUT_TEXT)) {
    if($LINE =~ /^#> /) { next; } # copy of command-line entry
    if($LINE =~ /^##!/) { # RAW directives
      if($LINE =~ /^##! CLASS_ID=/) {
         $CLASS=$LINE;
         $CLASS =~ s/^##! CLASS_ID=//; 
         $FFLAG = 1;
         if($CLASS =~ /^CUT_/) { $FFLAG = 0; }
         if((exists($TSIF_BASE->{$CLASS})) and (ref($TSIF_BASE->{$CLASS}) eq "CODE")) {
           $METHOD = $TSIF_BASE->{$CLASS};
         } else {
           $METHOD = $DEFAULT_METHOD;
         }
         next;
      } elsif ($LINE =~ /^##!\s+HOST=(\S+)\s+DEVIP=(\S+)\s+HNAME=(\S+)\s*$/) {
         @AHOST = map { $A=$_; $A =~ s/^[A-Z]+=//; $A } split(/\s+/,$LINE,5);
         $HOST=$AHOST[1]; $DEVIP=$AHOST[2]; $HNAME=$AHOST[3];
         next;
      } elsif ($LINE =~ /^##! HOST=\S+\s*$/) {
        $HOST=$LINE;
        $HOST =~ s/^##! HOST=//; $HOST =~ s/\s+$//;
        ($DEVIP,$HNAME) = xresolve($HOST);
        next;
      }
    }
  unless($FFLAG) { next; }
  $OUTPUT_TEXT .= &$METHOD($DEVIP,$HNAME,$CLASS,$LINE);
  }

  return $OUTPUT_TEXT;
  
}

####################################################################### }}} 1
## tshoot / Main ###################################################### {{{ 1

=pod
C3750: <UnRestricted>
Gi1/0/14  HHHHHHHHHHHHHHH, M connected    707        a-full a-1000 10/100/1000BaseTX
Gi1/0/15                     disabled     1            auto   auto 10/100/1000BaseTX
Gi1/0/16  HHHHHHHHHHHHHHH MG connected    707        a-full a-1000 10/100/1000BaseTX
Gi1/0/17  HHHHHHHHHHHHHHH MG connected    707        a-full a-1000 10/100/1000BaseTX
Gi1/0/18                     disabled     routed       auto   auto 10/100/1000BaseTX
Gi1/0/19                     disabled     routed       auto   auto 10/100/1000BaseTX
Gi1/0/20  hhhhhhhhhhhh, mgmt connected    4          a-full a-1000 10/100/1000BaseTX
Gi1/0/21  DDDDDDDDDDDDDD MGM connected    706        a-full a-1000 10/100/1000BaseTX
Gi1/0/22  DDDDDDDDDDDDDD MGM connected    706        a-full a-1000 10/100/1000BaseTX
Gi1/0/23                     disabled     routed       auto   auto 10/100/1000BaseTX
Te1/1/1   DDDDDDDDDDDDDD-NEW connected    trunk        full    10G SFP-10GBase-SR
Te1/1/2   DDDDDDDDDDDDDD-NEW connected    trunk        full    10G SFP-10GBase-SR
Po1       DDDDDDDDDDDDDx-NEW connected    trunk      a-full    10G
Fa0                          disabled     routed       auto   auto 10/100BaseTX

NX9K:
Eth1/1        DDDDDDDDDDDDDD Eth connected trunk     full    100G    QSFP-100G-SR4-S
Eth1/2        DDDDDDDDDDDDDD Eth connected trunk     full    100G    QSFP-100G-SR4-S
Eth1/3        DDDDDDDDDDDDDD Eth connected trunk     full    100G    QSFP-100G-ER4-S
Eth1/4        DDDDDDDDDDDDDD Eth connected trunk     full    100G    QSFP-100G-ER4-S
Eth1/5        DDDDDDDDDDDDDDD 1/ connected trunk     full    100G    QSFP-100G-SR4-S
Eth1/6        --                 disabled  routed    auto    auto    QSFP-100G-LR4-S
Eth1/7        --                 disabled  routed    auto    auto    QSFP-100G-LR4-S
Eth1/8        --                 connected routed    full    100G    QSFP-100G-SR4-S
Eth1/9        --                 xcvrAbsen routed    auto    auto    --
Eth1/10       --                 xcvrAbsen routed    auto    auto    --
Eth1/11       --                 xcvrAbsen routed    auto    auto    --
=cut

=pod
# Example of Command sequese, that should be prepared by rawList2Cmd
# also it's usual sequece for any Cisco IOS,IOS XE, IOS XR, NX-OS
our $CMD = <<__CMD__;
terminal length 0
##!exit logout :CLASS_ID:RAW_OSVER
show ver
##!exit logout :CLASS_ID:RAW_IF_STATUS
show int status
exit
exit
exit
__CMD__

# Example of sequence for Juniper
our $JCMD = <<__CMD__;
set cli screen-length 0
show version
show chassis hardware
exit
__CMD__

# Example of sequence for F5
our $F5CMD = <<__CMD__;
modify cli preference pager disabled display-threshold 0
show net vlan | grep -E '^(Net|Tag)'
show ltm virtual | grep -E '^Ltm'
quit
__CMD__

# Example or RAW List
our $RL_NX9K = <<__RAW__;
RAW_NX9K_IF_DESC; show int description | include ^(Eth|Po|Vl)
RAW_NX9K_IF_STAT; show int status | include ^(Eth|Po|Vl)
RAW_NK9K_VLAN_DESC; show vlan brief | include ^[0-9]
CUT_EXIT; exit
__RAW__

#print sshExec("DDDDDDDDDDD-34","user",$CMD);  # NX-OS (default prompt is usually fine, but "cisco" can be used instead)
#print sshExec("DDDDDDDDDDD-98","user",$CMD);  # IOS   (default prompt is usually fine, but "cisco" can be used instead)
#print sshExec("DDDDDDDDDDD-70","user",$JCMD); # Junos (default prompt is usually fine, but "junos" can be used instaed)
#print sshExec("DDDDDDDDDDDC-52-01","user",$F5CMD,"f5"); # F5 uses a specific predefined prompt
#print raw2Csv(sshExec("DDDDDDDDDDD-34","user",rawList2Cmd($RL_NX9K)));
#print raw2Instant(sshExec("DDDDDDDDDDD-34","user",rawList2Cmd($RL_NX9K)),{},"unknown"); # if we want trace unsuported classes
#print raw2Instant(sshExec("DDDDDDDDDDD-34","user",rawList2Cmd($RL_NX9K)),{});  # Default behaviour, same as rawOutput2Csv
=cut

####################################################################### }}} 1
1;
# --- end ---

