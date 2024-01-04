#!/usr/bin/perl
#
# fping.pl - fping fake in PERL
# 20150629, Ing. Ondrej DURAS (dury)
# ~/prog/nett-tools/fping.pl
#

## MANUAL ############################################################# {{{ 1

our $VERSION = 2017.122901;
our $MANUAL=<<__END__;
NAME: Fast Ping 
FILE: fping.pl

DESCRIPTION:
   The script fping.pl a non-SUID simplified alternative to fping tool.
   It's designed to discover multiple hosts or IP addresses within
   the network.
    
SYNTAX:
   fping.pl [options] [targets...]
   cat targers.txt | fping.pl [options]

USAGE:
   fping -c 3 <<_END_
     1.2.3.4         # server 1
     server2         # server 2
     server3.att.com # server 3
   _END_
   fping -c 1 1.2.3.4 2.3.4.5
   fping --tcp --port http -c 1 server1 server2
   fping --udp -c 3 server1 server2
   fping --icmp -c 3 server1 server2 # root only
   fping --external -c 3 server1 server2
   fping --syn -f many-targets.txt
   fping --stream --port 22 server1
   fping --tcp --port 23 -g 145.26.66-67.1-254

NEW PARAMETERS:
   --tcp        TCP protocol used (default)
   --udp        UDP protocol used
   --icmp       ICMP protocol used, usable for root only
   --stream     TCP ptotocol used, but full connection opened first
   --syn        half-opened TCP connection method used
   --external   uses /bin/ping external tool to discover hosts
   --ping       uses /bin/ping external tool to discover hosts

   --port n     when TCP or UDP used, this allows to check particular port
   --hires      hight precision time
   --simple     messages contain "alive" or "UNREACHABLE" only
   --normal     messages contain technical details (default)
   --comment    output line contains the comment from input

FPING PARAMETERS:
   --alive      (-a) show targets that are alive only
   --bytes N    (-b) amount of ping data to send, in bytes (default 56)
   --count N    (-c) count of pings to send to each target (default 1)
   --stamp      (-D) print timestamp before each output line
   --file FILE  (-f) read list of targets from a file ( - means stdin)
   --gen  RANGE (-g) generates a range of IP addresses
   --interval N (-i) interval between sending ping packets (in millisec) (default 25)
   --loop       (-l) loop sending pings forever
   --pause N    (-p) pause before the next round of pings (in milisec, default 1000)
   --source IP  (-S) set source address
   --time N     (-t) individual target initial timeout (in millisec) (default 500)
   --unreachable(-u) show targets that are unreachable only
   targets      list of targets to check, hostnames or IP addresses

SEE ALSO:
  https://github.com/ondrej-duras/ (project /corporate)
  http://search.cpan.org/~rurban/Net-Ping/lib/Net/Ping.pm
  http://fping.org/  (by david\@schweikert.ch)

VERSION: ${VERSION}
__END__

####################################################################### }}} 1
## DEFAULTS ########################################################### {{{ 1

use strict;
use warnings;
use Socket;
use Net::Ping;

use constant 
{ 
   ALPHABET => 0, # used with MODE_ORDER
   NUMERIC  => 1, # used with MODE_ORDER
   ADDRESS  => 2  # used with MODE_ORDER
};

our $HHOST       = {};       # list of hosts to be investigated
our $CTHOST      = 0;        # host counter
our $FILE_IMPORT = "";       # list of hosts / host per line (--file or redirected STDIN)

our $DEF_PROTO   = "tcp";    # icmp,tcp,udp,syn,stream(tcp opened first),external(ping.exe)
our $DEF_TIMEOUT = 2;        # 2 seconds
our $DEF_BYTES   = 56;       # 56 bytes
our $DEF_SOURCE  = "";       # source IP , works with (ICMP or UDP) and root only
our $DEF_PORT    = 0;        # tcp/stream used if non-zero
our $DEF_COUNT   = 1;        # the number of attempts to ping a device
our $DEF_INTERVAL= 0.2;      # delay (0.2 second by default) after each packet sent
our $DEF_PAUSE   = 1.0;      # pause after each sequense of all hosts (1 second by default)
our $DEF_HIRES   = 0;        # Hi Resolution of time (basic time tick is about 55ms, HiRes is about 1ms)

