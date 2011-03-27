# Copyright (C) 2009 TWIKI.NET (http://www.twiki.net)
# Copyright (C) 2009-2010 Foswiki Contributors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the Foswiki root.

package Foswiki::Contrib::Stringifier::Plugins::XLSX;
use Foswiki::Contrib::Stringifier::Base;
our @ISA = qw( Foswiki::Contrib::Stringifier::Base );
__PACKAGE__->register_handler("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", ".xlsx");

use Text::Iconv;
use Encode ();
use Error qw(:try);

sub stringForFile {
    my ( $self, $file ) = @_;

    #my $converter = Text::Iconv->new("utf-8", "windows-1251");
    my $book;

    try {
	require Spreadsheet::XLSX;
        $book = Spreadsheet::XLSX->new($file);
    } catch Error with {
	return '';
    };

    return '' unless $book;

    my $text = '';

    foreach my $sheet ( @{ $book->{Worksheet} } ) {
        $text .= sprintf( "%s\n", $sheet->{Name} );
        $sheet->{MaxRow} ||= $sheet->{MinRow};

        foreach my $row ( $sheet->{MinRow} .. $sheet->{MaxRow} ) {
            $sheet->{MaxCol} ||= $sheet->{MinCol};

            foreach my $col ( $sheet->{MinCol} .. $sheet->{MaxCol} ) {
                my $cell = $sheet->{Cells}[$row][$col];
                if ($cell) {
                    $text .= sprintf( "%s\n", $cell->{Val} );
                }
            }
        }
    }

    return $self->fromUtf8($text);
}

1;