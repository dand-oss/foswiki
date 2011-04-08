# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

=pod

---+ package Foswiki::Plugins::MongoDBPlugin::DB


=cut

package Foswiki::Plugins::MongoDBPlugin::DB;

# Always use strict to enforce variable scoping
use strict;
use MongoDB;
use MongoDB::Cursor;
use Assert;
use Data::Dumper;
use Time::HiRes ();

#lets declare it ok to run queries on slaves.
#http://search.cpan.org/~kristina/MongoDB-0.42/lib/MongoDB/Cursor.pm#slave_okay
$MongoDB::Cursor::slave_okay = 1;

#I wish
#use constant MONITOR => $Foswiki::cfg{MONITOR}{'Foswiki::Plugins::MongoDBPlugin'} || 0;
use constant MONITOR => 0;

sub new {
    my $class  = shift;
    my $params = shift;

    my $self =
      bless( { %$params, session => $Foswiki::Func::SESSION }, $class );

    $Foswiki::Func::SESSION->{MongoDB} = $self;
    return $self;
}

sub query {
    my $self           = shift;
    my $database       = shift;
    my $collectionName = shift;
    my $ixhQuery       = shift;
    my $queryAttrs     = shift || {};

    my $startTime = [Time::HiRes::gettimeofday];

    my $collection = $self->_getCollection($database, 'current');
    print STDERR "searching mongo : "
      . Dumper($ixhQuery) . " , "
      . Dumper($queryAttrs) . "\n"
      if MONITOR;

#debugging for upstream
#print STDERR "----------------------------------------------------------------------------------\n" if DEBUG;
my $db   = $self->_getDatabase( $database );
#$db->run_command({"profile" => 2});

#use Devel::Peek;
#Dump($db->run_command({"count" => 'current', "query" => $ixhQuery}));
#print STDERR "----------------------------------------------------------------------------------\n";
    my $long_count = $db->run_command({"count" => 'current', "query" => $ixhQuery});
    my $cursor = $collection->query( $ixhQuery, $queryAttrs );
    #TODO: this is to make sure we're getting the cursor->count before anyone uses the cursor.
    my $count = $long_count;
    if ($count > 100) {
        $cursor->{noCache} = 1;
        $cursor = $cursor->fields({_web=>1, _topic=>1});
    }

##    my $real_count = $cursor->count;

##if (($cursor->count == 0) and $cursor->has_next()) {
	#fake it
##	$real_count = $long_count->{n};
	$cursor->{real_count} = $long_count->{n};
##}

##use Data::Dumper;
##    print STDERR "found "
##      . $cursor->count
##      . " (long_count = ".Dumper($long_count).") "
##      . " _BUT_ has_next is "
##      . ( $cursor->has_next() ? 'true' : 'false' ) . "\n" if DEBUG;

#more debugging
#print STDERR "get_collection(system.profile)".Dumper($db->get_collection("system.profile")->find->all)."\n";
#$db->run_command({"profile" => 0});
#print STDERR "----------------------------------------------------------------------------------\n" if DEBUG;

    #end timer
    my $endTime = [Time::HiRes::gettimeofday];
    my $timeDiff = Time::HiRes::tv_interval( $startTime, $endTime );
    print STDERR "query took $timeDiff\n" if MONITOR;
    push(@{$Foswiki::Func::SESSION->{MongoDB}->{lastQueryTime}}, $timeDiff);

    return $cursor;
}

sub update {
    my $self           = shift;
    my $database       = shift;
    my $collectionName = shift;
    my $address        = shift;
    my $hash           = shift;

    #    use Data::Dumper;
    print STDERR "+++++ mongo update $address == ".Dumper($hash)."\n" if MONITOR;

    my $collection = $self->_getCollection($database, $collectionName);

#TODO: not the most efficient place to create and index, but I want to be sure, to be sure.
    $self->ensureIndex( $collection, { _topic => 1 }, { name => '_topic' } );
#    $self->ensureIndex(
#        $collection,
#        { _topic => 1,             _web   => 1 },
#        { name   => '_topic:_web', unique => 1 }
#    );
    $self->ensureIndex(
        $collection,
        { 'TOPICINFO.author' => 1 },
        { name               => 'TOPICINFO.author' }
    );
    $self->ensureIndex(
        $collection,
        { 'TOPICINFO.date' => 1 },
        { name             => 'TOPICINFO.date' }
    );
    $self->ensureIndex(
        $collection,
        { 'TOPICPARENT.name' => 1 },
        { name               => 'TOPICPARENT.name' }
    );

#TODO: maybe should use the auto indexed '_id' (or maybe we can use this as a tuid - unique foreach rev of each topic..)
#then again, atm, its totally random, so may be good for sharding.

    $collection->update(
        { address  => $address },
        { address  => $address, %$hash },
        { 'upsert' => 1 }
    );
}

