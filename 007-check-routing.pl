#!/usr/bin/perl
# C2-CHECK-ROUTING.PL - Generator of check scripts for routing
# 20191021, Ing. Ondrej DURAS (dury)
# ~/prog/mvp-Minimal-Valuable-Product/c2-check-routing.pl

## MANUAL ############################################################# {{{ 1

our $VERSION=2019.110502;
our $MANUAL = <<__MANUAL__;
NAME: CHECK-ROUTING
FILE: c2-check-routing.pl

DESCRIPTION:
  It's boring to check whole path between many
  local and foreign targets, passing many redundant devices
  and many VRFs.
  This script generats a bash script, which performs such test
  more automatically.

  This generator asks for:
  - foreign targets (list of particular IP addresses)
  - places (device,type,vrf) where to check
  - local targets (list of particular IP addresses)
  - file name of bash script

  Generated script asks for:
  - credentials (SSHUSER and SSHPASS env variables)

  Requirements for generator:
  - functional simple perl whithout any extra packages

  Requirements for generates bash script:
  - unix like host (linux/solaris..)
  - ssh 
  - sshpass

USAGE:
  c2-check-routing.pl use example-inputs.txt
  read -p  'Login: ' SSHUSER
  read -sp 'Password: ' SSHPASS
  export SSHUSER,SSHPASS
  bash example-generated-TEST-SH.txt

EXAMPLE:
This is an example of file.
It's a customized text file with tags.
Everything except the tags #=routing is skipped.

#=routing script example-generated-TEST-SH.txt
#=routing label SIP SIGNALING
#=routing foreign 145.26.101.1
#=routing foreign 145.26.101.2
#=routing nexus D-005-QX-RS-70 IMS_SIG2IMS_SIGNALING green
#=routing junos D-101-QX-FW-80 CORE_IMS_SIG2IMS_SIGNALING. red
#=routing nexus D-005-QX-RS-70 CORE_IMS_SIG green
#=routing nexus D-101-QX-RS-32 IMS_SIG cyan
#=routing local 17.0.101.1
#=routing make
#=routing save

SEE ALSO:
  http://github.com/ondrej-duras/

VERSION: ${VERSION}
__MANUAL__

####################################################################### }}} 1
## DECLARATIONs and MAIN ############################################## {{{ 1

use Data::Dumper; 
our $MODE_COLOR = 0;
our $MODE_DEBUG = 0;
our $MODE_SCRIPT= [];
sub debug($);
sub color($);
sub colorman($);
sub cmdBase();
sub termInit();
sub interpreter($$$);

# Main part of program
termInit();  # initiate colors
unless(scalar(@ARGV)) {
  print colorman $MANUAL;
  exit;
}
our $DATA=cmdBase();   # takes a list of valid commands
interpreter($DATA,join(" ",@ARGV),"");
exit;


####################################################################### }}} 1
## COMMON FUNCTIONS of INTERPRETER #################################### {{{ 1

