#!/usr/bin/perl

use FindBin qw($Bin);
use lib "$Bin/../lib";
use WebServer;

my $pid = WebServer->new(8080)->background();
print "Use 'kill $pid' to stop server.\n";
