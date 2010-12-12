# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Infix::Parser

A simple stack-based parser that parses infix expressions with nonary,
unary and binary operators specified using an operator table.

Escapes are supported in strings, using backslash.

=cut

package Foswiki::Infix::Parser;

use strict;
use warnings;
use Assert;
use Error qw( :try );
use Foswiki::Infix::Error ();
use Foswiki::Infix::Node  ();

# Set to 1 for debug
use constant MONITOR_PARSER => 0;

=begin TML

---++ new($client_class, \%options) -> parser object

Creates a new infix parser. Operators must be added for it to be useful.

The tokeniser matches tokens in the following order: operators,
quotes (" and '), numbers, words, brackets. If you have any overlaps (e.g.
an operator '<' and a bracket operator '<<') then the first choice
will match.

=$client_class= needs to be the _name_ of a _package_ that supports the
following two functions:
   * =newLeaf($val, $type)= - create a terminal. $type will be:
      1 if the terminal matched the =words= specification (see below).
      2 if it is a number matched the =numbers= specification (see below)
      3 if it is a quoted string
   * =newNode($op, @params) - create a new operator node. @params
     is a variable-length list of parameters, left to right. $op
     is a reference to the operator hash in the \@opers list.
These functions should throw Error::Simple in the event of errors.
Foswiki::Infix::Node is such a class, ripe for subclassing.

