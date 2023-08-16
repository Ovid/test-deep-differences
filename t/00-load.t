#!/usr/bin/env perl

use lib 'lib';
use Test::Most;

use Test::Deep::Differences ();

pass "We were able to lood our primary modules";

diag "Testing Test::Deep::Differences Test::Deep::Differences:VERSION, Perl $], $^X";

done_testing;
