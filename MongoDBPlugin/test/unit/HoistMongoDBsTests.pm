# Test for hoisting REs from query expressions
package HoistMongoDBsTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki::Query::Parser;
use Foswiki::Plugins::MongoDBPlugin::HoistMongoDB;
use Foswiki::Query::Node;
use Foswiki::Meta;
use Data::Dumper;
use strict;

use constant MONITOR => 0;

#list of operators we can output
my @MongoOperators = qw/$or $not $nin $in/;
#list of all Query ops
#TODO: build this from code?
my @QueryOps = qw/== != > < =~ ~/;

#TODO: use the above to test operator coverage - fail until we have full coverage.
#TODO: test must run _last_


sub do_Assert {
    my $this                 = shift;
    my $query                = shift;
    my $mongoDBQuery         = shift;
    my $expectedMongoDBQuery = shift;

    #    print STDERR "HoistS ",$query->stringify();
    print STDERR "HoistS ", Dumper($query) if MONITOR;
    print STDERR "\n -> /", Dumper($mongoDBQuery), "/\n" if MONITOR;

    $this->assert_deep_equals( $expectedMongoDBQuery, $mongoDBQuery );

   #try out converttoJavascript
   print STDERR "\nconvertToJavascript: \n".Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::convertToJavascript($mongoDBQuery)."\n" if MONITOR;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    my $meta = Foswiki::Meta->new( $this->{session}, 'Web', 'Topic' );
    $meta->putKeyed(
        'FILEATTACHMENT',
        {
            name    => "att1.dat",
            attr    => "H",
            comment => "Wun",
            path    => 'a path',
            size    => '1',
            user    => 'Junkie',
            rev     => '23',
            date    => '25',
        }
    );
    $meta->putKeyed(
        'FILEATTACHMENT',
        {
            name    => "att2.dot",
            attr    => "",
            comment => "Too",
            path    => 'anuvver path',
            size    => '100',
            user    => 'ProjectContributor',
            rev     => '105',
            date    => '99',
        }
    );
    $meta->put( 'FORM', { name => 'TestForm' } );
    $meta->put(
        'TOPICINFO',
        {
            author  => 'AlbertCamus',
            date    => '12345',
            format  => '1.1',
            version => '1.1913',
        }
    );
    $meta->put(
        'TOPICMOVED',
        {
            by   => 'AlbertCamus',
            date => '54321',
            from => 'BouvardEtPecuchet',
            to   => 'ThePlague',
        }
    );
    $meta->put( 'TOPICPARENT', { name => '' } );
    $meta->putKeyed( 'PREFERENCE', { name => 'Red',    value => '0' } );
    $meta->putKeyed( 'PREFERENCE', { name => 'Green',  value => '1' } );
    $meta->putKeyed( 'PREFERENCE', { name => 'Blue',   value => '0' } );
    $meta->putKeyed( 'PREFERENCE', { name => 'White',  value => '0' } );
    $meta->putKeyed( 'PREFERENCE', { name => 'Yellow', value => '1' } );
    $meta->putKeyed( 'FIELD',
        { name => "number", title => "Number", value => "99" } );
    $meta->putKeyed( 'FIELD',
        { name => "string", title => "String", value => "String" } );
    $meta->putKeyed(
        'FIELD',
        {
            name  => "StringWithChars",
            title => "StringWithChars",
            value => "n\nn t\tt s\\s q'q o#o h#h X~X \\b \\a \\e \\f \\r \\cX"
        }
    );
    $meta->putKeyed( 'FIELD',
        { name => "boolean", title => "Boolean", value => "1" } );
    $meta->putKeyed( 'FIELD', { name => "macro", value => "%RED%" } );

    $meta->{_text} = "Green ideas sleep furiously";

    $this->{meta} = $meta;
}

sub test_hoistSimple {
    my $this        = shift;
    my $s           = "number=99";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery, { 'FIELD.number.value' => '99' } );
}

sub test_hoistSimple_OP_Like {
    my $this        = shift;
    my $s           = "String~'.*rin.*'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);
    $this->do_Assert( $query, $mongoDBQuery,
        { 'FIELD.String.value' => qr/(?-xism:\..*rin\..*)/ } );
}

sub test_hoistSimple2 {
    my $this        = shift;
    my $s           = "99=number";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

#TODO: should really reverse these, but it is harder with strings - (i think the lhs in  'web.topic'/something is a string..
    $this->do_Assert( $query, $mongoDBQuery, { '99' => 'FIELD.number.value' } );
}

