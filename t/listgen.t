#!/usr/bin/perl
use strict;
use warnings;
use Scalar::Util 'weaken';
use Test::More tests => 109;
BEGIN {unshift @INC, '../lib'}
use List::Gen '*';

diag "List::Gen $List::Gen::VERSION";

sub t {
    push @_, shift;
    goto &{Test::More->can(shift)}
}

t ' mapn',
    is => join('' => mapn {$_ % 2 ? "[@_]" : "@_"} 3 => 1 .. 10), '[1 2 3]4 5 6[7 8 9]10';


t ' apply',
    is => join(' ' => apply {s/a/b/g} 'abcba', 'aok', 'nosubs'), 'bbcbb bok nosubs';


t ' zip',
    is => join(' ' => zip ['a'..'c'], [1 .. 3]), "a 1 b 2 c 3";


my @a = 1 .. 10;
my $twos = by 2 => @a;

t ' by/every: scalar constructor',
    like => ref ($twos), qr/List::Gen::erator/;

t ' by/every: scalar length',
    is => scalar @$twos, 5;

t ' by/every: scalar bounds',
    ok =>  ! defined eval {$$twos[5]}
       &&  $@ =~ /index 5 out of bounds \[0 .. 4\]/;


t ' by/every: scalar slices',
    ok =>  "@{$$twos[0]}" eq "1 2"
       &&  "@{$$twos[1]}" eq "3 4"
       &&  "@{$$twos[2]}" eq "5 6"
       &&  "@{$$twos[3]}" eq "7 8"
       &&  "@{$$twos[4]}" eq "9 10";


$$_[0] *= -1 for @$twos;

t ' by/every: scalar element aliasing',
   is  =>  "@a", "-1 2 -3 4 -5 6 -7 8 -9 10";

@a = 1 .. 9;
my @threes = every 3 => @a;

t ' by/every: array length',
   ok =>  @threes == 3;

t 'by/every: array slices',
   ok => "@{$threes[0]}" eq "1 2 3"
      && "@{$threes[1]}" eq "4 5 6"
      && "@{$threes[2]}" eq "7 8 9";

$$_[0] *= -1 for @threes;

t 'by/every: array element aliasing',
   is => "@a", "-1 2 3 -4 5 6 -7 8 9";

t 'range: simple',
   is => "@{range 0, 10}", "@{[0 .. 10]}";

t 'range: empty',
   is => "@{range 11, 10}", "@{[11 .. 10]}";

t 'range: short',
   is => "@{range 0, 0}", "@{[0 .. 0]}";

t 'range: negative to positive',
   is => "@{range -10, 10}", "@{[-10 .. 10]}";

t 'range: fractional step',
   is => "@{range 0, 5, 0.5}", "@{[map $_/2 => 0 .. 10]}";

t 'range: negative step',
   is => "@{range 10, -5, -1}", "@{[reverse -5 .. 10]}";

t 'range: length',
   ok => $#{range 0, 10, 1/3} == 30;

t 'range: bounds',
   ok => ! defined eval {range(0, 5, 0.5)->[11]}
       && $@ =~ /range index 11 out of bounds \[0 .. 10\]/;


{
    my $infinite = range 0, 9**9**9;
    t 'range: scalar @$infinite',
       cmp_ok => scalar @$infinite, '==', 2**31-1;

    t 'range: $infinite->size',
       cmp_ok => $infinite->size, '==', 9**9**9;

    my @list;
    for (@$infinite) {
        last if $_ > 100;
        push @list, $_
    }
    t 'range: for (@$infinite) {...}',
       is_deeply => \@list, [0 .. 100];

}

my $gen = gen {$_**2} cap 0 .. 10;

t 'gen {...} cap',
   is => $$gen[5], 25;

$gen = gen {$_**3} 0, 10;

t 'gen',
   is => $$gen[3], 27;

t 'gen @_ == 1',
   is => (gen {$_**2} 10)->[4], 16;

{
    local $List::Gen::LIST = 1;
    my $sum = 0;
    $sum += $_ for gen {$_*2} 1, 10;

    t 'gen direct for loop',
       is => $sum, 110;
}

my $ta = range 0, 2**128, 0.5;

