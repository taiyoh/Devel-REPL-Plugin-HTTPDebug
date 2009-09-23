package Devel::REPL::Plugin::HTTPDebug;

use Devel::REPL::Plugin;
use MooseX::AttributeHelpers;
use namespace::clean -except => [ 'meta' ];

use LWP::UserAgent;
require HTTP::Request::Common;
use Rose::URI;
use Term::ANSIColor qw(:constants);

my %query;
# cache for latest request and response
my ($req, $res);

our $VERSION = '0.01';

our %COLORS = (
    HEADER_KEY   => BOLD.BLUE,
    HEADER_VALUE => ''
);

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
    $comm ||= $line;
    $args ||= '';
    return $orig->($self, "\$_REPL->$comm($args)") if $self->can($comm);
    return $orig->(@_);
};

sub add {
    my $self = shift;
    my %p = ($_[1]) ? @_ : %{$_[0]};
    while (my ($k, $v) = each %p) {
        $query{$k} = $v;
    }
}

do {
    my %aliases = ();
    sub set_alias {
        my $self = shift;
        my ($key, $value) = @_;
        $aliases{$key} = $value;
    }
    sub call {
        my $self = shift;
        my $key = shift;
        $self->eval($aliases{$key}) if $aliases{$key};
    }
};

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

sub hdump { coloring_line($req->as_string) }

sub rdump {
    my $h = $res->protocol . " ". $res->code . " " . $res->message;
    coloring_line($h . "\n" . $res->headers->as_string)
}

sub cdump { $res->decoded_content }

sub coloring_line {
    my $line = shift;
    my @lines = split "\n", $line;
    @lines = map {
        if(my ($k, $v) = (/^(.+?) (.+?)$/)) {
            $k = $COLORS{HEADER_KEY}   . $k . RESET if $COLORS{HEADER_KEY};
            $v = $COLORS{HEADER_VALUE} . $v . RESET if $COLORS{HEADER_VALUE};
            "${k} ${v}";
        }
        else {
            $_
        }
    } @lines;
    return join("\n", @lines)."\n";
}

sub get {
    my $self = shift;
    $res = $self->get_q(@_);
    $self->print(rdump() ."\n". cdump());
}

sub get_q {
    my $self = shift;
    my $u = $self->_get_url(@_) or return;
    $u->query_form(%query);
    $req = HTTP::Request->new(GET => "$u");
    $res = $self->ua->request($req);
}

sub post {
    my $self = shift;
    $res = $self->post_q(@_) or return;
    $self->print(rdump() ."\n". cdump());
}

sub post_q {
    my $self = shift;
    my $u = $self->_get_url(@_) or return;
    $req = HTTP::Request::Common::POST("$u", [ %query ]);
    $res = $self->ua->request($req);
}

sub file {
    my $self = shift;
    my $res = $self->file_q(@_) or return;
    $self->print(rdump() ."\n". cdump());
}

sub file_q {
    my $self = shift;
    my $u = $self->_get_url(@_) or return;
    $req = HTTP::Request::Common::POST(
        "$u",
        Content_Type => 'form-data',
        Content => [ %query ]
    );
    $res = $self->ua->request($req);
}

sub _get_url {
    my $self = shift;
    my ($path, @p) = @_;
    if (!$self->host) {
        $self->print('no host');
        return;
    }
    my $u = Rose::URI->new;
    $u->scheme('http');
    $u->host($self->host);
    $u->path($path);
    $self->add(@p) if @p;
    return $u;
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
