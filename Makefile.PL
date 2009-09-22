use inc::Module::Install;
name 'Devel-REPL-Plugin-HTTPDebug';
all_from 'lib/Devel/REPL/Plugin/HTTPDebug.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