#BUGGER. compound indexes won't help with large queries
#> db.current.dropIndexes();
#{
#	"nIndexesWas" : 2,
#	"msg" : "non-_id indexes dropped for collection",
#	"ok" : 1
#}
#> db.current.find().sort({_topic:1})
#error: {
#	"$err" : "too much data for sort() with no index.  add an index or specify a smaller limit",
#	"code" : 10128
#}
#> db.current.ensureIndex({_web:1, _topic:1, 'TOPICINFO.date':1, 'TOPICINFO.author': 1});
#> db.current.find().sort({_topic:1})
#error: {
#	"$err" : "too much data for sort() with no index.  add an index or specify a smaller limit",
#	"code" : 10128
#}
#>
#    $collection->ensure_index( { 'TOPICINFO.author' => 1, 'TOPICINFO.date' => 1, 'TOPICPARENT.name' => 1  } );
#    $collection->ensure_index( { 'TOPICINFO.author' => -1, 'TOPICINFO.date' => -1, 'TOPICPARENT.name' => -1  } );
#MongoDB's ensure_index causes the server to re0index, even if that index already exists, so we need to wrap it.
sub ensureIndex {
    my $self       = shift;
    my $collection = shift;#must be a collection obj
    my $indexRef   = shift;    #can be a hashref or an ixHash
    my $options    = shift;

    ASSERT( defined( $options->{name} ) ) if DEBUG;

    if ( ref($collection) eq '' ) {
die 'must convert $collection param to be a collection obj';
        #convert name of collection to collection obj
        #$collection = $self->_getCollection($database, $collection);
    }

    #cache the indexes we know about
    if ( not defined( $self->{mongoDBIndexes} ) ) {
        my @indexes = $collection->get_indexes();
        $self->{mongoDBIndexes} = \@indexes;
    }
    foreach my $index ( @{ $self->{mongoDBIndexes} } ) {

        #print STDERR "we already have:  ".$index->{name}." index\n";
        if ( $options->{name} eq $index->{name} ) {

            #already exists, do nothing.
            return;
        }
    }
    if ( scalar( @{ $self->{mongoDBIndexes} } ) >= 40 ) {
        print STDERR
"*******************ouch. MongoDB can only have 40 indexes per collection\n"
          if MONITOR;
        return;
    }
    print STDERR "creating " . $options->{name} . " index\n" if MONITOR;

    #TODO: consider doing these in a batch at the end of a request, or?
    $collection->ensure_index( $indexRef, $options );
    undef $self->{mongoDBIndexes};    #clear the cache :/
}


sub remove {
    my $self           = shift;
    my $database       = shift;
    my $collectionName = shift;
    my $mongoDbQuery           = shift;

    my $collection = $self->_getCollection($database, $collectionName);

    $collection->remove($mongoDbQuery);
}

sub updateSystemJS {
    my $self = shift;
    my $database       = shift;
    my $functionname = shift;
    my $sourcecode = shift;
    
    my $collection = $self->_getCollection($database, 'system.js');

use MongoDB::Code;
    my $code = MongoDB::Code->new('code' => $sourcecode);
   
    $collection->save(
        {
            _id => $functionname,
            value => $code
        }
    );
}


#######################################################
sub getDatabaseName {
    my $self           = shift;
    my $web       = shift;
    
    #using webname as database name, so we need to sanitise
    #replace / with __ and pre-pend foswiki__ ?
    $web =~ s/\//__/g;
    return 'foswiki__'.$web;
}
sub _getDatabase {
    my $self           = shift;
    my $database       = shift;
    
    my $connection = $self->_connect();
    return $connection->get_database( $self->getDatabaseName($database) );
}
sub _getCollection {
    my $self           = shift;
    my $database       = shift;
    my $collectionName = shift;
    
    my $db   = $self->_getDatabase($database);

    return $db->get_collection($collectionName);
}

sub _connect {
    my $self = shift;

    if ( not defined( $self->{connection} ) ) {
        $self->{connection} = MongoDB::Connection->new(
            host => $self->{host},
            port => $self->{port}
        );
        ASSERT( $self->{connection} ) if DEBUG;
    }
    return $self->{connection};
}

#I'm using this to test where i'm up to
sub _MONGODB {
    my $self   = shift;
    my $params = shift;

    my $web   = $params->{web};
    my $database = $web;
    my $topic = $params->{topic};

    my $collection = $self->_getCollection($database, 'current');
    my $data = $collection->find_one( { _web => $web, _topic => $topic } );

    use Foswiki::Plugins::MongoDBPlugin::Meta;
    my $meta =
      new Foswiki::Plugins::MongoDBPlugin::Meta( $self, $data->{_web},
        $data->{_topic}, $data );

    return $meta->stringify();

    #return join(', ', map { "$_: ".($data->{$_}||'UNDEF')."\n" } keys(%$data));
}

1;
__END__
This copyright information applies to the MongoDBPlugin:

# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright 2010 - SvenDowideit@fosiki.com
#
# MongoDBPlugin is # This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the root of this distribution.