sub interpreter($$$) {
  my ($BASE,$COMMAND,$NOTHING)=@_;
  $COMMAND =~ s/^\s+//;
  $COMMAND =~ s/\s+$//;
  $COMMAND =~ s/\s+/ /g;
  if($COMMAND eq "" )   { return; }
  if($COMMAND =~ /^#/)  { return; }
  if($COMMAND =~ /^!/)  { $COMMAND=~s/^!//;  system($COMMAND); return; }
  if($COMMAND =~ /^\./) { $COMMAND=~s/^\.//; eval($COMMAND); return; }

  my $FFLAG=0;
  foreach my $IX (@$BASE) {
    my $PATTERN = $IX->[0];
    next unless $COMMAND =~ /^${PATTERN}$/;
    my $FUNCTION = $IX->[1];
    if( not exists(&$FUNCTION)) { 
      warn "Error: '${FUNCTION}' does not exist !\n"; 
      return; 
    }
    debug "\033[34mCOMMAND : $COMMAND";
    debug "\033[34m" . (Data::Dumper->Dump([$IX],["DETAILS"]));
    &$FUNCTION($BASE,$COMMAND,$IX);
    $FFLAG=1; last;
  }
  #warn "!Syntax error '${COMMAND}'" unless $FFLAG;
  unless($FFLAG) {
    print color "\033[1;31mSyntax error: '${COMMAND}' !\033[m\n";
  }
}

sub termInit() {
$MODE_COLOR=0;
if (($^O =~/lin/i) and (-t OUTPUT)) { $MODE_COLOR=1; return; }
if (($^O =~/win/i) and (eval "use Win32::Console::ANSI; return 1;")) { $MODE_COLOR=1; return; }
}

# foldMarker("## DETAILS ",50,"{{\{ 1\n");
# foldMarker("## DETAILS ",50,"}}\} 1\n");
sub foldMarker($$$) {
  my($TEXT,$WIDTH,$MARK)=@_;
  my $LEN =length $TEXT;
  my $DOTS=$WIDTH - $LEN;
  my $PAT=""; for (my $I=0;$I<$DOTS;$I++) { $PAT .="#"; }
  $TEXT = "${TEXT}${PAT} ${MARK}";
  return $TEXT;
}

sub debug($) {
  my $TEXT=shift;
  return unless $MODE_DEBUG;
  print color "\033[32m#: ${TEXT}\033[m\n";
}

sub color($) {
  my $TEXT=shift;
  if($MODE_COLOR) { return $TEXT; }
  $TEXT =~ s/\033\[[0-9;]*[mJH]//g;
  return $TEXT;
}

sub colorman($) {
  my $TEXT=shift;
  unless($MODE_COLOR) { return $TEXT; }
  $TEXT =~ s/^([ A-Z]+:)/\033[36m$1\033[32m/gm;
  $TEXT =~ s/^(#=[-a-z0-9]+ .*)$/\033[33m$1\033[32m/gm;
  $TEXT .= "\033[m";
}

sub interactive($$$) {
  my($BASE,$COMMAND,$LINE)=@_;
  my $PROMPT = $LINE->[2];
  my $MOTD   = $LINE->[3];
  print color "${MOTD}\033[m\n";
  while(1) {
    print color "${PROMPT}\033[m";
    $COMMAND=<STDIN>;
    interpreter($BASE,$COMMAND,"");
  }
}

sub scripting($$$) {
  my($BASE,$COMMAND,$DETAILS)=@_;
  my $FILENAME=(split(/\s+/,$COMMAND))[1]; # file name of interpreted script
  my $TAGPAT=$DETAILS->[2];                 # pattern of tag (within customized texts)
  $MODE_DEBUG=$DETAILS->[3];
  my $SCRIPT = [];
  my $FH;

  # reading a file
  unless(open $FH,"<",$FILENAME) { 
    die color "\033[31m#! Error: file '${FILENAME}' not reachable !\033[m\n"; 
  }
  debug "\033[36mOpening file '${FILENAME}'\033[m";
  while(my $LINE=<$FH>) {
    chomp $LINE;
    unless($LINE=~/${TAGPAT}/) { next; }
    $LINE =~ s/${TAGPAT}//;
    push @$SCRIPT,$LINE;
    debug "${LINE}\033[m";
  }
  debug "\033[36mClosing file '${FILENAME}'\033[m";
  close $FH;
  @$MODE_SCRIPT = @$SCRIPT;

  # executing sequence of commands
  foreach $CMD (@$SCRIPT) {
    interpreter($BASE,"${CMD}","");
  }
}

sub cmd($$$) {
  my($BASE,$COMMAND,$LINE)=@_;
  my $NOTE = $LINE->[3];
  my $CMD  = $LINE->[2];
  print "${CMD}\n${NOTE}\n";
  system("${CMD}")
}

sub perl($$$) {
  my($BASE,$COMMAND,$LINE)=@_;
  eval($LINE->[2]);
  if(exists($LINE->[3])) {
    my $MSG=$LINE->[3];
    print color "\033[1;32m${MSG}\033[m\n";
  }
}

sub quit($$$) {
  my($BASE,$COMMAND,$LINE)=@_;
  my $BYE=$LINE->[2];
  print $BYE;
  exit;
}

sub help($$$) {
  my($BASE,$COMMAND,$LINE)=@_;
  my $PATERN = $COMMAND;
  $PATERN =~ s/^(\?\?|-+h|-*help) //;
  foreach my $LN (@$BASE) {
    my $CMD=$LN->[0];
    if($CMD =~ /${PATERN}/) {
      print "${CMD}\n";
    }
  } 
}

sub dump($$$) {
  my($BASE,$COMMAND,$LINE)=@_;
  my $PATERN = $COMMAND;
  $PATERN =~ s/^(\?\?\?|-+d|-*dump) //;
  foreach my $LN (@$BASE) {
    my $CMD=$LN->[0];
    if($CMD =~ /${PATERN}/) {
      my $OUT = join(" :: ",@$LN);
      print "${OUT}\n";
    }
  } 
}

####################################################################### }}} 1
## APPLICATION SPECIFIC COMMANDS ###################################### {{{ 1

our $FNAME_OUTPUT="";  # file name for output
our $TOUTPUT  = "";    # content of output file
our $TEXT_LABEL="";    # yellow label used to mark beging and end
our $AFOREIGN = [];    # list of foreign targets (IP addresses)
our $ADEVICE  = [];    # list of lines (each contains type hostname vrfname color)
our $ALOCAL   = [];    # list of local targets (ip addresses)

sub cmd_script($$$) {
  my($BASE,$COMMAND,$DETAIL)=@_;
  $COMMAND =~ s/^\S+\s+//;
  $FNAME_OUTPUT=$COMMAND;
  debug "output filename '${FNAME_OUTPUT}'";
  $TOUTPUT  = "";
  debug "clearing content of output.";
  $AFOREIGN = [];
  $ADEVICE  = [];
  $ALOCAL   = [];
  debug "clearing AFOREIGN,ADEVICE,ALOCAL tables";
}

sub cmd_label($$$) {
  my($BASE,$COMMAND,$DETAIL)=@_;
  $COMMAND =~ s/^\S+\s+//;
  $TEXT_LABEL=$COMMAND;
  debug "changing label to '${TEXT_LABEL}'";
}

sub cmd_foreign($$$) {
  my($BASE,$COMMAND,$DETAIL)=@_;
  $COMMAND =~ s/^\S+\s+//;
  push @$AFOREIGN,$COMMAND;
  debug "adding foreign target '${COMMAND}'";
}

sub cmd_device($$$) {
  my($BASE,$COMMAND,$DETAIL)=@_;
  push @$ADEVICE,$COMMAND;
  debug "adding device '${COMMAND}'";
}

sub cmd_local($$$) {
  my($BASE,$COMMAND,$DETAIL)=@_;
  $COMMAND =~ s/^\S+\s+//;
  push @$ALOCAL,$COMMAND;
  debug "adding local target '${COMMAND}'";
}

sub cmd_make($$$) {
  my($BASE,$COMMAND,$DETAIL)=@_;
  debug "\033[36mCompilation details:\033[33m\n" . (Data::Dumper->Dump(
    [$FNAME_OUTPUT,$TEXT_LABEL,$AFOREIGN,$ADEVICE,$ALOCAL],
    ["FNAME_OUTPUT","TEXT_LABEL","AFOREIGN","ADEVICE","ALOCAL"]
  ));
  $TOUTPUT  = "#!/bin/bash\n";

  $TOUTPUT .= foldMarker("## CONFIG ",77,"{{\{ 1\n\n");
  $TOUTPUT .= out_config();
  $TOUTPUT .= "\n" . foldMarker("",77,"}}\} 1\n");

  $TOUTPUT .= foldMarker("## LIBRARY ",77,"{{\{ 1\n\n");
  $TOUTPUT .= out_library();
  $TOUTPUT .= "\n" . foldMarker("",77,"}}\} 1\n");

  $TOUTPUT .= foldMarker("## MAIN ",77,"{{\{ 1\n\n");
  $TOUTPUT .= out_main();
  $TOUTPUT .= "\n" . foldMarker("",77,"}}\} 1\n");

  $TOUTPUT .= "# --- end ---\n";

  debug "\033[36mGenerated File\033[35m\n" . $TOUTPUT;
}

sub cmd_save($$$) {
  my($BASE,$COMMAND,$DETAIL)=@_;
  debug "\033[36mSaving to file '${FNAME_OUTPUT}'";
  my $FH;
  unless(open($FH,">",$FNAME_OUTPUT)) { 
    die color "\033[1;31m#!Error: cannot create '${FNAME_OUTPUT}' !\033[m\n"; 
  }
  binmode $FH;
  print $FH $TOUTPUT;
  close $FH;
  debug "\033[36mdone. '${FNAME_OUTPUT}'";
}

####################################################################### }}} 1
## APPLICATION SPECIFIC OUTPUT ######################################## {{{ 1

sub out_config() {
  # Head and config
  my $TOUTPUT;
 
  $TOUTPUT .= "#=routing script ${FNAME_OUTPUT}\n";
  $TOUTPUT .= "#=routing label ${TEXT_LABEL}\n";
  foreach my $LINE (@$AFOREIGN) {
    $TOUTPUT .= "#=routing foreign ${LINE}\n";
  }
  foreach my $LINE (@$ADEVICE) {
    $TOUTPUT .= "#=routing ${LINE}\n";
  }
  foreach my $LINE (@$ALOCAL) {
    $TOUTPUT .= "#=routing local ${LINE}\n";
  }
  $TOUTPUT .= "#=routing make\n";
  $TOUTPUT .= "#=routing save\n";

  return $TOUTPUT;
}

sub out_library() {
return <<'__LIBRARY__';

if [ -z "${SSHUSER}" ]; then
  echo "Error: apply command: read -p  'Login: ' SSHUSER; export SSHUSER"
  exit
fi
if [ -z "${SSHPASS}" ]; then
  echo "Error: apply command: read -sp 'Password: ' SSHPASS; export SSHPASS"
  exit
fi

# | include "best|via" | exclude "^'" | no-more   # for nexus
# | match "\*|via" | except "="                   # for junos
RT="| include \"best|via\" | exclude \"^'\" | no-more"
JR="| match \"\\*|via\" | except \"=\""

function shx() {
  HOST=$1
  #sshpass -e ssh -tt -o PubkeyAuthentication=no -l ${SSHUSER} ${HOST} 2>/dev/null
  sshpass -e ssh -o PubkeyAuthentication=no -l ${SSHUSER} ${HOST} 2>/dev/null
}

function say() {
  COLOR=$1
  TEXT=$2
  if [ ! -t 1 ]; then  # if STDOUT redirected
    echo "##> ${TEXT}"
  elif [ "${COLOR}" == "g" -o "${COLOR}" == "green" ];  then
    echo -e "\033[1;32m##> ${TEXT}\033[m"
  elif [ "${COLOR}" == "r" -o "${COLOR}" == "red" ];    then
    echo -e "\033[1;31m##> ${TEXT}\033[m"
  elif [ "${COLOR}" == "c" -o "${COLOR}" == "cyan" ];   then
    echo -e "\033[1;36m##> ${TEXT}\033[m"
  elif [ "${COLOR}" == "b" -o "${COLOR}" == "blue" ];   then
    echo -e "\033[1;34m##> ${TEXT}\033[m"
  elif [ "${COLOR}" == "y" -o "${COLOR}" == "yellow" ]; then
    echo -e "\033[1;33m##> ${TEXT}\033[m"
  else 
    echo "##> ${TEXT}"
  fi
}

__LIBRARY__
}

sub out_main() {
  my $TOUTPUT = "";
  my $CTFOREIGN= scalar @$AFOREIGN;
  my $CTLOCAL  = scalar @$ALOCAL;

  $TOUTPUT .= "say yellow \"${TEXT_LABEL} ... starting\"\n";
  foreach my $DEVICE (@$ADEVICE) {
    my($PLATFORM,$HNAME,$VRF,$COLOR) = split(/\s+/,$DEVICE,4);
    if($PLATFORM eq "nexus") {
      $TOUTPUT .= "say ${COLOR} \"${PLATFORM} ${HNAME} vrf ${VRF}\"\n";
      $TOUTPUT .= "say ${COLOR} \"foreign ${CTFOREIGN}x\"\n";
      $TOUTPUT .= "cat <<__CMD__ | shx ${HNAME}\n";
      foreach my $FOREIGN (@$AFOREIGN) {
        $TOUTPUT .= "  show ip route vrf ${VRF} ${FOREIGN} \$RT\n"; 
      }
      $TOUTPUT .= "exit\n";
      $TOUTPUT .= "__CMD__\n";
  
  
      $TOUTPUT .= "say ${COLOR} \"local ${CTLOCAL}x\"\n";
      $TOUTPUT .= "cat <<__CMD__ | shx ${HNAME}\n";
      foreach my $LOCAL (@$ALOCAL) {
        $TOUTPUT .= "  show ip route vrf ${VRF} ${LOCAL} \$RT\n"; 
      }
      $TOUTPUT .= "exit\n";
      $TOUTPUT .= "__CMD__\n\n";
      next;
    }

    if($PLATFORM eq "junos") {
      $TOUTPUT .= "say ${COLOR} \"${PLATFORM} ${HNAME} vrf ${VRF}\"\n";
      $TOUTPUT .= "say ${COLOR} \"foreign ${CTFOREIGN}x\"\n";
      $TOUTPUT .= "cat <<__CMD__ | shx ${HNAME}\n";
      foreach my $FOREIGN (@$AFOREIGN) {
        $TOUTPUT .= "  show route table ${VRF} ${FOREIGN} \$JR\n"; 
      }
      $TOUTPUT .= "exit\n";
      $TOUTPUT .= "__CMD__\n";
  
  
      $TOUTPUT .= "say ${COLOR} \"local ${CTLOCAL}x\"\n";
      $TOUTPUT .= "cat <<__CMD__ | shx ${HNAME}\n";
      foreach my $LOCAL (@$ALOCAL) {
        $TOUTPUT .= "  show route table ${VRF} ${LOCAL} \$JR\n"; 
      }
      $TOUTPUT .= "exit\n";
      $TOUTPUT .= "__CMD__\n\n";
      next;
    }
  }
  $TOUTPUT .= "say yellow \"${TEXT_LABEL} ... done.\"\n";
  return $TOUTPUT;
}

####################################################################### }}} 1
## COMMAND BASE ####################################################### {{{ 1

sub cmdBase() {
return [
  ['script\s+\S+',"cmd_script"],
  ['label\s+.*','cmd_label'],
  ['foreign\s+\S+','cmd_foreign'],
  ['nexus\s+\S+\s+\S+\s+\S+','cmd_device'],
  ['junos\s+\S+\s+\S+\s+\S+','cmd_device'],
  ['local\s+\S+','cmd_local'],
  ['make','cmd_make'],
  ['save','cmd_save'],
  ['use \S+','scripting','#=routing\s+','0'],
  ['use \S+ debug','scripting','#=routing\s+','1'],
  ["err.*","err","Nejaka schvalna chybka"],
  ["color off|no color","perl",'$MODE_COLOR=0'],
  ["color on","perl",'$MODE_COLOR=1'],
  ["debug on","perl",'$MODE_DEBUG=1'],
  ["debug off|no debug","perl",'$MODE_DEBUG=0'],
  ["exit|quit|logout","quit","done."],
  ["-i|shell","interactive","\033[32mcr\033[36m>> ","\033[1;37mCheck Routing 2020\nquit to exit"],
  ['(\?\?\?|-+d|-*dump) .*',"dump"],
  ['(\?\?|-+h|-*help) .*',"help"]
];
}

####################################################################### }}} 1
# --- end ---

