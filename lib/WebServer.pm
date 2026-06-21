package WebServer;

use strict;
use warnings;

use HTTP::Server::Simple::CGI;
use base qw(HTTP::Server::Simple::CGI);
use JSON;

use FindBin qw($Bin);
use lib $Bin;
use SQLHelper;

=encoding utf8

=head1 NAME

WebServer 

=head1 DESCRIPTION

Simple web server for task. 

=cut


my %dispatch = (
    '/log' => \&resp_log,
);

sub handle_request {
    my $self = shift;
    my $cgi  = shift;

    my $path = $cgi->path_info();
    my $handler = $dispatch{$path};

    if (ref($handler) eq "CODE") {
        print "HTTP/1.0 200 OK\r\n";
        $handler->($cgi);
    } else {
        print "HTTP/1.0 404 Not found\r\n";
        print $cgi->header,
                $cgi->start_html('Not found'),
                $cgi->h1('Not found'),
                $cgi->end_html;
    }
}

sub resp_log {
    my $CGI  = shift;
    return if !ref $CGI;

    my $Data = _GetData ( Email => $CGI->param ('email') || '');
    if ($Data && @$Data > 100) {
        print $CGI->header
            , $CGI->start_html("log")
            , $CGI->h1("Result: ")
            , 'The number of rows in the resulting selection exceeds 100'
            , $CGI->end_html;
    } else {
        my $_JSON = JSON->new->allow_nonref(1)->allow_blessed(1);
        my $Result;
        $Result = $_JSON->encode($Data) if ref($Data);

        print $CGI->header(-type => "application/json", -charset => "utf-8");
        print $Result;
    }
}

sub _GetData {

    my ( %Param ) = @_;

    if ( !$Param{Email} ) {
        warn "Email parameter is required! \n";
        return;
    }

    my $SQLHelperObject = SQLHelper->new();
    my $Result = $SQLHelperObject->SelectAll(
        SQL => qq{
            SELECT dt, str FROM (
                SELECT int_id, created AS dt, str FROM message WHERE id = ?
            UNION
                SELECT int_id, created AS dt, str FROM log WHERE address = ?
            ) a
            ORDER BY int_id, dt DESC LIMIT 101
        },
        Bind => [ $Param{Email}, $Param{Email} ],
    );

    return $Result;
}

1;
