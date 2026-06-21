package SQLHelper;

use strict;
use warnings;

use Cwd;
use DBI;


=encoding utf8

=head1 NAME

SQLHelper

=head1 DESCRIPTION

Helper for sql queries for task. 

=cut

sub new {

    my ( $Class ) = @_;

    my $Self = {};
    bless $Self, $Class;

    return $Self;
}


=head2 _GetConfig()

    Get config for connection to a database

=cut

sub _GetConfig {

    my ( $Self ) = @_;
    my $Config = {}; 

    my $Dir = getcwd;
    open ENV_FILE, $Dir . "/../.env" or die "Ошибка открытия файла: $!";

    while (my $Line = <ENV_FILE>) {
        if ( $Line && $Line =~ /^(\w+)=(.+)$/ ) {
            $Config->{$1} = $2;
        }
    }

    close ENV_FILE;

    return $Config; 
}

=head2 _GetConnection()

    Get connect to a database

=cut

sub _GetConnection {

    my ( $Self ) = @_;
    my $Config = $Self->_GetConfig();

    $Self->{_Connection} = DBI->connect(
        $Config->{DB_DSN},
        $Config->{DB_USER},
        $Config->{DB_PASSWORD},
        {
            PrintError  => 0,
            RaiseError  => 0,
            AutoCommit  => 1,
            LongReadLen => 1000000,
            LongTruncOk => 1,
            InactiveDestroy => 0,
            mysql_enable_utf8 => 1,
            pg_enable_utf8 => 1,
        }
    );

    return  1;

}

sub _QueryHandle {
    my ( $Self, %Param ) = @_;

    unless ($Self->{_Connection}) {
        $Self->_GetConnection();
    }

    if ( !$Param{SQL} ) {
        print "SQL parameter is required! \n";
        return;
    }

    if ( $Param{Bind} && ref $Param{Bind} ne 'ARRAY' ) {
        print "Incorrect parameter Bind \n";
        return;
    }

    if (defined( $Param{Limit} ) ) {
        my $Limit = int($Param{Limit});

        if ($Limit > 0) {
            $Param{SQL} .= ' LIMIT ' . $Limit;
        } else {
            print "Incorrect parameter Limit : $Param{Limit} \n";
            return;
        } 
    }

    my @Array;
    if ( $Param{Bind} ) {
        for my $Data ( @{ $Param{Bind} } ) {
            unless ( ref $Data  ) {
                push @Array, $Data;
            } else {
                print "No SCALAR param in Bind! \n";
                return;
            }
        }
    }

    my $StatementHandle;
    if ($Param{PrepareCached}) {
        $StatementHandle = $Self->{_Connection}->prepare_cached($Param{SQL});
    } else {
        $StatementHandle = $Self->{_Connection}->prepare($Param{SQL});
    }

    unless ($StatementHandle && $StatementHandle->execute(@Array)) {
        print  "Query execution error: $@ (SQL = $Param{SQL})\n";
        return;
    }

    return $StatementHandle;

}

=head2 Do()

    For DDL, DML queries 

=cut

sub Do {

    my ( $Self, %Param ) = @_;

    my $StatementHandle = $Self->_QueryHandle( %Param );

    return unless $StatementHandle;

    $StatementHandle->finish;

    return 1;
}


=head2 SelectAll()

    Get data from select query

=cut

sub SelectAll {

    my ( $Self, %Param ) = @_;

    my $StatementHandle = $Self->_QueryHandle( %Param );

    return unless $StatementHandle;

    my $DataResult = [];
    while (my $Row = $StatementHandle->fetchrow_hashref ()) {
        push @$DataResult, $Row;
    }

    $StatementHandle->finish;

    return $DataResult;

}

sub DESTROY 
{ 
    my $Self = shift;

    if ($Self->{_GetConnection}) {
        $Self->{_GetConnection}->disconnect();
    }
}

1;