sub test_hoistOR {
    my $this        = shift;
    my $s           = "number=12 or string='bana'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert(
        $query,
        $mongoDBQuery,
        {
            '$or' => [
                { 'FIELD.number.value' => '12' },
                { 'FIELD.string.value' => 'bana' }
            ]
        }
    );
}

sub test_hoistOROR {
    my $this        = shift;
    my $s           = "number=12 or string='bana' or string = 'apple'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert(
        $query,
        $mongoDBQuery,
        {
            '$or' => [
                { 'FIELD.number.value' => '12' },
                { 'FIELD.string.value' => 'bana' },
                { 'FIELD.string.value' => 'apple' }
            ]
        }
    );
}

sub test_hoistBraceOROR {
    my $this        = shift;
    my $s           = "(number=12 or string='bana' or string = 'apple')";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert(
        $query,
        $mongoDBQuery,
        {
            '$or' => [
                { 'FIELD.number.value' => '12' },
                { 'FIELD.string.value' => 'bana' },
                { 'FIELD.string.value' => 'apple' }
            ]
        }
    );
}

sub test_hoistANDBraceOROR {
    my $this = shift;
    my $s =
      "(number=12 or string='bana' or string = 'apple') AND (something=12)";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert(
        $query,
        $mongoDBQuery,
        {
            'FIELD.something.value' => '12',
            '$or'                   => [
                { 'FIELD.number.value' => '12' },
                { 'FIELD.string.value' => 'bana' },
                { 'FIELD.string.value' => 'apple' }
            ]
        }
    );
}


sub test_hoistBraceANDBrace_OPTIMISE {
    my $this = shift;
    my $s    = "(TargetRelease = 'minor') AND (TargetRelease = 'minor')";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert(
        $query,
        $mongoDBQuery,
        {
            'FIELD.TargetRelease.value' => 'minor' 
        }
    );
}

#need to optimise it, as mongo cna't have 2 keys of the same name, its queries are a hash
sub test_hoistBraceANDBrace {
    my $this = shift;
    my $s    = "(TargetRelease != 'minor') AND (TargetRelease != 'major')";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert(
        $query,
        $mongoDBQuery,
        {
          'FIELD.TargetRelease.value' => {
                                           '$nin' => [
                                                       'minor',
                                                       'major'
                                                     ]
                                         }
        }
    );
}

sub test_hoistBrace {
    my $this        = shift;
    my $s           = "(number=12)";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery, { 'FIELD.number.value' => '12' } );
}

sub test_hoistAND {
    my $this        = shift;
    my $s           = "number=12 and string='bana'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert(
        $query,
        $mongoDBQuery,
        {
            'FIELD.number.value' => '12',
            'FIELD.string.value' => 'bana'
        }
    );
}

sub test_hoistANDAND {
    my $this        = shift;
    my $s           = "number=12 and string='bana' and something='nothing'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert(
        $query,
        $mongoDBQuery,
        {
            'FIELD.number.value'    => '12',
            'FIELD.something.value' => 'nothing',
            'FIELD.string.value'    => 'bana'
        }
    );
}

sub test_hoistSimpleFieldDOT {
    my $this        = shift;
    my $s           = "FIELD.number.bana = 12";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    #TODO: there's and assumption that the bit before the . is the form-name
    $this->do_Assert( $query, $mongoDBQuery, { 'FIELD.bana.value' => '12' } );
}
sub test_hoistMETAFieldDOT {
    my $this        = shift;
    my $s           = "META:FIELD.number.bana = 12";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    #TODO: there's and assumption that the bit before the . is the form-name
    $this->do_Assert( $query, $mongoDBQuery, { 'FIELD.bana.value' => '12' } );
}

sub test_hoistSimpleDOT {
    my $this        = shift;
    my $s           = "number.bana = 12";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    #TODO: there's and assumption that the bit before the . is the form-name
    $this->do_Assert( $query, $mongoDBQuery, { 'FIELD.bana.value' => '12' } );
}
sub test_hoistSimpleField {
    my $this        = shift;
    my $s           = "number = 12";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    #TODO: there's and assumption that the bit before the . is the form-name
    $this->do_Assert( $query, $mongoDBQuery, { 'FIELD.number.value' => '12' } );
}

