#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use FindBin::libs;

use Getopt::Long::Descriptive;

my $format = 'Usage: %c %o';
my @opts = (
  [ 'host|h=s' => 'define host (optional)' ],
  [ 'use_session' => 'use session (optional)' ],
  [ 'agent=s' => 'define agent (optional)' ],
);

my ($opts, $usage) = describe_options($format, @opts);

use Devel::REPL;

my $repl = Devel::REPL->new;
$repl->load_plugin($_) for qw(History LexEnv HTTPDebug);
$repl->host($opts->{host}) if $opts->{host};
$repl->use_session if $opts->{use_session};

# safari4
my $ua = 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_1; ja-jp) AppleWebKit/531.9 (KHTML, like Gecko) Version/4.0.3 Safari/531.9';
$ua = $opts->{agent} if $opts->{agent};
$repl->ua->agent($ua);

$repl->run;
