package Devel::REPL::Plugin::HTTPDebug;

use Devel::REPL::Plugin;
use MooseX::AttributeHelpers;
use namespace::clean -except => [ 'meta' ];

use LWP::UserAgent;
require HTTP::Request::Common;
use Rose::URI;
use Term::ANSIColor;

use Data::Dumper;
$Data::Dumper::Indent = 1;

my %query;
my $format = 'raw';
# cache for latest request and response

our $VERSION = '0.01';

our %COLORS = (
    HEADER_KEY   => 'bold blue',
    HEADER_VALUE => '',
    CONTENT => ''
);

has ua => (
    is => 'ro',
    isa => 'Object',
    lazy => 1,
    default => sub { LWP::UserAgent->new }
);

has req => (
    is => 'rw',
    isa => 'HTTP::Request',
);

has res => (
    is => 'rw',
    isa => 'HTTP::Response',
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
    default => sub { return shift->_new_cookie; }
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

sub _new_cookie {
    my $self = shift;
    require HTTP::Cookies;
    return HTTP::Cookies->new(file => $self->cookie_file, autosave => 1);
}

# 違う出力にしたいときは、aroundで変えてほしい
sub _dumper {
    require YAML;
    return YAML->can('Dump');
}

sub add {
    my $self = shift;
    my %p = %{$_[0]};
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
    unlink $self->cookie_file if -e $self->cookie_file;
    $self->cookie($self->_new_cookie);
}

sub hdump {
    my $self = shift;
    coloring_line($self->req->as_string);
}

sub rdump {
    my $self = shift;
    my $res = $self->res;
    my $h = join(' ', ($res->protocol, $res->code, $res->message));
    coloring_line($h . "\n" . $res->headers->as_string)
}

sub cdump {
    my $self = shift;
    my $str = $self->res->decoded_content;
    if ($format eq 'json') {
        # ここも変えられたらいい気はするけど…
        require JSON::XS;
        my $dumped = _dumper->(JSON::XS::decode_json($str));
        utf8::encode($dumped) if utf8::is_utf8($dumped);
        return $dumped;
    }
    elsif ($format eq 'xml') {
        # 本音は XML::Simple sucks
        require XML::Simple;
        utf8::encode($str) if utf8::is_utf8($str);
        my $dumped = _dumper->(XMLin($str));
        utf8::encode($dumped) if utf8::is_utf8($dumped);
        return $dumped;
    }
    return $str;
}

sub coloring_line {
    my $line = shift;
    my @lines = split "\n", $line;
    @lines = map {
        if(my ($k, $v) = (/^(.+?) (.+?)$/)) {
            $k = colored($k, $COLORS{HEADER_KEY})   if $COLORS{HEADER_KEY};
            $v = colored($v, $COLORS{HEADER_VALUE}) if $COLORS{HEADER_VALUE};
            "${k} ${v}";
        }
        else {
            $_
        }
    } @lines;
    return join("\n", @lines)."\n";
}

sub get  { shift->_req_common('get_q', @_);  }
sub post { shift->_req_common('post_q', @_); }
sub file { shift->_req_common('file_q', @_); }

sub _req_common {
    my ($self, $c, $path, $args, $res_format) = @_;
    $self->$c($path, $args) or return;
    $format = $res_format || 'raw';
    $self->print($self->rdump ."\n". $self->res->decoded_content);
}

sub get_q {
    my $self = shift;
    my $u = $self->_get_url(@_) or return;
    $u->query_form(%query);

    my $req = HTTP::Request->new(GET => "$u");
    $self->req($req);
    $self->res($self->ua->request($self->req));
}

sub post_q {
    my $self = shift;
    my $u = $self->_get_url(@_) or return;

    my $req = HTTP::Request::Common::POST("$u", [ %query ]);
    $self->req($req);
    $self->res($self->ua->request($self->req));
}

sub file_q {
    my $self = shift;
    my $u = $self->_get_url(@_) or return;

    my $req = HTTP::Request::Common::POST(
        "$u",
        Content_Type => 'form-data',
        Content => [ %query ]
    );
    $self->req($req);
    $self->res($self->ua->request($req));
}

sub _get_url {
    my $self = shift;
    my ($path, $p) = @_;
    if (!$self->host) {
        $self->print('no host');
        return;
    }
    my $u = Rose::URI->new;
    $u->scheme('http');
    $u->host($self->host);
    $u->path($path);
    $self->add($p) if %$p;
    return $u;
}

1;
__END__

=head1 NAME

Devel::REPL::Plugin::HTTPDebug -

=head1 SYNOPSIS

  $ ./bin/http_debug.pl

=head1 DESCRIPTION

Devel::REPL::Plugin::HTTPDebug is

=head1 AUTHOR

taiyoh E<lt>sun.basix@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
