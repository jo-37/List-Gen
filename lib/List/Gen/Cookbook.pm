package List::Gen::Cookbook;
    use warnings;
    use strict;

=head1 NAME

List::Gen::Cookbook - how to get the most out of L<List::Gen>

=head1 COOKBOOK

this document contains tips and tricks for working with and combining generators

=head2 iteration

given the generator C< my $gen = gen {2**$_} 100; > which computes the first
hundred powers of two, here are a few was to iterate over it (that all maintain
lazy evaluation):

    for (@$gen) {...}       # no need to reset generator between calls
    for my $p (@$gen) {...}
    ... for @$gen;

    while (<$gen>) {...}    # generator must be reset with `$gen->reset`
    ... while <$gen>        # between calls, also be sure to `local $_` before
                            # while loops that modify `$_`
    while (my $p = <$gen>) {...}
    while (defined(my $p = $gen->())) {...}
    while ($gen->more) {do something with $gen->next}

since all of these iteration examples remain lazy (only generating values on
demand), you can C< last > at any time to break out of the loop.

=head2 list creation

you can dereference finite length generators to pass all of their elements to
a function:

    say sum @$gen;

but it is usually faster to write it this way:

    say sum $gen->all;

generators interpolate in strings like normal arrays:

    say "@$gen[0 .. 10]";

do not call C<< ->all >> or use array dereferencing on infinite generators.  in
some places you may get an error, others, it will loop forever (and probably run
out of memory at some point).

=head2 inline generators

the generators without code blocks, C< range > and C< glob >, can be directly
dereferenced with C< @{...} >

    for (@{range 0.345, -21.5, -0.5}) {...}

    for (@{< 1 .. 10 by 2 >}) {...}

for those with code blocks, perl needs a little help to figure out whats going
on:

    for (@{ +gen {$_**2} 1, 10 }) {...}  # a '+' or ';' before it does the trick

=head2 glob syntax

if you export the C< glob > function from L<List::Gen>, that function and the
C<< <*.glob> >> operator will have one special case overridden.  if given an
argument that matches the following pattern:

   /^ ( .+ : )? number .. number ( (by | += | -= | [-+,]) number )?
                                 ( (if | when) .+ )? $/

then the arguments will be passed to C< range >, C< gen >, and C< filter > as
appropriate. any argument that doesn't match that pattern will be passed to
perl's builtin C< glob > function.  here are a few examples:

    <1 .. 10>                    ~~  range 1, 10
    <1 .. 10 by 2>               ~~  range 1, 10, 2
    <10 .. 1 -= 2>               ~~  range 10, 1, -2
    <x * x: 1 .. 10>             ~~  gen {$_ * $_} 1, 10
    <sin: 0 .. 3.14 += 0.01>     ~~  gen {sin} 0, 3.14, 0.01
    <1 .. 10 if x % 2>           ~~  filter {$_ % 2} 1, 10
    <sin: 0 .. 100 by 3 if /5/>  ~~  filter {/5/} gen {sin} 0, 100, 3

    for (@{< 0 .. 1_000_000_000 by 2 >}) { # starts instantly
        print "$_\n";
        last if $_ >= 100;        # exits the loop with only 51 values generated
    }

    my @files = <*.txt>;  # works as normal

=head2 normal generators

the C< range > and C< makegen > functions are the most primitive generators,
C< range > producing a lazy list, and C< makegen > storing an array.

you build upon these with the other generator functions/methods.  many
generator functions will pass their arguments along to C< range > or
C< makegen > as needed, so you rarely need to use them directly.

    gen {$_**2} 100             ~~  gen {$_**2} range 0, 100

    my @names = qw/bob alice eve/;
    gen {"hello $_!"} \@names   ~~  gen {"hello $_!"} makegen @names

those were two examples of C< gen > the generator equivalent of C< map > that
attaches a code block to a generator.

=head2 iterative generators

there is one other primitive generator type, the C< iterate > generator, which
is used when your algorithm is iterative in nature.  iterative generators come
in two flavors, single element per iteration, and multi element per iteration.

    my $fib = do {
        my ($an, $bn) = (0, 1);
        iterate {
            my $return = $an;
            ($an, $bn) = ($bn, $an + $bn);
            $return
        }
    };

    my $multi = do {
        my $var;
        iterate_multi {
            my @return = ...;
        }
    }

