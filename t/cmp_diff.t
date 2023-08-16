#!/usr/bin/env perl

use lib 'lib', 't/lib';
use v5.20.0;
use warnings;
use Test::Tester;
use Test::Builder;
use Test::Deep::Differences qw( cmp_diff get_diff );
use Test::Most;
use Test2::Plugin::UTF8;
use Test::Deep qw(
  cmp_details
  ignore
  array_each
  superhashof
  re
);

my $int_re   = re('^\d+$');
my $alpha_re = re('^[a-z]+$');

sub check {
    my ( $cmp_diff_args, $expected, $name ) = @_;
    my ( $have, $want, $explanation )       = @$cmp_diff_args;
    unless ( defined $name ) {
        my $ref = ref $have // 'scalar';
        $name = "cmp_diff check against $ref";
    }

    my $ok   = $expected->{ok};
    my $diag = ref $expected->{diag} ? delete $expected->{diag} : undef;
    my $show_diff = delete $expected->{show_diff};
    check_test( sub { cmp_diff( $have, $want, $explanation ) }, $expected, $name );

    if ( !$ok && $diag ) {
        my $diff = get_diff( $have, $want );
        like $diff, $diag, 'diag() should match our regex';
    }
    if ( $show_diff ) {
        my $diff = get_diff( $have, $want );
        explain $diff;
    }
}

subtest 'basic sanity test' => sub {
    my %have = (
        foo => 1,
        bar => 'baz',
        baz => [ 1, 2, 3 ],
        qux => { a => 1, b => 2, c => 3 },
    );

    my %want = %have;

    check(
        [ \%have, \%want, 'compare two matching hashrefs' ],
        { ok => 1 },
        'compare two matching hashrefs should succeed'
    );
    $want{baz} = ignore;
    check(
        [ \%have, \%want, 'ignored elements are ignored' ],
        { ok => 1 },
        'comparing with ignore() should succeed',
    );
};

subtest 'Various scalar tests' => sub {
    check(
        [ 1, $int_re, 'Compare a scalar to a regex' ],
        { ok => 1 },
        're() checks work as expected',
    );

    check(
        [ 1, $alpha_re, 'integers should not match alphas' ],
        {
            ok   => 0,
            diag => qr/1.*\[a-z\]\+/,
        }
    );
    my $foo = 'this';
    my $bar = $int_re;

    check(
        [ \$foo, $bar, 'a reference should not match an integer' ],
        { ok => 0 },
        'integers should not match references',
    );

    my $empty = '';

    check(
        [ \$empty, $bar ],
        { ok => 0 }
    );

    check(
        [ \$empty, re('no match') ],
        { ok => 0 }
    );
};

subtest 'arrayref tests' => sub {
    check(
        [ [ 1, 2, 3 ], [ 1, 2, 3 ], 'We can compare simple arrayrefs' ],
        { ok => 1 },
    );

    check(
        [ [ 1, 2, 3 ], [ 3, 2, 3 ], 'Mismatched arrays of scalars should fail' ],
        { ok => 0 },
    );

    check(
        [ [ 1, 2, [ 1, 2 ] ], [ 1, 2, [ 1, 2 ] ], 'matching nested arrays should succeed' ],
        { ok => 1 },
    );

    check(
        [ [ 1, 2, [ 1, 2 ] ], [ $int_re, 2, [ 1, 2 ] ], 'matching nested arrays should succeed, even with regexes' ],
        { ok => 1 },
    );

    check(
        [ [ 1, 2, [ 1, 2 ] ], [ 1, 2, [ qw/that this/, [ 3, 4 ] ] ], 'mismatching nested arrays should fail' ],
        { ok => 0 },
    );
};

subtest 'hashref tests' => sub {
    check(
        [ { foo => 1, bar => 2 }, { foo => 1, bar => 2 }, 'We can compare simple hashrefs' ],
        { ok => 1 },
    );

    check(
        [ { foo => 1, bar => 2 }, { foo => 1, bar => 3 }, 'Mismatched hashrefs should fail' ],
        { ok => 0 },
    );

    check(
        [ { foo => 1, bar => 2 }, { foo => 1, bar => { baz => 2 } }, 'Mismatched hashrefs should fail' ],
        { ok => 0 },
    );

    my %have = (
        foo  => 1,
        bar  => 'baz',
        baz  => [ 1, 2, 3 ],
        qux  => { a    => 1, b => 2, c => 3 },
        this => { that => { the => { other => 1 } } },
    );

    my %want = (
        foo => 1,
        bar => 'baz',
        baz => [ ignore(), 2, 3 ],
        qux => { a => 1, b => $alpha_re, c => 3 },
    );

    check(
        [ \%have, \%want, 'compare two mismatching deeply hashrefs should fail' ],
        { ok => 0, show_diff => 1 },
    );
};

subtest 'complex deep checks' => sub {
    my $have = {
        foo => 1,
        bar => 'baz',
        items => [
            {
                name => 'club',
                price => 100,
            },
            {
                name => 'spade',
            },
        ],
    };
    my $want = {
        foo => $int_re,
        bar => $alpha_re,
        items => array_each(
            superhashof{
                name => $alpha_re,
            }
        ),
    };
    check(
        [ $have, $want, 'complex deep check' ],
        { ok => 1},
    );

    $want->{extra} = 'oops!';
    check(
        [ $have, $want, 'complex deep check failure' ],
        { ok => 0, show_diff => 1 },
    );
};

subtest 'check ignore' => sub {
    check(
        [ [ 1, 3 ], [ ignore(), 2 ], 'compare two mismatching deeply hashrefs should fail' ],
        { ok => 0 },
    );

    check(
        [ [ 1, 3 ], ignore(), 'compare top-level item to ignore should succeed' ],
        { ok => 1 },
    );
};

done_testing;