t 'get > 2**31-1',
   cmp_ok => $ta->get(2**128), '==', 2**127;

t 'size > 2**31-1',
   cmp_ok => $ta->size, '==', 2**129;

$ta = range 0, 3;

my $acc;
t 'iterator code deref',
   ok => eval {while (defined(my $i = $ta->())) {
             $acc .= "$i "
         } 1 }
      && $acc eq '0 1 2 3 ';

t 'iterator reset',
   ok => ! defined $ta->()
      && do {$ta->reset;
         $ta->() == 0};

{

my $gen = gen {$_**2} 0, 10;

local $_;
my @list;
push @list, $_ while <$gen>;
t 'handle, while',
    is => "@list", '0 1 4 9 16 25 36 49 64 81 100';

$gen->reset;

my $str;
$str .= <$gen>.' ' while $gen->more;

t 'handle, scalar',
    is => $str, '0 1 4 9 16 25 36 49 64 81 100 ';

$gen->index = 6;

@list = ();
while (my $x = <$gen>) {
    push @list, $x;
}
t 'handle, while my',
    is => "@list", "36 49 64 81 100";

}


t 'glob: <1 .. 10>',
   is_deeply => <1 .. 10>, range 1, 10;

t 'glob: <1 .. 10 by 2>',
   is_deeply => <1 .. 10 by 2>, range 1, 10, 2;

t 'glob: <10 .. 1 -= 2>',
   is_deeply => <10 .. 1 -= 2>, range 10, 1, -2;

t 'glob: <x * x: 1 .. 10>',
   is_deeply => <x * x: 1 .. 10>, gen {$_ * $_} 1, 10;

t 'glob: <sin: 0 .. 3.14 += 0.01>',
   is_deeply => <sin: 0 .. 3.14 += 0.01>, gen {sin} 0, 3.14, 0.01;

t 'glob: <0 .. 10 if x % 2>',
   is_deeply => <0 .. 10 if x % 2>, filter {$_ % 2} 0, 10;

t 'glob: <0 .. 100 by 3 if /5/>',
   is_deeply => <0 .. 100 by 3 if /5/>, filter {/5/} 0, 100, 3;

t 'glob: <sin: 0 .. 100 by 3 if /5/>',
   is_deeply => <sin: 0 .. 100 by 3 if /5/>, filter {/5/} gen {sin} 0, 100, 3;

t 'glob: early exit',
   do {
       my @vals;
       for (@{< 0 .. 1_000_000_000 by 2 >}) {
           push @vals, $_;
            last if $_ >= 100;
       }
       is_deeply => \@vals, [map $_*2 => 0 .. 50]
   };

t 'glob: <*.t>',
   is_deeply => [sort <*.t>], do {
       opendir my $dir, '.';
       [sort grep /\.t$/, readdir $dir]
   };

{
    my $fib = do {
        my ($an, $bn) = (0, 1);
        iterate {
            my $ret = $an;
            ($an, $bn) = ($bn, $an + $bn);
            $ret;
        }
    };

    t 'iterate',
       is => "@$fib[0 .. 15]\n@$fib[0 .. 20]\n@$fib[5 .. 10]",
             "0 1 1 2 3 5 8 13 21 34 55 89 144 233 377 610\n".
             "0 1 1 2 3 5 8 13 21 34 55 89 144 233 377 610 987 1597 2584 4181 6765\n".
             "5 8 13 21 34 55";
}
{
    my $fib = do {
        my ($x, $y) = (0, 1);
        gather {
            ($x, $y) = ($y, take($x) + $y)
        }
    };

    t 'gather / take',
       is => "@$fib[0 .. 15]\n@$fib[0 .. 20]\n@$fib[5 .. 10]",
             "0 1 1 2 3 5 8 13 21 34 55 89 144 233 377 610\n".
             "0 1 1 2 3 5 8 13 21 34 55 89 144 233 377 610 987 1597 2584 4181 6765\n".
             "5 8 13 21 34 55";

    my $nest = gather {take(sum @{+gather {take($_*$_)} $_ + 1})};

    t 'gather / take, nest',
        is_deeply => "@$nest[0 .. 10]",
        join ' ' => map {sum map {$_*$_} 0 .. $_} 0 .. 10;
}

