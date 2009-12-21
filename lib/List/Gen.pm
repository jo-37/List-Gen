package List::Gen;
    use warnings;
    use strict;
    use Carp;
    use Exporter     'import';
    use Scalar::Util 'reftype';
    use List::Util
    our @list_util   = qw/first max maxstr min minstr reduce shuffle sum/;
    our @EXPORT      = qw/mapn by every range gen genr cache apply zip min max reduce/;
    our @EXPORT_OK   = (our @list_util, @EXPORT, qw/d deref slide expand collect/);
    our %EXPORT_TAGS = (all => \@EXPORT_OK, base => \@EXPORT);
    our $VERSION     = '0.30';

=head1 NAME

List::Gen - provides functions for generating lists

=head1 VERSION

version 0.30

=head1 SYNOPSIS

this module provides higher order functions, iterators, and other utility functions for
working with lists. walk lists with any step size you want, create lazy ranges and arrays
with a map like syntax that generate values on demand. there are several other hopefully
useful functions, and all functions from List::Util are available.

    use List::Gen;

    print "@$_\n" for every 5 => 1 .. 15;
    # 1 2 3 4 5
    # 6 7 8 9 10
    # 11 12 13 14 15

    print mapn {"$_[0]: $_[1]\n"} 2 => %myhash;

    for (range 0.345, -21.5, -0.5) {
        # loops over 0.345, -0.155, -0.655, -1.155 ... -21.155
    }

=head1 EXPORT

    use List::Gen; # is the same as
    use List::Gen qw/mapn by every range gen genr cache apply zip min max reduce/;

    the following functions are available:
        mapn by every range gen genr cache apply zip min max reduce d deref slide expand collect
        from List::Util => first max maxstr min minstr reduce shuffle sum

=head1 FUNCTIONS

=over 8

=item C<mapn CODE NUM LIST>

this function works like the builtin C<map> but takes C<NUM> sized steps
over the list, rather than one element at a time.  inside the C<CODE> block,
the current slice is in C<@_> and C<$_> is set to C<$_[0]>.  slice elements
are aliases to the original list.  if C<mapn> is called in void context,
the C<CODE> block will be executed in void context for efficiency.

    print mapn {$_ % 2 ? "@_" : " [@_] "} 3 => 1..20;
    # 1 2 3 [4 5 6] 7 8 9 [10 11 12] 13 14 15 [16 17 18] 19 20

    print "student grades: \n";
    mapn {
        print shift, ": ", (reduce {$a + $b} @_)/@_, "\n";
    } 5 => qw {
        bob   90 80 65 85
        alice 75 95 70 100
        eve   80 90 80 75
    };

=cut
    sub mapn (&$@) {
        my ($sub, $n, @ret) = splice @_, 0, 2;
        croak '$_[1] must be >= 1' unless $n >= 1;
        return map $sub->($_) => @_ if $n == 1;
        my $ret = defined wantarray;
        while (@_) {
            local *_ = \$_[0];
            if ($ret) {push @ret =>
                  $sub->(splice @_, 0, $n)}
            else {$sub->(splice @_, 0, $n)}
        }
        @ret
    }


=item C<by NUM LIST>

=item C<every NUM LIST>

C<by> and C<every> are exactly the same, and allow you to add variable step size
to any other list control structure with whichever reads better to you.

    for (every 2 => @_) {do something with pairs in @$_}

    grep {do something with triples in @$_} by 3 => @list;

the functions generate an array of array references to C<NUM> sized slices of C<LIST>.
the elements in each slice are aliases to the original list.

in list context, returns a real array.
in scalar context, returns a generator.

    my @slices = every 2 => 1 .. 10;     # real array
    my $slices = every 2 => 1 .. 10;     # generator
    for (every 2 => 1 .. 10) { ... }     # real array
    for (@{every 2 => 1 .. 10}) { ... }  # generator