sub test_hoistGT {
    my $this        = shift;
    my $s           = "number>12";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        { 'FIELD.number.value' => { '$gt' => '12' } } );
}

sub test_hoistGTE {
    my $this        = shift;
    my $s           = "number>=12";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        { 'FIELD.number.value' => { '$gte' => '12' } } );
}

sub test_hoistLT {
    my $this        = shift;
    my $s           = "number<12";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        { 'FIELD.number.value' => { '$lt' => '12' } } );
}

sub test_hoistLTE {
    my $this        = shift;
    my $s           = "number<=12";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        { 'FIELD.number.value' => { '$lte' => '12' } } );
}

sub test_hoistEQ {
    my $this        = shift;
    my $s           = "number=12";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery, { 'FIELD.number.value' => '12' } );
}

sub test_hoistNE {
    my $this        = shift;
    my $s           = "number!=12";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        { 'FIELD.number.value' => { '$ne' => '12' } } );
}

sub test_hoistNOT_EQ {
    my $this        = shift;
    my $s           = "not(number=12)";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);
    $this->do_Assert( $query, $mongoDBQuery,
        { 'FIELD.number.value' => { '$ne' => '12' } } );
}

sub test_hoistCompound {
    my $this = shift;
    my $s =
"number=99 AND string='String' and (moved.by='AlbertCamus' OR moved.by ~ '*bert*')";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);
    $this->do_Assert(
        $query,
        $mongoDBQuery,
        {
            'FIELD.number.value' => '99',
            '$or'                => [
                { 'TOPICMOVED.by' => 'AlbertCamus' },
                { 'TOPICMOVED.by' => qr/(?-xism:.*bert.*)/ }
            ],
            'FIELD.string.value' => 'String'
        }
    );
}

sub test_hoistCompound2 {
    my $this = shift;
    my $s =
"(moved.by='AlbertCamus' OR moved.by ~ '*bert*') AND number=99 AND string='String'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert(
        $query,
        $mongoDBQuery,
        {
            'FIELD.number.value' => '99',
            'FIELD.string.value' => 'String',
            '$or'                => [
                { 'TOPICMOVED.by' => 'AlbertCamus' },
                { 'TOPICMOVED.by' => qr/(?-xism:.*bert.*)/ }
            ]
        }
    );
}

sub test_hoistAlias {
    my $this        = shift;
    my $s           = "info.date=12345";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery, { 'TOPICINFO.date' => '12345' } );
}

sub test_hoistFormField {
    my $this        = shift;
    my $s           = "TestForm.number=99";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery, { 'FIELD.number.value' => '99' } );
}

sub test_hoistText {
    my $this        = shift;
    my $s           = "text ~ '*Green*'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);
    $this->do_Assert( $query, $mongoDBQuery,
        { '_text' => qr/(?-xism:.*Green.*)/ } );
}

sub test_hoistName {
    my $this        = shift;
    my $s           = "name ~ 'Web*'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        { '_topic' => qr/(?-xism:Web.*)/ } );
}

sub test_hoistName2 {
    my $this        = shift;
    my $s           = "name ~ 'Web*' OR name ~ 'A*' OR name = 'Banana'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert(
        $query,
        $mongoDBQuery,
        {
            '$or' => [
                { '_topic' => qr/(?-xism:Web.*)/ },
                { '_topic' => qr/(?-xism:A.*)/ },
                { '_topic' => 'Banana' }
            ]
        }
    );
}

sub test_hoistOP_Match {
    my $this        = shift;
    my $s           = "text =~ '.*Green.*'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        { '_text' => qr/(?-xism:.*Green.*)/ } );
}


