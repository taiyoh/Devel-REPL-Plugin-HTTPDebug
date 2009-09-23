package Devel::REPL::Plugin::HTTPDebug;

use Devel::REPL::Plugin;
use MooseX::AttributeHelpers;
use namespace::clean -except => [ 'meta' ];

use LWP::UserAgent;
use Rose::URI;

my %query;
# cache for latest request
my ($req, $res);

our $VERSION = '0.01';

has ua => (
    is => 'ro',
    isa => 'Object',
    lazy => 1,
    default => sub { LWP::UserAgent->new }
);

has cookie_file => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub {
        my $self = shift;
        (my $pkg = ref $self) =~ s/::/_/g;
        return sprintf('/tmp/%s_cookie.txt', $pkg);
    }
);

has cookie => (
    is => 'rw',
    isa => 'HTTP::Cookies',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $file = $self->cookie_file;
        require HTTP::Cookies;
        return HTTP::Cookies->new(file => $file, autosave => 1);
    }
);

has host => (
    is => 'rw',
    isa => 'Str',
);

around 'eval' => sub {
    my $orig = shift;
    my ($self, $line) = @_;
    my ($comm, $args) = ($line =~ /^(.+?) (.+?)$/);
    $comm ||= '';
    $args ||= '';
    return $orig->($self, "\$_REPL->$comm($args)") if $self->can($comm);
    return $orig->(@_);
};

sub add {
    my $self = shift;
    my %p = @_;
    %p = %{$_[0]} unless $_[1];
    while (my ($k, $v) = each %p) {
        $query{$k} = $v;
    }
}

sub use_session {
    my $self = shift;
    $self->ua->cookie_jar($self->cookie);
}

sub clear { %query = (); }

sub clear_session {
    my $self = shift;
    $self->cookie->clear($self->host);
}

sub undef_session {
    my $self = shift;
    $self->ua->cookie_jar(undef);
    unlink $self->cookie_file;
    my $c = HTTP::Cookies->new(file => $self->cookie_file, autosave => 1);
    $self->cookie($c);
}

sub get {
    my $self = shift;
    my $res = $self->get_q(@_);
    $self->print($res->as_string);
}

sub hdump { $req->as_string; }
sub rdump { $res->{_headers}->as_string; }
sub cdump { $res->decoded_content }

sub get_q {
    my $self = shift;
    my ($path, @p) = @_;
    if (!$self->host) {
        $self->print('no host');
        return '';
    }
    my $u = Rose::URI->new;
    $u->scheme('http');
    $u->host($self->host);
    $u->path($path);
    $self->add(@p) if @p;
    $u->query_form(%query);
    my $url = "$u";
    $req = HTTP::Request->new(GET => $url);
    $res = $self->ua->request($req);
}

sub post {
    my $self = shift;
    my $res = $self->post_q(@_);
    $self->print($res->as_string);
}

sub post_q {
    my $self = shift;
    my ($path, %p) = @_;
    if (!$self->host) {
        $self->print('no host');
        return '';
    }
    my $u = Rose::URI->new;
    $u->scheme('http');
    $u->host($self->host);
    $u->path($path);
    $self->add(%p);
    my $url = "$u";
    my $content = $self->serialize;
    $req = HTTP::Request->new(POST => $url);
    $req->header('Content-Type' => 'application/x-www-form-urlencoded');
    $req->header('Content-Length' => length($content));
    $req->content($content);
    $res = $self->ua->request($req);
}

sub serialize {
    my $u = Rose::URI->new;
    $u->query(\%query);
    return $u->query;
}

1;
__END__

=head1 NAME

Devel::REPL::Plugin::HTTPDebug -

=head1 SYNOPSIS

  use Devel::REPL::Plugin::HTTPDebug;

=head1 DESCRIPTION

Devel::REPL::Plugin::HTTPDebug is

=head1 AUTHOR

taiyoh E<lt>sun.basix@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
