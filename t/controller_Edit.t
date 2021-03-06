#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
BEGIN { $ENV{DBIX_CONFIG_DIR} = "t" };

use Test::More tests => 43;
use AmuseWikiFarm::Schema;
use File::Spec::Functions qw/catfile catdir/;
use lib catdir(qw/t lib/);
use AmuseWiki::Tests qw/create_site/;
use Test::WWW::Mechanize::Catalyst;

my $builder = Test::More->builder;
binmode $builder->output,         ":utf8";
binmode $builder->failure_output, ":utf8";
binmode $builder->todo_output,    ":utf8";


my $schema = AmuseWikiFarm::Schema->connect('amuse');
my $site_id = '0edit1';
my $site = create_site($schema, $site_id);
ok ($site);
my $host = $site->canonical;
my $mech = Test::WWW::Mechanize::Catalyst->new(catalyst_app => 'AmuseWikiFarm',
                                               host => $host);

$mech->get_ok('/action/text/new');
ok($mech->form_id('login-form'), "Found the login-form");
$mech->set_fields(username => 'root',
                  password => 'root');
$mech->click;
$mech->content_contains('You are logged in now!');

diag "Uploading a text";
my $title = 'test-fixes';
ok($mech->form_id('ckform'), "Found the form for uploading stuff");
$mech->set_fields(author => 'pippo',
                  title => $title,
                  textbody => "\n");

$mech->click;

$mech->content_contains('Created new text');

diag "In " . $mech->response->base->path;

$mech->form_id('museform');

my %expected = (
                en => q{“hello” l’albero l’“adesso” ‘adesso’},
                fi => q{”hello” l’albero l’”adesso” ’adesso’},
                it => q{“hello” l’albero l’“adesso” ‘adesso’},
                hr => q{„hello” l’albero l’„adesso” ‘adesso’},
                mk => q{„hello“ l’albero l’„adesso“ ’adesso‘},
                sr => q{„hello“ l’albero l’„adesso“ ’adesso’},
                es => q{«hello» l’albero l’«adesso» ‘adesso’},
                ru => q{«hello» l’albero l’«adesso» ‘adesso’},
               );

$mech->tick(fix_links => 1);
$mech->tick(fix_typography => 1);
$mech->tick(fix_footnotes => 1);
$mech->tick(fix_nbsp => 1);
$mech->tick(remove_nbsp => 1);

foreach my $lang (keys %expected) {
    my $body =<<"EOF";
#title $title
#lang $lang

"hello" l'albero l'"adesso" 'adesso' [2]

[3] footnote http://amusewiki.org nbsp nbsp removed
EOF
    $mech->form_id('museform');
    $mech->field(body => $body);
    $mech->click('preview');
    $mech->form_id('museform');
    my $got_body = $mech->value('body');
    like $got_body, qr/\Q$expected{$lang}\E \[1\]/;
    $mech->content_contains($expected{$lang} . ' [1]');
    my $exp_string =
      q{[1] footnote [[http://amusewiki.org][amusewiki.org]] nbsp nbsp removed};
    like $got_body, qr/\Q$exp_string\E/, "links, nbsp, footnotes fixed";
}

my $off_before =<<'EOF';
#title Title
#lang en

"hello" l'albero l'"adesso" 'adesso' [2] [3]

[3] footnote http://amusewiki.org nbsp nbsp removed
EOF

my $off_after =<<'EOF';
#title Title
#lang en

"hello" l'albero l'"adesso" 'adesso' [2] [3]

[3] footnote http://amusewiki.org nbsp nbsp removed

[4] footnote

[4] blablabla
EOF


foreach my $muse_body ($off_before, $off_after) {
    $mech->form_id('museform');
    $mech->untick(fix_links => 1);
    $mech->untick(fix_typography => 1);
    $mech->untick(fix_footnotes => 1);
    $mech->untick(fix_nbsp => 1);
    $mech->untick(remove_nbsp => 1);
    $mech->field(body => $muse_body);
    $mech->click('preview');
    $mech->form_id('museform');
    $mech->tick(fix_footnotes => 1);
    $mech->field(body => $muse_body);
    $mech->click('preview');
    $mech->form_id('museform');
    is $mech->value('body'), $muse_body, "Changes ignored";
    $mech->content_like(qr/Footnotes mismatch: found .+ footnotes .+ and found .+ footnote/);
}

diag "Testing the timestamp";
$mech->get_ok('/action/text/new');
ok($mech->form_id('ckform'), "Found the form for uploading stuff");
my $date = '2014-11-11 11:11';
$mech->set_fields(title => "custom timestamp",
                  pubdate => $date);
$mech->click;
$mech->content_contains("#pubdate 2014-11-11") or diag $mech->content;

diag "Testing the js validation";
$mech->content_contains(q[$("#rev-message").rules('add', "required");]);
$mech->content_contains(q[message: "required",]);
my $editing = $mech->uri->path;
$mech->get_ok("/admin/sites/edit/$site_id/");
$mech->submit_form(with_fields => {
                                   do_not_enforce_commit_message => 'on',
                                  },
                   button => 'edit_site');
$mech->get_ok($editing);
$mech->content_lacks(q[$("#rev-message").rules('add', "required");]);
$mech->content_lacks(q[message: "required",]);
