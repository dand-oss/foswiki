# Plugin for Foswiki Collaboration Platform, http://foswiki.org/
#
# Copyright (C) 2007-2009 MichaelDaum http://michaeldaumconsulting.com
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

package Foswiki::Contrib::RtfContrib::Converter;
use strict;

use vars qw($debug);

use LWP::UserAgent;
use Foswiki::Plugins::DBCachePlugin::Core;
use Foswiki::Attrs ();
use Foswiki::Sandbox ();

$debug = $Foswiki::cfg{RtfContrib}{Debug} || 0;

################################################################################
# static
sub writeDebug {
  print STDERR "Converter - $_[0]\n" if $debug;
}

###############################################################################
# constructor
sub new {
  my ($class, $session) = @_;

  my $this = bless({}, $class);

  $this->{session} = $session;
  $this->{web} = $session->{webName};
  $this->{topic} = $session->{topicName};
  $this->{query} = Foswiki::Func::getCgiQuery();

  my $pubDir = $Foswiki::cfg{PubDir} || $Foswiki::cfg{PubDir};
  my $systemWebName = $Foswiki::cfg{SystemWebName} || $Foswiki::cfg{SystemWebName};
  my $cacheDir = $Foswiki::cfg{RtfContrib}{CacheDir} || $Foswiki::cfg{RtfContrib}{CacheDir};

  $this->{cacheDir} = 
    $cacheDir 
    || $pubDir.'/'.$systemWebName.'/RtfContrib';

  $this->{cacheUrl} = $Foswiki::cfg{RtfContrib}{CacheUrl} 
    || $Foswiki::cfg{PubUrlPath}.'/'.$Foswiki::cfg{SystemWebName}.'/RtfContrib';
  $this->{defaultRtfTemplate} = $Foswiki::cfg{RtfContrib}{DefaultRtfTemplate} 
    || "$Foswiki::cfg{SystemWebName}.RtfContrib.default-template.rtf";

  $this->{db} = Foswiki::Plugins::DBCachePlugin::Core::getDB($this->{web});
  die "unable to get cache for web $this->{web}" unless $this->{db};

  mkdir $this->{cacheDir} unless -d $this->{cacheDir};

  # Graphics::Magick is less buggy than Image::Magick
  my $impl = 
    $Foswiki::cfg{RtfContrib}{ImageImpl} || 
    $Foswiki::cfg{ImagePlugin}{Impl} || 
    $Foswiki::cfg{ImageGalleryPlugin}{Impl} || 
    'Graphics::Magick'; 

  writeDebug("creating new image mage using $impl");
  eval "use $impl";
  die $@ if $@;
  $this->{mage} = new $impl;

  writeDebug("new converter $class");

  return $this;
}

################################################################################
# caches the resulting file into a file
sub cacheRtf {
  my ($this, $rtf) = @_;

  writeDebug("called cacheRtf");

  # get rtf filename
  my $fileName = $this->getFileName();

  # write it to the file
  unless (open( FILE, ">$fileName" ))  {
    die "Can't create file $fileName - $!\n";
  }

  print FILE $rtf;
  close( FILE);
}

################################################################################
sub getFileName {
  my $this = shift;

  my $fileName = $this->{query}->param('filename') || "$this->{topic}.rtf";

  ($fileName) = Foswiki::Sandbox::sanitizeAttachmentName($fileName);
  $fileName = $this->{cacheDir}.'/'.$fileName;
  $this->{fileName} = $fileName;

  writeDebug("fileName=$fileName");

  return $fileName;
}

################################################################################
sub getUrlName {
  my $this = shift;

  my $fileName = $this->{query}->param('filename') || "$this->{topic}.rtf";
  ($fileName) = Foswiki::Sandbox::sanitizeAttachmentName($fileName);
  my $urlName = $this->{cacheUrl}.'/'.$fileName;
  $this->{urlName} = $urlName;

  writeDebug("urlName=$urlName");

  return $urlName
}

################################################################################
# returns a list (rtf, errorMsg)
# errorMsg = '' if everything is ok
# rtf = undef if an error occured
sub genRtf {
  my $this = shift;

  writeDebug("called genRtf");

  my $template = $this->{query}->param('template') 
    || $this->{defaultRtfTemplate};

  my $templateWeb = $this->{web};
  my $templateTopic = $this->{topic};
  if ($template =~ /^(.*)[\/\.](.*?)[\/\.](.*?\.rtf)$/) {
    $templateWeb = $1;
    $templateTopic = $2;
    $template = $3;
  }
  writeDebug("templateWeb=$templateWeb, templateTopic=$templateTopic, template=$template");
  
  my $rtf = Foswiki::Func::readAttachment($templateWeb, $templateTopic, $template);
  return (undef, "template '$templateWeb.$templateTopic.$template' not found") 
    unless $rtf;

  $this->processTemplate($rtf);

  #writeDebug("result=$rtf");

  return ($rtf, '');
}

