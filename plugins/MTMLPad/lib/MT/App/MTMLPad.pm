package MT::App::MTMLPad;
use strict;
use warnings;
use MT::App;
use base qw( MT::App::Comments );

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;
    $app->add_methods(
        top  => \&top,
        view => \&view,
        save => \&save,
        author => \&view_author,
    );
    $app;
}

sub init_request {
    my $app = shift;
    delete $app->{__path_info};
    $app->SUPER::init_request(@_);

    $app->param(blog_id => 2);
    $app->param(static => '/') unless $app->param('static');
    $app->config( CommentScript => '' );

    my $path = $app->path_info || '';
    my @paths = split '/', $path;
    shift @paths unless $paths[0];
    my ( $mode, $id ) = @paths;
    if ( $mode =~ /^\d+$/ ) {
        $id   = $mode;
        $mode = 'view';
    }
    if ( $mode =~ /[^\w\.\-]/ ) {
        die "Bad request";
    }
    if ( $mode eq 'new' ) {
        $mode = 'view';
        $id   = undef;
    }

    $app->param( __mode => $mode );
    $app->param( id     => $id );
    $app->{default_mode} = 'top';
}

sub prepare_standard_params {
    my $app = shift;
    my %param;
    my ( $sess_obj, $commenter ) = $app->_get_commenter_session();
    if ( $commenter ) {
        $param{user}      = $commenter;
        $param{user_name} = $commenter->name;
        $param{user_id}   = $commenter->id;
    }
    return \%param;
}

sub top {
    my $app = shift;
    my $param = $app->prepare_standard_params;
    $param->{script_url} = '/';
    my @entry_objs = MT->model('entry')->load({
            blog_id => 2,  #FIXME: hardcoded
        }, {
            direction  => 'descend',
            limit      => 10,
    });
    my %author_ids = map { $_->author_id => 1 } @entry_objs;
    my @author_objs = MT->model('author')->load({ id => [ keys %author_ids ] });
    my %author_objs = map { $_->id => $_ } @author_objs;
    my @entries;
    for my $entry ( @entry_objs ) {
        my $author = $author_objs{ $entry->author_id };
        push @entries, {
            id          => $entry->id,
            title       => $entry->title,
            author_id   => $author->id,
            author_name => $author->name,
        };
    }
    $param->{entries} = \@entries;
    my $plugin = MT->component('MTMLPad');
    return $plugin->load_tmpl('top.tmpl', $param);
}

sub view {
    my $app = shift;
    my $param = $app->prepare_standard_params;

    if ( my $id = $app->param('id') ) {
        return $app->error('Bad request') if $id =~ /\D/;
        my $entry = MT->model('entry')->load($id)
            or return $app->error('Bad request');

        $param->{id}       = $id;
        $param->{title}    = $entry->title;
        $param->{text}     = $entry->text;

        $param->{mine} = !$param->{user}                        ? 0
                       : $entry->author_id == $param->{user_id} ? 1
                       :                                          0
                       ;
        $param->{editable} = $param->{mine};
        my $author = MT->model('author')->load($entry->author_id);
        $param->{author_name} = $author ? $author->name : '(deleted author)';
        $param->{author_id}   = $author ? $author->id   : 0;
    }
    else {
        $param->{new_object} = 1;
        $param->{editable}   = 1;
    }

    my $plugin = MT->component('MTMLPad');
    return $plugin->load_tmpl('view.tmpl', $param );
}

sub save {
    my $app = shift;
    my $param = $app->prepare_standard_params;
    my $id = $app->param('id');
    my $entry;
    if ( $id ) {
        $entry = MT->model('entry')->load($id)
            or return $app->error('Bad request');
        return $app->error('Bad request')
            if $entry->author_id != $param->{user_id};
    }
    else {
        $entry = MT->model('entry')->new;
        $entry->author_id( $param->{user_id} );
    }
    $entry->blog_id(2); ## FIXME: hardcoded
    $entry->status(1);
    $entry->title( $app->param('title') );
    $entry->text( $app->param('text') );
    $entry->save;
    $app->param( id => $entry->id );
    return $app->redirect( '/view/' . $entry->id );
}

sub view_author {
    my $app = shift;
    my $param = $app->prepare_standard_params;

    my $id = $app->param('id') or return $app->error('Bad request');
    return $app->error('Bad request') if $id =~ /\D/;
    my $author = MT->model('author')->load($id)
        or return $app->error('Bad request');
    $param->{id}       = $id;
    $param->{name}     = $author->name;
    $param->{me} = !$param->{user}                  ? 0
                 : $author->id == $param->{user_id} ? 1
                 :                                    0
                 ;
    $param->{editable} = $param->{me};

    my @entry_objs = MT->model('entry')->load({
            author_id => $id,
            blog_id   => 2,  #FIXME: hardcoded
        }, {
            direction  => 'descend',
            limit      => 10,
    });
    my @entries;
    for my $entry ( @entry_objs ) {
        push @entries, {
            id          => $entry->id,
            title       => $entry->title,
        };
    }

    $param->{entries} = \@entries;
    my $plugin = MT->component('MTMLPad');
    return $plugin->load_tmpl('view_author.tmpl', $param );
}

sub AUTOLOAD {
    my $app = shift;
    ( my $method = our $AUTOLOAD ) =~ s/^.*:://;
    my $sub = *{ "$app->SUPER::" . $method };
    $sub->(@_);
}

1;
