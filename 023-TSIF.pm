##!/usr/bin/perl
# 20201117, Ing. Ondrej DURAS Capt. (Ret.) (dury)

package TSIF;
## MANUAL ############################################################# {{{ 1


our $VERSION = 2021.021601;
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

  pwaCred
  pwaMethod
  pwaLogin
  pwaPassword

  xresolve

  oneLine
  singleLinedConfig
  save2File
  loadFile
  sortText

  sshExec
  sshExecCisco
  rawList2Cmd
  raw2Csv
  raw2Instant

  raw4Unknown
  raw4Default
  raw4Empty  

  nowhite
  portSort
  loadHostList
  dev2Instant
  alldev2Instant
  
  $CLASS_MARKER
  $CLASS_PREFIX
  $HOST_PREFIX

  $RL_LIST
  $RL_NXOS_TAB
  $RL_NXOS_TOPO
  $RL_C3750_TOPO

  $TSIF_BASE
);

our $CLASS_MARKER = "##!exit logout :CLASS_ID:";
our $CLASS_PREFIX = "##! CLASS_ID=";
our  $HOST_PREFIX = "##! HOST=";

our $HOSTLIST     = ""; # List of fully qualified / discovered network devices (example bellow)
our $IF_DATA   = {}; # interface name => interface attribute class => interface data ...big structure
our $TSIF_BASE = {}; # RAW_CLASS => sub($$$$$) { data line handling procedure ... }, ... used by raw2Instant() function

# used by $TSIF_BASE subRoutines
our $ACTROUTE = ""; # ip route network
our $ACTVRF   = ""; # ip route vrf
our $ACTIF    = ""; # vrrp interface
our $ACTSTATE = ""; # vrrp status Active/Backup
our $ACTVIP   = ""; # vrrp Virtual IP
our $ACTPRIO  = ""; # vrrp priority
our $ACTACTIV = ""; # vrrp master


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
## sub oneLine / singleLinedConfig #################################### {{{ 1

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

sub oneLine($) {
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
        pop @STACK_P; pop @STACK_L; $STACK_C--;
        $FFLAG=1; next;
      }
      $FFLAG = 0;
    }
    push @STACK_P,$PAD; push @STACK_L,$TEXT; $STACK_C++;
    #print join(";",@STACK_L) ."\n";
    $OUTPUT .= join(";",@STACK_L) ."\n";
  }
  return $OUTPUT;
}

sub singleLinedConfig($) {
  return oneLine(shift);
}
####################################################################### }}} 1
## sub multiLine ###################################################### {{{ 1

=pod
DECLARATION:
  MULTILENED_TXT=multiLine($ONELINED;$SHIFT);

DESCRIPTION:
  it's reverse function to oneLine.
=cut

