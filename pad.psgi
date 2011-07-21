### Movable Type content viewer
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
use MT::FileMgr::Local;
use MT::WeblogPublisher;

my $mt = MT->new;

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
    my $tokens   = $build->compile( $ctx, $template )
        or return build_error( $build->errstr );
    my $out      = $build->build( $ctx, $tokens )
        or return build_error( $build->errstr );

    my $res      = Plack::Response->new();
    $res->status(200);
    $res->header( 'Content-Type' => 'text/plain' );
    $res->header( 'Access-Control-Allow-Origin' => 'http://localhost:5001' );
    $res->content( Encode::encode_utf8($out) );
    return $res->finalize;
};
