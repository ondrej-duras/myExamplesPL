#!/usr/bin/perl
#

## MANUAL ############################################################# {{{ 1

#our $VERSION = 2017.061301;
our $VERSION = 2021.100701;
our $MANUAL  = <<__MANUAL__;
NAME: Cisco Password EN/DEcryption utility
FILE: cpass.pl

DESCRIPTION:
  Helps encrypt and/or decrypt Cisco IOS 7 type passwords
  shown/stored in most of cisco devices

USAGE:
  cpass --encrypt hello123 --salt 10
  cpass --decrypt 9878778978979
  cpass --manuf   FCW2152G0EA

PARAMETERS:
  --encrypt encrypt following plain text
  --decrypt decrypt encrypted cisco password
  --salt    hexadecimal constant, helps to crypt
  --manuf   takes date of manufacture from cisco serial number

VERSION: ${VERSION}
__MANUAL__

####################################################################### }}} 1
## EN/DEcoding ######################################################## {{{ 1

use strict;
use warnings;

# our @CISCO_XLAT = (
#   0x64, 0x73, 0x66, 0x64, 0x3b, 0x6b, 0x66, 0x6f, 0x41,
#   0x2c, 0x2e, 0x69, 0x79, 0x65, 0x77, 0x72, 0x6b, 0x6c,
#   0x64, 0x4a, 0x4b, 0x44, 0x48, 0x53, 0x55, 0x42 );
# our $CISCO_LEN = 26;


our @CISCO_XLAT=(
  0x64, 0x73, 0x66, 0x64, 0x3b, 0x6b, 0x66, 0x6f, 0x41, 0x2c, 0x2e,
  0x69, 0x79, 0x65, 0x77, 0x72, 0x6b, 0x6c, 0x64, 0x4a, 0x4b, 0x44,
  0x48, 0x53, 0x55, 0x42, 0x73, 0x67, 0x76, 0x63, 0x61, 0x36, 0x39,
  0x38, 0x33, 0x34, 0x6e, 0x63, 0x78, 0x76, 0x39, 0x38, 0x37, 0x33,
  0x32, 0x35, 0x34, 0x6b, 0x3b, 0x66, 0x67, 0x38, 0x37);
our $CISCO_LEN = scalar @CISCO_XLAT;


sub cisco_encrypt($;$) {
  my ($TEXT,$SALT)=@_;
  chomp $TEXT;
  my $LEN=length $TEXT;
  unless($SALT) { $SALT = rand($CISCO_LEN); }
  my $CODE=sprintf("%02X",$SALT);
  for(my $I=0; $I < $LEN; $I++) {
    $CODE .= sprintf("%02X",
      ord(substr($TEXT,$I,1)) ^ $CISCO_XLAT[($SALT % $CISCO_LEN)]
    );
    $SALT = ($SALT + 1) % $CISCO_LEN;
  }
  return $CODE;
}

sub cisco_decrypt($) {
  my $CODE = shift;
  my $SALT = hex(substr($CODE,0,2));
  my $LEN  = length $CODE;
  my $TEXT = "";
  for(my $I=2; $I<$LEN; $I+=2) {
    $TEXT .= chr( hex(substr($CODE,$I,2)) ^ $CISCO_XLAT[($SALT % $CISCO_LEN)]);
    $SALT = ($SALT + 1) % $CISCO_LEN;
  }
  return $TEXT;
}

####################################################################### }}} 1
## CISCO SERIAL NUMBERS -manuf ######################################## {{{ 1

# Cisco Serial Number Format:
# ============================
# AAAYYWWXXXX - serial number sample
#
# AAA  - Cisco Suply Manufacturer
# YY   - 1996 + YY = Year of manufacture
# WW   - Week of manufacture
# XXXX - Unique Identifier
#
# Week codes (WW):
# A(5w)   1-5 : January   D(4w) 15-18 : April  G(4w) 28-31 : July      J(4w) 41-44 : October
# B(4w)   6-9 : February  E(4w) 19-22 : May    H(4w) 32-35 : August    K(4w) 45-48 : November
# C(5w) 10-14 : March     F(5w) 23-27 : June   I(5w) 36-40 : September L(4w) 49-52 : December
# https://community.cisco.com/t5/switching/cisco-serial-number-lookups/td-p/1375234

# MOTH CODES          A       B        C     D     E   F    G    H      I         J       K        L
our @MONTHS_T = qw/none January February March April May June July August September October November December/;
# our $WEEK2MONTH = "0123456789 123456789 123456789 123456789 12";
  our $WEEK2MONTH = "-AAAAABBBBCCCCCDDDDEEEEFFFFFGGGGHHHHIIIIIJJJJKKKKLLLL";
        
sub cisco_manuf($) {
  my $SERIAL = shift;
  unless ($SERIAL =~ /\S{3}[0-9]{4}\S{4}/) { return "unknown"; }
  my ($MAN,$YEAR,$WEEK,$UID) = $SERIAL =~ m/(\S{3})([0-9][0-9])([0-9][0-9])(.*)/;
  $YEAR = int($YEAR) + 1996;
  my $MONTH = $MONTHS_T[ord(substr($WEEK2MONTH,int($WEEK),1))-64];
  return "${YEAR}-${MONTH}";
}

####################################################################### }}} 1
## MAIN ############################################################### {{{ 1

our $MODE_ENCRYPT = "";
our $MODE_DECRYPT = "";
our $MODE_SALT    = undef;
our $MODE_MANUF   = "";

unless(scalar @ARGV) {
  print $MANUAL;
  exit;
}

while(my $ARGX = shift @ARGV) {
 if($ARGX =~ /^-+e/) { $MODE_ENCRYPT = shift @ARGV; next; }
 if($ARGX =~ /^-+d/) { $MODE_DECRYPT = shift @ARGV; next; }
 if($ARGX =~ /^-+s/) { $MODE_SALT    = shift @ARGV; next; }
 if($ARGX =~ /^-+m/) { $MODE_MANUF   = shift @ARGV; next; }
 warn "#-cpass: warning: Unknown argument !\n";
}

if($MODE_ENCRYPT) { print cisco_encrypt($MODE_ENCRYPT,$MODE_SALT); }
if($MODE_DECRYPT) { print cisco_decrypt($MODE_DECRYPT);            }
if($MODE_MANUF)   { print cisco_manuf($MODE_MANUF); }
if( -t STDOUT )  { print "\n"; }

####################################################################### }}} 1
# --- end ---