sub test_hoistOP_Where {
    my $this        = shift;
    my $s           = "preferences[name='SVEN']";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

# db.current.find({ 'PREFERENCE.__RAW_ARRAY' : { '$elemMatch' : {'name' : 'SVEN' }}})

    $this->do_Assert( $query, $mongoDBQuery,
        { 'PREFERENCE.__RAW_ARRAY' => { '$elemMatch' => {'name' => 'SVEN' }}}
        );
}
#
sub test_hoistOP_Where1 {
    my $this        = shift;
    my $s           = "fields[value='FrequentlyAskedQuestion']";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

# db.current.find({ 'PREFERENCE.__RAW_ARRAY' : { '$elemMatch' : {'name' : 'SVEN' }}})

    $this->do_Assert( $query, $mongoDBQuery,
        {
          'FIELD.__RAW_ARRAY' => {
                                                    '$elemMatch' => {
                                                                      'value' => 'FrequentlyAskedQuestion'
                                                                    }
                                                  }
                                              }
        );
}
sub test_hoistOP_Where2 {
    my $this        = shift;
    my $s           = "META:FIELD[value='FrequentlyAskedQuestion']";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

# db.current.find({ 'PREFERENCE.__RAW_ARRAY' : { '$elemMatch' : {'name' : 'SVEN' }}})

    $this->do_Assert( $query, $mongoDBQuery,
        {
          'FIELD.__RAW_ARRAY' => {
                                                    '$elemMatch' => {
                                                                      'value' => 'FrequentlyAskedQuestion'
                                                                    }
                                                  }
                                              }
        );
}
sub test_hoistOP_Where3 {
    my $this        = shift;
    my $s           = "META:FIELD[name='TopicClassification' AND value='FrequentlyAskedQuestion']";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

# db.current.find({ 'PREFERENCE.__RAW_ARRAY' : { '$elemMatch' : {'name' : 'SVEN' }}})

    $this->do_Assert( $query, $mongoDBQuery,
    {
          'FIELD.__RAW_ARRAY' => {
                                   '$elemMatch' => {
                                                     'value' => 'FrequentlyAskedQuestion',
                                                     'name' => 'TopicClassification'
                                                   }
                                 }
        }
        );
}
sub test_hoistOP_Where4 {
    my $this        = shift;
    my $s           = "META:FIELD[name='TopicClassification'][value='FrequentlyAskedQuestion']";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

# db.current.find({ 'PREFERENCE.__RAW_ARRAY' : { '$elemMatch' : {'name' : 'SVEN' }}})

    $this->do_Assert( $query, $mongoDBQuery,
    {
          'FIELD.__RAW_ARRAY' => {
                                   '$elemMatch' => {
                                                     'value' => 'FrequentlyAskedQuestion',
                                                     'name' => 'TopicClassification'
                                                   }
                                 }
        }
        );
}
#i think this is meaninless, but i'm not sure.
sub test_hoistOP_preferencesDotName {
    my $this        = shift;
    my $s           = "preferences.name='BLAH'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        {  'PREFERENCE.name' => 'BLAH' } );
}

sub test_hoistORANDOR {
    my $this        = shift;
    my $s           = "(number=14 OR number=12) and (string='apple' OR string='bana')";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert(
        $query,
        $mongoDBQuery,
{
          'FIELD.number.value' => {
                                    '$in' => [
                                               '14',
                                               '12'
                                             ]
                                  },
          'FIELD.string.value' => {
                                    '$in' => [
                                               'apple',
                                               'bana'
                                             ]
                                  }
        }
    );
}

sub test_hoistLcRHSName {
    my $this        = shift;
    my $s           = "name = lc('WebHome')";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        {
            '$where' => "this._topic == foswiki_toLowerCase('WebHome')"
        }
        );
}


sub test_hoistLcLHSField {
    my $this        = shift;
    my $s           = "lc(Subject) = 'WebHome'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        {
            '$where' => "foswiki_toLowerCase(foswiki_getField(this, 'FIELD.Subject.value')) == 'WebHome'"
        }
        );
}

sub test_hoistLcLHSName {
    my $this        = shift;
    my $s           = "lc(name) = 'WebHome'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        {
            '$where' => "foswiki_toLowerCase(this._topic) == 'WebHome'"
        }
        );
}

sub DISABLEtest_hoistLcRHSLikeName {
#TODO: this requires the hoister to notice that its a constant and that it can pre-evaluate it
    my $this        = shift;
    my $s           = "name ~ lc('Web*')";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        { '_topic' => qr/(?-xism:web.*)/ } );
}


sub test_hoistLcLHSLikeName {
    my $this        = shift;
    my $s           = "lc(name) ~ 'Web*'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        {
            '$where' => "( /^Web.*\$/.test(foswiki_toLowerCase(this._topic)) )"
        }
        );
}

sub test_hoistLengthLHSName {
    my $this        = shift;
    my $s           = "length(name) = 12";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        {
            '$where' => "foswiki_length(this._topic) == 12"
        }
        );
}
sub test_hoistLengthLHSString {
    my $this        = shift;
    my $s           = "length('something') = 9";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        {
            '$where' => "foswiki_length('something') == 9"
        }
        );
}

