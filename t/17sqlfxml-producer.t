#!/usr/bin/perl -w
# vim:filetype=perl

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

local $^W = 0;

use strict;
use Test::More;
use Test::Exception;
use Test::SQL::Translator qw(maybe_plan);

use Data::Dumper;
my %opt;
BEGIN { map { $opt{$_}=1 if s/^-// } @ARGV; }
use constant DEBUG => (exists $opt{d} ? 1 : 0);
use constant TRACE => (exists $opt{t} ? 1 : 0);

use FindBin qw/$Bin/;

my $file = "$Bin/data/mysql/sqlfxml-producer-basic.sql";

local $SIG{__WARN__} = sub {
    CORE::warn(@_)
        unless $_[0] =~ m#XML/Writer#;
};

# Testing 1,2,3,4...
#=============================================================================

BEGIN {
    maybe_plan(14,
        'XML::Writer',
        'Test::Differences',
        'SQL::Translator::Producer::XML::SQLFairy');
}

use Test::Differences;
use SQL::Translator;
use SQL::Translator::Producer::XML::SQLFairy;

#
# basic stuff
#
{
my ($obj,$ans,$xml);

$ans = <<EOXML;
<schema name="" database="" xmlns="http://sqlfairy.sourceforge.net/sqlfairy.xml">
  <tables>
    <table name="Basic" order="1">
      <fields>
        <field name="id" data_type="integer" size="10" is_nullable="0" is_auto_increment="1" is_primary_key="1" is_foreign_key="0" order="1">
          <extra />
          <comments>comment on id field</comments>
        </field>
        <field name="title" data_type="varchar" size="100" is_nullable="0" default_value="hello" is_auto_increment="0" is_primary_key="0" is_foreign_key="0" order="2">
          <extra />
          <comments></comments>
        </field>
        <field name="description" data_type="text" size="65535" is_nullable="1" default_value="" is_auto_increment="0" is_primary_key="0" is_foreign_key="0" order="3">
          <extra />
          <comments></comments>
        </field>
        <field name="email" data_type="varchar" size="255" is_nullable="1" is_auto_increment="0" is_primary_key="0" is_foreign_key="0" order="4">
          <extra />
          <comments></comments>
        </field>
      </fields>
      <indices>
        <index name="titleindex" type="NORMAL" fields="title" options="" />
      </indices>
      <constraints>
        <constraint name="" type="PRIMARY KEY" fields="id" reference_table="" reference_fields="" on_delete="" on_update="" match_type="" expression="" options="" deferrable="1" />
        <constraint name="" type="UNIQUE" fields="email" reference_table="" reference_fields="" on_delete="" on_update="" match_type="" expression="" options="" deferrable="1" />
      </constraints>
    </table>
  </tables>
  <views></views>
  <triggers></triggers>
  <procedures></procedures>
</schema>
EOXML

$obj = SQL::Translator->new(
    debug          => DEBUG,
    trace          => TRACE,
    show_warnings  => 1,
    add_drop_table => 1,
    from           => "MySQL",
    to             => "XML-SQLFairy",
);
$xml = $obj->translate($file) or die $obj->error;
ok("$xml" ne ""                             ,"Produced something!");
print "XML:\n$xml" if DEBUG;
# Strip sqlf header with its variable date so we diff safely
$xml =~ s/^([^\n]*\n){7}//m;
eq_or_diff $xml, $ans, "XML looks right";

} # end basic stuff

#
# View
#
# Thanks to Ken for the schema setup lifted from 13schema.t
{
my ($obj,$ans,$xml);

$ans = <<EOXML;
<schema name="" database="" xmlns="http://sqlfairy.sourceforge.net/sqlfairy.xml">
  <tables></tables>
  <views>
    <view name="foo_view" fields="name,age" order="1">
      <sql>select name, age from person</sql>
    </view>
  </views>
  <triggers></triggers>
  <procedures></procedures>
</schema>
EOXML

    $obj = SQL::Translator->new(
        debug          => DEBUG,
        trace          => TRACE,
        show_warnings  => 1,
        add_drop_table => 1,
        from           => "MySQL",
        to             => "XML-SQLFairy",
    );
    my $s      = $obj->schema;
    my $name   = 'foo_view';
    my $sql    = 'select name, age from person';
    my $fields = 'name, age';
    my $v      = $s->add_view(
        name   => $name,
        sql    => $sql,
        fields => $fields,
        schema => $s,
    ) or die $s->error;

    # As we have created a Schema we give translate a dummy string so that
    # it will run the produce.
    lives_ok {$xml =$obj->translate("FOO");} "Translate (View) ran";
    ok("$xml" ne ""                             ,"Produced something!");
    print "XML attrib_values=>1:\n$xml" if DEBUG;
    # Strip sqlf header with its variable date so we diff safely
    $xml =~ s/^([^\n]*\n){7}//m; 
    eq_or_diff $xml, $ans                       ,"XML looks right";
} # end View

#
# Trigger
#
# Thanks to Ken for the schema setup lifted from 13schema.t
{
my ($obj,$ans,$xml);

$ans = <<EOXML;
<schema name="" database="" xmlns="http://sqlfairy.sourceforge.net/sqlfairy.xml">
  <tables></tables>
  <views></views>
  <triggers>
    <trigger name="foo_trigger" database_event="insert" on_table="foo" perform_action_when="after" order="1">
      <action>update modified=timestamp();</action>
    </trigger>
  </triggers>
  <procedures></procedures>
</schema>
EOXML

    $obj = SQL::Translator->new(
        debug          => DEBUG,
        trace          => TRACE,
        show_warnings  => 1,
        add_drop_table => 1,
        from           => "MySQL",
        to             => "XML-SQLFairy",
    );
    my $s                   = $obj->schema;
    my $name                = 'foo_trigger';
    my $perform_action_when = 'after';
    my $database_event      = 'insert';
    my $on_table            = 'foo';
    my $action              = 'update modified=timestamp();';
    my $t                   = $s->add_trigger(
        name                => $name,
        perform_action_when => $perform_action_when,
        database_event      => $database_event,
        on_table            => $on_table,
        action              => $action,
    ) or die $s->error;

    # As we have created a Schema we give translate a dummy string so that
    # it will run the produce.
    lives_ok {$xml =$obj->translate("FOO");} "Translate (Trigger) ran";
    ok("$xml" ne ""                             ,"Produced something!");
    print "XML attrib_values=>1:\n$xml" if DEBUG;
    # Strip sqlf header with its variable date so we diff safely
    $xml =~ s/^([^\n]*\n){7}//m; 
    eq_or_diff $xml, $ans                       ,"XML looks right";
} # end Trigger

#
# Procedure
#
# Thanks to Ken for the schema setup lifted from 13schema.t
{
my ($obj,$ans,$xml);

$ans = <<EOXML;
<schema name="" database="" xmlns="http://sqlfairy.sourceforge.net/sqlfairy.xml">
  <tables></tables>
  <views></views>
  <triggers></triggers>
  <procedures>
    <procedure name="foo_proc" parameters="foo,bar" owner="Nomar" order="1">
      <sql>select foo from bar</sql>
      <comments>Go Sox!</comments>
    </procedure>
  </procedures>
</schema>
EOXML

    $obj = SQL::Translator->new(
        debug          => DEBUG,
        trace          => TRACE,
        show_warnings  => 1,
        add_drop_table => 1,
        from           => "MySQL",
        to             => "XML-SQLFairy",
    );
    my $s          = $obj->schema;
    my $name       = 'foo_proc';
    my $sql        = 'select foo from bar';
    my $parameters = 'foo, bar';
    my $owner      = 'Nomar';
    my $comments   = 'Go Sox!';
    my $p          = $s->add_procedure(
        name       => $name,
        sql        => $sql,
        parameters => $parameters,
        owner      => $owner,
        comments   => $comments,
    ) or die $s->error;

    # As we have created a Schema we give translate a dummy string so that
    # it will run the produce.
    lives_ok {$xml =$obj->translate("FOO");} "Translate (Procedure) ran";
    ok("$xml" ne ""                             ,"Produced something!");
    print "XML attrib_values=>1:\n$xml" if DEBUG;
    # Strip sqlf header with its variable date so we diff safely
    $xml =~ s/^([^\n]*\n){7}//m; 
    eq_or_diff $xml, $ans                       ,"XML looks right";
} # end Procedure

#
# Field.extra
#
{
my ($obj,$ans,$xml);

$ans = <<EOXML;
<schema name="" database="" xmlns="http://sqlfairy.sourceforge.net/sqlfairy.xml">
  <tables>
    <table name="Basic" order="2">
      <fields>
        <field name="foo" data_type="integer" size="10" is_nullable="1" is_auto_increment="0" is_primary_key="0" is_foreign_key="0" order="5">
          <extra ZEROFILL="1" />
          <comments></comments>
        </field>
      </fields>
      <indices></indices>
      <constraints></constraints>
    </table>
  </tables>
  <views></views>
  <triggers></triggers>
  <procedures></procedures>
</schema>
EOXML

    $obj = SQL::Translator->new(
        debug          => DEBUG,
        trace          => TRACE,
        show_warnings  => 1,
        add_drop_table => 1,
        from           => "MySQL",
        to             => "XML-SQLFairy",
    );
    my $s = $obj->schema;
    my $t = $s->add_table( name => "Basic" ) or die $s->error;
    my $f = $t->add_field(
        name      => "foo",
        data_type => "integer",
        size      => "10",
    ) or die $t->error;
    $f->extra(ZEROFILL => "1");

    # As we have created a Schema we give translate a dummy string so that
    # it will run the produce.
    lives_ok {$xml =$obj->translate("FOO");} "Translate (Field.extra) ran";
    ok("$xml" ne ""                             ,"Produced something!");
    print "XML:\n$xml" if DEBUG;
    # Strip sqlf header with its variable date so we diff safely
    $xml =~ s/^([^\n]*\n){7}//m;
    eq_or_diff $xml, $ans                       ,"XML looks right";
} # end extra