sub multiLine($;$) {
  my ($INPUT,$SHIFT)  = @_;  # string of input text
  my $OUTPUT = "";    # string of output/returned string
  my $LAST   = "";      # previous/last parsed line
  my $LINE   = "";
  unless($SHIFT) { $SHIFT  = " "; }  # increment of indentation
  foreach $LINE (split(/\n/,$INPUT)) {
    if($LINE =~/^#/) { $OUTPUT .= "${LINE}\n"; next; }
    my @ALAST = split(/;/,$LAST); $LAST = $LINE;
    my @ALINE = split(/;/,$LINE);
    my $EXTRA = 0;
    my $INDENT= "";    # indent ... spaces of indentation / for whole level of recursion
    my ($ILAST,$ILINE);

    while($ILINE = shift @ALINE) {
      if(scalar(@ALAST)) {  $ILAST = shift @ALAST; }
      else { $EXTRA = 1; $ILAST = ""; }
      if ( ($EXTRA == 0 ) and ($ILINE eq $ILAST )) {  $INDENT .= $SHIFT; next; }
      $EXTRA = 1;
      $OUTPUT .= "${INDENT}${ILINE}\n"; $INDENT .= $SHIFT;
    }
  }
  return $OUTPUT;
}


####################################################################### }}} 1
## sub save2File loadFile sortText #################################### {{{ 1

sub save2File($$) {
  my ($FNAME,$DATA) = @_;
  open(my $fh,">",$FNAME) or die "#! No File '${FNAME}' created !\n";
  print $fh $DATA;
  close $fh;
  print "#+ File '${FNAME}' written.\n";

}

sub loadFile($) {
  my $FNAME = shift;
  my $TIME = time();
  open(my $fh,"<",$FNAME) or die "#! None File '${FNAME}' found !\n";
  my @DATA=<$fh>;
  close $fh;
  my $DATA_CT = scalar @DATA;
  $DATA = join("",@DATA);
  my $DATA_SZ = length $DATA;
  $TIME = time() - $TIME;
  print "#: File '${FNAME}' Loaded. Lines=${DATA_CT} Bytes=${DATA_SZ} Time=${TIME} sec\n";
  return $DATA;
}

sub sortText($) {
  my $TEXT = shift;
  return join("\n",sort split("\n",$TEXT)) . "\n";
}


####################################################################### }}} 1
## sub sshExec / sshExecCisco ######################################### {{{ 1

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

# sshExec for one command on Cisco devices
sub sshExecCisco($$$;$) {
  my($HOST,$CRED,$COMMAND,$PROMPT)=@_;
  $COMMAND = "terminal length 0\n" . $COMMAND . "\nexit\nexit\n";
  return sshExec($HOST,$CRED,$COMMAND,$PROMPT);
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
  #my $CLASS = "";
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
  #my $CLASS = "";
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

## $RL_LISTs - RAW Lists - Command Sets for platforms ################# {{{ 1

our $RL_LIST = {
 "nxos" => \$RL_NX9K,
 "c3750" => \$RL_C3750
};

our $RL_NXOS_TAB = <<__RAWLIST__;
RAW_NX9K_VLAN; show vlan brief | include ^[0-9]
RAW_NX9K_IFSTAT; show int status | include "^(Po|Vl)"
CUT_CLEARLINE; show clock
RAW_NX9K_ROUTES; show ip route vrf all
CUT_CLEARLINE; show clock
RAW_NX9K_IPv6ROUTE; show ipv6 route vrf all
RAW_NX9K_VRRP; show vrrp detail
RAW_NX9K_HSRP; show hsrp brief
__RAWLIST__

our $RL_NXOS_TOPO = <<__RAW__;
##!cisco
RAW_NX9K_VLAN_DESC; show vlan brief | include ^[0-9]
OPT_CLEAR_IF_DATA;  show clock
RAW_NX9K_H_STATUS;  show int status | include ^(Eth|Po[0-9]|Vl|Lo|mgmt)
RAW_NX9K_H_DESC;    show int description | include ^(Eth|Po[0-9]|Vl|Lo|mgmt)
OPT_FEED_IF_DESC;   show clock
OPT_CLEAR_IF_DATA;  show clock
RAW_NX9K_H_NATIVE;  show int trunk | begin "Native" | end "Vlans Allowed" | include "^(Eth|Po[0-9])"
RAW_NX9K_H_TRUNK;   show int trunk | begin "Vlans Allowed" | end "Err-disabled" | include "^(Eth|Po[0-9])"
OPT_FEED_IF_TRUNK;  show clock
__RAW__

our $RL_C3750_TOPO = <<__RAW__;
##!cisco
RAW_C3750_VLAN_DESC; show vlan brief | include ^[0-9]
OPT_CLEAR_IF_DATA;   show clock
RAW_C3750_H_STATUS;  show int status | include ^(Gi|Fa|Te|Po[0-9]|Vl|Lo)
RAW_C3750_H_DESC;    show int description | include ^(Gi|Fa|Te|Po[0-9]|Vl|Lo)
OPT_FEED_IF_DESC;    show clock
RAW_C3750_IF_TRUNK;  show int switchport
__RAW__

####################################################################### }}} 1
## TSIF_BASE Support subRoutines ###################################### {{{ 1

# Striping white spaces from both ends
# of the single line string
sub nowhite($) {
  my $TEXT = shift;
  if($TEXT eq undef) { return ""; }
  $TEXT =~ s/^\s+//;
  $TEXT =~ s/\s+$//;
  return $TEXT;
}

# sorts interface names in proper order.
# @E = qw( Eth1/1 Eth1/2 Eth1/101 Eth3/21 Eth1/22 Eth1/21 Eth1/45 Eth2/101);
sub portSort($$) {
  my ($a,$b) = @_;
  my ($TA,$NA,$TB,$BN,$XX);
  ($TA,$NA) = $a =~ /(.*[^0-9])([0-9]+)$/; # test,number part
  ($TB,$NB) = $b =~ /(.*[^0-9])([0-9]+)$/;
  # print "#: (${a} -> ${TA} ${NA}) (${b} -> ${TB} ${NB})\n"; # DEBUG
  unless($XX=($TA cmp $TB)) { $XX=(int($NA) <=> int($NB)); }
  return $XX;
}


sub raw_VLAN_DESC($$$$) {
   my ($DEVIP,$HNAME,$CLASS,$LINE) = @_;
   my($ID,$NAME,$STATE);
   $CLASS="VLAN_DESC";
   $ID   = substr($LINE, 0, 4); $ID   =~ s/\s+//g;
   $NAME = substr($LINE, 5,32); $NAME =~ s/\s+//g;
   $STATE= substr($LINE,38, 9); $STATE=~ s/\s+//g;
   return "${DEVIP};${HNAME};${CLASS};${ID};${NAME};${STATE};-na-;-na-\n";
}

# our $HOSTLIST=<<__HOSTLIST__;
# 10.39.1.101;D-005-BA-RS-50;HOST;ssh;user;nx9k
# 10.39.1.102;D-005-BA-RS-51;HOST;ssh;user;nx9k
# 10.39.1.103;D-101-BA-RS-60;HOST;ssh;user;nx9k
# 10.39.1.104;D-101-BA-RS-61;HOST;ssh;user;nx9k
# 10.39.2.97;D-005-BA-LW-97;HOST;ssh;user;c3750
# 10.39.2.98;D-101-BA-LW-98;HOST;ssh;user;c3750
# __HOSTLIST__

# loads a HostList from file formated as an example above
sub loadHostList($) {
  my $FNAME = shift;
  my $fh;
  open($fh,"<",$FNAME) or die "#! None HOSTLIST.csv found !\n";
  $HOSTLIST=join("",<$fh>);
  close $fh;
}

sub dev2Instant($;$) {
  my ($LINE,$fh)=@_;
  unless($fh) { $fh=STDOUT; }
  my($DEVIP,$HNAME,$CLASS,$PROTO,$CRED,$TYPE)=split(/\s*;\s*/,$LINE,6);
  my $RAW;
  unless(exists($RL_LIST->{$TYPE})) { return "#! Warning: wrong device type: ${LINE}\n"; }
  if($PROTO eq "ssh") {
    my $ATIME = time;
    my $RL = ${$RL_LIST->{$TYPE}};
    # print $RL; # DEBUG
    $RAW=sshExec($HNAME,$CRED,rawList2Cmd($RL));
    my $BTIME = time;
    my $TTIME = $BTIME - $ATIME;
    if(length($RAW) < 1000) { return "#! Connection Failed ! (${TTIME})\n"; }
    print $fh raw2Instant($RAW,$TSIF_BASE);
    my $CTIME = time;
    my $QTIME = $CTIME - $ATIME;
    return " ..... ok. (${TTIME} $QTIME)\n";
  }
}

sub alldev2Instant($$) {
  my($INFILE,$OUTFILE)=@_;
  unless(pwaLogin("user")) { die "#! . prepare.sh first !\n"; }
  my $XTIME = time;
  #loadHostList("HOSTLIST.csv");
  loadHostList($INFILE);
  open(my $fh_out,">",$OUTFILE) or die "#! No output created !\n";
  foreach my $LINE (split(/\n/,$HOSTLIST)) {
    next if $LINE =~ /^\s*$/;
    next if $LINE =~ /^\s*#/;
    print "${LINE}";
    print ";" . dev2Instant($LINE,$fh_out);
  }
  close $fh_out;
  my $YTIME = time;
  my $ZTIME = $YTIME - $XTIME;
  print "#+ done. (${ZTIME}sec)\n";
}

#$RAW = sshExec("D-005-BA-RS-50","user",rawList2Cmd($RL_NX9K));
#$INSTANT = raw2Instant($RAW,$TSIF_BASE);

#$RAW = sshExec("D-005-BA-LW-97","user",rawList2Cmd($RL_C3750));
#$INSTANT .= raw2Instant($RAW,$TSIF_BASE);

#print $RAW;
#print "# ---\n";

#$CSV = raw2Csv($RAW1);
#print $CSV;
#print "# ---\n";

#print $INSTANT;
#print "# ---\n";

## Way to Collect status tables from Nexus
#print "#: Collecting Status Tables from OLD '${OLDHNAME}' ...\n";
#unless(pwaPassword($OLDCRED)) { die "#! '${OLDCRED}' credentials first !\n"; }
#our $RAW = sshExec($OLDHNAME,$OLDCRED,rawList2Cmd($RL_NXOS_TAB));
#our $INS = raw2Instant($RAW,$TSIF_BASE);
#save2File("d15-TABLES-OLD-${OLDHNAME}.csv",$INS);



####################################################################### }}} 1
## $TSIF_BASE definition ############################################## {{{ 1

our $IF_DATA={};
our $TSIF_BASE = {
"CUT_CLEARLINE" => sub {
  my($DEVIP,$HNAME,$CLASS,$LINE) = @_;
  $ACTROUTE = "";
  $ACTVRF   = "";

},
"RAW_NX9K_ROUTES" => sub {
  my($DEVIP,$HNAME,$CLASS,$LINE) = @_;
  if($LINE =~ /^'/) { return ""; }
  if($LINE =~ /^IP Route Table for VRF "/) {
    $ACTVRF = $LINE; $ACTVRF =~ s/^.* "//; $ACTVRF =~ s/"$//;
  }
  if($LINE =~ /^[0-9]+(\.[0-9]+){3}\/[0-9]+/) {
    $ACTROUTE = $LINE; return "";
  }
  if($LINE =~ /^\s+\*via/) {
    my $OUT = "${ACTROUTE} ${LINE}";
    $OUT =~ s/,/;/g;
    $OUT =~ s/\s+/ /g;
    $OUT =~ s/\]; [0-9a-z:]+;/\];;/;
    return "${DEVIP};${HNAME};NET_ROUTE;${ACTVRF};${OUT}\n";
  }
  return "";
},
"RAW_NX9K_IPv6ROUTE" => sub {
  my($DEVIP,$HNAME,$CLASS,$LINE) = @_;
  if($LINE =~ /^'/) { return ""; }
  if($LINE =~ /^IPv6 Routing Table for VRF "/) {
    $ACTVRF = $LINE; $ACTVRF =~ s/^.* "//; $ACTVRF =~ s/"$//;
  }
  if($LINE =~ /^[0-9a-f]+(:[0-9a-f]*)+/) {
    $ACTROUTE = $LINE; return "";
  }
  if($LINE =~ /^\s+\*via/) {
    my $OUT = "${ACTROUTE} ${LINE}";
    $OUT =~ s/,/;/g;
    $OUT =~ s/\s+/ /g;
    $OUT =~ s/\]; [0-9a-z:]+;/\];;/;
    return "${DEVIP};${HNAME};NET_IPv6ROUTE;${ACTVRF};${OUT}\n";
  }
  return "";
},
"RAW_NX9K_IFSTAT" => sub {
  my($DEVIP,$HNAME,$CLASS,$LINE) = @_;
  my($IF,$NAME,$STATUS,$WASTE) = split(/\s+/,$LINE,4);
  return "${DEVIP};${HNAME};NET_IFSTAT;${IF};${STATUS}\n";
},
"RAW_NX9K_VLAN" => sub {
  my($DEVIP,$HNAME,$CLASS,$LINE) = @_;
  my($ID,$NAME,$STATUS,$WASTE) = split(/\s+/,$LINE,4);
  return "${DEVIP};${HNAME};NET_VLAN;${ID};${NAME};${STATUS}\n";
},
"RAW_NX9K_VRRP" => sub {
  my($DEVIP,$HNAME,$CLASS,$LINE) = @_;
  if($LINE =~/^(Vlan|port|Eth)/) {
    $ACTIF = $LINE; $ACTIF =~ s/\s.*//;
    return "";
  }
  if($LINE =~ /^\s*State is /) {
    $ACTSTATE = $LINE; $ACTSTATE =~ s/^\s*State is //;
    return "";
  }
  if($LINE =~ /Virtual IP/) {
    $ACTIP = $LINE; $ACTIP =~ s/^.* is /vip:/;
  }
  if($LINE =~ /^\s*Priority/) {
    $ACTPRIO = $LINE; $ACTPRIO =~ s/,.*//; $ACTPRIO =~ s/^\s*Priority /Prio:/;
    return "";
  }
  if($LINE =~ /^\s*Master router is/) {
    $ACTACTIV = $LINE; $ACTACTIV =~ s/^.*router is /master:/;
    return "${DEVIP};${HNAME};IF_VRRP;${ACTIF};${ACTSTATE};vip:${ACTIP};Prio:${ACTPRIO};master:${ACTACTIV}\n";
  }
},
"RAW_NX9K_HSRP" => sub {
  my($DEVIP,$HNAME,$CLASS,$LINE) = @_;
  $LINE =~s/^\s+//;
  my($IF,$GRP,$ASTER,$PRIO,$PPP,$STATE,$ACTIVE,$STANDBY,$VIP,$WASTE) = split(/\s+/,$LINE,10);
  return "${DEVIP};${HNAME};IF_HSRP;${IF};${STATE};${VIP};${PRIO};${ACTIVE}\n";
},

 "OPT_CLEAR_IF_DATA" => sub {
   my($DEVIP,$HNAME,$CLASS,$LINE) = @_;
   $IF_DATA = {};
   return "";
 },
 "RAW_NX9K_H_STATUS" => sub {  # --------------
   my($DEVIP,$HNAME,$CLASS,$LINE) = @_;
   my($IF,$STATUS,$VLAN,$SPEED,$SFP);
   my $PT;

   $IF     = nowhite(substr($LINE,0,13)); # ^ -------------
   $STATUS = nowhite(substr($LINE,33,9)); # ---------------------------------- ---------
   $VLAN   = nowhite(substr($LINE,43,9)); # -------------------------------------------- ---------
   $SPEED  = nowhite(substr($LINE,61,7)); # -------------------------------------------------------------- -------
   $SFP    = nowhite(substr($LINE,69));   # ---------------------------------------------------------------------- $

   unless(exists($IF_DATA->{$IF})) { $IF_DATA->{$IF}={}; }
   $PT = $IF_DATA->{$IF};

   $PT->{"STATUS"} = $STATUS;
   $PT->{"VLAN"}   = $VLAN;
   $PT->{"SPEED"}  = $SPEED;
   $PT->{"SFP"}    = $SFP;
   return "";
 },
 "RAW_C3750_H_STATUS" => sub {  # --------------
   my($DEVIP,$HNAME,$CLASS,$LINE) = @_;
   my($IF,$STATUS,$VLAN,$SPEED,$SFP);
   my $PT;

   $IF     = nowhite(substr($LINE,0,10));
   $STATUS = nowhite(substr($LINE,29,12));
   $VLAN   = nowhite(substr($LINE,42,8));
   $SPEED  = nowhite(substr($LINE,60,6));
   $SFP    = nowhite(substr($LINE,67));

   unless(exists($IF_DATA->{$IF})) { $IF_DATA->{$IF}={}; }
   $PT = $IF_DATA->{$IF};

   $PT->{"STATUS"} = $STATUS;
   $PT->{"VLAN"}   = $VLAN;
   $PT->{"SPEED"}  = $SPEED;
   $PT->{"SFP"}    = $SFP;
   return "";
 },
 "RAW_NX9K_H_DESC" => sub {
   my($DEVIP,$HNAME,$CLASS,$LINE) = @_;
   my($IF,$DESC,$PT,$WASTE);

   if($LINE =~ /^Eth[0-9]/) {
     ($IF,$WASTE,$WASTE,$DESC) = split(/\s+/,$LINE,4);
   } else {
     ($IF,$DESC) = split(/\s+/,$LINE,2);
   }
   unless(exists($IF_DATA->{$IF})) { $IF_DATA->{$IF}={}; }
   $IF_DATA->{$IF}->{"DESC"} = $DESC;
   return "";

 },
 "RAW_C3750_H_DESC" => sub {
   my($DEVIP,$HNAME,$CLASS,$LINE) = @_;
   my($IF,$DESC,$PT,$WASTE);

   ($IF,$WASTE) = split(/\s/,$LINE,2);
   $DESC = substr($LINE,55);

   unless(exists($IF_DATA->{$IF})) { $IF_DATA->{$IF}={}; }
   $IF_DATA->{$IF}->{"DESC"} = $DESC;
   return "";
 },
 "OPT_FEED_IF_DESC" => sub {
   my($DEVIP,$HNAME,$CLASS,$LINE) = @_;
   my($IF,$STATUS,$VLAN,$SPEED,$SFP,$DESC,$PT);
   my $OUTPUT = "";
   foreach $IF (sort portSort keys %$IF_DATA) {
     $PT = $IF_DATA->{$IF};
     $STATUS = nowhite($PT->{"STATUS"});
     $VLAN   = nowhite($PT->{"VLAN"});
     $SPEED  = nowhite($PT->{"SPEED"});
     $SFP    = nowhite($PT->{"SFP"});
     $DESC   = nowhite($PT->{"DESC"});
     $OUTPUT .= "${DEVIP};${HNAME};IF_DESC;${IF};${STATUS};${VLAN};${SPEED};${SFP};${DESC}\n";
   }
   return $OUTPUT;
 },
 "RAW_C3750_VLAN_DESC" => \&raw_VLAN_DESC,
 "RAW_NX9K_VLAN_DESC"  => \&raw_VLAN_DESC,
 "RAW_NX9K_H_NATIVE" =>sub {
   my($DEVIP,$HNAME,$CLASS,$LINE) = @_;
   my($IF,$NATIVE,$WASTE) = split(/\s+/,$LINE,3);

   unless(exists($IF_DATA->{$IF})) { $IF_DATA->{$IF}={}; }
   $IF_DATA->{$IF}->{"NATIVE"} = $NATIVE;
   return "";

 },
 "RAW_NX9K_H_TRUNK" => sub{
   my($DEVIP,$HNAME,$CLASS,$LINE) = @_;
   my ($IF,$VLANS);
   our $TRUNK_IF;
   if($LINE =~ /^(Po[0-9]|Eth)/) {
    ($IF,$VLANS) = split(/\s+/,$LINE,2);
    $TRUNK_IF=$IF;
   } else {
    $IF=$TRUNK_IF;
    $VLANS=$LINE;
   }
   unless(exists($IF_DATA->{$IF})) { $IF_DATA->{$IF}={}; }
   unless(exists($IF_DATA->{$IF}->{"TRUNK"})) {
     $IF_DATA->{$IF}->{"VLANS"} = $VLANS;
   } else {
     $IF_DATA->{$IF}->{"VLANS"} .= $VLANS;
   }
   return "";
 },
 "OPT_FEED_IF_TRUNK" => sub{
   my($DEVIP,$HNAME,$CLASS,$LINE) = @_;
   my($IF,$NATIVE,$VLANS,$PT);
   my $OUTPUT = "";
   foreach $IF (sort portSort keys %$IF_DATA) {
     $PT = $IF_DATA->{$IF};
     $NATIVE = nowhite($PT->{"NATIVE"});
     $VLANS  = nowhite($PT->{"VLANS"});
     $OUTPUT .= "${DEVIP};${HNAME};IF_TRUNK;${IF};${NATIVE};;${VLANS}\n";
   }
   return $OUTPUT;
 },
 "RAW_C3750_IF_TRUNK" => sub {
   my($DEVIP,$HNAME,$CLASS,$LINE) = @_;
   our $RAW_IF;
   our $RAW_NATIVE;
   our $RAW_VLANS;
   our $RAW_TRUNK;
   my $WASTE;
   if($LINE =~ /^Name:/) {
     ($WASTE,$RAW_IF) = split(/\s+/,$LINE,2);
     return "";
   }
   if($LINE =~ /^Operational Mode:/) {
     $RAW_TRUNK=$LINE; $RAW_TRUNK=~s/^.*://;
     return "";
   }
   if($LINE =~ /^Trunking Native Mode VLAN:/) {
     $RAW_NATIVE=$LINE; $RAW_NATIVE=~s/^.*: //;
     $RAW_NATIVE=~s/[^0-9]//g;
     return "";
   }
   if($LINE =~ /Trunking VLANs Enabled:/) {
     $RAW_VLANS = $LINE; $RAW_VLANS =~s/^.*: //;
     unless($RAW_TRUNK =~ "trunk") { return ""; }
     return "${DEVIP};${HNAME};IF_TRUNK;${RAW_IF};${RAW_NATIVE};;${RAW_VLANS}\n";
   }
 }
}; # --- End of $TSIF_BASE ---


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

