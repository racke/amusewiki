#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use lib 'lib';
use AmuseWikiFarm::Schema;
use Data::Dumper;
use Try::Tiny;
use Cwd;

# load the db

my $schema = AmuseWikiFarm::Schema->connect('amuse');

die "Couldn't load the schema! Please check dbic.yaml!\n" unless $schema;

# try if we have tables in this db. If so, bail out.

print "BEWARE! I'm going to recreate the database from scratch!\n";
print qq{Are you sure you want to continue? Please type "YES": };

my $answer = ask_user();

if ($answer eq 'YES') {
    $schema->deploy;
}
else {
    print "Ok, bailing out\n";
    exit;
}



if (my @sites = $schema->resultset('Site')->all) {
    die "There are already sites in this database, aborting\n";
}

if (my @users = $schema->resultset('User')->all) {
    die "There are already user in this database, aborting\n";
}


# we need to collect some details
print <<EOF;

The database is ready.

First we need to create a site. We need an host and a site code. The
site code should be alphanumerical only, without any special
character, should not start with a zero (reserved for testing) and
have a maximum length of 16 characters, while the host should point to
your server (without any protocol).

EOF

print qq{Please type the site's host (e.g. "example.org"): };
my $host = ask_user();
if ($host =~ m/^\s*([a-z0-9-]+(\.[a-z0-9-]+)*)\s*$/) {
    $host = $1;
    print qq{Host is "$host"\n};
}
else {
    die "Host name doesn't look valid\n";
}

print qq{Please type the site code (e.g. "mywiki"): };
my $site_id = ask_user();
if ($site_id =~ m/^\s*([1-9a-z][0-9a-z]{1,15})\s*$/) {
    $site_id = $1;
    print qq{Site code is "$site_id"\n};
}
else {
    die "Site code contains illegal characters\n";
}

print <<EOF;

Now we need to create a root user, which should be able to create
librarians and new sites. Username should be alphanumerical only,
lowercase, without any special character. For the initial password,
please avoid non-ascii characters. Later you can change it on the web
interface and set it to whatever you want.

EOF

print "Root account username: ";
my $username = ask_user();

if ($username =~ m/\s*([a-z0-9]+)\s*/) {
    $username = $1;
}
else {
    die qq{Bad username "$username"\n};
}

print "Root account password: ";
my $password = ask_user();

if ($password =~ m/^[[:ascii:]]+$/) {
    
}
else {
    die qq{Bad password, non ascii\n};
}

print <<"EOF";
Summary of the initial setup:

Host: $host
Site ID: $site_id
Root username: $username
Root password: $password

EOF

print "Does it look good? (type YES if correct): ";
my $confirm = ask_user();

if ($confirm eq 'YES') {
    print "Creating the site\n";
}
else {
    die "Aborting\n";
}

my $site = $schema->resultset('Site')->create({
                                               id => $site_id,
                                               canonical => $host,
                                              });

if ($site->initialize_git) {
    print "An stub repository has been created at " . $site->repo_root . "\n";
}

my $user = $schema->resultset('User')->create({
                                               username => $username,
                                               password => $password,
                                              });
$user->set_roles([{ role => 'root' }]);

print "\n";

print "########## START NGINX configuration ##########\n\n";

print <<"EOF";

All done, please configure the webserver. If you use nginx, you can
execute:

 ./script/generate-nginx-conf.pl

which will generate a suitable configuration for nginx.

After the webserver is configured, you can now start the app with

 ./init-all start.

You may want to login at http://$host/login and then edit the site
configuration at http://$host/admin/sites/edit/$site_id

After the site configuration, you should bootstrap the repository with

 ./script/bootstrap_archive.pl

EOF

sub ask_user {
    my $reply = <>;
    chomp $reply;
    return $reply;
}


