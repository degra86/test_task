#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));

use FindBin qw($Bin);
use lib "$Bin/../lib";
use SQLHelper;

my $SQLHelperObject = SQLHelper->new();

$SQLHelperObject->Do(SQL => 'TRUNCATE TABLE message');
$SQLHelperObject->Do(SQL => 'TRUNCATE TABLE log');

open FILE, "$Bin/../data/out" or die "Ошибка открытия файла: $!";

my $LogFile = '$Bin/../logs/log.err';

# my $RegExEmail = qr{[A-Z0-9._%+-]+@(?:[A-Z0-9-]+\.)+[A-Z]{2,6}};

my $Statistics = { LineNumber => 0, MessageCnt => 0, LogCnt => 0 };
my %IDs;

while (my $Line = <FILE>) {
    $Statistics->{LineNumber}++;
    chomp $Line;

    my $LineData = {};
    unless ($Line =~ s/^(\d{4}\-\d{2}\-\d{2}\s\d{2}:\d{2}:\d{2}) //i) {
        LogMessage('incorrect field format dt');
        next;
    }

    $LineData->{Date} = $1; 
    $LineData->{String} = $Line;

    unless ($Line =~ s/^([\w\d]{6}\-[\w\d]{6}-[\w\d]{2}) //i) {
        LogMessage('incorrect field format int_id');
        next;
    }
    $LineData->{IntID} = $1;

    if ($Line =~ s/^<= //) {
        unless ($Line =~ /\bid=([^\s]+)/) {
            LogMessage('incorrect field format id');
            next;
        }
        $LineData->{ID} = $1;
        if ($IDs{$LineData->{ID}}) {
            LogMessage(" the value of the id field ($LineData->{ID}) is not unique");;
            next;
        }
        $IDs{$LineData->{ID}} = 1;
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
        LogMessage('Query execution error');
        next;
    }
}

print qq{
    Processed: $Statistics->{LineNumber} lines.\n
    Inserted: 
        $Statistics->{MessageCnt} message records,
        $Statistics->{LogCnt} log records.\n
}; 


sub LogMessage {

    my ($Message) = @_;
    my $Timestamp = localtime();
    my $LogEntry = "[$Timestamp] Строка $Statistics->{LineNumber}: $Message\n";

    if (!-e $LogFile) {
        open(my $FH, '>', $LogFile) or die "Не могу создать $LogFile: $!";
        print $FH $LogEntry;
        close($FH);
    } else {
        open(my $FH, '>>', $LogFile) or die "Не могу открыть $LogFile: $!";
        print $FH $LogEntry;
        close($FH);
    }

}

1;