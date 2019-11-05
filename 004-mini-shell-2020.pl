#!/usr/bin/perl
# 004-MINI-SHELL-2020 - Universal interpreter / Launcher of the Most used utilities
# 20191021, Ing. Ondrej DURAS (dury)
# ~/prog/mvp-Minimal-Valuable-Product/004-mini-shell-2020.pl


our $VERSION=2019.110501;


use Data::Dumper; 
our $MODE_COLOR = 0;
our $MODE_DEBUG = 0;
sub debug($);
sub color($);
sub cmdBase();
sub termInit();
sub interpreter($$$);

# Main part of program
termInit();  # initiate colors
our $DATA=cmdBase();   # takes a list of valid commands
interpreter($DATA,join(" ",@ARGV),"");
exit;


# Functions

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
    &$FUNCTION($BASE,$COMMAND,$IX);
    debug "PATTERN : ${PATTERN}";
    debug $COMMAND ." >> " . Dumper($IX);
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

sub debug($) {
  my $TEXT=shift;
  return unless $MODE_DEBUG;
  print color "\033[1;32m${TEXT}\033[m\n";
}

sub color($) {
  my $TEXT=shift;
  if($MODE_COLOR) { return $TEXT; }
  $TEXT =~ s/\033\[[0-9;]*[mJH]//g;
  return $TEXT;
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

sub ffox($$$) {
  my($BASE,$COMMAND,$LINE)=@_;
  #my $FFOX='start "C:\opt\ffox\firefox.exe"';
  my $FFOX='start "C:\Program Files\Mozilla Firefox\firefox.exe"';
  my $NOTE = $LINE->[3];
  my $URL  = $LINE->[2];
  print "firefox ${URL}\n${NOTE}\n";
  system("${FFOX} \"${URL}\"")
}

sub msie($$$) {
  my($BASE,$COMMAND,$LINE)=@_;
  #my $MSIE='"C:\Program Files\Internet Explorer\iexplore.exe"';
  my $MSIE='"C:\Program Files (x86)\Internet Explorer\iexplore.exe"';
  my $NOTE = $LINE->[3];
  my $URL  = $LINE->[2];
  print "MS Internet Explorer ${URL}\n${NOTE}\n";
  system("${MSIE} \"${URL}\"")
}

sub fold($$$) {
  my($BASE,$COMMAND,$LINE)=@_;
  my $FOLD='start "c:\windows\explorer.exe"';
  my $NOTE = $LINE->[3];
  my $URL  = $LINE->[2];
  print "MS File Explorer ${URL}\n${NOTE}\n";
  system("${FOLD} \"${URL}\"")
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

sub cmdBase() {
return [
["ffox any","ffox","file:///c:/usr/html/index.html","firefox home page"],
["ffox wlc","ffox","file:///c:/usr/html/wlc.html","Wireless Lan Controllers"],
["ffox home","ffox","file:///c:/usr/html/index.html","home page by FireFox"],
["msie home","msie","file:///c:/usr/html/index.html","home page by IE"],
["fold home","fold",'c:\usr\html',"home page by MS File Explorer"],
["osk ie","msie","http://www.orange.sk","Orange Slovensko"],
["osk ff","ffox","http://www.orange.sk","Orange Slovensko"],
["say hello","cmd","echo hello","Len tak zo srandy"],
["err.*","err","Nejaka schvalna chybka"],
["color off|no color","perl",'$MODE_COLOR=0'],
["color on","perl",'$MODE_COLOR=1'],
["debug on","perl",'$MODE_DEBUG=1'],
["debug off|no debug","perl",'$MODE_DEBUG=0'],
["exit|quit|logout","quit","done."],
["-i|shell","interactive","\033[1;33m>>> ","\033[1;37mMini Shell 2020\nquit to exit"],
['(\?\?\?|-+d|-*dump) .*',"dump"],
['(\?\?|-+h|-*help) .*',"help"]
];
}
# --- end ---

