#!/usr/bin/perl

sub isRedir() {
  if( -t STDIN) {
    print "STDIN  (0) directed to Terminal.\n";
  } else {
    print "STDIN  (0) directed to Pipe.\n";
  }
  if( -t STDOUT) {
    print "STDOUT (1) directed to Terminal.\n";
  } else {
    print "STDOUT (1) directed to Pipe.\n";
  }
  if( -t STDERR) {
    print "STDERR (2) directed to Terminal.\n";
  } else {
    print "STDERR (2) directed to Pipe.\n";
  }
}

our $MODE_COLOR=2;
if($^O = "MSWin32") {
 if(eval("use Win32::Console::ANSI; return 1;")) { 
    $MODE_COLOR=1; 
    $VER = $Win32::Console::ANSI::VERSION;
    print "\033[1J\033[2J\033[0;0H\033[1;33m"
        . "Perl package Win32::Console::ANSI version ${VER} ($^O)"
        . "\033[0;37m\n";
    isRedir();
    exit;
 }
 else { 
    $MODE_COLOR=0; 
    system("CLS");
    print "None Perl package Win32::Console::ANSI found !\n";
    isRedir();
    exit;
 }
} else {
    $MODE_COLOR=1;
    print "\033[1J\033[2J\033[0;0H\033[1;33m"
        . "Unix compatible platform detexted. ($^O)"
        . "\033[0;37m\n";
    isRedir();
}



