#!/usr/bin/perl

our $USERS=['jano','fero','peter'];

@$USERS = map { $_ . "_adm" } @$USERS;

print join("\n",@$USERS);
print "\n---\n";
print join "\n", grep { $_ =~ /o_adm$/ } @$USERS;
print "\n---\n";
print join "\n", grep /o_adm$/, @$USERS;

