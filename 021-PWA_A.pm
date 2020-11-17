#
# PWA.pm - PassWord Agent - A - Framework for Public Environment
# 20201117, Ing. Ondrej DURAS Capt. (Ret.) (dury) 0905-012-888
# 
# DESCIPTION:
# Authentication Library for the Network Scripts (ssh).
# "A" clone of PWA library is intended to show 
# the minimal crossplatform/crosslanguage framework.
#
# DECLARATION:
# ($METHOD,$LOGIN,$PASSWORD) = pwaCred($PROFILE);
# $METHOD = pwaMethod($PROFILE);
# $LOGIN = pwaLogin($PROFILE);
# $PASSWORD = pwaPassword($PROFILE);
#
# PARAMETERS:
# $PROFILE - represents common nickname of combination METHOD/LOGIN/PASSWORD
# $METHOD - It's equal to "REALM", here "ssh" is mostly used.
# $LOGIN - UserName used for authentication
# $PASSWORD - user's password for authentication
#
# FUNCTIONS:
# pwaCred - returns array with credentials
# pwaMethod - returns method only
# pwaLogin - returns username only
# pwaPassword - returns password only
#
# PROFILE:
# CRED_USER environment variable is an "user" profile CRED_CPES is "cpes"...
# CRED_USER should be formated like following example:
# export CRED_USER = "ssh:meno1:Hesielko_kuMeno11"
# Instead of original PWA, using PWA_<PROFILE> environment variables,
# this one "A" clone uses legacy CRED_<PROFILE> environment variables.
#
# METHODS:
# Methods are equal to REALMs used in HTTP/S authentication within the Web World.
# ...previously. But Today the main function of METHOD is to distiguish
# between interactively used credentials and cron-based credentials.
# So usual METHOD values are ssh,telnet,http,snmp for interactive or cron for non-interactive.
# Interactive credentials should not stolen from user logged into terminal,
# while cron-based credentials should not be stolen from the non-interactive script.
# These two security requirements have completely diferent back-end implementation,
# even front-end is still the same.
#
# SECURITY:
# This PERL module shows basic API only. 
# It's very simplified implementation
# without any security features.
# If you intend some level of security, then 
# clone, modify, compile and use PWA_B variant of PWA library.
#
# SEE LASO:
# https://github.com/ondrej-duras/
#
# $|=1; # perldoc perlvar that explains
# select( (select(OUT), $| = 1)[0] );
# tested also on Perl 5.8.4 / sun4u/sparc
# package PWA; # uncomment this and comment following 
package PWA_A; # if necessary

use strict;
use warnings;
use Exporter;

our $VERSION = 2020.111701;
our @ISA=qw( Exporter );
our @EXPORT = qw(
  pwaCred
  pwaMethod
  pwaLogin
  pwaPassword
);


sub pwaCred($) {
  my $PROFILE = "CRED_" . uc(shift);
  unless(exists($ENV{$PROFILE}) ) {
    warn "#! Warning: None credential profile '${PROFILE}' found!\n";
    return ("","","");
  }
  my ($METHOD,$LOGIN,$PASSWORD) = split(/:/,$ENV{$PROFILE},3);
  unless($METHOD   =~ /\S/) { $METHOD   = ""; }
  unless($LOGIN    =~ /\S/) { $LOGIN    = ""; }
  unless($PASSWORD =~ /\S/) { $PASSWORD = ""; }
  return ($METHOD,$LOGIN,$PASSWORD);
}

sub pwaMethod($) {
  return (pwaCred(shift))[0];
}

sub pwaLogin($) {
  return (pwaCred(shift))[1];
}

sub pwaPassword($) {
  return (pwaCred(shift))[2];
}

1;
# --- end ---

