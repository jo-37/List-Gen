package
    List::Gen::Testing;
    use warnings;
    use strict;
    use Carp;

    sub import {
        no strict 'refs';
        *{caller().'::t'} = \&t;
        *{caller().'::T'} = sub (&) {goto &t};
    }

    my %arity = (
        ok        => 1,
        is        => 2,
        is_deeply => 2,
        like      => 2,
        cmp_ok    => 3,
    );

    our ($name, $count, $declare);
    my @tests;
    sub setup_subs {
        for my $sub (keys %arity) {
            push @tests, $sub;
            my $code = Test::More->can($sub) or die "no test '$sub'";
            no strict 'refs';
            *$sub = sub {$code->(@_, $name.' '.++$count)};
        }
    }

    sub t {
        if (@_ == 1 and ref $_[0] ne 'CODE') {
            $declare or croak "test name '@_' declaration outside of test sub";
            $name  = shift;
            $count = 0;
            return;
        }
        local $name = shift if @_ > 1;
        local $Test::Builder::Level
            = $Test::Builder::Level + 1;

        if (@_ == 1 and ref $_[0] eq 'CODE') {
            setup_subs unless defined &ok;
            local ($declare, $count) = 1;
            no strict 'refs';
            local @{(caller).'::'}{@tests} = @{__PACKAGE__.'::'}{@tests};
            shift->()
        }
        else {
            my $num;
            while (@_) {
                my $test = shift;
                (Test::More->can($test) or croak "no test: $test")->(
                    splice(@_, 0, $arity{$test} || croak "no arity: $test"),
                    $name . ($num++ || @_ ? " $num" : '')
                )
            }
        }
    }

    1;
