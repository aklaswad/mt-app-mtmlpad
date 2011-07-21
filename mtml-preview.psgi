use strict;
use warnings;
use Plack::Request;
use Plack::Response;
use Plack::Builder;
use lib qw( lib extlib );
use Encode;
use MT;
use MT::Builder;
use MT::Template::Context;
use MT::Template::Handler;

$ENV{MT_CONFIG} = 'mtml-preview-config.cgi';
my $mt = MT->new;

## Kill some tags for security.
{
    my $orig_invoke = \&MT::Template::Handler::invoke;
    my %danger_tag = map { $_ => 1 } qw(
        include
        includeblock
    );
    no warnings 'redefine';
    *MT::Template::Handler::invoke = sub {
        my $tag = $_[1]->stash('tag');
        return "<< Sorry, tag [$tag] is not available. >>"
            if $danger_tag{lc $tag};
        $orig_invoke->(@_);
    };
}

sub build_error {
    my ($error) = @_;
    my $res = Plack::Response->new(400);
    $res->header( 'Content-Type' => 'text/plain' );
    $res->header( 'Access-Control-Allow-Origin' => 'http://localhost:5001' );
    $res->content( Encode::encode_utf8($error) );
    return $res->finalize;
}

my $app = sub {
    my $env      = shift;
    my $req      = Plack::Request->new($env);
    my $path     = $req->path;
    my $template = $req->param('template');
    my $url      = $req->param('url');
    my $build    = MT::Builder->new;
    my $ctx      = MT::Template::Context->new;
    my $blog     = MT->model('blog')->load(1);
    $ctx->stash( blog => $blog );

    my ( $tokens, $out );

    $tokens = eval { $build->compile( $ctx, $template ) };
    return build_error( 'Internal error at compile: ' . $@ ) if $@;
    return build_error( 'Compile error: ' . $build->errstr ) unless defined $tokens;

    $out = eval { $build->build( $ctx, $tokens ) };
    return build_error( 'Internal error at build: ' . $@ ) if $@;
    return build_error( 'Build error: ' . $build->errstr ) unless defined $out;

    my $res      = Plack::Response->new();
    $res->status(200);
    $res->header( 'Content-Type' => 'text/plain' );
    $res->header( 'Access-Control-Allow-Origin' => MT->config->MTMLPadURL );
    $res->content( Encode::encode_utf8($out) );
    return $res->finalize;
};