if you plan to use all the slices, the real array is better.
if you only need a few, the generator won't need to compute all of
the other slices.

    print "@$_\n" for every 3 => 1..9;
    # 1 2 3
    # 4 5 6
    # 7 8 9

    my @a = 1 .. 10;
    for (every 2 => @a) {
        @$_[0, 1] = @$_[1, 0]  # flip each pair
    }
    print "@a";
    # 2 1 4 3 6 5 8 7 10 9

    print "@$_\n" for grep {$$_[0] % 2} by 3 => 1 .. 9;
    # 1 2 3
    # 7 8 9

=cut


{package
    List::Gen::By;
    our @ISA = 'List::Gen::Tie';
    use Carp;
    sub TIEARRAY {
        my ($class, $n) = splice @_, 0, 2;
        my $size = @_ / $n;
        $size++ if $size > int $size;
        bless [$n, \@_, int $size] => $class
    }
    sub FETCHSIZE {$_[0][2]}
    sub FETCH {
        my ($n, $array) = @{ $_[0] };
        my $i = $n * $_[1];
        $i < @$array
            ? sub{\@_}->(@$array[$i .. $i + $n - 1])
            : croak "index $_[1] out of bounds [0 .. @{[int( $#$array / $n )]}]"
    }
}   sub by ($@) {
        croak '$_[0] must be >= 1' unless $_[0] >= 1;
        if (wantarray) {
            unshift @_, sub {\@_};
            goto &mapn
        }
        tie my @ret => 'List::Gen::By', @_;
        bless \@ret => 'List::Gen::Access';
    }
    sub every ($@); *every = \&by;



=item C<apply {CODE} LIST>

apply a function that modifies C<$_> to a copy of C<LIST> and return the copy

    print join ", " => apply {s/$/ one/} "this", "and that";
    > this one, and that one

=cut
    sub apply (&@) {
        my ($sub, @ret) = @_;
        $sub->() for @ret;
        wantarray ? @ret : pop @ret
    }


=item C<zip LIST_of_ARRAYREF>

interleaves the passed in lists to create a new list.
C<zip> continues until the end of the longest list,
C<undef> is returned for missing elements of shorter lists.

    %hash = zip [qw/a b c/], [1..3]; # same as
    %hash = (a => 1, b => 2, c => 3);

=cut
    sub zip {
        map {my $i = $_;
            map $$_[$i] => @_
        } 0 .. max map $#$_ => @_
    }


=back

=head2 generators

=over 8

in this document, generators will refer to tied arrays that generate their elements
on demand.  generators can be used as iterators in perl's list control structures
such as C< for map or grep >.  since generators are lazy, infinite generators
can be created. slow generators can also be cached

all generator functions, in scalar context, will return a reference to a tied array.
elements are created on demand as they are dereferenced.

    my $range = range 0, 1_000_000, 0.2; # will produce 0.0, 0.2, 0.4, ... 1000000.0

    say map sprintf('% -5s', $_)=> @$range[10 .. 15]; # calculates 5 values from $range

    my $gen = genr {$_**2} $range;  # attaches a generator function to a range

    say map sprintf('% -5s', $_)=> @$gen[10 .. 15];

    >>  2  2.2  2.4  2.6  2.8  3
    >>  4  4.84 5.76 6.76 7.84 9

the returned reference also has the following methods:

    $gen->()             # ->next() style iterator
    $gen->more           # test if $gen->() not past end
    $gen->reset          # reset $gen->() to 0
    $gen->reset(4)       # next $gen->() returns $$gen[4]
    $gen->(index)        # returns $$gen[index]
    $gen->get(index)     # same
    $gen->(4 .. 12)      # returns @$gen[4 .. 12]
    $gen->slice(4 .. 12) # same
    $gen->size           # returns scalar @$gen

direct access through dereferencing the array is usually clearer and faster.
the methods are only necessary when working with indicies outside of perl's
limit (0 .. 2**31 - 1). or when fetching a list return value (perl clamps
the return to a scalar with the array syntax).

