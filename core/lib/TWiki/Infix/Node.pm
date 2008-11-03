
=pod

---+ package TWiki::Infix::Node

Base class for node types generated by Infix::Parser. You don't *have* to use
it, but it may be useful.

=cut

package TWiki::Infix::Node;

use strict;

# 1 for debug
sub MONITOR_EVAL { 0 }

# Leaf token types
use vars qw ($NAME $STRING $NUMBER);
$NAME   = 1;
$NUMBER = 2;
$STRING = 3;

=pod

---++ ClassMethod newNode( $o, @p ) -> \$if

Construct a new parse node (contract with Infix::Parser)

=cut

sub newNode {
    my $class = shift;
    my $op    = shift;
    my $this  = bless( {}, $class );
    @{ $this->{params} } = @_;
    $this->{op} = $op;
    return $this;
}

=pod

---++ ClassMethod newLeaf( $val, $type ) -> \$if

Construct a new terminal node (contract with Infix::Parser)

=cut

sub newLeaf {
    my ( $class, $val, $type ) = @_;
    return newNode( $class, $type, $val );
}

=pod

---++ ObjectMethod evaluate(...) -> $result

Execute the parse node. The parameter array is passed on, by reference,
to the evaluation functions.

=cut

sub evaluate {
    my ( $this, $clientData ) = @_;

    my $result;
    if ( !ref( $this->{op} ) ) {
        $result = $this->{params}[0];
        if (MONITOR_EVAL) {
            print STDERR "LEAF: ", ( defined($result) ? $result : 'undef' ),
              "\n";
        }
    }
    else {
        my $fn = $this->{op}->{evaluate};
        $result = &$fn( $clientData, @{ $this->{params} } );
        if (MONITOR_EVAL) {
            print STDERR "NODE: ", $this->stringify(), " -> ",
              ( defined($result) ? $result : 'undef' ), "\n";
        }
    }
    return $result;
}

sub stringify {
    my $this = shift;

    unless ( ref( $this->{op} ) ) {
        if ( $this->{op} == $TWiki::Infix::Node::STRING ) {
            return "'$this->{params}[0]'";
        }
        else {
            return $this->{params}[0];
        }
    }

    return
      $this->{op}->{name} . '{'
      . join( ',', map { $_->stringify() } @{ $this->{params} } ) . '}';
}

1;
__DATA__

Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/

Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

Author: Crawford Currie http://c-dot.co.uk
