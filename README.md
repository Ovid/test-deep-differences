# NAME

Test::Deep::Differences - Show diff of non-matching data structures when using Test:Deep

# VERSION

version 0.01

# SYNOPSIS

```perl
use Test::Deep;
use Test::Deep::Differences qw(cmp_diff);

my $have = { foo => 'bar' };
my $want = { foo => 'baz' };

cmp_diff( $have, $want, "data structures match" );
```

# DESCRIPTION

This module provides `cmp_diff()`, which compares two data structures just
like `cmp_deeply()` from [Test::Deep](https://metacpan.org/pod/Test%3A%3ADeep) does. However, if the test fails, it
provides a useful diff between the two data structures.

Note that if the `cmp_diff()` call succeeds, it will be as fast as
`cmp_deeply()`. If it fails, it will be slower because it needs to clone and
recursively walk the data structures.

# FUNCTIONS

All functions are exported on demand.

## `cmp_diff( $got, $expected, $optional_name )`

```
cmp_diff( $got, $expected, $name ); 
```

Compares two data structures and if they match, the test passes and the
function returns true.

If it fails, it returns false and will `diag` a diff between the two data
structures, as explained below.

## `get_diff( $got, $expected )`

```
diag get_diff( $got, $expected );
```

Returns a string containing a diff between the two data structures, as
explained below.

# BEFORE AND AFTER

With `cmp_deeply`, we can take data like this:

```perl
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
```

And compare it to a structure like this:

```perl
my $want = {
    foo   => $int_re,
    bar   => $alpha_re,
    items => array_each(
        superhashof{
            name => $alpha_re,
        }
    ),
};
```

However, what if `$want` has an extra key of `extra => 'oops!'`? You get
diagnostics like this:

```
# Comparing hash keys of $data
# Missing: 'extra'
```

It's not always immediately clear what that means, _especially_ if you have a
deeply nested data structure. [Test::Differences](https://metacpan.org/pod/Test%3A%3ADifferences) offers a wonderful
`eq_or_diff` function that makes it trivial to find differences between two
data structures, but using it with the `Test::Deep` data structure matchers
results in this:

```perl
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
```

Even for this tiny example, it's very hard to read and see what the real failure is.
`Test::Deep::Differences` makes it easy:

```perl
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
```

What we do is, if the data structures don't match, we recursively walk the
structures and anything in the `Got` structure which matches the `Expected`
structure is simply copied to it. This means the resulting diff only shows
items which do not match.

# AUTHOR

Curtis "Ovid" Poe <curtis.poe@gmail.com>

# COPYRIGHT AND LICENSE

This software is Copyright (c) 2023 by Curtis "Ovid" Poe.

This is free software, licensed under:

```
The Artistic License 2.0 (GPL Compatible)
```
