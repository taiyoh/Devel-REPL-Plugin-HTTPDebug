#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use FindBin::libs;

use Getopt::Long::Descriptive;

my $format = 'Usage: %c %o';
my @opts = (
  [ 'host|h=s'    => 'define host' ],
  [ 'use_session' => 'use session' ],
  [ 'agent=s'     => 'define agent' ],
  [ 'color_hk=s'  => 'define color for Header key' ],
  [ 'color_hv=s'  => 'define color for Header value' ],
);

my ($opts, $usage) = describe_options($format, @opts);

use Devel::REPL;

my $repl = Devel::REPL->new;
$repl->load_plugin($_) for qw(History LexEnv HTTPDebug);

$repl->host($opts->{host}) if $opts->{host};
$repl->use_session if $opts->{use_session};

$Devel::REPL::Plugin::HTTPDebug::COLORS{HEADER_KEY} = $opts->{color_hk}   if $opts->{color_hk};
$Devel::REPL::Plugin::HTTPDebug::COLORS{HEADER_VALUE} = $opts->{color_hv} if $opts->{color_hv};

# safari4
my $ua = 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_1; ja-jp) AppleWebKit/531.9 (KHTML, like Gecko) Version/4.0.3 Safari/531.9';
$ua = $opts->{agent} if $opts->{agent};
$repl->ua->agent($ua);

$repl->run;
