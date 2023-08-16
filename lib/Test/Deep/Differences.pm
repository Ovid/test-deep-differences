package Test::Deep::Differences;

# ABSTRACT: Show diff of non-matching data structures when using Test:Deep

use v5.20.0;
use warnings;

use Carp 'croak';
use Test::Builder;
use Text::Diff 'diff';
use Test::Deep 'cmp_details';
use Data::Dumper;
use Data::Alias;
use Storable 3.08 'dclone';    # min version to clone regexes
use Scalar::Util 'blessed';

use parent 'Exporter';
our $VERSION = '0.01';

our @EXPORT    = qw( cmp_diff );    ## no critic(ProhibitAutomaticExportation)
our @EXPORT_OK = qw( get_diff );

sub cmp_diff ($$;$) {
    my ( $have, $want, $name ) = @_;
    $name //= 'Data Structures Match';
    my ( $ok, undef ) = cmp_details( $have, $want );

    my $tb = Test::Builder->new;
    $tb->ok( $ok, $name );

    if ( not $ok ) {

        # if we got to here, cmp_details failed, so we walk and resolve the
        # data structures
        my $diff = get_diff( $have, $want )
          or croak("PANIC! Test failed, but no differences found between data structures.");
        $tb->diag($diff);
    }

    return $ok;
}

sub get_diff ($$) {
    my ( $have, $want ) = @_;

    # deep clone these puppies to avoid mutating the originals. Also avoids
    # circular references
    foreach ( $have, $want ) {
        next unless ref $_;
        $_ = dclone($_);
    }

    _walk_and_mutate( $have, $want );

    return diff(
        _to_string($have),
        _to_string($want),
        {
            STYLE       => 'Table',
            FILENAME_A  => 'Got',
            FILENAME_B  => 'Expected',
            OFFSET_A    => 1,
            OFFSET_B    => 1,
            INDEX_LABEL => "Ln",
        }
    );
}

sub _walk_and_mutate {
    alias my ( $have, $want ) = @_;
    if ( _quick_check( $have, $want ) ) {
        return $want;
    }
    my $have_ref = ref $have;
    my $want_ref = ref $want;

    if ( $have_ref eq $want_ref ) {
        if ( $have_ref eq 'HASH' ) {
            _walk_hash( $have, $want );
        }
        elsif ( $have_ref eq 'ARRAY' ) {
            _walk_array( $have, $want );
        }
        elsif ( $have_ref eq 'SCALAR' ) {
            _walk_scalar( $have, $want );
        }
    }
    _resolved($want);
}

sub _quick_check {
    alias my ( $have, $want ) = @_;
    if ( blessed $want && $want->isa('Test::Deep::Ignore') ) {
        $want = $have;
        return 1;
    }
    my ( $ok, undef ) = cmp_details( $have, $want );
    if ($ok) {
        $want = $have;    # set the $want value to the $have value
        return 1;
    }
    return 0;
}

sub _walk_array {
    alias my ( $have, $want ) = @_;
    return if _quick_check( $have, $want );

    foreach my $i ( 0 .. $#$have ) {
        next unless exists $want->[$i];
        _walk_and_mutate( $have->[$i], $want->[$i] );
    }
}

sub _walk_hash {
    alias my ( $have, $want ) = @_;
    return if _quick_check( $have, $want );

    foreach ( sort keys $have->%* ) {
        next unless exists $want->{$_};
        _walk_and_mutate( $have->{$_}, $want->{$_} );
    }
}

sub _walk_scalar {
    alias my ( $have, $want ) = @_;

    if ( defined $have && defined $want && ref $have eq ref $want ) {
        if ( cmp_details( $have, $want ) ) {
            $want = $have;
        }
    }
    return $want;
}

sub _resolved {
    alias my ($value) = @_;
    if ( blessed $value ) {
        if ( $value->isa('Test::Deep::Regexp') ) {

            # XXX this is a hack because Test::Deep::Regexp doesn't have a
            # way to fetch the value directly, as far as I can tell
            my $value = $value->{val};
            return "re($value)";
        }
        elsif ( $value->isa('JSON::PP::Boolean') ) {
            return 0 + $value ? 'json_true' : 'json_false';
        }
        else {

            # do nothing because Test::Deep doesn't have instrospection (am I
            # wrong?)
        }
    }
    elsif ( ref $value eq 'ARRAY' ) {
        $_ = _resolved($_) foreach $value->@*;
    }
    elsif ( ref $value eq 'HASH' ) {
        $_ = _resolved($_) foreach values $value->%*;
    }
    return $value;
}