{
    my $iter = 0;
    my $gm = do {
        my $i = 0;
        gather_multi {
            $iter++;
            take($i++), take($i++) for 1 .. 5
        }
    };
    t 'gather_multi',
        is => "@$gm[0 .. 5]", '0 1 2 3 4 5';

    t 'gather_multi, iter',
        is => $iter, 1;

    t 'gather_multi, inside',
        is => "@$gm[3 .. 7]", '3 4 5 6 7';

    t 'gather_multi, iter unchanged',
        is => $iter, 1;

    t 'gather_multi, more',
        is => "@$gm[8 .. 14]", '8 9 10 11 12 13 14';

    t 'gather_multi, iter++',
        is => $iter, 2;
}

{
my $seq = sequence <1 .. 5>, <20 .. 30>, <6 .. 9>, <10 .. 0 -= 2>;

t 'sequence',
    is => "@$seq", '1 2 3 4 5 20 21 22 23 24 25 26 27 28 29 30 6 7 8 9 10 8 6 4 2 0';

my $val = eval {$$seq[100]};
t 'sequence bounds',
    like => $@, qr/index 100 out of bounds/;

$seq = sequence <1 .. 10 if x % 2>, <20 .. 30>, <40 .. 60 if not x % 3>;

t 'sequence mutable',
    is => join( ' ' => $seq->all ), '1 3 5 7 9 20 21 22 23 24 25 26 27 28 29 30 42 45 48 51 54 57 60';
}

t 'flip',
   is => "@{; flip gen {$_**2} 0, 10}", "@{; gen {$_**2} 10, 0, -1}";

my $count = 0;
my $cached = cache gen {$count++; $_**2} 0, 100;

t 'cache: tied constructor',
   ok => $count == 0
      && $cached->isa('List::Gen::erator');

t 'cache: tied test',
   ok => $$cached[4] == 16
      && $$cached[6] == 36
      && $count == 2
      && $$cached[4] == 16
      && $$cached[6] == 36
      && $count == 2
      && "@$cached[4 .. 6]" eq '16 25 36'
      && $count == 3;

$count = 0;
$cached = cache sub {$count++; $_[0]**3};

t 'cache: coderef constructor',
   ok => $count == 0
      && ref $cached eq 'CODE';

t 'cache: coderef test',
   ok => $cached->(3) == 27
      && $cached->(4) == 64
      && $count == 2
      && $cached->(3) == 27
      && $cached->(4) == 64
      && $count == 2;

$count = 0;
$cached = cache list => sub {$count++; $_[0] + $_[1], $_[0] * $_[1]};

t 'cache: coderef list constructor',
   ok => $count == 0
      && ref $cached eq 'CODE';

t 'cache: coderef list test',
   ok => "@{[$cached->(1, 2)]}" eq '3 2'
      && "@{[$cached->(2, 3)]}" eq '5 6'
      && $count == 2
      && "@{[$cached->(1, 2)]}" eq '3 2'
      && "@{[$cached->(2, 3)]}" eq '5 6'
      && $count == 2;


my $filter = filter {$_ % 2} 0, 100;

t 'filter: simple',
   ok => $#$filter == 100
      && "@$filter[5 .. 10]" eq '11 13 15 17 19 21'
      && $#$filter == 88;

$filter->apply;

t 'filter: apply',
   ok => $#$filter == 49
      && $$filter[-1] == 99;

$filter = gen {"$_ "}
       filter {length > 1}
       filter {$_ % 5}
       filter {$_ % 2}
       filter {$_ % 3}
          gen {$_} 0 => 100;

{local $" = '';
t 'filter: stack',
   ok => $filter->size == 101
      && "@$filter[3 .. 6]" eq '19 23 29 31 '
      && $filter->size == 67
      && "@$filter[15 .. 20]" eq '67 71 73 77 79 83 '
      && $filter->size == 28
      && join(''=>$filter->all) eq '11 13 17 19 23 29 31 37 41 43 47 49 53 59 61 67 71 73 77 79 83 89 91 97 ';
}

{
    my $filtered = filter {/5/} 0, 104;
    my $ok = 1;
    for (@$filtered) {
        $ok = 0 if not defined
    }
    t 'filter: foreach',
        ok => $ok;
}

