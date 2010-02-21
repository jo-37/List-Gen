#!/usr/bin/perl
use strict;
use warnings;
use Scalar::Util 'weaken';
use Test::Simple tests => 46;
BEGIN {unshift @INC, '../lib'}
use List::Gen '*';

print "List::Gen $List::Gen::VERSION\n";

{no warnings 'redefine';
    my $ok = \&ok;
    *ok = sub ($;$) {push @_, shift; goto &$ok}
}

ok  ' mapn'
=>  join('' => mapn {$_ % 2 ? "[@_]" : "@_"} 3 => 1 .. 10) eq '[1 2 3]4 5 6[7 8 9]10';


ok  ' apply'
=>  join(' ' => apply {s/a/b/g} 'abcba', 'aok', 'nosubs') eq 'bbcbb bok nosubs';


ok  ' zip'
=>  join(' ' => zip ['a'..'c'], [1 .. 3]) eq "a 1 b 2 c 3";


my @a = 1 .. 10;
my $twos = by 2 => @a;

ok  ' by/every: scalar constructor'
=>  ref ($twos) =~ 'List::Gen::erator';

ok  ' by/every: scalar length'
=>  @$twos == 5;

ok  ' by/every: scalar bounds'
=>  ! defined eval {$$twos[5]}
&&  $@ =~ /index 5 out of bounds \[0 .. 4\]/;


ok  ' by/every: scalar slices'
=>  "@{$$twos[0]}" eq "1 2"
&&  "@{$$twos[1]}" eq "3 4"
&&  "@{$$twos[2]}" eq "5 6"
&&  "@{$$twos[3]}" eq "7 8"
&&  "@{$$twos[4]}" eq "9 10";


$$_[0] *= -1 for @$twos;

ok  ' by/every: scalar element aliasing'
=>  "@a" eq "-1 2 -3 4 -5 6 -7 8 -9 10";

@a = 1 .. 9;
my @threes = every 3 => @a;

ok  ' by/every: array length'
=>  @threes == 3;

ok  'by/every: array slices'
=>  "@{$threes[0]}" eq "1 2 3"
&&  "@{$threes[1]}" eq "4 5 6"
&&  "@{$threes[2]}" eq "7 8 9";

$$_[0] *= -1 for @threes;

ok  'by/every: array element aliasing'
=>  "@a" eq "-1 2 3 -4 5 6 -7 8 9";

ok  'range: simple'
=>  "@{range 0, 10}" eq "@{[0 .. 10]}";

ok  'range: empty'
=>  "@{range 11, 10}" eq "@{[11 .. 10]}";

ok  'range: short'
=>  "@{range 0, 0}" eq "@{[0 .. 0]}";

ok  'range: negative to positive'
=>  "@{range -10, 10}" eq "@{[-10 .. 10]}";

ok  'range: fractional step'
=>  "@{range 0, 5, 0.5}" eq "@{[map $_/2 => 0 .. 10]}";

ok  'range: negative step'
=>  "@{range 10, -5, -1}" eq "@{[reverse -5 .. 10]}";

ok  'range: length'
=>  $#{range 0, 10, 1/3} == 30;

ok  'range: bounds'
=>  ! defined eval {range(0, 5, 0.5)->[11]}
&&  $@ =~ /range index 11 out of bounds \[0 .. 10\]/;


my $gen = gen {$_**2} cap 0 .. 10;

ok  'gen {...} cap'
=>  $$gen[5] == 25;

$gen = gen {$_**3} 0, 10;

ok  'gen'
=>  $$gen[3] == 27;

ok  'gen @_ == 1'
=>  (gen {$_**2} 10)->[4] == 16;

{
    local $List::Gen::LIST = 1;
    my $sum = 0;
    $sum += $_ for gen {$_*2} 1, 10;
    ok  'gen direct for loop' => $sum == 110;
}

my $ta = range 0, 2**128, 0.5;

ok  'get > 2**31-1'
=>  $ta->get(2**128) == 2**127;

ok  'size > 2**31-1'
=>  $ta->size == 2**129;

$ta = range 0, 3;

my $acc;
ok  'iterator code deref'
=>  eval {while (defined(my $i = $ta->())) {
        $acc .= "$i "
    } 1 }
&&  $acc eq '0 1 2 3 ';

ok  'iterator reset'
=>  ! defined $ta->()
&&  do {$ta->reset;
    $ta->() == 0};


ok  'flip'
=>  "@{; flip gen {$_**2} 0, 10}" eq "@{; gen {$_**2} 10, 0, -1}";

my $count = 0;
my $cached = cache gen {$count++; $_**2} 0, 100;

ok  'cache: tied constructor'
=>  $count == 0
&&  $cached->isa('List::Gen::erator');

