#!/usr/bin/perl
use 5.20.2;
# use strict;
# use warnings;

use Cwd;
use DBI;
use DBI::Const::GetInfoType;

my $dir = getcwd;
open FILE, $dir . "/out" or die "Ошибка открытия файла: $!";

our $db = DBI -> connect ($db_dsn, $db_user, $db_password, { # Необходимо настроить параметры БД
    PrintError  => 0,
    RaiseError  => 1,
    AutoCommit  => 1,
    LongReadLen => 1000000,
    LongTruncOk => 1,
    InactiveDestroy => 0,
    mysql_enable_utf8 => 1,
    pg_enable_utf8 => 1,
});

sql_do ('TRUNCATE TABLE message');
sql_do ('TRUNCATE TABLE log');

# В ТЗ имеется неоднозначности:
# - ограничение NOT NULL, подразумевает, что строки с пустыми данными по ним возможно не нужны.
#   Но фраза 'записываются все остальные строки', как бы  говорит о проивоположном.
#   Принял решение грузить по максимуму заменяя на '', отслеживая только за первичный ключ.
# - несказанно, что делать со строками, которые нельзя загрузить -- формирую ошибку.
# RFC для email позволяет и такое /[A-Z0-9._%+-]+@(?:[A-Z0-9-]+\.)+[A-Z]{2,6}/i, но вариант ниже надёжный(для меня), да и в искомом файле нестадартных email нет

my ($n, %ids);

my %queries = (
    message => {sql => 'INSERT INTO message (created, id, int_id, str) values(?, ?, ?, ?)'},
    log     => {sql => 'INSERT INTO log (created, int_id, str, address) values(?, ?, ?, ?)'},
);

while (my $line = <FILE>) {
    $n++;
    unless (
        $line =~ /^
            (\d{4}\-\d{2}\-\d{2}\s\d{2}:\d{2}:\d{2})\s+
            ((?:
                ([\w\d]{6}\-[\w\d]{6}-[\w\d]{2})\s+
                (?:(?:(<=)|=>|->|\*\*|==)\s+
                    (?(4)
                        (?:.*\bid=(\d+)\b)?
                        |
                        ([-._a-z0-9]+@(?:[a-z0-9][-a-z0-9]+\.)+?[a-z]{2,6})\b
                    )
                )?
            )?.*)
        $/xio
    ) {
        print "Строка $n: ошибка формата строки\n";
        next;
    }

    my ($dt, $str, $int_id, $is_arrival, $id, $email) = ($1, $2, $3, $4, $5, $6);
    # vld_date ($dt); # Валидация даты по идее тоже должна быть, не стал расписывать, ибо не суть, а в исходном файле порядок
    if ($is_arrival) {
        unless (defined $id) {
            print "Строка $n: отсутствует обязательное поле id\n";
            next;
        }
        if ($ids {$id}) {
            print "Строка $n: значение поле id ($id) не уникально\n";
            next;
        }
        $ids {$id} = 1;
        sql_do ($queries {message}, $dt, $id, $int_id || '', $str);
    } else {
       sql_do ($queries {log}, $dt, $int_id || '', $str, $email);
    }
}

close FILE;

eval {
    map { $_ -> {st} -> finish if $_ -> {st} } values %queries;
    $db -> disconnect;
};

################################################################################

sub sql_do {
    my ($query, @params) = @_;

    eval {
        if (ref $query ne 'HASH') {
            $query = { sql => $query, is_instant => 1 };
        }
        $query -> {st} = $db -> prepare ($query -> {sql}, {})
            unless $query -> {st};
        $query -> {st} -> execute (@params);
    };
    if ($@) {
        die "Ошибка выполнения запроса: $@ (SQL = $query)\n";
    }
    $query -> {st} -> finish if $query -> {is_instant};
}

sub vld_date {}
