package WebServer;

use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));


use HTTP::Server::Simple::CGI;
use base qw(HTTP::Server::Simple::CGI);
use JSON;
use HTML::Entities;

use FindBin qw($Bin);
use lib $Bin;
use SQLHelper;

=encoding utf8

=head1 NAME

WebServer 

=head1 DESCRIPTION

Simple web server for task. 

=cut

my %Dispatch = (
    '/json'       => \&_GetJSONData,
    '/'           => \&_SearchForm,
    '/index.html' => \&_SearchForm,
    '/data'       => \&_ShowData,
);

sub handle_request {

    my ($Self, $CGI) = @_;

    my $Path = $CGI->path_info();
    my $Handler = $Dispatch{$Path};

    if (ref($Handler) eq "CODE") {
        print "HTTP/1.0 200 OK\r\n";
        $Handler->($CGI);
    } else {
        print "HTTP/1.0 404 Not found\r\n";
        print
            $CGI->header,
            $CGI->start_html('Not found'),
            $CGI->h1('Not found'),
            $CGI->end_html;
    }

}

my $HTMLStyles = <<'HTML';
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f0f0f0; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; }
        .data-box { background: #e8f4f8; padding: 15px; margin: 10px 0; border-radius: 5px; }
        .data-display { background: #bbbbbb; color: #d4d4d4; padding: 15px; border-radius: 5px; font-family: monospace; }
        #status { color: #28a745; margin: 10px 0; }
        button { background: #007bff; color: white; border: none; padding: 10px 20px; border-radius: 5px; cursor: pointer; }
        button:hover { background: #0056b3; }
        table {
            border-collapse: collapse;
            width: 100%;
            max-width: 600px;
            margin: 20px auto;
            font-family: Arial, sans-serif;
        }
        th, td {
            border: 1px solid #333;
            padding: 10px 15px;
            text-align: left;
        }
        th { background-color: #4CAF50; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        tr:hover { background-color: #ddd; }

    </style>
HTML

sub _SearchForm {

    my $CGI = shift;
    return if !ref $CGI;

    print $CGI->header(-type => 'text/html', -charset => 'utf-8');
    print  <<HTML;
<html>
<head>
    <meta charset="UTF-8">
    <title>Форма поиска по email</title>
    $HTMLStyles
</head>
<body>
    <div class="container">
        <h1>📊 Форма поиска по email</h1>
        <div id="status">🟢 Сервер запущен</div>
        <form form action="http://localhost:8080/data" method="post">
            <div class="data-box" style="display: flex; align-items: center; gap: 10px;">
                <label for="mail"><b>E-mail:</b></label>
                <input type="text" id="email" name="email">
            </div>
            <div style="margin: 20px 0;">
                <button type="submit">📥 Получить данные</button>
            </div>
        </form>
    </div>
</body>
</html>
HTML

}

sub _ShowData {

    my $CGI = shift;
    return if !ref $CGI;

    my $Email = $CGI->param ('email') || '';

    my $Data = _GetData ( Email => $Email );

    my $DataHTML = <<HTML;
    <table>
        <thead>
            <tr>
                <th>dt</th>
                <th>str</th>
            </tr>
        </thead>
        <tbody>
HTML

    if ($Data && ref $Data eq 'ARRAY' ) {
        if ( @$Data > 100 ) {
            $DataHTML = '<h3 style="color: red;">Количество строк в результирующей выборке превышает 100, выборка ограничена 100-ей записей</h3>' . $DataHTML;
            pop @$Data;
        }

        for my $Row (@$Data) {
            my $SafeString = encode_entities($Row->{str});

            $DataHTML .= <<HTML;
                <tr>
                    <td>$Row->{dt}</td>
                    <td>$SafeString</td>
                </tr>
HTML
        }
    }

    $DataHTML .= <<HTML;
        </tbody>
    </table>
HTML

    print $CGI->header(-type => 'text/html', -charset => 'utf-8');
    print <<HTML;
<html>
<head>
    <meta charset="UTF-8">
    <title>Данные с сервера</title>
    $HTMLStyles
</head>
<body>
    <div class="container">
        <h1>Данные с сервера:</h1>
        <form form action="/" method="post">
            <input type="Hidden" name="email" value="$Email"/>
            <div style="margin: 20px 0;">
                <button onclick="history.back()">↩️ Вернуться</button>
                <button type="submit" formaction="http://localhost:8080/json">📥 Скачать JSON</button>
            </div>
            <div class="data-box" style="display: flex; align-items: center; gap: 10px;">
                <div class="data-display">
                    $DataHTML
                </div>
            </div>
        </form>
    </div>
</body>
</html>
HTML

}

sub _GetJSONData {

    my $CGI = shift;
    return if !ref $CGI;

    my $Email = $CGI->param ('email') || '';

    my $Data = _GetData ( Email => $Email );

    pop @$Data if $Data && ref $Data eq 'ARRAY' && @$Data > 100;

    my $JSON = JSON->new->allow_nonref(1)->allow_blessed(1);
    my $Result;
    $Result = $JSON->encode($Data) if ref($Data);

    print $CGI->header(-type => "application/json", -charset => "utf-8");
    print $Result;

}

sub _GetData {

    my ( %Param ) = @_;

    if ( !$Param{Email} ) {
        warn "Email parameter is required! \n";
        return;
    }

    my $SQLHelperObject = SQLHelper->new();

    # поиск по точному совпадению
    my $Result = $SQLHelperObject->SelectAll(
        SQL => qq{
            SELECT dt, str FROM (
                SELECT int_id, created AS dt, str FROM message WHERE str LIKE ?
            UNION
                SELECT int_id, created AS dt, str FROM log WHERE address = ?
            ) a
            ORDER BY
                int_id, dt
            LIMIT
                101
        },
        Bind => [ 
            '%<= ' . $Param{Email} . ' %', # исходя из содержимого файла
            $Param{Email}
        ],
    );

    return $Result;
}

1;
