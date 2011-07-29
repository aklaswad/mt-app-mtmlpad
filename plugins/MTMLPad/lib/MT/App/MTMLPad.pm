package MT::App::MTMLPad;
use strict;
use warnings;
use MT::App;
use MT::Entry;
use MT::Builder;
use MT::Template::Context;
use base qw( MT::App::Comments );
use MT::CMS::OAuth;
use MT::Util qw( relative_date );

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;
    $app->add_methods(
        top  => \&top,
        view => \&view,
        save => \&save,
        list => \&list_entries,
        delete => \&delete_entry,
        author => \&view_author,
        login => \&login,
        oauth_verified => \&oauth_verified,
    );
    $app->{requires_login} = 0;
    $app;
}

sub load_tmpl {
    my $app = shift;
    my $plugin = MT->component('MTMLPad');
    return $plugin->load_tmpl(@_) || $app->SUPER::load_tmpl(@_);
}

sub script { return '/' }

sub login {
    my $app = shift;
    my $client = $app->param('client');
    my $endpoint = MT->config->MTMLPadURL . 'oauth_verified';
    $endpoint .= '?client=' . $client if $client eq 'twitter';
    MT::CMS::OAuth::oauth_login($app, our_endpoint => $endpoint, @_);
}

sub oauth_verified {
    my $app = shift;
    my $endpoint = MT->config->MTMLPadURL . 'oauth_verified';
    MT::CMS::OAuth::oauth_verified($app, our_endpoint => $endpoint, @_);
}

sub init_request {
    my $app = shift;
    delete $app->{__path_info};
    $app->SUPER::init_request(@_);

    $app->param(blog_id => MT->config->MTMLPadBlogID);
    $app->param(static => '/') unless $app->param('static');
    $app->config( CommentScript => '' );

    my $path = $app->path_info || '';
    my @paths = split '/', $path;
    shift @paths unless $paths[0];
    my ( $mode, $id ) = @paths;
    if ( $mode && $mode =~ /^\d+$/ ) {
        $id   = $mode;
        $mode = 'view';
    }
    if ( $mode && $mode =~ /[^\w\.\-]/ ) {
        die "Bad request";
    }
    if ( $mode && $mode eq 'new' ) {
        $mode = 'view';
        $id   = undef;
    }

    $app->param( __mode => $mode );
    $app->param( id     => $id );
    $app->{default_mode} = 'top';

    my ( $sess_obj, $commenter ) = $app->_get_commenter_session();
    $app->user($commenter);
}

sub prepare_standard_params {
    my $app = shift;
    my %param;
    my ( $sess_obj, $commenter ) = $app->_get_commenter_session();
    my $blog = MT->model('blog')->load( MT->config->MTMLPadBlogID )
        or die "Internal Error: Blog for MTMLPad not found.";
    $param{application_name} = "MTMLPad";
    $param{blog} = $blog;

    ## FIXME: MT::App returns empty value. maybe because of difference
    ##        between CGI and CGI::PSGI. need to investigate...
    $param{script_url} = '/';
    if ( $commenter ) {
        $param{user}         = $commenter;
        $param{user_name}    = $commenter->nickname;
        $param{user_link}    = $commenter->url;
        $param{user_id}      = $commenter->id;
        $param{user_auth}    = $commenter->auth_type;
        $param{user_userpic} = $commenter->userpic_url();# Width => 20, Height => 20, Square => 1 );

        $param{user_posts}   = MT->model('entry')->count({
            blog_id   => MT->config->MTMLPadBlogID,
            author_id => $commenter->id,
        });
    }
    else {
        my $external_authenticators
            = $app->external_authenticators( $blog, \%param );
        if (@$external_authenticators) {
            $param{auth_loop}      = $external_authenticators;
            $param{default_signin} = $external_authenticators->[0]->{key}
                unless exists $param{default_signin};
        }
    }
    $param{this_url} = MT->config->MTMLPadURL . $app->path_info;
    return \%param;
}

sub set_default_tmpl_params {
    my $app = shift;
    my $tmpl = shift;
    $app->SUPER::set_default_tmpl_params($tmpl);

    ## FIXME: MT::App returns empty value. maybe because of difference
    ##        between CGI and CGI::PSGI. need to investigate...
    $tmpl->param( script_url => '/' );
    $tmpl;
}

