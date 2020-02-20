#!/usr/bin/perl

# DEVIP;HNAME;CLASS;... =TSIF=

use Socket;
use IPC::Open2;
use Data::Dumper;
use PWA;

@HLIST = qw/
D-PP-ONYX-RS-32
D-PP-ONYX-RS-33
D-PP-ONYX-RS-34
D-PP-ONYX-RS-35
D-PP-ONYX-RS-32
D-PP-ONYX-RS-33
/; 



foreach $HNAME (@HLIST) {

  print "${HNAME} connect\n";
  $pid=open2($fh_out,$fh_in,"sshpass -p "
            . pwaPassword("user")." ssh -tt -o PubKeyAuthentication=no -l "
            . pwaLogin("user")." ${HNAME}");
  unless($pid) {
    print STDERR "ERROR: ${HNAME} connection failed !\n";
    next;
  }

  sleep(2);
  print $fh_in "show running | no-more\n";
  print $fh_in "exit\n";
  close $fh_in;

  @OUTA=<$fh_out>;
  @OUTA = grep {!/user|pass|auth|md5|snmp-server/} @OUTA;
  #@OUTA = grep {s/^.*(user|pass|auth|md5|snmp-server).*$/<RESTRICTED>/} @OUTA;
  close $fh_out;

  waitpid($pid,0);

  print "${HNAME} writing\n";
  open $FH,">","${HNAME}-Config.txt" or next;
  print $FH @OUTA;
  close $FH;
}

print qx/ls -l/;
print qx/grep username *Config.txt/;
print qx/rm IMS-Config.zip/;
system("zip IMS-Config.zip *Config.txt");
print "# done.\n";


