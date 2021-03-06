#!perl

use strict;
use warnings;

use Test::More tests => 15;
BEGIN { $ENV{DBIX_CONFIG_DIR} = "t" };

use File::Spec::Functions qw/catfile catdir/;
use lib catdir(qw/t lib/);
use AmuseWiki::Tests qw/create_site/;
use AmuseWikiFarm::Schema;
use Test::WWW::Mechanize::Catalyst;
use Data::Dumper;

my $schema = AmuseWikiFarm::Schema->connect('amuse');

my $site_id = '0ssl0';
my $site = create_site($schema, $site_id);

$site->update({ secure_site => 1});

my $mech = Test::WWW::Mechanize::Catalyst->new(catalyst_app => 'AmuseWikiFarm',
                                               host => "$site_id.amusewiki.org");

$mech->get_ok('/');
is $mech->uri->scheme, 'http', "Getting the root leads to a plain site";
$mech->get_ok('/login');
is $mech->uri->scheme, 'https', "/login redirects to secure site";

# login then

ok($mech->submit_form(with_fields => {username => 'root', password => 'root' },
                      button => 'submit'), "Found the form");

is $mech->uri->scheme, 'https', 'still in https';

$mech->get_ok("http://$site_id.amusewiki.org/admin/sites");
is $mech->uri->scheme, 'https', 'still in https despite being asked a plain one';
$mech->get_ok("http://$site_id.amusewiki.org/");
is $mech->uri->scheme, 'https', "Authenticated can't get a plain page";
$mech->get_ok('/logout');
$mech->get_ok("http://$site_id.amusewiki.org");
is $mech->uri->scheme, 'http', "Non authenticated can get a plain page";
$mech->get_ok("http://$site_id.amusewiki.org/login");
is $mech->uri->scheme, 'https', "Login is ssl again";