sub set_entry_params {
    my $app = shift;
    my ( $entry, $param ) = @_;
    $param = {} unless defined $param;
    my $login_user = $app->user;

    my @lines = split "\n", ($entry->text_more || '');
    $param->{entry_id}            = $entry->id;
    $param->{entry_title}         = $entry->title;
    $param->{entry_text}          = $entry->text;
    $param->{entry_text_raw}      = $entry->text;
    $param->{entry_summary_lines} = \@lines;
    $param->{entry_views}         = $entry->to_ping_urls; ## hack
    $param->{entry_tags}          = [ $entry->tags ];

    my $blog = MT->model('blog')->load($entry->blog_id);
    my $created_on = $entry->created_on;
    $param->{entry_created_on_ts} = $created_on,
    $param->{entry_created_on}    = relative_date( $created_on, time, $blog );
    my $modified_on = $entry->created_on;
    $param->{entry_modified_on_ts} = $created_on,
    $param->{entry_modified_on}    = relative_date( $created_on, time, $blog );
    if ( my $author = $entry->author ) {
        $app->set_author_params($author, $param);
    }
    if ( $login_user ) {
        $param->{entry_is_mine} = $entry->author_id == $login_user->id ? 1 : 0;
        $param->{entry_editable} = $param->{entry_is_mine};
    }
    $param;
}

sub set_author_params {
    my $app = shift;
    my ( $author, $param ) = @_;
    $param = {} unless defined $param;
    $param->{author_id}       = $author->id;
    $param->{author_name}     = $author->nickname;
    $param->{author_userpic}  = $author->userpic_url();
    $param->{author_userpic_medium}  = $author->userpic_url( Width => 28, Height => 28, Square => 1 );
    $param->{author_userpic_small}  = $author->userpic_url( Width => 20, Height => 20, Square => 1 );
    $param->{author_post_count} = MT->model('entry')->count({
        blog_id   => MT->config->MTMLPadBlogID,
        author_id => $author->id,
    });
    $param->{author_auth_type} = $author->auth_type;
    $param->{author_auth_type} =~ s/^oauth\.//;
    $param->{author_external_profile_url} = $author->url;

    my $login_user = $app->user;
    $param->{author_is_me} = !$login_user                   ? 0
                           : $author->id == $login_user->id ? 1
                           :                                  0
                           ;
    $param->{author_editable} = $param->{author_is_me};
    $param;
}

sub top {
    my $app = shift;
    my $param = $app->prepare_standard_params;
    $param->{script_url} = '/';
    my $offset = int($app->param('offset')) || 0;
    my $entries_per_page = 10;
    my @entry_objs = MT->model('entry')->load({
            blog_id => MT->config->MTMLPadBlogID,
        }, {
            sort       => 'created_on',
            direction  => 'descend',
            limit      => $entries_per_page + 1,
            offset     => $offset,
    });
    my @entries;
    for my $entry ( @entry_objs ) {
        push @entries, $app->set_entry_params($entry);
    }
    my $has_next;
    if ( scalar @entries > $entries_per_page ) {
        pop @entries;
        $has_next = 1;
    }
    $param->{entries} = \@entries;
    $param->{has_next} = $has_next;
    $param->{has_prev} = $offset > 0;
    $param->{next_offset} = $offset + $entries_per_page;
    $param->{prev_offset} = $offset - $entries_per_page;
    my $plugin = MT->component('MTMLPad');
    my $tmpl = $plugin->load_tmpl('top.tmpl', $param);
    my $blog = MT->model('blog')->load( MT->config->MTMLPadBlogID );
    $tmpl->context->stash( blog => $blog );
    return $tmpl;
}