ok  'cache: tied test'
=>  $$cached[4] == 16
&&  $$cached[6] == 36
&&  $count == 2
&&  $$cached[4] == 16
&&  $$cached[6] == 36
&&  $count == 2
&&  "@$cached[4 .. 6]" eq '16 25 36'
&&  $count == 3;

$count = 0;
$cached = cache sub {$count++; $_[0]**3};

ok  'cache: coderef constructor'
=>  $count == 0
&&  ref $cached eq 'CODE';

ok  'cache: coderef test'
=>  $cached->(3) == 27
&&  $cached->(4) == 64
&&  $count == 2
&&  $cached->(3) == 27
&&  $cached->(4) == 64
&&  $count == 2;

$count = 0;
$cached = cache list => sub {$count++; $_[0] + $_[1], $_[0] * $_[1]};

ok  'cache: coderef list constructor'
=>  $count == 0
&&  ref $cached eq 'CODE';

ok  'cache: coderef list test'
=>  "@{[$cached->(1, 2)]}" eq '3 2'
&&  "@{[$cached->(2, 3)]}" eq '5 6'
&&  $count == 2
&&  "@{[$cached->(1, 2)]}" eq '3 2'
&&  "@{[$cached->(2, 3)]}" eq '5 6'
&&  $count == 2;


my $filter = filter {$_ % 2} 0, 100;

ok  'filter: simple'
=>  $#$filter == 100
&&  "@$filter[5 .. 10]" eq '11 13 15 17 19 21'
&&  $#$filter == 89;

$filter->apply;

ok  'filter: apply'
=>  $#$filter == 49
&&  $$filter[-1] == 99;

$filter = gen {"$_ "}
          filter {length > 1}
          filter {$_ % 5}
          filter {$_ % 2}
          filter {$_ % 3}
          gen {$_} 0, 100;
sub say {print @_,"\n"}

{local $" = '';
ok  'filter: stack'
=>  $filter->size == 101
&&  "@$filter[3 .. 6]" eq '19 23 29 31 '
&&  $filter->size == 76
&&  "@$filter[15 .. 20]" eq '67 71 73 77 79 83 '
&&  $filter->size == 38
&&  join(''=>$filter->all) eq '11 13 17 19 23 29 31 37 41 43 47 49 53 59 61 67 71 73 77 79 83 89 91 97 ';
}

my $multigen = gen {$_, $_/2, $_/4} 1, 10;

ok  'expand: pre'
=>  join(' '=> $$multigen[0]) eq '0.25'
&&  join(' '=> &$multigen(0)) eq '1 0.5 0.25'
&&  @$multigen == 10
&&  $multigen->size == 10;


my $expanded = expand $multigen;

ok  'expand: post'
=>  join(' '=> @$expanded[0 .. 2]) eq '1 0.5 0.25'
&&  join(' '=> &$expanded(0 .. 2)) eq '1 0.5 0.25'
&&  @$expanded == 30
&&  $expanded->size == 30;


my $fib; $fib = cache gen {$_ < 2  ? $_ : &$fib($_ - 1) + &$fib($_ - 2)};

ok  'generators: fibonacci'
=>  "@$fib[0 .. 15]" eq '0 1 1 2 3 5 8 13 21 34 55 89 144 233 377 610';

my $fac; $fac = cache gen {$_ < 2 or $_ * &$fac($_ - 1)};

ok  'generators: factorial'
=>  "@$fac[0 .. 10]" eq '1 1 2 6 24 120 720 5040 40320 362880 3628800';


my $genzip = genzip [range(0, 100)->filter(sub{$_ % 2})->all], range(-100, 9**9**9);

ok  'genzip'
=>  "@$genzip[5 .. 15]" eq '-98 7 -97 9 -96 11 -95 13 -94 15 -93';


ok  'deref'
=>  join(' ' => map d, 1, [2, 3], 4, {5, 6}, 7, \8, 9 ) eq '1 2 3 4 5 6 7 8 9';


ok  'slide'
=>  join(', ' => slide {"@_"} 2 => 1 .. 5) eq '1 2, 2 3, 3 4, 4 5, 5';

{no strict 'refs';
    my $pkg;
    my $get;
    {
        my $gen = gen {$_**2};
        $pkg = ref $gen;
        $get = $gen->can('get');
        ok  'curse: create'
        =>  ref $get eq 'CODE'
        &&  $get->(undef,5) == 25;
    }
    ok  'curse: destroy'
    =>  ! defined %{$pkg.'::'} # warns in 5.11.*
    &&  $get->(undef,5) == 25
    &&  do {weaken $get;
        ! eval {no warnings; say $get->(undef,3); 1}
    };
}
