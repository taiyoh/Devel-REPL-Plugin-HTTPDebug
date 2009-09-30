use strict;
use Test::More qw/no_plan/;

# ないよりはマシという程度のテスト…

use Devel::REPL;
BEGIN { use_ok 'Devel::REPL::Plugin::HTTPDebug' }

my $repl = Devel::REPL->new;
$repl->load_plugin($_) for qw(HTTPDebug);

my $cookie1 = $repl->_new_cookie;
isa_ok($cookie1, 'HTTP::Cookies');

my $dumper = $repl->_dumper;
ok(ref($dumper), 'CODE');

