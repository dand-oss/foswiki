# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.

use strict;
use warnings;

=pod

---+ package Foswiki::Configure::Checkers::Tasks::StatusServerCAFile
Configure GUI checker for the {Tasks}{StatusServerCAFile} configuration item.

Verifies that a CAfile or CApath is specified and readable when https client verification is selected.
Verifies no world write.

Any problems detected are reported.

=cut

package Foswiki::Configure::Checkers::Tasks::StatusServerCAFile;
use base 'Foswiki::Configure::Checker';


=pod

---++ ObjectMethod check( $valueObject ) -> $errorString
Validates the {Tasks}{StatusServerCAFile} item for the configure GUI
   * =$valueObject= - configure value object

Returns empty string if OK, error string with any errors

=cut

sub check {
    my $this = shift;

    my $e = '';

    my $cafile =  $Foswiki::cfg{Tasks}{StatusServerCAFile} || '';
    if( $cafile ) {
        $Foswiki::cfg{Tasks}{StatusServerVerifyClient} or
          return $this->WARN( "CA file is not used unless https client verification is active" );

        -r $cafile
          or return $this->ERROR( "CA file must be webserver-readable" );

        ((stat $cafile)[2] || 0) & 002 and return $this->ERROR( "File permissions allow world write" );
    } elsif( $Foswiki::cfg{Tasks}{StatusServerVerifyClient} ) {
        my $capath =  $Foswiki::cfg{Tasks}{StatusServerCAPath} || '';

        $capath && -d $capath && -r $capath
          or return $this->ERROR( "Client verification requires either a webserver-readable CA file or a CA path" );
    }

    return $e;
}

1;

__END__

This is an original work by Timothe Litt.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 3
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at
http://www.gnu.org/copyleft/gpl.html