sub test_hoistLengthLHSNameGT {
    my $this        = shift;
    my $s           = "length(name) < 12";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        {
            '$where' => "foswiki_length(this._topic) < 12"
        }
        );
}

sub test_hoist_d2n_value {
    my $this        = shift;
    my $s           = "d2n noatime";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        {
          '$where' => "foswiki_d2n(foswiki_getField(this, 'FIELD.noatime.value'))"
        }
        );
}

sub test_hoist_d2n_valueAND {
    my $this        = shift;
    my $s           = "d2n(noatime) and topic='WebHome'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        {
#TODO: need to figure out how to not make both into js
          '$where' => " ( (foswiki_d2n(foswiki_getField(this, 'FIELD.noatime.value'))) )  && foswiki_getField(this, 'FIELD.topic.value') == 'WebHome'"
#          '$where' => 'foswiki_d2n(this.FIELD.noatime.value)',
#          'FIELD.topic.value' => 'WebHome'
        }
        );
}

sub test_hoist_d2n {
    my $this        = shift;
    my $s           = "d2n(name) < d2n('1998-11-23')";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        {
           '$where' => "foswiki_d2n(this._topic) < foswiki_d2n('1998-11-23')"
        }
        );
}


sub test_hoist_Item10323_1 {
    my $this        = shift;
    my $s           = "lc(TermGroup)=~'bio'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        {
               '$where' => "( /bio/.test(foswiki_toLowerCase(foswiki_getField(this, 'FIELD.TermGroup.value'))) )"
        }
        );
}
sub test_hoist_Item10323_2 {
    my $this        = shift;
    my $s           = "lc(TermGroup)=~lc('bio')";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        {
#           '$where' => " (Regex('bio'.toLowerCase(), '').test(this.FIELD.TermGroup.value.toLowerCase())) "
#find a special case
            'FIELD.TermGroup.value' => qr/(?i-xsm:.*bio.*)/i
        }
        );
}

sub test_hoist_Item10323_2_not {
    my $this        = shift;
    my $s           = "not(lc(TermGroup)=~lc('bio'))";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        {
#          '$where' => "! (  ( (Regex('bio'.toLowerCase(), '').test(this.FIELD.TermGroup.value.toLowerCase())) )  ) "
          'FIELD.TermGroup.value' => {
                                       '$not' => qr/(?i-xsm:bio)/
                                     }

        }
        );
}

sub test_hoist_Item10323 {
    my $this        = shift;
    my $s           = "form.name~'*TermForm' AND lc(Namespace)=~lc('ant') AND lc(TermGroup)=~lc('bio')";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        {
          'FORM.name' => qr/(?-xism:^.*TermForm$)/,
#          '$where' => ' ( (Regex(\'ant\'.toLowerCase(), \'\').test(this.FIELD.Namespace.value.toLowerCase())) )  &&  ( (Regex(\'bio\'.toLowerCase(), \'\').test(this.FIELD.TermGroup.value.toLowerCase())) ) '
          'FIELD.TermGroup.value' => qr/(?i-xsm:bio)/,
          'FIELD.Namespace.value' => qr/(?i-xsm:ant)/
        }
        );
}

sub test_hoist_maths {
    my $this        = shift;
    my $s           = "(12-Namespace)<(24*60*60-5) AND (TermGroup DIV 12)>(WebScale*42.8)";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        {
           '$where' =>  " ( ((12)-(foswiki_getField(this, 'FIELD.Namespace.value')) < (((24)*(60))*(60))-(5)) )  &&  ((foswiki_getField(this, 'FIELD.TermGroup.value'))/(12) > (foswiki_getField(this, 'FIELD.WebScale.value'))*(42.8)) "
        }
        );
}

sub test_hoist_concat {
    my $this        = shift;
    my $s           = "'asd' + 'qwe' = 'asdqwe'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        {
           '$where' => '(\'asd\')+(\'qwe\') == \'asdqwe\''
        }
        );
}
#this one is a nasty perler-ism
sub test_hoist_concat2 {
    my $this        = shift;
    my $s           = "'2' + '3' = '5'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        {
           '$where' => '(2)+(3) == 5'
        }
        );
}
sub test_hoist_concat3 {
    my $this        = shift;
    my $s           = "2 + 3 = 5";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        {
           '$where' => '(2)+(3) == 5'
        }
        );
}

