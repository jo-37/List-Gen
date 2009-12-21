#!/usr/bin/perl
use strict;
use warnings;

use Test::Simple tests => 35;
BEGIN {unshift @INC, '../lib'}
use List::Gen ':all';

print "List::Gen version $List::Gen::VERSION\n";

ok  join('' => mapn {$_ % 2 ? "[@_]" : "@_"} 3 => 1 .. 10) eq '[1 2 3]4 5 6[7 8 9]10'
=>  ' mapn';


ok  join(' ' => apply {s/a/b/g} 'abcba', 'aok') eq 'bbcbb bok'
=>  ' apply';


ok  join(' ' => zip ['a'..'c'], [1 .. 3]) eq "a 1 b 2 c 3"
=>  ' zip';


my @a = 1 .. 10;
my $twos = by 2 => @a;

ok  ref tied @$twos eq 'List::Gen::By'
=>  ' by/every: scalar constructor';

ok  @$twos == 5
=>  ' by/every: scalar length';

ok  ! defined eval {$$twos[5]}
&&  $@ =~ /index 5 out of bounds \[0 .. 4\]/
=>  ' by/every: scalar bounds';

ok  "@{$$twos[0]}" eq "1 2"
&&  "@{$$twos[1]}" eq "3 4"
&&  "@{$$twos[2]}" eq "5 6"
&&  "@{$$twos[3]}" eq "7 8"
&&  "@{$$twos[4]}" eq "9 10"
=>  ' by/every: scalar slices';

$$_[0] *= -1 for @$twos;

ok  "@a" eq "-1 2 -3 4 -5 6 -7 8 -9 10"
=>  ' by/every: scalar element aliasing';

@a = 1 .. 9;
my @threes = by 3 => @a;

ok  @threes == 3
=>  ' by/every: array length';

ok  "@{$threes[0]}" eq "1 2 3"
&&  "@{$threes[1]}" eq "4 5 6"
&&  "@{$threes[2]}" eq "7 8 9"
=>  'by/every: array slices';

$$_[0] *= -1 for @threes;

ok  "@a" eq "-1 2 3 -4 5 6 -7 8 9"
=>  'by/every: array element aliasing';


ok  "@{range 0, 10}" eq "@{[0 .. 10]}"
=>  'range: simple';

ok  "@{range 11, 10}" eq "@{[11 .. 10]}"
=>  'range: empty';

ok  "@{range 0, 0}" eq "@{[0 .. 0]}"
=>  'range: short';

ok  "@{range -10, 10}" eq "@{[-10 .. 10]}"
=>  'range: negative to positive';

ok  "@{range 0, 5, 0.5}" eq "@{[map $_/2 => 0 .. 10]}"
=>  'range: fractional step';

ok  "@{range 10, -5, -1}" eq "@{[reverse -5 .. 10]}"
=>  'range: negative step';

ok  $#{range 0, 10, 1/3} == 30
=>  'range: length';

ok  ! defined eval {range(0, 5, 0.5)->[11]}
&&  $@ =~ /range index 11 out of bounds \[0 .. 10\]/
=>  'range: bounds';


my $gen = gen {$_**2} 0 .. 10;

ok  $$gen[5] == 25
=>  'gen';

$gen = genr {$_**3} 0, 10;

ok  $$gen[3] == 27
=>  'genr';

my $ta = range 0, 2**128, 0.5;


ok  $ta->get(2**128) == 2**127
=>  'get > 2**31-1';

ok  $ta->size == 2**129
=>  'size > 2**31-1';

$ta = range 0, 3;

my $acc;
ok  eval {while (defined(my $i = $ta->())) {
		$acc .= "$i "
	} 1 }
&&  $acc eq '0 1 2 3 '
=>  'iterator code deref';

ok  ! defined $ta->()
&&  do {$ta->reset;
	$ta->() == 0}
=>  'iterator reset';

my $count = 0;
my $cached = cache genr {$count++; $_**2} 0, 100;

ok  $count == 0
&&  ref $cached eq 'List::Gen::Access'
=>  'cache: tied constructor';

ok  $$cached[4] == 16
&&  $$cached[6] == 36
&&  $count == 2
&&  $$cached[4] == 16
&&  $$cached[6] == 36
&&  $count == 2
&&  "@$cached[4 .. 6]" eq '16 25 36'
&&  $count == 3
=>  'cache: tied test';

$count = 0;
$cached = cache sub {$count++; $_[0]**3};

ok  $count == 0
&&  ref $cached eq 'CODE'
=>  'cache: coderef constructor';

ok  $cached->(3) == 27
&&  $cached->(4) == 64
&&  $count == 2
&&  $cached->(3) == 27
&&  $cached->(4) == 64
&&  $count == 2
=>  'cache: coderef test';

$count = 0;
$cached = cache list => sub {$count++; $_[0] + $_[1], $_[0] * $_[1]};

ok  $count == 0
&&  ref $cached eq 'CODE'
=>  'cache: coderef list constructor';

ok  "@{[$cached->(1, 2)]}" eq '3 2'
&&  "@{[$cached->(2, 3)]}" eq '5 6'
&&  $count == 2
&&  "@{[$cached->(1, 2)]}" eq '3 2'
&&  "@{[$cached->(2, 3)]}" eq '5 6'
&&  $count == 2
=>  'cache: coderef list test';

my $multigen = genr {$_, $_/2, $_/4} 1, 10;

ok	join(' '=> $$multigen[0]) eq '0.25'
&&  join(' '=> &$multigen(0)) eq '1 0.5 0.25'
&&  @$multigen == 10
&&  $multigen->size == 10
=>  'expand: pre';

my $expanded = expand $multigen;

ok  join(' '=> @$expanded[0 .. 2]) eq '1 0.5 0.25'
&&  join(' '=> &$expanded(0 .. 2)) eq '1 0.5 0.25'
&&  @$expanded == 30
&&  $expanded->size == 30
=>  'expand: post';


ok  join(' ' => map d, 1, [2, 3], 4, {5, 6}, 7, \8, 9 ) eq '1 2 3 4 5 6 7 8 9'
=>  'deref';


ok  join(', ' => slide {"@_"} 2 => 1 .. 5) eq '1 2, 2 3, 3 4, 4 5, 5'
=>  'slide';