################################################################################
sub processTemplate {
  my $this = shift;
  # my rtf = shift; ... we use $_[0] instead

  my $topicObj = $this->{db}->fastget($this->{topic});
  return unless $topicObj; # not found

  my $formName = $topicObj->fastget('form');
  my $formObj = $topicObj->fastget($formName) if $formName;
  my $attachmentsObj = $topicObj->fastget('attachments');

  # insert keys 
  if ($formObj) {
    $_[0] =~ s/\%FORMFIELD\\{("?.*?"?)\\}\%/$this->handleFormField($formObj, $1)/ge;
  } else {
    # remove formfield tags if there's none
    $_[0] =~ s/\%FORMFIELD\\{"?.*?"?\\}\%//ge;
  }
  $_[0] =~ s/\%TOPIC\%/$this->{topic}/g;
  $_[0] =~ s/\%WEB\%/$this->{web}/g;
  $_[0] =~ s/\%AUTHOR\%/$this->handleAuthor($topicObj)/ge;
  $_[0] =~ s/\%RTFCONTRIB_RELEASE\%/$Foswiki::Contrib::RtfContrib::RELEASE/g;
  $_[0] =~ s/\%RTFCONTRIB_VERSION\%/$Foswiki::Contrib::RtfContrib::VERSION/g;
  $_[0] =~ s/\%REVISION\%/$this->handleRevision($topicObj)/ge;
  $_[0] =~ s/\%TEXT\%/$this->handleTopicKey($topicObj, '_sectiondefault')/ge;
  $_[0] =~ s/\%SECTION\\{("?.*?"?)\\}\%/$this->handleTopicKey($topicObj, $1)/ge;
  $_[0] =~ s/\%ATTACHMENT\\{("?.*?"?)\\}\%/$this->handleAttachment($attachmentsObj, $1)/ge;
  $_[0] =~ s/\%IMAGE\\{("?.*?"?)\\}\%/$this->handleImage($1)/ge;
  $_[0] =~ s/\%CELL\\{(.*?)\\}%/$this->handleCell($1)/ge;
}


################################################################################
sub handleRevision {
  my ($this, $obj) = @_;

  my $revision = $obj->fastget('info')->fastget('version');
  $revision =~ s/^.*\.(.*?)$/$1/o;

  return $revision;
}

################################################################################
sub handleAuthor {
  my ($this, $obj) = @_;

  my $author = $obj->fastget('info')->fastget('author');

  if (defined(&Foswiki::Users::getWikiName)) {# newer engines
    my $session = $Foswiki::Plugins::SESSION;
    $author = $session->{users}->getWikiName($author);
  }

  return $author;
}

################################################################################
sub handleFormField {
  my ($this, $obj, $params) = @_;

  $params = new Foswiki::Attrs($params);
  my $key = $params->{_DEFAULT} || $params->{key};
  my $format = $params->{format} || '$value';
  my $header = $params->{header} || '';
  my $footer = $params->{footer} || '';
  my $value = $obj->fastget($key) || '';

  my $result = $format;
  $result =~ s/\$value/$value/g;
  return '' unless $result;

  $result =~ s/%([\da-f]{2})/chr(hex($1))/gei; # Foswiki::urlDecode
  $result = $header.$this->tml2rtf($result).$footer;

  #writeDebug("result=$result");

  return $result;
}

################################################################################
sub handleTopicKey {
  my ($this, $obj, $params) = @_;

  writeDebug("handleTopicKey($params)");
  $params = new Foswiki::Attrs($params);
  my $key = $params->{_DEFAULT} || $params->{key};
  my $format = $params->{format} || '$value';
  my $header = $params->{header} || '';
  my $footer = $params->{footer} || '';
  my $value = $obj->fastget($key) || '';
  #writeDebug("key=$key, format=$format, value=$value");
  
  my $result = $format;
  $result =~ s/\$value/$value/g;
  return '' unless $result;

  return $header.$this->tml2rtf($result).$footer;
}

################################################################################
sub handleAttachment {
  my ($this, $obj, $params) = @_;

  writeDebug("handleAttachment($params");

  $params = new Foswiki::Attrs($params);
  my $name = $params->{_DEFAULT} || $params->{name};
  
  my $attachment;
  ## todo

  return '';
}