sub UNTRUE_test_hoist_shorthandPref {
    my $this        = shift;
    my $s           = "Red=12";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        {
                     'PREFERENCE.__RAW_ARRAY' => {
                                        '$elemMatch' => {
                                                          'value' => '12',
                                                          'name' => 'Red'
                                                        }
                                      }
        }
        );
}
sub test_hoist_longhandPref {
    my $this        = shift;
    my $s           = "preferences[value=12].Red";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        {
                     'PREFERENCE.__RAW_ARRAY' => {
                                        '$elemMatch' => {
                                                          'value' => '12',
                                                          'name' => 'Red'
                                                        }
                                      }
        }
        );
}
sub test_hoist_longhandField_value {
    my $this        = shift;
#see QueryTests::verify_meta_squabs_MongoDBQuery
    my $s           = "fields[name='number'].value";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        {
                     'FIELD.__RAW_ARRAY' => {
                                        '$elemMatch' => {
                                                          'name' => 'number'
                                                        }
                                      }
        }
        );
}


sub test_hoist_longhand2Pref {
    my $this        = shift;
    my $s           = "preferences[value=12 AND name='Red']";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        {
                     'PREFERENCE.__RAW_ARRAY' => {
                                        '$elemMatch' => {
                                                          'value' => '12',
                                                          'name' => 'Red'
                                                        }
                                      }
        }
        );
}

sub BROKENtest_hoist_PrefPlusAccessor {
    my $this        = shift;
    my $s           = "preferences[value=12].name = 'Red'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert( $query, $mongoDBQuery,
        {
                     'PREFERENCE.__RAW_ARRAY' => {
                                        '$elemMatch' => {
                                                          'value' => '12',
                                                          'name' => 'Red'
                                                        }
                                      }
        }
        );
}


#this is basically a SEARCH with both the topic= and excludetopic= set
sub test_hoistTopicNameIncludeANDNOExclude {
    my $this = shift;
    my $s =
      "name='Item' AND (something=12 or something=999 or something=123)";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert(
        $query,
        $mongoDBQuery,
        {
          '$or' => [
                     {
                       'FIELD.something.value' => '12'
                     },
                     {
                       'FIELD.something.value' => '999'
                     },
                     {
                       'FIELD.something.value' => '123'
                     }
                   ],
          '_topic' => 'Item'
            }
    );
}

sub test_hoistTopicNameNOIncludeANDExclude {
    my $this = shift;
    my $s =
      "(NOT(name='Item')) AND (something=12 or something=999 or something=123)";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert(
        $query,
        $mongoDBQuery,
        {
          '$or' => [
                     {
                       'FIELD.something.value' => '12'
                     },
                     {
                       'FIELD.something.value' => '999'
                     },
                     {
                       'FIELD.something.value' => '123'
                     }
                   ],
          '_topic' => { '$ne'=>'Item' }
            }
    );
}

sub test_hoistTopicNameNOIncludeANDExclude2 {
    my $this = shift;
    my $s =
      "((name!='Item')) AND (something=12 or something=999 or something=123)";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert(
        $query,
        $mongoDBQuery,
        {
          '$or' => [
                     {
                       'FIELD.something.value' => '12'
                     },
                     {
                       'FIELD.something.value' => '999'
                     },
                     {
                       'FIELD.something.value' => '123'
                     }
                   ],
          '_topic' => { '$ne'=>'Item' }
            }
    );
}

sub test_hoistTopicNameIncludeANDExclude {
    my $this = shift;
    my $s =
      "(name='Item' AND NOT name='ItemTemplate') AND (something=12 or something=999 or something=123)";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert(
        $query,
        $mongoDBQuery,
        {
          '$or' => [
                     {
                       'FIELD.something.value' => '12'
                     },
                     {
                       'FIELD.something.value' => '999'
                     },
                     {
                       'FIELD.something.value' => '123'
                     }
                   ],
#          '$where' => '! ( this._topic == \'ItemTemplate\' ) ',
          '_topic' => {
                        '$nin' => [
                                    'ItemTemplate'
                                  ],
                        '$in' => [
                                   'Item'
                                 ]
                      }
            }
    );
}

