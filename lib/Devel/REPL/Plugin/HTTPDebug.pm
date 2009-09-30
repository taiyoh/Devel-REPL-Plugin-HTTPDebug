package Devel::REPL::Plugin::HTTPDebug;

use utf8;
use Devel::REPL::Plugin;
use MooseX::AttributeHelpers;
use namespace::clean -except => [ 'meta' ];

use LWP::UserAgent;
require HTTP::Request::Common;
use Rose::URI;
use Term::ANSIColor;

my %query;

our $VERSION = '0.01';

our %COLORS = (
    REQHEADER_KEY   => 'bold blue',
    REQHEADER_VALUE => '',
    RESHEADER_KEY   => 'bold blue',
    RESHEADER_VALUE => '',
    CONTENT => ''
);

has ua => (
    is => 'ro',
    isa => 'Object',
    lazy => 1,
    default => sub { LWP::UserAgent->new }
);

do {
    my %attr = (
        req => 'HTTP::Request',
        res => 'HTTP::Response',
        host => 'Str'
    );
    while (my ($k, $v) = each %attr) {
        has $k => ( is => 'rw', isa => $v );
    }
};

has dump_format => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => 'raw'
);

# 違う出力にしたいときは、適当に変えていただけると嬉しいです
has dumper => (
    is => 'ro',
    isa => 'CodeRef',
    lazy => 1,
    default => sub {
        require YAML;
        return YAML->can('Dump');
    }
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

sub req_dump {
    my $self = shift;
    coloring_line($self->req->as_string, 'req');
}

sub res_dump {
    my $self = shift;
    my $res = $self->res;
    my $h = join(' ', ($res->protocol, $res->code, $res->message));
    coloring_line($h . "\n" . $res->headers->as_string, 'res')
}

sub cdump {
    my $self = shift;
    my $str = $self->res->decoded_content;
    if ($self->dump_format eq 'json') {
        # ここも変えられたらいい気はするけど…
        require JSON::XS;
        my $dumped = $self->dumper->(JSON::XS::decode_json($str));
        utf8::encode($dumped) if utf8::is_utf8($dumped);
        return $dumped;
    }
    elsif ($self->dump_format eq 'xml') {
        # 本音は XML::Simple sucks
        require XML::Simple;
        my $dumped = $self->dumper->(XML::Simple::XMLin($str));
        utf8::encode($dumped) if utf8::is_utf8($dumped);
        return $dumped;
    }
    return $str;
}

sub coloring_line {
    my $line = shift;
    my $flag = shift || 'req';
    my @lines = split "\n", $line;
    @lines = map {
        if(my ($k, $v) = (/^(.+?) (.+?)$/)) {
            my $hk = $COLORS{uc($flag).'HEADER_KEY'};
            my $hv = $COLORS{uc($flag).'HEADER_VALUE'};
            $k = colored($k, $hk) if $hk;
            $v = colored($v, $hv) if $hv;
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
    $self->dump_format($res_format || 'raw');
    $self->print(
        $self->res_dump ."\n".
        $self->res->decoded_content
    );
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
    $p ||= {};
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

=encoding utf-8

=head1 NAME

Devel::REPL::Plugin::HTTPDebug -

=head1 SYNOPSIS


  $ ./bin/http_debug.pl --host=ma.la

  $ get_q '/is/married', { foo => 'bar' }
  HTTP::Response=HASH(0x1f36980)
  $ req_dump
  GET http://ma.la/is/married?foo=bar
  User-Agent: Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_1; ja-jp) AppleWebKit/531.9 (KHTML, like Gecko) Version/4.0.3 Safari/531.9

  $ res_dump
  HTTP/1.1 200 OK
  Connection: close
  Date: Wed, 23 Sep 2009 09:40:44 GMT
  Server: Apache
  Content-Type: text/javascript; charset=utf-8
  Client-Date: Wed, 23 Sep 2009 09:40:38 GMT
  Client-Peer: 221.186.251.72:80
  Client-Response-Num: 1
  Client-Transfer-Encoding: chunked

  $ cdump
  true

  $ get_q '/is/married', { foo => 'bar' }, 'json'
  HTTP::Response=HASH(0x1ed7188)
  $ cdump
  --- !!perl/scalar:JSON::XS::Boolean 1


=head1 DESCRIPTION

see Devel::REPL::Plugin::HTTPDebug::Doc.ja.pod

=cut