our $MODE_ALIVE  = 1;        # displays alive hosts only
our $MODE_DEAD   = 1;        # displays unreachable hosts only
our $MODE_SUMMARY= 1;        # 
our $MODE_FORMAT = 1;        # 0=result (alive/unreachable) 1=duration till response received
our $MODE_RESOLVE= 1;        # 1=IP addresses & FQDN; 0= IP addresses only
our $MODE_RANGE  = "";       # range of IP addresses to be add into hostlist (-g 1.2.3.1-254)
our $MODE_LOOP   = 0;        # 0=DEF_COUNT used 1=never ending loop
our $MODE_ORDER  = ALPHABET; # 0=hosts in alphabet order 1=numeric (comming order) 2=ip address order
our $MODE_DEBUG  = "";       # allows troubleshooting messages to STDOUT
our $MODE_COLOR  = 2;        # 0=no colors, 1=color 2=to be decided
our $MODE_COMMENT= 0;        # 0- simple, 1=copies comments to output
our $MODE_STAMP  = 0;        # 1=timestamp

####################################################################### }}} 1
## FUNCTIONS ########################################################## {{{ 1

# Makes colors to the terminal
sub xcolor
{ my $MSG=shift;
  return $MSG unless $MODE_COLOR;
  $MSG=~s/^#:.*$/\033\[0;34m$&\033\[m/mg;
  $MSG=~s/^#-.*$/\033\[1;31m$&\033\[m/mg;
  $MSG=~s/^[A-Z ]+:.*$/\033[1;33m$&\033[m/mg;
  $MSG=~s/^ +-.*$/\033[0;36m$&\033[m/mg;
  $MSG=~s/^ +[^A-Za-z0-9(].*$/\033[1;36m$&\033[m/mg;
  return $MSG;
}

# Troubleshooting messages
sub xdebug
{ my $MSG=shift;
  return unless $MODE_DEBUG;
  return unless $MSG=~/${MODE_DEBUG}/;
  print xcolor "#:${MSG}\n";
}

# translates HNAME or DEVIP into vector
# (DEVIP,HNAME)
# to try ping at least the IP is needed
sub xresolve($)
{ my $HOST=shift;
  my ($DEVIP,$HNAME,$ADDR);
  if( not $MODE_RESOLVE)
   {
     $HNAME=$HOST;
     if($HOST=~/^[0-9]+(\.[0-9]+){3}$/)
      { $DEVIP=$HOST; }
     else
      { $DEVIP=""; }
   }
  elsif($HOST=~/^[0-9]+(\.[0-9]+){3}$/)
   {
     # translates IP address into FQDN
     $DEVIP=$HOST;
     $ADDR=inet_aton($DEVIP);
     $HNAME=gethostbyaddr($ADDR,AF_INET);
     unless(defined($HNAME)) { $HNAME=$DEVIP; }
   }
  else
   {
     # translated FQDN/HNAME into Device IP address
     $HNAME=$HOST;
     $ADDR=gethostbyname($HNAME);
     if(defined($ADDR)) { $DEVIP=inet_ntoa($ADDR); }
     else { $DEVIP=""; }
   }
  xdebug "xresolve ${HOST} => ${DEVIP};${HNAME}";
  return($DEVIP,$HNAME);
}

# adds a host from input file or commandline
# into list of hosts for investigations
sub xhost_add($)
{ my $HOST=shift;

  my($DEVIP,$HNAME)=xresolve($HOST);
  unless($DEVIP)
   {
     print xcolor "#- No IP address found for the host ${HOST} !\n";
     return 0;
   }
  $CTHOST++;

  $HHOST->{$HOST}={};
  my $PHOST=$HHOST->{$HOST};
  $PHOST->{devip}=$DEVIP; # DEVice IP address
  $PHOST->{hname}=$HNAME; # HostName/FQDN
  $PHOST->{sent}=0; # how many packets sent
  $PHOST->{came}=0; # how many packets received
  $PHOST->{resp}=0; # what is the response time

  # order by 'string'
  # sorted by order how they come 
  # the number translated into string
  if($MODE_ORDER == NUMERIC ) 
   { $PHOST->{order}=sprintf("%015u", $CTHOST); }

  # order by IP address => 1.2.3.4 into 001002003004
  elsif ($MODE_ORDER == ADDRESS )
   {
     if($HOST=~/^[0-9]+(\.[0-9]+){3}$/)
       { $PHOST->{order}=sprintf("%03u%03u%03u%03u",split(/\./,$HOST,4)); }
     else
       { $PHOST->{order}=$HOST; }
   }

  # order by host as-is
  else
   { $PHOST->{order}=$HOST; }
  xdebug "adding to HHOST: ${HOST} (${HNAME}) [${DEVIP}]";
  return $DEVIP;
}

# generates IP range and adds each IP address to the hostlist
sub xhost_range($)
{ my $IPRANGE=shift;
  my $FFLAG=0;
  unless( $IPRANGE=~/^[0-9-]+(\.[0-9-]+){3}$/ ) { return 0; }
  my ($AA,$BB,$CC,$DD)=split(/\./,$IPRANGE,4);
  xdebug "IPrange: ${AA} . ${BB} . ${CC} . ${DD}";
  my $AAMIN= my $AAMAX= $AA; if($AA=~/-/) { ($AAMIN,$AAMAX)=split(/-/,$AA,2); }
  my $BBMIN= my $BBMAX= $BB; if($BB=~/-/) { ($BBMIN,$BBMAX)=split(/-/,$BB,2); }
  my $CCMIN= my $CCMAX= $CC; if($CC=~/-/) { ($CCMIN,$CCMAX)=split(/-/,$CC,2); }
  my $DDMIN= my $DDMAX= $DD; if($DD=~/-/) { ($DDMIN,$DDMAX)=split(/-/,$DD,2); }

  $AAMIN=0 if $AAMIN<0; $AAMAX=255 if $AAMAX>255;
  $BBMIN=0 if $BBMIN<0; $BBMAX=255 if $BBMAX>255;
  $CCMIN=0 if $CCMIN<0; $CCMAX=255 if $CCMAX>255;
  $DDMIN=0 if $DDMIN<0; $DDMAX=255 if $DDMAX>255;
  xdebug "IPrange: $AAMIN-$AAMAX . $BBMIN-$BBMAX . $CCMIN-$CCMAX . $DDMIN-$DDMAX";

  for(my $AAIX=$AAMIN;$AAIX<=$AAMAX;$AAIX++)
   { for(my $BBIX=$BBMIN;$BBIX<=$BBMAX;$BBIX++)
      { for(my $CCIX=$CCMIN;$CCIX<=$CCMAX;$CCIX++)
         { for(my $DDIX=$DDMIN;$DDIX<=$DDMAX;$DDIX++)
            { my $IPADDR=sprintf("%d.%d.%d.%d",$AAIX,$BBIX,$CCIX,$DDIX);
              $FFLAG++ if xhost_add($IPADDR);
              xdebug "IPrange: adding ${IPADDR}\n";
            } # DDIX
         }    # CCIX
      }       # BBIX
   }          # AAIX
  return $FFLAG;
}

####################################################################### }}} 1
## PING_PRINT ######################################################### {{{ 1

sub ping_print($)
{  my $XHOST=shift;
   my $PHOST=$HHOST->{$XHOST};
   my $PACKETS=$PHOST->{packets};
   my $ADDRESS=$PHOST->{addr};
   my $SENT=$PHOST->{sent};
   my $RESP=$PHOST->{resp};
   my $DURATION;
   if($DEF_HIRES)
    { $DURATION=$RESP ." s"; }
   else
    { $DURATION=sprintf("%6.3f ms",1000*$RESP); }

   # are we going to put result on output ???
   if( $MODE_ALIVE==0 and $PACKETS>0  ) { return; }
   if( $MODE_DEAD==0  and $PACKETS==0 ) { return; }

   # what is the text of the message
   my $TEXT="";
   if($MODE_FORMAT)
   {
     $TEXT="${XHOST}(${ADDRESS}) : [${SENT}], ${PACKETS} packet(s), ${DURATION}";
   } else {
     $TEXT=" is alive";
     $TEXT=" is UNREACHABLE" unless $PACKETS;
     $TEXT="${XHOST}(${ADDRESS})".$TEXT;
   }

   # adding comment
   if($MODE_COMMENT and defined($PHOST->{comment}))
   { $TEXT .= " #" . $PHOST->{comment}; }

   # adding timestamp if required
   if($MODE_STAMP)
   { my $STAMP=time; $TEXT="[${STAMP}] ${TEXT}"; }
   # a bit of colors ... and write to output
   if($MODE_COLOR)
   {
     my $COLOR="\033[0;36m";
     $COLOR="\033[1;36m" if $RESP > 0.25;
     $COLOR="\033[0;35m" unless $PACKETS;
     $COLOR="\033[1;31m" if $PACKETS > 1;
     print "${COLOR}${TEXT}\033[m\n"; 
   }
   else
   { print "${TEXT}\n"; }

}
####################################################################### }}} 1
## PING simple (ping+ack at once) ##################################### {{{ 1

sub ping_simple($)
{ 
 my $XMODE=shift;  # tcp(*),udp,stream,icmp
 my $XPROTO="";
 if($XMODE eq "tcp")    { $XPROTO="tcp"; }
 if($XMODE eq "stream") { $XPROTO="tcp"; }
 if($XMODE eq "udp")    { $XPROTO="udp"; }

 # 'root' euid test for icmp mode
 if($XMODE eq "icmp" and $> ) 
  { 
    print xcolor "#- No root no icmp ! Use -external parameter to use /bin/ping tool .\n";
    return; 
  }  

 my $ping=Net::Ping->new($XMODE,$DEF_TIMEOUT,$DEF_BYTES);
 if($DEF_SOURCE) { $ping->bind($DEF_SOURCE); }
 if($XPROTO and $DEF_PORT)   
  { 
   if($DEF_PORT=~/[^0-9]/) 
    { $ping->port_number(scalar(getservbyname($DEF_PORT, $XPROTO))); }
   else
    { $ping->port_number($DEF_PORT); }
  }

 # High Time Resolution used.
 if($DEF_HIRES)
  { $ping->hires(); xdebug "HiRes used"; }
 
 # main 'ping' cycle. each round sends and trying to receive a packet.
 my $COUNT=$DEF_COUNT;
 while($MODE_LOOP or $COUNT--)
  {
   foreach my $XHOST ( sort { $HHOST->{$a}->{order} cmp $HHOST->{$b}->{order} } keys %$HHOST )
    {
     my $PHOST=$HHOST->{$XHOST};
     my ($RET_PACKETS,$RET_DURATION,$RET_ADDRESS)=$ping->ping($PHOST->{devip});
     $PHOST->{sent}++;
     $PHOST->{came}+=$RET_PACKETS;
     $PHOST->{packets}=$RET_PACKETS;
     $PHOST->{resp}=$RET_DURATION;
     $PHOST->{addr}=$RET_ADDRESS;
     ping_print($XHOST);
     sleep($DEF_INTERVAL);
    }
    sleep($DEF_PAUSE);
  }
 $ping->close;
}

####################################################################### }}} 1
## PING SYN (ping in one cycle, ack in another one) ################### {{{ 1

sub ping_syn
{ 
 my $ping=Net::Ping->new("syn",$DEF_TIMEOUT,$DEF_BYTES);
 if($DEF_SOURCE) { $ping->bind($DEF_SOURCE); }

 my %HDEVIP=();
 foreach my $XHOST ( keys %$HHOST )
  { $HDEVIP{$HHOST->{$XHOST}->{devip}}=$XHOST; }


 # High Time Resolution used.
 if($DEF_HIRES)
  { $ping->hires(); xdebug "HiRes used"; }
 
 # main 'ping' cycle. each round sends and trying to receive a packet.
 my $COUNT=$DEF_COUNT;
 while($MODE_LOOP or $COUNT--)
  {
   # removing the last round
   foreach my $XHOST ( keys %$HHOST )
    {
     my $PHOST=$HHOST->{$XHOST};
     $PHOST->{addr}="";
     $PHOST->{packets}=0;
     $PHOST->{resp}=0;
    }

   # sending packets
   foreach my $XHOST ( keys %$HHOST )
    {
     my $PHOST=$HHOST->{$XHOST};
     $ping->ping($PHOST->{devip});
    }

   # collecting answers
   while( my ($RET_HOST,$RET_DURATION,$RET_ADDRESS)=$ping->ack() )
    {
     $RET_HOST=$HDEVIP{$RET_HOST};
     my $PHOST=$HHOST->{$RET_HOST};
     $PHOST->{sent}++;
     $PHOST->{came}+=1;
     $PHOST->{packets}=1;
     $PHOST->{resp}=$RET_DURATION;
     $PHOST->{addr}=$RET_ADDRESS;
    }
   foreach my $XHOST ( sort { $HHOST->{$a}->{order} cmp $HHOST->{$b}->{order} } keys %$HHOST )
    {
     ping_print($XHOST);
    }
    sleep($DEF_PAUSE);
  }
 $ping->close;
}

####################################################################### }}} 1
## Command-Line ####################################################### {{{ 1

while(my $ARGX=shift @ARGV)
{
  unless($ARGX=~/^\-/)   { xhost_add($ARGX); next; }

  # protocol
  if($ARGX=~/^-?-tcp$/)         { $DEF_PROTO="tcp";         xdebug "option: --tcp";      next; } # (e ok)
  if($ARGX=~/^-?-udp$/)         { $DEF_PROTO="udp";         xdebug "option: --udp";      next; } # (e ok)
  if($ARGX=~/^-?-icmp$/)        { $DEF_PROTO="icmp";        xdebug "option: --icmp";     next; } # (e ok)
  if($ARGX=~/^-?-syn/)          { $DEF_PROTO="syn";         xdebug "option: --syn";      next; } # (e ok)
  if($ARGX=~/^-?-str/)          { $DEF_PROTO="stream";      xdebug "option: --stream";   next; } # (e ok)
  if($ARGX=~/^-?-ext/)          { $DEF_PROTO="external";    xdebug "option: --external"; next; } # (e ok)
  if($ARGX=~/^-?-pin/)          { $DEF_PROTO="external";    xdebug "option: --external"; next; } # (e ok)

  if($ARGX=~/^-?-t(ime.*)?$/)   { $DEF_TIMEOUT=shift @ARGV; xdebug "option: --timeout";  next; } # (-t ok)
  if($ARGX=~/^-?-b(yte)?/)      { $DEF_BYTES=shift   @ARGV; xdebug "option: --bytes";    next; } # (-b )
  if($ARGX=~/^-?-(S|src|sou)/)  { $DEF_SOURCE=shift  @ARGV; xdebug "option: --source";   next; } # (-S )
  if($ARGX=~/^-?-[Cc](ount)?$/) { $DEF_COUNT=shift   @ARGV; xdebug "option: --count";    next; } # (-c ok)
  if($ARGX=~/^-?-hires/)        { $DEF_HIRES=1;             xdebug "option: --hires";    next; } # (e ok)
  if($ARGX=~/^-?-no-?hires/)    { $DEF_HIRES=0;             xdebug "option: --no-hires"; next; } # (e ok) 
  if($ARGX=~/^-?-l(oop)?$/)     { $MODE_LOOP=1;             xdebug "option: --loop";     next; } # (-l ok)
  if($ARGX=~/^-?-simple$/)      { $MODE_FORMAT=0;           xdebug "option: --simple";   next; }
  if($ARGX=~/^-?-normal$/)      { $MODE_FORMAT=1;           xdebug "option: --normal";   next; }
  if($ARGX=~/^-?-(D|stamp)$/)   { $MODE_STAMP=1;            xdebug "option: --stamp";    next; } # (-D )
  if($ARGX=~/^-?-no-?stamp$/)   { $MODE_STAMP=0;            xdebug "option: --no-stamp"; next; } # (e ok)
  
  
  if($ARGX=~/^-?-port/)         { $DEF_PORT=shift     @ARGV; xdebug "option: --port";    next; } # (e ok)
  if($ARGX=~/^-?-i(nterval)?$/) { $DEF_INTERVAL=(shift @ARGV)/1000.0; xdebug "option: --interval";next; } # (-i ok)
  if($ARGX=~/^-?-p(ause)?$/)    { $DEF_PAUSE=(shift    @ARGV)/1000.0; xdebug "option: --pause";   next; } # (-p ok)
  if($ARGX=~/^-?-f(ile)?$/)     { $FILE_IMPORT=shift  @ARGV; xdebug "option: --file";    next; } # (-f ok)
  if($ARGX=~/^-?-g(en.*)?/)     { $MODE_RANGE=shift @ARGV; xhost_range($MODE_RANGE); xdebug "option: --gen ${MODE_RANGE}"; next; }

  if($ARGX=~/^-?-a(live)?$/)    { $MODE_ALIVE=1; $MODE_DEAD=0; xdebug "option: --alive"; next; } # (-a ok)
  if($ARGX=~/^-?-(u|dead)$/)    { $MODE_ALIVE=0; $MODE_DEAD=1; xdebug "option: --dead";  next; } # (-u ok)
  if($ARGX=~/^-?-(n|names?)$/)  { $MODE_RESOLVE=1;          xdebug "option: --names";    next; } # (-n ok)
  if($ARGX=~/^-?-(A|add.*)$/)   { $MODE_RESOLVE=0;          xdebug "option: --addresses";next; } # (-A ok)
  if($ARGX=~/^-?-comment$/)     { $MODE_COMMENT=1;          xdebug "option: --comment";  next; } # (e ok)
  if($ARGX=~/^-?-no-?comment$/) { $MODE_COMMENT=0;          xdebug "option: --no-comment";next; } # (e ok)
  if($ARGX=~/^-?-sum/)          { $MODE_SUMMARY=1;          xdebug "option: --summary";  next; } # (e ok)
  if($ARGX=~/^-?-no-?sum/)      { $MODE_SUMMARY=0;          xdebug "option: --no-summary";next; } # (e ok)
  
  if($ARGX=~/^-?-no-?color$/)   { $MODE_COLOR=0;            xdebug "option: --no-color"; next; } # (e ok)
  if($ARGX=~/^-?-color$/)       { $MODE_COLOR=1;            xdebug "option: --color";    next; } # (e ok)
  if($ARGX=~/^-?-no-?debug$/)   { $MODE_DEBUG="";           xdebug "option: --no-debug"; next; } # (e ok)
  if($ARGX=~/^-?-debug$/)       { $MODE_DEBUG=".*";         xdebug "option: --debug";    next; } # (e ok)

  die "#- Bad command-line option ${ARGX}\n";
}
if($MODE_COLOR==2) { 
  if( -t STDOUT) { 
    unless( $^O eq "MSWin32") { $MODE_COLOR=1; }  # all other platforms
    else { $MODE_COLOR = 1; }                     # Win32 platform (possible to change default behaviour 0 or 1)
  } else { 
    $MODE_COLOR=0;  # STDOUT redirected to file
  } 
}
if(($MODE_COLOR==1) and ( $^O eq "MSWin32")) {
  my $CODE="use Win32::Console::ANSI; return 1;";
  unless(eval($CODE)) { $MODE_COLOR = 0; }
}

unless($FILE_IMPORT) { unless( -t STDIN) { $FILE_IMPORT="-"; xdebug "STDIN is redirected"; } }

####################################################################### }}} 1
## Reading Hosts from file/STDIN ###################################### {{{ 1

if($FILE_IMPORT)
{
 my $fh;
 if($FILE_IMPORT eq "-") 
  { open $fh,"<&STDIN" or die "#- STDIN is not usable for import !\n"; }
 else
  { open $fh,"<",$FILE_IMPORT or die "#- File ${FILE_IMPORT} is not usable for import !\n"; }

 while(my $LINE=<$fh>)
  {
    next if $LINE=~/^\s*#/;
    next if $LINE=~/^\s*$/;
    my $COMMENT="";
    if($LINE=~/[#;]/) { ($LINE,$COMMENT)=split(/[#;]/,$LINE,2); }
    $LINE=~s/^\s+//; $LINE=~s/\s+$//;
    if(xhost_add($LINE) and $COMMENT) { chomp $COMMENT; $HHOST->{$LINE}->{comment}=$COMMENT; }
  }
 close $fh;
}


####################################################################### }}} 1
## ACTION ############################################################# {{{ 1

unless(scalar keys %$HHOST)  { print xcolor $MANUAL; exit; }
if($DEF_PROTO eq "tcp")      { ping_simple("tcp");   exit; }
if($DEF_PROTO eq "udp")      { ping_simple("udp");   exit; }
if($DEF_PROTO eq "external") { ping_simple("external"); exit; }
if($DEF_PROTO eq "icmp")     { ping_simple("icmp"); exit; }
if($DEF_PROTO eq "syn")      { ping_syn(); exit; }

####################################################################### }}} 1

# --- end ---