sub list_entries {
    my $app = shift;
    my $param = $app->prepare_standard_params;
    $param->{script_url} = '/';
    my $offset = int($app->param('offset')) || 0;
    my $entries_per_page = 10;
    my @entry_objs = MT->model('entry')->load({
            blog_id => MT->config->MTMLPadBlogID,
        }, {
            sort       => 'created_on',
            direction  => 'descend',
            limit      => $entries_per_page + 1,
            offset     => $offset,
    });
    my @entries;
    for my $entry ( @entry_objs ) {
        push @entries, $app->set_entry_params($entry);
    }
    my $has_next;
    if ( scalar @entries > $entries_per_page ) {
        pop @entries;
        $has_next = 1;
    }
    $param->{entries} = \@entries;
    $param->{has_next} = $has_next;
    $param->{has_prev} = $offset > 0;
    $param->{next_offset} = $offset + $entries_per_page;
    $param->{prev_offset} = $offset - $entries_per_page;

    my %format = (
        html => {
            tmpl => 'list_posts.tmpl',
        },
        atom => {
            tmpl => 'list_atom.tmpl',
        },
        json => {
            tmpl => 'list_json.tmpl',
        },
    );
    my $mode = $app->param('format') || 'html';
    my $format = $format{$mode};
    my $plugin = MT->component('MTMLPad');
    my $tmpl = $plugin->load_tmpl($format->{tmpl}, $param);
    my $blog = MT->model('blog')->load( MT->config->MTMLPadBlogID );
    $tmpl->context->stash( blog => $blog );
    return $tmpl;
}

sub view {
    my $app = shift;
    my $param = $app->prepare_standard_params;
    if ( my $id = $app->param('id') ) {
        return $app->error('Bad request') if $id =~ /\D/;
        my $entry = MT->model('entry')->load($id)
            or return $app->error('Bad request');
        # use to_ping_urls column for page view.
        my $views = $entry->to_ping_urls || 0;
        $entry->to_ping_urls( $views + 1 );
        $entry->save;
        $app->set_entry_params($entry, $param);
    }
    else {
        $param->{new_object}     = 1;
        $param->{entry_editable} = 1;
    }

    my $plugin = MT->component('MTMLPad');
    my $tmpl =  $plugin->load_tmpl('view.tmpl', $param );
    my $blog = MT->model('blog')->load( MT->config->MTMLPadBlogID );
    $tmpl->context->stash( blog => $blog );
    return $tmpl;
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
    $entry->blog_id(MT->config->MTMLPadBlogID);
    $entry->status( MT::Entry::RELEASE() );
    $entry->title( $app->param('title') );
    my $text = $app->param('text');
    my $summary = $app->param('summary');
    if ( $summary =~ m{<(?!/?span)} ) {
        return $app->error( 'Invalid Request' );
    }
    chomp $summary;
    $entry->text_more( $summary );
    $entry->text( $text );
    my @tags = _taglist_from_text($text);
    $entry->set_tags(@tags);
    $entry->save;
    $app->param( id => $entry->id );
    return $app->redirect( '/view/' . $entry->id );
}

sub _taglist_from_text {
    my $text = shift;
    my $build = MT::Builder->new;
    my $ctx   = MT::Template::Context->new;
    my $tokens = $build->compile($ctx, $text);
    my %tags;
    _taglist_core( $tokens, \%tags );
    return wantarray ? keys %tags : \%tags;
}

sub _taglist_core {
    my ( $tokens, $hashref ) = @_;
    for my $token ( @$tokens ) {
        my $tag = lc $token->[0];
        next if $tag eq 'text';
        $hashref->{$tag} ||= 0;
        $hashref->{$tag}++;
        _taglist_core( $token->[2], $hashref ) if $token->[2];
    }
}

sub delete_entry {
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
    $entry->remove or return $app->error('Failed to delete entry');
    return $app->redirect( '/' );
}

sub view_author {
    my $app = shift;
    my $param = $app->prepare_standard_params;

    my $id = $app->param('id') or return $app->error('Bad request');
    return $app->error('Bad request') if $id =~ /\D/;
    my $author = MT->model('author')->load($id)
        or return $app->error('Bad request');
    $app->set_author_params($author, $param);

    my @entry_objs = MT->model('entry')->load({
            author_id => $id,
            blog_id   => MT->config->MTMLPadBlogID,
        }, {
            sort       => 'created_on',
            direction  => 'descend',
    });
    my @entries;
    for my $entry ( @entry_objs ) {
        push @entries, $app->set_entry_params($entry);
    }

    $param->{author_entries} = \@entries;
    my $plugin = MT->component('MTMLPad');
    my $tmpl = $plugin->load_tmpl('view_author.tmpl', $param );
    my $blog = MT->model('blog')->load( MT->config->MTMLPadBlogID );
    $tmpl->context->stash( blog => $blog );
    return $tmpl;
}

sub AUTOLOAD {
    my $app = shift;
    ( my $method = our $AUTOLOAD ) =~ s/^.*:://;
    my $sub = *{ "$app->SUPER::" . $method };
    $sub->(@_);
}

1;