some generator functions such as C<range>, in list context, return the actual tied array.
it only makes sense to use this syntax directly in list control structures, otherwise all
elements will be generated during the first copy. the real tied array also does not have
the above accessor methods.

=back

=cut

{package
    List::Gen::Tie;
    use Carp;
    no strict   'refs';
    no warnings 'uninitialized';
    for my $sub qw(TIEARRAY FETCH STORE FETCHSIZE STORESIZE CLEAR
                PUSH POP SHIFT UNSHIFT SPLICE UNTIE EXTEND) {
        *$sub = sub {croak "$sub @_[1 .. @_]not supported"}
    }
    sub DESTROY {}
}
{package
    List::Gen::Access;
    sub get  {tied(@{$_[0]})->FETCH(    $_[1])}
    sub size {tied(@{$_[0]})->FETCHSIZE($_[1])}
    sub slice {
        my $self = tied @{+shift};
        map $self->FETCH($_) => @_
    }
    my %index;
    use overload qw< fallback 1 &{} >=> sub {
        my $self = tied @{$_[0]};
        sub {@_ and return
                @_ == 1 ? $self->FETCH($_[0])
                        : map $self->FETCH($_) => @_;
            my $i = $index{$self}++;
            $i < $self->FETCHSIZE
               ? $self->FETCH($i)
               : undef
        }
    };
    sub reset {$index{tied @{$_[0]}} = $_[1] || 0}
    sub more {
        my $self = tied @{$_[0]};
        $index{$self} < $self->FETCHSIZE
    }
}


=over 8

=item C<range START STOP [STEP]>

returns a generator for values from C<START> to C<STOP> by C<STEP>, inclusive.

C<STEP> defaults to 1 but can be fractional and negative.
depending on your choice of C<STEP>, the last value returned may
not always be C<STOP>.

    range(0, 3, 0.4) returns (0, 0.4, 0.8, 1.2, 1.6, 2, 2.4, 2.8)

in list context, returns a generator array (see warning above).
in scalar context, returns a generator reference (usually what you want).
to obtain a real array, simply assign a range to an C<ARRAY> variable.

    print "$_ " for range 0, 1, 0.1;
    # 0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1

    print "$_ " for range 5, 0, -1;
    # 5 4 3 2 1 0

    my $nums = range 0, 1_000_000, 2;
    print "@$nums[10, 100, 1000]";
    # gets the tenth, hundredth, and thousandth numbers in the range
    # without calculating any other values

since the returned generator uses lazy evaluation, even gigantic ranges are
created instantly, and take little space.  however, when used directly in
a for loop, perl seems to preallocate space for the array anyway.
for reasonably sized ranges this is unnoticeable, but for huge ranges,
avoiding the problem is as simple as wrapping the range with C<@{ }>

    for (@{range 2**30, -2**30, -1.3}) {
        # the loop will start immediately without eating all
        # your memory, and hopefully you will exit the loop early
    }

=cut

{package
    List::Gen::Range;
    our @ISA = 'List::Gen::Tie';
    use Carp;
    sub TIEARRAY {
        my ($class, $low, $high, $step, $size) = (@_, 1);
        $size = $_ > 0 ? int : 0
            for 1 + ($step > 0 ? $high - $low : $low - $high) / abs $step;
        bless [$low, $step, $high < 9**9**9 ? $size : $high] => $class
    }
    sub FETCHSIZE {$_[0][2]}
    sub FETCH {
        my ($low, $step, $size) = @{ $_[0] };
        $_[1] < $size
            ? $low + $step * $_[1]
            : croak "range index $_[1] out of bounds [0 .. @{[$size - 1]}]"
    }
}   sub range {
             tie my @ret => 'List::Gen::Range', @_;
        wantarray ? @ret
           : bless \@ret => 'List::Gen::Access'
    }

=item C<gen CODE LIST>

=item C<genr CODE GENERATOR>

=item C<genr CODE START STOP [STEP]>

C<gen> is a lazy version of C<map> which attaches a code block to a list.
it returns a generator that will apply the code block on demand.
C<genr> works the same way, except it takes a generator, or suitable arguments
for C<range>.  with no arguments, C<genr> uses the range 0 .. infinity

