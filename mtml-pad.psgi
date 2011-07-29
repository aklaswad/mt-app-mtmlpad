#!/usr/bin/perl -w
use strict;
use lib qw( lib extlib );
BEGIN { $ENV{MT_CONFIG} = 'mtml-pad-config.cgi' }
use MT;
BEGIN {
    MT->new;
}
use MT::App::MTMLPad;
use CGI::PSGI;
use Plack::Builder;
use Plack::App::URLMap;
use Plack::App::File;

my $mt_app = sub {
    my $env = shift;
    my $cgi = CGI::PSGI->new($env);
    local *ENV = { %ENV, %$env }; # some MT::App method needs this
    my $app = MT::App::MTMLPad->new( CGIObject => $cgi,  );
    MT->set_instance($app);

    # Cheap hack to get the output
    my($header_sent, $body);
    local *MT::App::send_http_header = sub { $header_sent++ };
    local *MT::App::print = sub { my $self = shift; $body .= "@_" if $header_sent };

    $app->init_request(CGIObject => $cgi);
    $app->{cookies} = do { $cgi->cookie; $cgi->{'.cookies'} }; # wtf
    $app->run;

    # copied from MT::App::send_http_header
    my $type = $app->{response_content_type} || 'text/html';
    if ( my $charset = $app->charset ) {
        $type .= "; charset=$charset"
            if ( $type =~ m!^text/! || $type =~ m!\+xml$! )
            && $type !~ /\bcharset\b/;
    }

    if ($app->{redirect}) {
        $app->{cgi_headers}{-status}   = 302;
        $app->{cgi_headers}{-location} = $app->{redirect};
    } else {
        $app->{cgi_headers}{-status}
            = ( $app->response_code || 200 )
            . ( $app->{response_message} ? ' ' . $app->{response_message} : '' );
    }

    $app->{cgi_headers}{-type} = $type;
    my($status, $headers) = $app->{query}->psgi_header( %{ $app->{cgi_headers} } );
    return [ $status, $headers, [ $body ] ];
};

builder {
    mount "/mt-static", builder {
        Plack::App::File->new({ root => "mt-static" });
    };
    mount "/favicon.ico", builder {
        Plack::App::File->new( file => 'mtml-pad.ico' );
    };
    mount "/", $mt_app;
};