The remaining parameters are named, and specify options that affect the
behaviour of the parser:
   1 =words=>qr//= - should be an RE specifying legal words (unquoted
     terminals that are not operators i.e. names and numbers). By default
     this is =\w+=.
     It's ok if operator names match this RE; operators always have precedence
     over atoms.
   2 =numbers=>qr//= - should be an RE specifying legal numbers (unquoted
     terminals that are not operators or words). By default
     this is =qr/[+-]?(?:\d+\.\d+|\d+\.|\.\d+|\d+)(?:[eE][+-]?\d+)?/=,
     which matches integers and floating-point numbers. Number
     matching always takes precedence over word matching (i.e. "1xy" will
     be parsed as a number followed by a word. A typical usage of this option
     is when you only want to recognise integers, in which case you would set
     this to =numbers => qr/\d+/=.

=cut

sub new {
    my ( $class, $options ) = @_;

    my $this = bless(
        {
            client_class => $options->{nodeClass},
            operators    => [],
            initialised  => 0,
        },
        $class
    );

    $this->{numbers} =
      defined( $options->{numbers} )
      ? $options->{numbers}
      : qr/(\d+\.\d+|\d+\.|\.\d+|\d+)([eE][+-]?\d+)?/;

    $this->{words} =
      defined( $options->{words} )
      ? $options->{words}
      : qr/\w+/;

    return $this;
}

=begin TML

---++ ObjectMethod finish()
Break circular references.

=cut

sub finish {
    my $self = shift;

}

=begin TML

---++ ObjectMethod addOperator($oper)
Add an operator to the parser.

=$oper= is an object that implements the Foswiki::Infix::OP interface.

=cut

sub addOperator {
    my ( $this, $op ) = @_;
    push( @{ $this->{operators} }, $op );
    $this->{initialised} = 0;
}

# Initialise on demand before a first parse
sub _initialise {
    my $this = shift;

    return if $this->{initialised};

    # Build operator lists
    my @stdOpsRE;
    my @bracketOpsRE;
    foreach my $op ( @{ $this->{operators} } ) {

        # Build a RE for the operator. Note that operators
        # that end in \w are terminated with \b
        my $opre = quotemeta( $op->{name} );
        $opre .= ( $op->{name} =~ /\w$/ ) ? '\b' : '';
        if ( $op->{casematters} ) {
            $op->{InfixParser_RE} = qr/$opre/;
        }
        else {
            $op->{InfixParser_RE} = qr/$opre/i;
        }
        if ( defined( $op->{close} ) ) {

            # bracket op
            $this->{bracket_ops}->{ lc( $op->{name} ) } = $op;

            $opre = quotemeta( $op->{close} );
            $opre .= ( $op->{close} =~ /\w$/ ) ? '\b' : '';
            if ( $op->{casematters} ) {
                $op->{InfixParser_closeRE} = qr/$opre/;
            }
            else {
                $op->{InfixParser_closeRE} = qr/$opre/i;
            }
            push( @bracketOpsRE, $op->{InfixParser_RE} );
        }
        else {
	    if ($op->{arity} == 1) {
		$this->{unary_ops}->{ lc( $op->{name} ) } = $op;
	    } else {
		$this->{standard_ops}->{ lc( $op->{name} ) } = $op;
	    }
            push( @stdOpsRE, $op->{InfixParser_RE} );
        }
    }

    # Build regular expression of all standard operators.
    $this->{standard_op_REs} = join( '|', @stdOpsRE );

    # and repeat for bracket operators
    $this->{bracket_op_REs} = join( '|', @bracketOpsRE );

    $this->{initialised} = 1;
}

=begin TML

---++ ObjectMethod parse($string) -> $parseTree
Parses =$string=, calling =newLeaf= and =newNode= in the client class
as necessary to create a parse tree. Returns the result of calling =newNode=
on the root of the parse.

Throws Foswiki::Infix::Error in the event of parse errors.

=cut

sub parse {
    my ( $this, $expr ) = @_;
    my $data = $expr;
    $this->_initialise();
    return _parse( $this, $expr, \$data );
}

# Simple stack parser, after Knuth
sub _parse {
    my ( $this, $expr, $input, $term ) = @_;

    throw Foswiki::Infix::Error("Empty expression")
      unless defined($expr);
    $$input = "()" unless $$input =~ /\S/;

    my @opers  = ();
    my @opands = ();

    $input ||= \$expr;

    print STDERR "Parse: $$input\n" if MONITOR_PARSER;
    my $lastTokWasOper = 1;
    try {
        while ( $$input =~ /\S/ ) {
            if ( $$input =~ s/^\s*($this->{standard_op_REs})// ) {
                my $opname = $1;
                my $op = $this->{unary_ops}->{ lc($opname) } ||
		    $this->{standard_ops}->{ lc($opname) };
		if ($lastTokWasOper && $opname =~ $this->{words}
		    && $op->{arity} > 1) {
		    # op is a word name, and is in an operand position,
		    # and is not unary. Treat it as an operand.
		    push( @opands,
			  $this->{client_class}
			  ->newLeaf( $opname, Foswiki::Infix::Node::NAME ) );
		    print STDERR "Operand: name '$opname'\n" if MONITOR_PARSER;
		    $lastTokWasOper = 0;
		    next;
		}
		if ($lastTokWasOper && $this->{unary_ops}->{ lc($opname) }) {
		    # Op immediately follows another op, and allows unary.
		    $op = $this->{unary_ops}->{ lc($opname) };
		} else {
		    $op = $this->{standard_ops}->{ lc($opname) } ||
			$this->{unary_ops}->{ lc($opname) };
		}
                print STDERR "Operator: $op\n" if MONITOR_PARSER;
                ASSERT( $op, $opname ) if DEBUG;
                _apply( $this, $op->{prec}, \@opers, \@opands );
                push( @opers, $op );
		$lastTokWasOper = 1;
            }
            elsif ( $$input =~ s/^\s*(['"])(|.*?[^\\])\1// ) {
                my $q   = $1;
                my $val = $2;
                print STDERR "Operand: qs '$val'\n" if MONITOR_PARSER;

                # Handle escaped characters in the string. This is where
                # expansions such as \n are handled
                $val =~
s/(?<!\\)\\(0[0-7]{2}|x[a-fA-F0-9]{2}|x{[a-fA-F0-9]+}|n|t|\\|$q)/eval('"\\'.$1.'"')/ge;
                push( @opands,
                    $this->{client_class}
                      ->newLeaf( $val, Foswiki::Infix::Node::STRING ) );
		$lastTokWasOper = 0;
            }
            elsif ( $$input =~ s/^\s*($this->{numbers})// ) {
                my $val = 0 + $1;
                print STDERR "Operand: number $val\n" if MONITOR_PARSER;
                push( @opands,
                    $this->{client_class}
                      ->newLeaf( $val, Foswiki::Infix::Node::NUMBER ) );
		$lastTokWasOper = 0;
            }
            elsif ( $$input =~ s/^\s*($this->{words})// ) {
                print STDERR "Operand: word '$1'\n" if MONITOR_PARSER;
                my $val = $1;
                push( @opands,
                    $this->{client_class}
                      ->newLeaf( $val, Foswiki::Infix::Node::NAME ) );
		$lastTokWasOper = 0;
            }
            elsif ( $$input =~ s/^\s*($this->{bracket_op_REs})// ) {
                my $opname = $1;
                print STDERR "Tok: open bracket $opname\n" if MONITOR_PARSER;
                my $op = $this->{bracket_ops}->{ lc($opname) };
                ASSERT($op) if DEBUG;
                _apply( $this, $op->{prec}, \@opers, \@opands );
                push( @opers, $op );
                push( @opands,
                    $this->_parse( $expr, $input, $op->{InfixParser_closeRE} )
                );
		$lastTokWasOper = 0;
            }
            elsif ( defined($term) && $$input =~ s/^\s*$term// ) {
                print STDERR "Tok: close bracket $term\n" if MONITOR_PARSER;
		# if the operand stack is empty, push an empty array
		# nonary operator
		$this->onCloseExpr(\@opands);
                last;
            }
            else {
                throw Foswiki::Infix::Error( 'Syntax error', $expr, $$input );
            }
        }
        _apply( $this, 0, \@opers, \@opands );
    }
    catch Error::Simple with {

        # Catch errors thrown during the tree building process
        throw Foswiki::Infix::Error( shift, $expr, $$input );
    };
    throw Foswiki::Infix::Error( 'Missing operator', $expr, $$input )
      unless scalar(@opands) == 1;
    throw Foswiki::Infix::Error(
        'Excess operators (' . join( ' ', map { $_->{name} } @opers ) . ')',
        $expr, $$input )
      if scalar(@opers);
    my $result = pop(@opands);
    print STDERR "Return " . $result->stringify() . "\n" if MONITOR_PARSER;
    return $result;
}

# Apply ops on the stack while their precedence is higher than $prec
# For each operator on the stack with precedence >= $prec, pop the
# required number of operands, construct a new parse node and push
# the node back onto the operand stack.
sub _apply {
    my ( $this, $prec, $opers, $opands ) = @_;

    while (scalar(@$opers)
        && $opers->[-1]->{prec} >= $prec
        && scalar(@$opands) >= $opers->[-1]->{arity} )
    {
        my $op    = pop(@$opers);
        my $arity = $op->{arity};
        my @prams;
        while ( $arity-- ) {
            unshift( @prams, pop(@$opands) );

            # Should never get thrown, but just in case...
            throw Foswiki::Infix::Error("Missing operand to '$op->{name}'")
              unless $prams[0];
        }
        if (MONITOR_PARSER) {
            print STDERR "Apply $op->{name}("
              . join( ', ', map { $_->stringify() } @prams ) . ")\n";
        }
	my $folded;
	if ( ref($prams[0]->{op}) && $op == $prams[0]->{op} && $op->{canfold}) {
	    push( @{$prams[0]->{params}}, $prams[1] );
	    push( @$opands, $prams[0] );
	} else {
	    push( @$opands, $this->{client_class}->newNode( $op, @prams ) );
	}
    }
}

=begin TML

---++ onCloseExpr($@opands)
Designed to be overridden by subclasses that need to perform an action on the
operand stack (such as pushing) when a sub-expression is closed. Also called
when the root expression is closed. The default is a no-op.

=cut

sub onCloseExpr {
    my ($this, $opands) = @_;
}

1;
__END__
Author: Crawford Currie http://c-dot.co.uk

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