sub test_hoistTopicNameIncludeRegANDExclude {
    my $this = shift;
    my $s =
      "(name~'Item*' AND NOT name='ItemTemplate') AND (something=12 or something=999 or something=123)";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert(
        $query,
        $mongoDBQuery,
        {
          '$or' => [
                     {
                       'FIELD.something.value' => '12'
                     },
                     {
                       'FIELD.something.value' => '999'
                     },
                     {
                       'FIELD.something.value' => '123'
                     }
                   ],
#          '$where' => '! ( this._topic == \'ItemTemplate\' ) ',
          '_topic' => {
                        '$nin' => [
                                    'ItemTemplate'
                                  ],
                        '$in' => [
                                   qr/(?-xism:^Item.*$)/
                                 ]
                      }
            }
    );
}
sub test_hoistTopicNameIncludeRegANDExcludeReg {
    my $this = shift;
    my $s =
      "(name~'Item*' AND NOT name~'*Template') AND (something=12 or something=999 or something=123)";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert(
        $query,
        $mongoDBQuery,
        {
          '$or' => [
                     {
                       'FIELD.something.value' => '12'
                     },
                     {
                       'FIELD.something.value' => '999'
                     },
                     {
                       'FIELD.something.value' => '123'
                     }
                   ],
#          '$where' => '! ( ( /^.*Template$/.test(this._topic) ) ) ',
          '_topic' => {
                        '$nin' => [
                                    qr/(?-xism:^.*Template$)/
                                  ],
                        '$in' => [
                                   qr/(?-xism:^Item.*$)/
                                 ]
                      }
            }
    );
}

sub test_hoist_dateAndRelationship {
    my $this = shift;
    my $s = "form.name~'*RelationshipForm' AND ( (NOW - info.date) < (60*60*24*7))";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert(
        $query,
        $mongoDBQuery,
        {
#TODO: this is caused by the delay_function at line 360 of the hoister ('why')
#          'FORM.name' => qr/(?-xism:^.*RelationshipForm$)/,
#          '$where' => "(foswiki_getField(this, 'FIELD.NOW.value'))-(foswiki_getField(this, 'TOPICINFO.date')) < (((60)*(60))*(24))*(7)"
            '$where' => ' ( (( /^.*RelationshipForm$/.test(foswiki_getField(this, \'FORM.name\')) )) )  &&  ((foswiki_getField(this, \'FIELD.NOW.value\'))-(foswiki_getField(this, \'TOPICINFO.date\')) < (((60)*(60))*(24))*(7)) '
        }
    );
}

sub test_hoist_MultiAnd {
    my $this = shift;
#ignore that this could be optimised out - we're testing that the hoister manages to get the logic reasonalbe'
    my $s = "(name = 'fest' AND name = 'test' AND name = 'pest')";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert(
        $query,
        $mongoDBQuery,
        {
          '$where' => ' (this._topic == \'test\')  && this._topic == \'pest\'',
          '_topic' => 'fest'
        }
    );
   $this->assert_equals(
            " ( (this._topic == 'test')  && this._topic == 'pest')  && this._topic == 'fest'", 
            Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::convertToJavascript($mongoDBQuery)
            );
}

sub test_hoist_not_in {
#this tests a number of things, including that the 'not' actually goes around all the inner logic
    my $this = shift;
    my $s = "not(name = 'fest' AND name = 'test' AND name = 'pest')";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert(
        $query,
        $mongoDBQuery,
        {
          '$where' => '! (  ( (this._topic == \'test\')  && this._topic == \'pest\')  && this._topic == \'fest\' ) '
#            '$where' => {
#                '$ne' => " ( (this._topic == 'test')  && this._topic == 'pest')  && this._topic == 'fest'"
#            }
        }
    );
   $this->assert_equals(
            '! (  ( (this._topic == \'test\')  && this._topic == \'pest\')  && this._topic == \'fest\' ) ',
            Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::convertToJavascript($mongoDBQuery)
            );
}

