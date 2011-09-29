#!/usr/bin/perl
use strict;
use warnings;

BEGIN {
    eval q{
        use 5.010;
    1} or eval q{
        use Test::More skip_all => 'List::Gen::Perl6 requires Perl 5.10+';
        exit;
    }
}

use Test::More tests => 17;
use lib qw(../lib lib t/lib);
use List::Gen 0;
use List::Gen::Perl6;
use List::Gen::Testing;

t 'hyper +',
	is => (<0...> <<+>> [1,2,3])->take(10)->str, '1 2 3 1 2 3 1 2 3 1';

t 'hyper R,',
	is => (<1..> >>R,>> 10)->take(10)->str, '10 1 10 2 10 3 10 4 10 5 10 6 10 7 10 8 10 9 10 10';

t 'triangle reduction as code',
	is => [..*]->(<2...>)->take(10)->str, '2 4 8 16 32 64 128 256 512 1024';

t 'triangle reduction as op',
	is => ([..*] <2...>)->take(10)->str, '2 4 8 16 32 64 128 256 512 1024';

t 'triangle reduction as code 2',
	is => [\*]->(<2...>)->take(10)->str, '2 4 8 16 32 64 128 256 512 1024';

t 'triangle reduction as op 2',
	is => ([\*] <2...>)->take(10)->str, '2 4 8 16 32 64 128 256 512 1024';

t 'reduction as code',
	is => [+]->(1..10), 55;

t 'reduction as op list',
	is => ([+] 1..10), 55;

t 'reduction as op gen',
	is => ([+] <1..10>), 55;

t 'hyper inf R** one',
	is => (<1..> >>R**>> 2)->take(10)->str, '2 4 8 16 32 64 128 256 512 1024';


my $sum = [\+];
t 'reduction code ref',
	is => $sum->(1..10)->str, '1 3 6 10 15 21 28 36 45 55';

t 'Z',  is => (<1..3> Z <4..6>)->str, '1 4 2 5 3 6';

t 'Z.', is => (<1..3> Z. <4..6>)->str, '14 25 36';

t 'gen Z array',
	is => (<1..3> Z [4..6])->str, '1 4 2 5 3 6';

t 'X',  is => (<1..3> X <4..6>)->str, '1 4 1 5 1 6 2 4 2 5 2 6 3 4 3 5 3 6';

t 'X+', is => (<1..3> X+ <4..6>)->str, '5 6 7 6 7 8 7 8 9';

my @a = (1..10);
t 'reduce array',
	is => ([+] @a), 55;
