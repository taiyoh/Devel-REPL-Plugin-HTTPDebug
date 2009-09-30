#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
#use FindBin::libs;

use Getopt::Long::Descriptive;

my $format = 'Usage: %c %o';
my @opts = (
    [ 'host|h=s'    => 'ホスト名を指定' ],
    [ 'use_session' => 'セッションを使用するかどうか、あらかじめ指定できる' ],
    [ 'agent=s'     => 'ユーザエージェントを任意に指定できる（ディフォルトはsafari4）' ],
    [ 'color_reqk=s'  => 'リクエストヘッダのキーの色を指定できる' ],
    [ 'color_reqv=s'  => 'リクエストヘッダの値の色を指定できる' ],
    [ 'color_resk=s'  => 'レスポンスヘッダのキーの色を指定できる' ],
    [ 'color_resv=s'  => 'レスポンスヘッダの値の色を指定できる' ],
);

my ($opts, $usage) = describe_options($format, @opts);

use Devel::REPL;

my $repl = Devel::REPL->new;
$repl->load_plugin($_) for qw(History LexEnv HTTPDebug);

$repl->host($opts->{host}) if $opts->{host};
$repl->use_session if $opts->{use_session};

$Devel::REPL::Plugin::HTTPDebug::COLORS{REQHEADER_KEY}   = $opts->{color_reqk} if $opts->{color_reqk};
$Devel::REPL::Plugin::HTTPDebug::COLORS{REQHEADER_VALUE} = $opts->{color_reqv} if $opts->{color_reqv};
$Devel::REPL::Plugin::HTTPDebug::COLORS{RESHEADER_KEY}   = $opts->{color_resk} if $opts->{color_resk};
$Devel::REPL::Plugin::HTTPDebug::COLORS{RESHEADER_VALUE} = $opts->{color_resv} if $opts->{color_resv};

# safari4
my $ua = 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_1; ja-jp) AppleWebKit/531.9 (KHTML, like Gecko) Version/4.0.3 Safari/531.9';
$ua = $opts->{agent} if $opts->{agent};
$repl->ua->agent($ua);

$repl->run;