my $multigen = gen {$_, $_/2, $_/4} 1, 10;

t 'expand: pre',
   ok => join(' '=> $$multigen[0]) eq '0.25'
      && join(' '=> &$multigen(0)) eq '1 0.5 0.25'
      && @$multigen == 10
      && $multigen->size == 10;


my $expanded = expand $multigen;

t 'expand: post',
   ok => join(' '=> @$expanded[0 .. 2]) eq '1 0.5 0.25'
      && join(' '=> &$expanded(0 .. 2)) eq '1 0.5 0.25'
      && @$expanded == 30
      && $expanded->size == 30;


my $fib; $fib = cache gen {$_ < 2  ? $_ : $$fib[$_ - 1] + $$fib[$_ - 2]};

t 'generators: fibonacci',
   is => "@$fib[0 .. 15]", '0 1 1 2 3 5 8 13 21 34 55 89 144 233 377 610';

my $fac; $fac = cache gen {$_ < 2 or $_ * $$fac[$_ - 1]};

t 'generators: factorial',
   is => "@$fac[0 .. 10]", '1 1 2 6 24 120 720 5040 40320 362880 3628800';


my $genzip = genzip [range(0, 100)->filter(sub{$_ % 2})->all], range(-100, 9**9**9);

t 'genzip',
   is => "@$genzip[5 .. 15]", '-98 7 -97 9 -96 11 -95 13 -94 15 -93';

my $overlay = overlay gen {$_ ** 2};

t 'overlay',
   ok => "@$overlay[1 .. 4]" eq '1 4 9 16'
      && eval {$$overlay[2] = 1}
      && "@$overlay[1 .. 4]" eq '1 1 9 16';

{
my $ofib; $ofib = overlay cache gen {$$ofib[$_ - 1] + $$ofib[$_ - 2]};
@$ofib[0, 1] = (0, 1);

t 'overlay: fibonacci 1',
   is => "@$ofib[0 .. 15]", '0 1 1 2 3 5 8 13 21 34 55 89 144 233 377 610';
}

{
my $ofib; $ofib = gen {$$ofib[$_ - 1] + $$ofib[$_ - 2]}
                ->cache
                ->overlay( 0 => 0, 1 => 1 );

t 'overlay: fibonacci 2',
   is => "@$ofib[0 .. 15]", '0 1 1 2 3 5 8 13 21 34 55 89 144 233 377 610';
}

t 'recursive',
   is => join(' ', gen {self($_ - 1) + self($_ - 2)}
                 ->overlay( 0 => 0, 1 => 1 )
                 ->cache
                 ->recursive
                 ->slice(0 .. 15)
        ), '0 1 1 2 3 5 8 13 21 34 55 89 144 233 377 610';


eval {
    my $cube = While {$_ < 30} gen {$_**3};

    t 'while',
       is_deeply => [$cube->all], [qw/0 1 8 27/];

    my $gen = do {
        my ($a, $b) = (0, 1);
        gather {
            ($a, $b) = ($b, take($a) + $b)
        }
    }->while(sub {$_ < 700});

    t 'while, iterative',
       is_deeply => do {
            my @fib;
            push @fib, $_ for @$gen;
            \@fib
       }, [qw/0 1 1 2 3 5 8 13 21 34 55 89 144 233 377 610/];

    my $while = While {$_ < 10} gen {$_};

    t 'while, initial over',
        is => $$while[20], undef;

    t 'while, second over',
        ok => !eval {my $x = $$while[20]; 1};

    t 'while, second over msg',
       like => $@, qr/past end/;

    t 'while, under after over',
        is => $$while[7], 7;

    t 'while, over-- after over',
        is => $$while[19], undef;

    my $deref = While {$_ < 10} gen {$_};

    t 'while, array deref outside foreach',
        ok => !eval {my $x = join ' ' => @$deref; 1};

    t 'while, array deref outside foreach msg',
        like => $@, qr/past end/;

    t 'while, second array deref',
        is => "@$deref", '0 1 2 3 4 5 6 7 8 9';

} or diag $@;