sub _to_string {
    my $data = shift;
    $data = _resolved($data);
    local $Data::Dumper::Indent    = 1;
    local $Data::Dumper::Sortkeys  = 1;
    local $Data::Dumper::Terse     = 1;
    local $Data::Dumper::Quotekeys = 0;
    local $Data::Dumper::Deepcopy  = 1;
    my $dump = Dumper($data);
    return \$dump;
}

1;

__END__

=head1 SYNOPSIS

    use Test::Deep;
    use Test::Deep::Differences qw(cmp_diff);

    my $have = { foo => 'bar' };
    my $want = { foo => 'baz' };

    cmp_diff( $have, $want, "data structures match" );

=head1 DESCRIPTION

This module provides C<cmp_diff()>, which compares two data structures just
like C<cmp_deeply()> from L<Test::Deep> does. However, if the test fails, it
provides a useful diff between the two data structures.

Note that if the C<cmp_diff()> call succeeds, it will be as fast as
C<cmp_deeply()>. If it fails, it will be slower because it needs to clone and
recursively walk the data structures.

=head1 FUNCTIONS

All functions are exported on demand.

=head2 C<cmp_diff( $got, $expected, $optional_name )>

    cmp_diff( $got, $expected, $name ); 

Compares two data structures and if they match, the test passes and the
function returns true.

If it fails, it returns false and will C<diag> a diff between the two data
structures, as explained below.

=head2 C<get_diff( $got, $expected )>

    diag get_diff( $got, $expected );

Returns a string containing a diff between the two data structures, as
explained below.

=head1 BEFORE AND AFTER

With L<Test::Deep>'s C<cmp_deeply>, we can take data like this:

    my $have = {
        foo   => 1,
        bar   => 'baz',
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

And compare it to a structure like this:

    my $want = {
        foo   => $int_re,
        bar   => $alpha_re,
        items => array_each(
            superhashof{
                name => $alpha_re,
            }
        ),
    };

However, what if C<$want> has an extra key of C<< extra => 'oops!' >>? You get
diagnostics like this:

    # Comparing hash keys of $data
    # Missing: 'extra'

It's not always immediately clear what that means, I<especially> if you have a
deeply nested data structure. L<Test::Differences> offers a wonderful
C<eq_or_diff> function that makes it trivial to find differences between two
data structures, but using it with the C<Test::Deep> data structure matchers
results in this:

    +----+-----------------------+----+-----------------------------------+
    | Elt|Got                    | Elt|Expected                           |
    +----+-----------------------+----+-----------------------------------+
    |   0|{                      |   0|{                                  |
    *   1|  bar => 'baz',        *   1|  bar => bless( {                  *
    *   2|  foo => 1,            *   2|    val => qr/^[a-z]+$/            *
    *   3|  items => [           *   3|  }, 'Test::Deep::Regexp' ),       *
    *   4|    {                  *   4|  extra => 'oops!',                *
    *   5|      name => 'club',  *   5|  foo => bless( {                  *
    *   6|      price => 100     *   6|    val => qr/^\d+$/               *
    *   7|    },                 *   7|  }, 'Test::Deep::Regexp' ),       *
    *   8|    {                  *   8|  items => bless( {                *
    *   9|      name => 'spade'  *   9|    val => bless( {                *
    *  10|    }                  *  10|      val => {                     *
    *  11|  ]                    *  11|        name => bless( {           *
    |    |                       *  12|          val => qr/^[a-z]+$/      *
    |    |                       *  13|        }, 'Test::Deep::Regexp' )  *
    |    |                       *  14|      }                            *
    |    |                       *  15|    }, 'Test::Deep::SuperHash' )   *
    |    |                       *  16|  }, 'Test::Deep::ArrayEach' )     *
    |  12|}                      |  17|}                                  |
    +----+-----------------------+----+-----------------------------------+

Even for this tiny example, it's very hard to read and see what the real failure is.
C<Test::Deep::Differences> makes it easy:

    +---+-----------------+---+---------------------+
    | Ln|Got              | Ln|Expected             |
    +---+-----------------+---+---------------------+
    |  1|{                |  1|{                    |
    |  2|  bar => 'baz',  |  2|  bar => 'baz',      |
    |   |                 *  3|  extra => 'oops!',  *
    |  3|  foo => 1,      |  4|  foo => 1,          |
    |  4|  items => [     |  5|  items => [         |
    |  5|    {            |  6|    {                |
    +---+-----------------+---+---------------------+

What we do is, if the data structures don't match, we recursively walk the
structures and anything in the C<Got> structure which matches the C<Expected>
structure is simply copied to it. This means the resulting diff only shows
items which do not match.

=head1 SEE ALSO

=over 4

=item * L<Test::Deep>

=item * L<Test::Differences>

=item * L<Test2::Tools::Compare>

=back

