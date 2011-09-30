package List::Gen::Perl6;
    use strict;
    use warnings;
    use lib '../../';
    use List::Gen ();
    use Filter::Simple;
    use Carp ();
    BEGIN {
        FILTER_ONLY      all => \&_filter_hyper,
            code_no_comments => \&_filter_rest;
    }
    my $ops = join '|' => map quotemeta, ',', qw (+ - / * ** x % . & | ^ < > <<
                                      >> <=> cmp lt gt eq ne le ge == != <= >=);
    sub _filter_hyper {
        s/ (<<|>>) (R?(?:$ops)) (<<|>>) /$1'$2'$3/gx;
    }
    sub _filter_rest {
        s{
            (?<!<)
            \[ (\.\.|\\)? ($ops) \]
            (?= \s* (?! \b$ops\b | [;\)\]\}\>] ) )
        }{
            my $t = $1 || '';
            $t = '..' if $t eq '\\';
            "List::Gen::Perl6::_reduceWith '$t$2', "
        }egx;
        s{
            (?<!<)
            \[ (\.\.|\\)? ($ops) \]
            (?!>)
        }{
            my $t = $1 || '';
            $t = '..' if $t eq '\\';
            "List::Gen::Perl6::_reduction('$t$2')"
        }gxe;
        s{
            (?<![\$\@\%\&\*]) \b Z \b ($ops)?
        }{
            $1 ? "|'$1'|" : '|'
        }gxe;
        s{
            (?<![\$\@\%\&\*]) \b X \b ($ops)?
        }{
            $1 ? "x'$1'x" : 'x'
        }gxe;
    }

    my %cache;
    sub _reduction {
        my $str = "[@_]";
        {return $cache{$str} || next}
        local $@;
        my $ret = eval {&List::Gen::glob($str)};
        ref $ret eq 'CODE' or Carp::croak("not a generator glob: $str\n$@\n");
        $cache{$str} = $ret;
    }
    sub _reduceWith {
        goto &{_reduction shift}
    }
    sub filter {
        my $str = shift;
        for ($str) {
            _filter_hyper;
            _filter_rest;
        }
        return $str;
    }

=head1 NAME

List::Gen::Perl6 - perl6 meta operators in perl5

=head1 SYNOPSIS

Many of the features found in L<List::Gen> borrow ideas from perl6.  However,
since the syntax of perl5 and perl6 differ, some of the constructs in perl5 are
longer/messier than in perl6.  C< List::Gen::Perl6 > is a source filter that
makes some of C<List::Gen>'s features more syntactic.

the new syntactic constructs are:

    cross:     generator X  generator
    crosswith: generator X+ generator
    zip:       generator Z  generator
    zipwith:   generator Z+ generator
    hyper:     generator <<+>> generator
    hyper:     generator >>+<< generator
    hyper:     generator >>+>> generator
    hyper:     generator <<+<< generator
    reduce:    [+] list
    triangular reduction: [\+]  list
                       or [..+] list

in the above, C< + > can be any perl binary operator.

here is a table showing the correspondence between the source filter constructs,
the native overloaded ops, and the operation expanded into methods and functions.

    List::Gen::Perl6      List::Gen                List::Gen expanded

    <1..3> Z <4..6>      ~~  <1..3> | <4..6>        ~~  <1..3>->zip(<4..6>)

    <1..3> Z. <4..6>     ~~  <1..3> |'.'| <4..6>    ~~  <1..3>->zipwith(sub {$_[0] . $_[1]}, <4..6>)

    <1..3> X <4..6>      ~~  <1..3> x <4..6>        ~~  <1..3>->cross(<4..6>)

    <1..3> X. <4..6>     ~~  <1..3> x'.'x <4..6>    ~~  <1..3>->crosswith(sub {$_[0] . $_[1]}, <4..6>)

    [+] 1..10            ~~  <[+] 1..10>            ~~  reduce {$_[0] + $_[1]} 1 .. 10
    [+]->(1..10)         ~~  <[+]>->(1..10)         ~~  same as above

    [\+] 1..10           ~~  <[..+] 1..10>          ~~  scan {$_[0] + $_[1]} 1 .. 10
    [\+]->(1..10)        ~~  <[..+]>->(1..10)       ~~  same as above

    <1..3> <<+>> <4..6>  ~~  <1..3> <<'+'>> <4..6>  ~~  gen {$$_[0] + $$_[1]} tuples <1..3>, <4..6>

Except for normal reductions C< [+] >, all of the new constructs return a generator.

When used without a following argument, reductions and triangular reductions will return
a code reference that will perform the reduction on its arguments.

    my $sum = [+];
    say $sum->(1..10);  # 55

Reductions can take a list of scalars, or a single generator as their argument.

Only the left hand side of the zip, cross, and hyper operators needs to be a
generator.  zip and cross will upgrade their rhs to a generator if it is an array.
hyper will upgrade it's rhs to a generator if it is an array or a scalar.

The source filter is limited in scope, and should not harm other parts of the code,
however, source filters are notoriously difficult to fully test, so take that
with a grain of salt.  Due to limitations of L<Filter::Simple>, hyper operators
will be filtered in both code and strings.  All other filters should skip strings.

This code is not really intended for serious work, ymmv.

=head1 AUTHOR

Eric Strom, C<< <asg at cpan.org> >>

=head1 BUGS

report any bugs / feature requests to C<bug-list-gen at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=List-Gen>.

comments / feedback / patches are also welcome.

=head1 COPYRIGHT & LICENSE

copyright 2009-2011 Eric Strom.

this program is free software; you can redistribute it and/or modify it under
the terms of either: the GNU General Public License as published by the Free
Software Foundation; or the Artistic License.

see http://dev.perl.org/licenses/ for more information.

=cut

1;
