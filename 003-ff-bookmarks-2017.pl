#!/usr/bin/perl
# FF - URL / Links from the command-line
# 20170314, Ing. Ondrej DURAS (dury)
# ~/prog/pl-win32/ff.pl


## MANUAL ############################################################# {{{ 1

our $VERSION = 2019.090301;
our $MANUAL  = <<__MANUAL__;
NAME: FF
FILE: ff.pl

USAGE:
  ff -fe c:\
  ff -ie -u https://intranet.sk
  ff -list instranet
  ff -edit
  ff int

PARAMETERS:
  -ff   - use a FireFox
  -ie   - use an Internet Explorer
  -fe   - use Windows native File Explorer
  -url  - particular URL
  -edit - edit the source code/data
  -list - search for links/keywords
  Anything else is recognized as the keyword.

VERSION: ${VERSION}
__MANUAL__

####################################################################### }}} 1
## DEFAULTS ########################################################### {{{ 1

use strict;
use warnings;
use POSIX;

# Platform detection
unless($^O =~ /MSWin32/) { 
  die "#- It's not implemented for the paltform ${^O} yet !\n"; 
}

# Defaults
#our $PATH_FF='c:\opt\ffox\firefox.exe';
our $PATH_FF='"C:\Program Files\Mozilla Firefox\firefox.exe"';
#our $PATH_IE='"C:\Program Files\Internet Explorer\iexplore.exe"';
our $PATH_IE='"C:\Program Files (x86)\Internet Explorer\iexplore.exe"';
our $PATH_FE='c:\windows\explorer.exe';
our $PATH_ME=$PATH_FF;
our $XBYB = "";
our $XKEY = "";
our $XURL = "";
our $XANY = "";
our $LIST = "";

# Identifing the default mode/browser on the script name basis
if (${0} =~ /ff\.cmd$/) { $XBYB = 'ff'; $PATH_ME = $PATH_FF; }
if (${0} =~ /ie\.cmd$/) { $XBYB = 'ie'; $PATH_ME = $PATH_IE; }
if (${0} =~ /fe\.cmd$/) { $XBYB = 'fe'; $PATH_ME = $PATH_FE; }

# Show the Manual if none argument has been provided.
unless(scalar @ARGV) {
  print $MANUAL;
  exit;
}

# Command-line attributes.
while(my $ARGX = shift @ARGV) {
  if ($ARGX =~ /^-+ff/)  { $XBYB = 'ff'; $PATH_ME = $PATH_FF; next; }  # -ff
  if ($ARGX =~ /^-+ie/)  { $XBYB = 'ie'; $PATH_ME = $PATH_IE; next; }  # -ie
  if ($ARGX =~ /^-+fe/)  { $XBYB = 'fe'; $PATH_ME = $PATH_FE; next; }  # -fe
  if ($ARGX =~ /^-+k/)   { $XKEY = shift @ARGV; next; }                # -key <key>
  if ($ARGX =~ /^-+u/)   { $XURL = shift @ARGV; next; }                # -url <url>
  if ($ARGX =~ /^-+l/)   { $LIST = shift @ARGV; next; }                # -list <something>
  if ($ARGX =~ /^-+a/)   { $LIST = '.*'; next; }                       # -all
  if ($ARGX =~ /^-+ed/)  { $XBYB = 'ed'; next; }                       # -edit
  $XANY = $ARGX;
}

####################################################################### }}} 1
## MAIN ############################################################### {{{ 1

if($LIST) {
  while(my $LINE=<DATA>) {
    chomp($LINE);
    next if $LINE=~/^\s*$/;
    next if $LINE=~/^\s*#/;
    next unless $LINE=~/${LIST}/;
    print "${LINE}\n";
  }
  exit;
}

if($XBYB eq 'ed') {
  my $TSTAMP=strftime("%Y%m%d",gmtime(time));
  my $IDX=1;
  my $FNAME="";
  while(1) {
    $FNAME = "c:/usr/good-oldies/ff/ff-${TSTAMP}".sprintf("%02d",$IDX).".pl";
    unless( -f $FNAME) { last; }
    $IDX++;
  }
  print "#: ${IDX} ${FNAME}\n";
  system("cp -vi ${0} ${FNAME}");
  system("vi ${0} -c\"\$\"");
  print "done.\n";
  exit;
}

while(my $LINE = <DATA>) {
  chomp($LINE);
  next if $LINE=~/^\s*$/;
  next if $LINE=~/^\s*#/;
  my ($BYB,$KEY,$URL)=split(/\s+/,$LINE);
  if($XKEY) { next if $XKEY ne $KEY; }
  if($XURL) { next if $XURL ne $URL; }
  if($XANY) { next if $LINE !~ /${XANY}/; }
  unless($XBYB) {
    $XBYB = $BYB;
    if($BYB eq 'ff') { $PATH_ME = "start ".$PATH_FF; }
    if($BYB eq 'ie') { $PATH_ME = $PATH_IE; }
    if($BYB eq 'fe') { $PATH_ME = $PATH_FE; }
  }
  print "Browser ........ ${BYB}\n";
  print "URL ............ ${URL}\n";
  print "KeyWord ........ ${KEY}\n";
  print "Command ........ ${PATH_ME}\n";

  # following command is not functional since one windows update
  #system("start \"${PATH_ME}\" \"${URL}\"");
  #my $CMD="start ${PATH_ME} \"${URL}\"";
  my $CMD="${PATH_ME} \"${URL}\"";
  print "${CMD}\n";
  system($CMD);
  last;
}

#=vim high Comment ctermfg=brown
####################################################################### }}} 1

__DATA__
ff gm    https://gmail.com
# GMail
ff yt    https://youtube.com
# YouTube
ff gh    https://github.com/ondrej-duras/
# GitHub / pub

ie ms https://www.microsoft.com
ie cisco https://www.cisco.com

fe doc c:\usr\Documents
fe prog c:\usr\prog

ff cisco-license-register http://www.cisco.com/go/license
ff juniper-license-register https://license.juniper.net/licensemanage/ 
ff svg-samples https://dev.w3.org/SVG/tools/svgweb/samples/svg-files/
ff freegeoip http://api.ipstack.com/api/8.8.8.8?access_key=7fee2605f06fa04f7d850f3ae45d26e6
ff stencils http://www.visiocafe.com/vsdfx.htm
# --- end ---