sub test_hoist_not_in2 {
    my $this = shift;
    my $s = "not(name = 'fest') AND not(name = 'test') AND not(name = 'pest')";
#    my $s = "name != 'fest' AND name != 'test' AND name != 'pest'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert(
        $query,
        $mongoDBQuery,
        {
#          '$where' => ' ( (! ( this._topic == \'fest\' ) )  &&  (! ( this._topic == \'test\' ) ) )  &&  (! ( this._topic == \'pest\' ) ) '
#OR
#          '_topic' => {
#                        '$not' => {
#                                    '$in' => [
#                                               'fest',
#                                               'test',
#                                               'pest'
#                                             ]
#                                  }
#                      }
#OR
#TODO: the OP_and gets confused sometimes
          '$where' => 'this._topic != \'pest\'',
          '_topic' => {
                        '$nin' => [
                                    'fest',
                                    'test'
                                  ]
                      }

        }
    );
   $this->assert_equals(
#            " ( (this._topic ! == 'fest' || this._topic ! == 'test' || this._topic ! == 'pest' ) ) ", 
#            " ( ( (! ( this._topic == \'fest\' ) )  &&  (! ( this._topic == \'test\' ) ) )  &&  (! ( this._topic == \'pest\' ) ) ) ",
            " (this._topic != 'pest')  && ! ( this._topic == 'fest' || this._topic == 'test' ) ",
            Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::convertToJavascript($mongoDBQuery)
            );
}

sub test_hoist_ref {
    my $this = shift;
    my $s = "'AnotherTopic'/number = 12";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert(
        $query,
        $mongoDBQuery,
        {
          '$where' => "(foswiki_getField(foswiki_getRef(\'localhost\', foswiki_getDatabaseName(this._web)+\'.current\', this._web, 'AnotherTopic'), 'FIELD.number.value')) == 12"
          #"(foswiki_getRef('AnotherTopic').FIELD.number.value) == 12",
        }
    );
}

sub test_hoist_ref2 {
    my $this = shift;
    my $s = "Source/info.rev!=SourceRev";
#    my $s = "form.name='TaxonProfile.Relationships.RelationshipForm' AND Source/info.rev!=SourceRev";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert(
        $query,
        $mongoDBQuery,
        {
          '$where' => '(foswiki_getField(foswiki_getRef(\'localhost\', foswiki_getDatabaseName(this._web)+\'.current\', this._web, foswiki_getField(this, \'FIELD.Source.value\')), \'TOPICINFO.rev\')) != foswiki_getField(this, \'FIELD.SourceRev.value\')'

        }
    );
}
sub test_hoist_ref3 {
    my $this = shift;
    my $s = "SourceRev>Source/info.rev";
#    my $s = "form.name='TaxonProfile.Relationships.RelationshipForm' AND Source/info.rev!=SourceRev";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert(
        $query,
        $mongoDBQuery,
        {
          '$where' => 'foswiki_getField(this, \'FIELD.SourceRev.value\') > (foswiki_getField(foswiki_getRef(\'localhost\', foswiki_getDatabaseName(this._web)+\'.current\', this._web, foswiki_getField(this, \'FIELD.Source.value\')), \'TOPICINFO.rev\'))'
        }
    );
}
sub test_hoist_ref4 {
    my $this = shift;
    my $s = "form.name='TaxonProfile.Relationships.RelationshipForm' AND Source/info.rev!=SourceRev";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert(
        $query,
        $mongoDBQuery,
        {
          '$where' => ' ( (foswiki_getField(this, \'FORM.name\') == \'TaxonProfile.Relationships.RelationshipForm\') )  &&  ((foswiki_getField(foswiki_getRef(\'localhost\', foswiki_getDatabaseName(this._web)+\'.current\', this._web, foswiki_getField(this, \'FIELD.Source.value\')), \'TOPICINFO.rev\')) != foswiki_getField(this, \'FIELD.SourceRev.value\')) '
        }
    );
}

sub test_hoist_Item10515 {
    my $this = shift;
    my $s = "lc(Firstname)=lc('JOHN')";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert(
        $query,
        $mongoDBQuery,
        {
          '$where' => 'foswiki_toLowerCase(foswiki_getField(this, \'FIELD.Firstname.value\')) == foswiki_toLowerCase(\'JOHN\')'
        }
    );
}



#test written to match Fn_SEARCH::verify_formQuery2
#Item10520: in Sven's reading of System.QuerySearch, this should return no results, as there is no field of the name 'TestForm'
sub DISABLEtest_hoist_ImplicitFormNameBUG {
    my $this = shift;
    my $s = "FormName";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $mongoDBQuery =
      Foswiki::Plugins::MongoDBPlugin::HoistMongoDB::hoist($query);

    $this->do_Assert(
        $query,
        $mongoDBQuery,
        {
          '$where' => '(foswiki_getField(this, \'FIELD.FormName.name\') )'
        }
    );
}

1;