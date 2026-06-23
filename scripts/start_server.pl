#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));

use FindBin qw($Bin);
use lib "$Bin/../lib";
use WebServer;

my $pid = WebServer->new(8080)->background();
print "Use 'kill $pid' to stop server.\n";