################################################################################
sub handleImage {
  my ($this, $params) = @_;

  writeDebug("handleImage($params)");

  $params = new Foswiki::Attrs($params);
  my $fileName = $params->{_DEFAULT};
  my $header = $params->{header} || '';
  my $footer = $params->{footer} || '';
  my $width = $params->{width};
  my $height = $params->{height};
  my $top = $params->{top};
  my $right = $params->{right};

  writeDebug("header=$header");
  writeDebug("footer=$footer");

  $height = 140 unless defined $height; # points
  $top = 161 unless defined $top;
  $right = 529 unless defined $right;

  my ($photo, $type, $imgWidth, $imgHeight, $errorMsg) = $this->getPhoto($fileName);
  return (undef, "error while fetching photo: $errorMsg") unless $photo;

  $imgWidth = 1 unless $imgWidth; # prevent division by zero; should never reach this
                                  # code: getPhoto() should have returned an
                                  # appropriate error message before. anyway.
  # encode
  my $blipCode = 'jpegblip';
  $blipCode = 'jpegblip' if $type =~ /jpe?g$/;
  $blipCode = 'pngblip' if $type =~ /png$/;
  $blipCode = 'emfblip' if $type =~ /emf$/;

  if ($blipCode) {
    
    # compute image scale
    # SMELL: make positioning more configurable; we only have pos top/right now
                                   
    my $ratio = ($height + 0.0) / ($imgHeight);
    my $twipsHeight = $height * 20;
    my $twipsWidth = int($imgWidth * $ratio * 20 +0.5);
    my $twipsTop = $top * 20; 
    my $twipsRight = $right * 20;
    my $twipsBottom = $twipsTop + $twipsHeight;
    my $twipsLeft = $twipsRight - $twipsWidth;

    writeDebug("ratio=$ratio, twipsWidth=$twipsWidth twipsHeight=$twipsHeight");
    writeDebug("top=$twipsTop, bottom=$twipsBottom, left=$twipsLeft, right=$twipsRight");

    #  "\\picscalex175\\picscaley213".
    #  "\\piccropl0\\piccropr0\\piccropt0\\piccropb0".
    #  "\\picw2540\\pich2540\\picwgoal1440\\pichgoal1440".
    $photo = 
      $header.
      "{\\pict".
      "\\picwgoal$twipsWidth\\pichgoal$twipsHeight\\picw$twipsWidth\\pich$twipsHeight".
      "\\$blipCode\n".
      join('', map {sprintf('%02X', $_)} unpack('C*', $photo)).
      "}\n".
      $footer;
    $photo =~ s/\$top/$twipsTop/g;
    $photo =~ s/\$bottom/$twipsBottom/g;
    $photo =~ s/\$left/$twipsLeft/g;
    $photo =~ s/\$right/$twipsRight/g;
  } else {
    $photo = " unsupported image type '$type' ";
  }

  #writeDebug("photo=$photo");

  return $photo;
}

################################################################################
sub handleCell {
  my ($this, $params) = @_;

  writeDebug("handleCell($params)");
  $params = new Foswiki::Attrs($params);
  my $theTopic = $params->{_DEFAULT} || $params->{topic} || $this->{topic};
  my $theWeb = $params->{web} || $params->{web} || $this->{web};
  my $theRow = $params->{row} || 0;
  my $theCol = $params->{col} || $params->{column} || 0;

  ($theWeb, $theTopic) = Foswiki::Func::normalizeWebTopicName($theWeb, $theTopic);
  writeDebug("theWeb=$theWeb, theTopic=$theTopic, theRow=$theRow, theCol=$theCol");

  my $db = $this->{db};
  if ($theWeb ne $this->{web}) {
    $db = Foswiki::Plugins::DBCachePlugin::Core::getDB($theWeb);
  }
  my $topicObj = $db->fastget($theTopic);
  return '' unless $topicObj;

  my $text = $topicObj->fastget('_sectiondefault');
  #writeDebug("text=$text");
  my $row = $theRow;
  my $result = '';
  while ($text =~ /[\n\r]\s*\|((?:.*\|)+)\s*(?=[\n\r])/g) {
    $row--;
    #writeDebug("got row '$1'");
    #writeDebug("row=$row");
    next if $row >= 0;
    my $line = $1;
    my $col = $theCol;
    for my $cell (split(/\|/,$1)) {
      $col--;
      #writeDebug("col=$col");
      #writeDebug("cell='$cell'");
      next if $col >= 0;
      $cell =~ s/^\s+//o;
      $cell =~ s/\s+$//o;
      $result = $cell;
      last;
    }
    last;
  }

  return $result;
}

