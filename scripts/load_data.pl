#!/usr/bin/perl
use strict;
use warnings;

use Cwd;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use SQLHelper;

my $SQLHelperObject = SQLHelper->new();

$SQLHelperObject->Do(SQL => 'TRUNCATE TABLE message');
$SQLHelperObject->Do(SQL => 'TRUNCATE TABLE log');

my $dir = getcwd;
open FILE, $dir . "/../data/out" or die "Ошибка открытия файла: $!";

# my $RegExEmail = qr{[A-Z0-9._%+-]+@(?:[A-Z0-9-]+\.)+[A-Z]{2,6}};

my $Statistics = { LineNumber => 0, MessageCnt => 0, LogCnt => 0 };

while (my $Line = <FILE>) {
    $Statistics->{LineNumber}++;
    chomp $Line;

    my $LineData = {};
    unless ($Line =~ s/^(\d{4}\-\d{2}\-\d{2}\s\d{2}:\d{2}:\d{2}) //i) {
        print "Line $Statistics->{LineNumber}: incorrect field format dt\n";
        next;
    }

    $LineData->{Date} = $1; 
    $LineData->{String} = $Line;

    unless ($Line =~ s/^([\w\d]{6}\-[\w\d]{6}-[\w\d]{2}) //i) {
        print "Line $Statistics->{LineNumber}: incorrect field format int_id\n";
        next;
    }
    $LineData->{IntID} = $1;

    if ($Line =~ s/^<= //) {
        unless ($Line =~ /\bid=([^\s]+)/) {
            print "Line $Statistics->{LineNumber}: incorrect field format id\n";
            next;
        }
        $LineData->{ID} = $1;
        $LineData->{IsMessage} = 1;
    } elsif ($Line =~ /([A-Z0-9._%+-]+@(?:[A-Z0-9-]+\.)+[A-Z]{2,6})/i) {
        $LineData->{Address} = $1;
    }

    my $SQLResult;
    if ($LineData->{IsMessage}) {
        $SQLResult = $SQLHelperObject->Do(
            SQL  => 'INSERT INTO message (created, id, int_id, str) values(?, ?, ?, ?)',
            Bind => [
                $LineData->{Date}, $LineData->{ID}, $LineData->{IntID}, $LineData->{String}
            ],
            PrepareCached => 1,
        );
        $Statistics->{MessageCnt}++ if $SQLResult;
    } else {
        $SQLResult = $SQLHelperObject->Do(
            SQL  => 'INSERT INTO log (created, int_id, str, address) values(?, ?, ?, ?)',
            Bind => [
                $LineData->{Date}, $LineData->{IntID}, $LineData->{String}, $LineData->{Address}
            ],
            PrepareCached => 1,
        );
        $Statistics->{LogCnt}++ if $SQLResult;

    }
    unless ($SQLResult) {
        print "Line $Statistics->{LineNumber}: Query execution error \n";
        next;
    }
}

print qq{
    Processed: $Statistics->{LineNumber} lines.\n
    Inserted: 
        $Statistics->{MessageCnt} message records,
        $Statistics->{LogCnt} log records.\n
}; 

1;