the iterative generators have some syntactic sugar you can use, in the form of
C< gather {...} > and C< take(...) >:

    my $fib = do {
        my ($x, $y) = (0, 1);
        gather {
            ($x, $y) = ($y, take($x) + $y)
        }
    };

don't confuse this implementation of C< gather/take > with the perl6
implementation, or the implementation of C< yield > in python.  since perl5 does
not have continuations, C< take > can't pause the execution of the gather block.
instead, it saves the value passed to it, and the gather block returns it when
the block ends.  you can use C< gather_multi > to C< take > multiple times.

all iterative generators implicitly cache their generated elements in an
internal array.  this allows random access within the generator.  unlike other
caching generators, you can not purge the iterator's cache (except by letting
all references to the generator fall out of scope, like a normal variable).
if you want an iterator that throws its values away, just write a subroutine:

    my $fib = do {
        my ($an, $bn) = (0, 1);
        sub {
            my $return = $an;
            ($an, $bn) = ($bn, $an + $bn);
            $return
        }
    };

    say $fib->() for 1 .. 10;


=head2 composite generators

there are many ways to modify generators.

    my $odd = filter {$_ % 2};
    my $squares_of_odd = gen {$_**2} $odd;

    my $less_than_1000 = While {$_ < 1000} $squares_of_odd;

    say for @$less_than_1000;

    my $this_is_same = While {$_ < 1000} gen {$_**2} filter {$_ % 2};

    say for @$this_is_same;

here is a sub that returns a generator producing the fibonacci sequence to a
given magnitude:

    sub fibonacci {
        my $limit   = 10**shift;
        my ($x, $y) = (0, 1);

        While {$_ < $limit} gather {
            ($x, $y) = ($y, take($x) + $y)
        }
    }

    say for @{fibonacci 15};


=head2 variable length generators

to implement C< grep > (as C< filter >) or C< while > (as C< While >) on a
generator means that the generator no longer knows its exact size at all times.
care has been taken to make sure that this doesn't bite you too much.

    my $pow = While {$_ < 20} gen {$_**2};

    say for @$pow;     # checks size on every iteration, works fine
    say while <$pow>;  # also works
    say $pow->all;     # ok too

each prints:

    0
    1
    4
    9
    16

but, if instead of C< say for @$pow > you had written C< map {say} @$pow >, perl
will try to expand C< @$pow > in list context, and it will not know when to
stop, since it only checks at the beginning.  the solution, in short, is to only
dereference variable length generators in slice C< @$gen[0 .. 10] > or iterator
C< ... for @$gen; > context, and never in list context.

in general, it makes more sense (and is faster) to build your constraint into
the calling code:

    my $pow = gen {$_**2};
    for (@$gen) {
        last if $_ > 20;
        say;
    }


=head2 recursive generators

the fibonacci sequence can be generated from the following definition:

    f[0] = 0;
    f[1] = 1;
    f[n] = f[n-1] + f[n-2];

here are a few ways to write that definition as a generator:

    my $fib; $fib = cache gen {$_ < 2  ? $_ : $$fib[$_ - 1] + $$fib[$_ - 2]};

    my $fib = gen {$_ < 2 ? $_ : self($_ - 1) + self($_ - 2)}
              ->cache
              ->recursive;

    my $fib; $fib = gen {$fib->($_ - 1) + $fib->($_ - 2)}
                  ->overlay( 0 => 0, 1 => 1 )
                  ->cache;

    my $fib; $fib = gen {$$fib[$_ - 1] + $$fib[$_ - 2]}->cache->overlay;
    @$fib[0, 1] = (0, 1);

bringing all those techniques together:

    my $fib = gen {self($_ - 1) + self($_ - 2)}
            ->overlay( 0 => 0, 1 => 1 )
            ->cache
            ->recursive;

the C< cache > function is used in each example because the recursive definition
of the fibonacci sequence would generate an exponentially increasing number of
calls to itself as the list grows longer.  C< cache > prevents any index from
being calculated more than once.


=head1 AUTHOR

Eric Strom, C<< <ejstrom at gmail.com> >>

=head1 COPYRIGHT & LICENSE

copyright 2009-2010 Eric Strom.

this program is free software; you can redistribute it and/or modify it under
the terms of either: the GNU General Public License as published by the Free
Software Foundation; or the Artistic License.

see http://dev.perl.org/licenses/ for more information.

=cut

__PACKAGE__ if 'first require';