################################################################################
sub getPhoto {
  my ($this, $fileName) = @_;

  return (undef, undef, undef, undef, "no fileName") unless $fileName;

  writeDebug("getPhoto($fileName)");

  my $photo = '';

  if ($fileName =~ /^(https?|ftp)/) {
    # remote file
    
    my $ua = LWP::UserAgent->new();
    $ua->agent('Foswiki RtfContrib'); 
    $ua->timeout(5);
    my $request = HTTP::Request->new('GET', $fileName);
    $request->referer(Foswiki::Func::getViewUrl($this->{web}, $this->{topic}));
    my $response = $ua->request($request);

    return (undef, undef, undef, undef, $response->status_line) if $response->is_error;

    $photo = $response->content;

  } else {
    # attachment 
    my $web = $this->{web};
    my $topic = $this->{topic};
    my $pubUrlPath =  Foswiki::Func::getPubUrlPath();
    $fileName =~ s/%([\da-f]{2})/chr(hex($1))/gei; # Foswiki::urlDecode
    $fileName =~ s/\%PUBURLPATH%/$pubUrlPath/go;
    if ($fileName =~ /^$pubUrlPath\/(.*)[\/\.](.*?)[\/\.](.*?)\.(jpe?g|png|emf)$/) {
      $web = $1;
      $topic = $2;
      $fileName = "$3.$4";
    }
    writeDebug("reading attachment '$fileName' at $web.$topic");
    $photo = Foswiki::Func::readAttachment($web, $topic, $fileName);
    return (undef, undef, undef, undef, "file not found") unless $photo;
  }
  $this->{mage}->BlobToImage($photo);
  my ($width, $height, $format) = $this->{mage}->Get('width', 'height', 'format');
  $format = lc($format);

  writeDebug("format=$format, width=$width, height=$height");

  return (undef, undef, undef, undef, "illegal file of undefined width")
    unless $width;

  return (undef, undef, undef, undef, "illegal file of undefined height")
    unless $height;

  return (undef, undef, undef, undef, "illegal file format")
    unless $format;

  return ($photo, $format, $width, $height, undef);
}

################################################################################
# translates wiki markup (and some basic html) to rtf
sub tml2rtf {
  my ($this, $text) = @_;

  return '' unless $text;

  #writeDebug("tml2rtf - text before=$text");

  # escape chars which are meaningful in rtf
  $text =~ s/([\\{}])/\\$1/go; 

  # special html chars
  $text =~ s/&nbsp;/\\~/go;
  $text =~ s/<p ?\/?>/\\par /g;
  $text =~ s/<br ?\/?>/\\line /g;
  $text =~ s/\%BR\%/\\line /g;

  # simple fonts
  $text =~ s/\*(.+?)\*/{\\b $1}/g; # bold
  $text =~ s/_(.+?)_/{\\i $1}/g; # italic
  $text =~ s/__(.+?)__/{\\i\\b $1}/g; # bold italic

#  $text =~ s/\%0d/\n/g; # SMELL: do we still need them?
#  $text =~ s/\%0a/\r/g;

  # headlines
  $text =~ s/(^|[\n\r])---(\++) ?(.*)([\n\r]|$)/handleHeadlines($3, $2)/ge;
  
  # empty lines
  $text =~ s/(^|[\n\r])\s+([\n\r]|$)/\\par /g;
  
  # TODO: parse wiki lists
  # TODO: parse wiki tables

  # encode special chars
  $text =~ s/�/\\'c4/go;
  $text =~ s/�/\\'e4/go;
  $text =~ s/�/\\'f6/go;
  $text =~ s/�/\\'fc/go;
  $text =~ s/�/\\'d6/go;
  $text =~ s/�/\\'dc/go;
  $text =~ s/�/\\'df/go;

  # TODO: have them all

  #writeDebug("tml2rtf - text after=$text");

  return $text;
}

################################################################################
sub handleHeadlines {
  my ($text, $level) = @_;

#  writeDebug("handleHeadlines($text, $level)");

  my $format;
  $format = '\fs20\sb100\b' if $level =~ /^\+\+\+\+\+\+$/;
  $format = '\fs24\sb150\b' if $level =~ /^\+\+\+\+\+$/;
  $format = '\fs28\sb200\b' if $level =~ /^\+\+\+\+$/;
  $format = '\fs32\sb300\b' if $level =~ /^\+\+\+$/;
  $format = '\fs36\sb480\b' if $level =~ /^\+\+$/;
  $format = '\fs40\sb480\b' if $level =~ /^\+$/;

  my $result = '';
  $result .= "\\par\n{\\pard $format $text\\par}\n";

#  writeDebug("result=$result");

  return $result;
}

1;
