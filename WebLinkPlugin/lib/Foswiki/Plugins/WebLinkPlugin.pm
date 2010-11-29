# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# WebLinkPlugin is Copyright (C) 2010 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::WebLinkPlugin;

use strict;
use warnings;

=begin TML

---+ package WebLinkPlugin

=cut

use Foswiki::Func ();

our $VERSION = '$Rev$';
our $RELEASE = '1.00';
our $SHORTDESCRIPTION = 'A parametrized %WEB macro';
our $NO_PREFS_IN_TOPIC = 1;
our $baseWeb;
our $baseTopic;
our $doneInit;


=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean

=cut

sub initPlugin {
  ($baseTopic, $baseWeb) = @_;

  Foswiki::Func::registerTagHandler('WEBLINK', \&WEBLINK);

  $doneInit = 0;
  return 1;
}

=begin TML

---++ init()

=cut

sub init {
  return if $doneInit;

  $doneInit = 1;

  require Foswiki::Plugins::WebLinkPlugin::Core;
  Foswiki::Plugins::WebLinkPlugin::Core::init($baseWeb, $baseTopic);
}

=begin TML

---+ WEBLINK($session, $params, $theTopic, $theWeb) -> $string

stub for WEBLINK to initiate the core before handling the macro

=cut

sub WEBLINK {
  init();
  return Foswiki::Plugins::WebLinkPlugin::Core::WEBLINK(@_);
}

1;