note that there is overhead involved with lazy generation.  simply replacing
all calls to C<map> with C<gen> will almost certainly slow down your code.
use C<gen> in situations where the time / memory required to completely generate
the list is unacceptable.

the return semantics are the same as C<range>.

    my @result = map {slow_function($_)} @source; # slow function called @source times
    my $result = gen {slow_function($_)} @source; # slow function not called

    my ($x, $y) = @$result[4, 7]; # slow function called twice

    my $lazy = genr {slow_function($_)} 1, 1_000_000_000;

    print $$lazy[1_000_000]; # slow_function only called once

=cut

{package
    List::Gen::GenRange;
    our @ISA = 'List::Gen::Tie';
    sub TIEARRAY {
        my ($class, $code, $range) = @_;
        bless [$code, tied(@$range), $range->size] => $class
    }
    sub FETCH {return $_[0][0]()
                  for $_[0][1]->FETCH($_[1])}
    sub FETCHSIZE    {$_[0][2]}
}
{package
    List::Gen::Capture;
    our @ISA = 'List::Gen::Tie';
    sub TIEARRAY {bless $_[1] => $_[0]}
    sub FETCH {return $_[0][0]()
                  for $_[0][ $_[1] + 1 ]}
    sub FETCHSIZE {$#{$_[0]}}
}
    sub gen (&@) {
        tie my @ret => 'List::Gen::Capture', \@_;
        wantarray ? @ret : bless \@ret => 'List::Gen::Access'
    }
    sub genr (&;$$$) {
        my $code = shift;
        my $range = @_ > 1 ? &range
            : eval {tied(@{$_[0]})->isa('List::Gen::Tie')} ? shift #?
            : range 0, 9**9**9;
        tie my @ret => 'List::Gen::GenRange', $code, $range;
        wantarray ? @ret : bless \@ret => 'List::Gen::Access'
    }


=item C<cache GENERATOR>

=item C<cache CODE>

=item C<cache list => CODE>

C<cache> will return a cached version of the generator returned by functions in this package.
when passed a code reference, cache returns a memoized code ref (arguments joined with C<$;>).
when in 'list' mode, CODE is executed in list context, otherwise scalar context is used.

    my $gen = cache gen {slow($_)} @source;

    print $gen->[123]; # slow called once
    ...
    print @$gen[123, 456] # slow called once

=cut

{package
    List::Gen::Cache;
    our @ISA = 'List::Gen::Tie';
    sub TIEARRAY {
        bless [$_[1], {}, $_[1]->FETCHSIZE] => $_[0]
    }
    sub FETCH {
        my ($self, $cache) = @{$_[0]};
        exists $$cache{$_[1]}
             ? $$cache{$_[1]}
             :($$cache{$_[1]} = $self->FETCH($_[1]))
    }
    sub FETCHSIZE {$_[0][2]}
}

sub cache ($;$) {
    my $gen = pop;
    if (ref $gen eq 'List::Gen::Access') {
        tie my @ret => 'List::Gen::Cache', tied @$gen;
        bless \@ret => 'List::Gen::Access'
    } elsif (ref $gen eq 'CODE') {
        my %cache;
        "@_" eq 'list'
            ? sub {
                my $arg = join $; => @_;
                exists $cache{$arg}
                     ? @{$cache{$arg}}
                     : @{$cache{$arg} = sub {\@_}->($gen->(@_))}
            } : sub {
                my $arg = join $; => @_;
                exists $cache{$arg}
                     ? $cache{$arg}
                     :($cache{$arg} = $gen->(@_))
            }
    } else {croak 'cache takes coderef or tied array iterator'}
}

=item C<expand GENERATOR>

=item C<expand SCALE GENERATOR>

C<expand> scales a generator with with elements that return equal sized lists.
can be passed a list length, or will automatically determine it from the length
of the list returned by the first element of the generator.
C<expand> implicitly caches its returned generator.

    my $multigen = genr {$_, $_/2, $_/4} 1, 10;  # each element returns a list

    say join ' '=> $$multigen[0];  # 0.25        # only last element
    say join ' '=> $multigen->(0); # 1 0.5 0.25  # works
    say scalar @$multigen;         # 10
    say $multigen->size;           # 10

    my $expanded = expand $multigen;

    say join ' '=> @$expanded[0 .. 2];  # 1 0.5 0.25
    say join ' '=> $expanded->(0 .. 2); # 1 0.5 0.25
    say scalar @$expanded;              # 30
    say $expanded->size;                # 30

    my $expanded = expand genr {$_, $_/2, $_/4} 1, 10; # in one line

=cut

{package
    List::Gen::Expand;
    our @ISA = 'List::Gen::Tie';
    sub TIEARRAY {
        my ($class, $self, $scale) = @_;
        my %cache;
        if ($scale == -1) {
            $scale = my @first = $self->FETCH(0);
            @cache{0 .. $#first} = @first;
        }
        bless [$self, $scale, \%cache, $scale * $self->FETCHSIZE] => $class;
    }
    sub FETCH {
        my ($self, $scale, $list) = @{$_[0]};
        my $i = $_[1];
        exists $$list{$i}
             ? $$list{$i}
             :(@$list{$i .. $i + $scale - 1}
                    = $self->FETCH(int($i/$scale)))[0];
    }
    sub FETCHSIZE {$_[0][3]}
}
    sub expand ($;$ ) {
        my $gen = pop;
        my $scale = shift || -1;
        croak unless ref $gen eq 'List::Gen::Access';
        tie my @ret => 'List::Gen::Expand', tied @$gen, $scale;
        wantarray ? @ret : bless \@ret => 'List::Gen::Access'
    }


=item C<collect SCALE GENERATOR>

C<collect> is the inverse of C<expand>

=cut
    sub collect ($$) {
        my ($scale, $gen) = @_;
        croak '$_[0] >= 1' if $scale < 1;
        $scale == 1 ? $gen
            : genr {&$gen($_ .. $_ + $scale - 1)} 0, $gen->size - 1, $scale
    }


=item C<d>

=item C<d SCALAR>

=item C<deref>

=item C<deref SCALAR>

dereference a C<SCALAR>, C<ARRAY>, or C<HASH> reference.  any other value is returned unchanged

    print join " " => map deref, 1, [2, 3, 4], \5, {6 => 7}, 8, 9, 10;
    # prints 1 2 3 4 5 6 7 8 9 10

=cut
    sub d (;$) {
        my ($x)  = (@_, $_);
        return $x unless my $type = reftype $x;
        $type eq 'ARRAY'  ? @$x :
        $type eq 'HASH'   ? %$x :
        $type eq 'SCALAR' ? $$x : $x
    }
    sub deref (;$); *deref = \&d;


=item C<slide {CODE} WINDOW LIST>

slides a C<WINDOW> sized slice over C<LIST>,
calling C<CODE> for each slice and collecting the result

as the window reaches the end, the passed in slice will shrink

    print slide {"@_\n"} 2 => 1 .. 4
    # 1 2
    # 2 3
    # 3 4
    # 4         # only one element here

=cut
    sub slide (&$@) {
        my ($code, $n, @ret) = splice @_, 0, 2;

        push @ret, $code->( @_[ $_ .. $_ + $n ] )
            for 0 .. $#_ - --$n;

        push @ret, $code->( @_[ $_ .. $#_ ])
                for $#_ - $n + 1 .. $#_;
        @ret
    }

=back

=head1 AUTHOR

Eric Strom, C<< <ejstrom at gmail.com> >>

=head1 BUGS

please report any bugs or feature requests to C<bug-list-functional at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=List-Functional>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 COPYRIGHT & LICENSE

copyright 2009 Eric Strom.

this program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

see http://dev.perl.org/licenses/ for more information.

=cut

no warnings;
'List::Gen';