{
    my $pow = Until {$_ > 20 } gen {$_**2};

    t 'until',
       is_deeply => [$pow->all], [qw/0 1 4 9 16/];

    my $gen = do {
        my ($a, $b) = (0, 1);
        gather {
            ($a, $b) = ($b, take($a) + $b)
        }
    }->until(sub {$_ > 700});

    t 'until, iterative',
       is_deeply => do {
            my @fib;
            push @fib, $_ for @$gen;
            \@fib
       }, [qw/0 1 1 2 3 5 8 13 21 34 55 89 144 233 377 610/];
}

{local $" = '';
    t 'mapkey',
       is => join( ' ' =>
                mapkey {
                    mapkey {
                        mapkey {
                            $_{sigil}.$_{name}.$_{number}
                        } number => 1 .. 3
                    } name => qw/a b c/
                } sigil => qw/$ @ %/
            ), '$a1 $a2 $a3 $b1 $b2 $b3 $c1 $c2 $c3 @a1 @a2 @a3 @b1 @b2 @b3 @c1 @c2 @c3 %a1 %a2 %a3 %b1 %b2 %b3 %c1 %c2 %c3';

    t 'cartesian 1',
      is => join( ' ' => @{;cartesian {"@_"} [qw/$ @ %/], [qw/a b/], [1 .. 3]}),
            '$a1 $a2 $a3 $b1 $b2 $b3 @a1 @a2 @a3 @b1 @b2 @b3 %a1 %a2 %a3 %b1 %b2 %b3';

    t 'cartesian 2',
       is => join(' ' => (cartesian {"@_"} map [split //], qw(abc de fghi))->all),
             join(' ' => <{a,b,c}{d,e}{f,g,h,i}>);

    my $num = 3;
    map {
        my @groups = split /\./;
        t "cartesian ".$num++,
           is => join(' ' => (cartesian {"@_"} map [split //], @groups)->all),
                 join(' ' => eval '<{'.(join '}{' => map {join ',' => split //} @groups ).'}>');
    } qw(
        a.bc.def..
        ab.c.def
        abc.de.f..
        abc.d.ef
        asdf.wqwer.ty.hfs.EQN3PD
        ...qwer.asdfzxcv...
        1234567890.abcdefghijklmnopqrstuvwxyz
        a.bcdef.hijk.lmnop.qrstuvwxyz
    )
}

t 'deref',
   is => join(' ' => map {d} 1, [2, 3], 4, {5, 6}, 7, \8, 9 ), '1 2 3 4 5 6 7 8 9';

t 'slide',
   ok => join(', ' => slide {"@_"} 2 => 1 .. 5) eq '1 2, 2 3, 3 4, 4 5, 5';

{no strict 'refs';
    my $pkg;
    my $get;
    {
        my $gen = range 0, 10;
        $pkg = ref $gen;
        $get = $gen->can('get');
        t 'curse: create',
           ok => ref $get eq 'CODE'
              && $get->(undef,5) == 5;
    }
    t 'curse: destroy',
       ok => ! %{$pkg.'::'}
          && $get->(undef,5) == 5
          && do {weaken $get;
           ! eval {no warnings; say $get->(undef,3); 1}
    };
}
{no strict 'refs';
    my ($pkg_gen, $pkg_range);
    my ($get_gen, $get_range);
    {
        my $range = range 0, 9**9**9;
        my $gen = gen {$_**2} $range;
        $pkg_gen = ref $gen;
        $pkg_range = ref $range;
        $get_gen = $gen->can('get');
        $get_range = $range->can('get');
    }

    t 'curse: pkg gen',    ok => ! %{$pkg_gen.'::'};
    t 'curse: pkg range',  ok => ! %{$pkg_range.'::'};

    t 'curse: get gen',    is => $get_gen->(undef,5), 25;
    t 'curse: get range',  is => $get_range->(undef,5), 5;

    weaken $get_gen;
    t 'curse: destroy gen', ok =>! eval {no warnings;  $get_gen->(undef,3); 1};
    t 'curse: keep range',  ok =>  eval {no warnings;  $get_range->(undef,3); 1};

    weaken $get_range;
    t 'curse: destroy range', ok =>! eval {no warnings;  $get_range->(undef,3); 1};
}
