#!perl

use strict;
use warnings;
use utf8;
use Test::More tests => 23;
BEGIN { $ENV{DBIX_CONFIG_DIR} = "t" };


use AmuseWikiFarm::Schema;
use Git::Wrapper;
use File::Spec::Functions qw/catfile catdir/;
use Text::Amuse::Compile::Utils qw/write_file read_file append_file/;
use File::Path qw/make_path remove_tree/;
use Data::Dumper;
use File::Temp;

use lib catdir(qw/t lib/);
use AmuseWiki::Tests qw/create_site/;

my $site_id = '0gitz0';
my $schema = AmuseWikiFarm::Schema->connect('amuse');
my $site = create_site($schema, $site_id);
my $archive_git = $site->git;

ok ($site, "Created $site_id");

my ($log) = $archive_git->log;

is $log->message, "Initial AMuseWiki setup\n", "Found root git revision";

ok ($site->repo_is_under_git, "db knows about git");

ok (!$schema->resultset('Site')->find('0blog0')->repo_is_under_git,
    "But blog.amusewiki is not");

diag "creating a new revision";

my ($revision, $error) =
  $site->create_new_text({ uri => 'first-test',
                           title => 'Hello',
                           lang => 'hr',
                           textbody => '<p>http://my.org My "precious"</p>',
                         }, 'text');
ok ($revision->id);

$revision->edit({
                 fix_links => 1,
                 fix_typography => 1,
                 body => $revision->muse_body,
                });
my $expected_starting = 'http://my.org My "precious"';
my $expected = '[[http://my.org][my.org]] My „precious”';

like $revision->starting_file_body, qr/\Q$expected_starting\E/,
  "Correctly unfiltered";

like $revision->muse_body, qr/\Q$expected\E/, "Correctly filtered";

$revision->commit_version("\rGar\0ba\0ge\r\nGar\rba\0ge\0\0Garbage");

my $uri = $revision->publish_text;

ok($uri, "Publish revision returned the uri") and diag "Found $uri";

my @logs = $archive_git->log;

ok ((@logs == 4), "Found 4 commits");
{
    local $Data::Dumper::Useqq = 1;
    diag Dumper(\@logs);
}
my @garbage = grep { $_->message =~ m/Garbage.*Garbage.*Garbage/s } @logs;
ok ((@garbage == 3), "Found 3 commits with the garbage string");
# testing \0 is not needed, git would die anyway and not commit that
@garbage = grep { $_->message =~ m/[\r\0]/s } @logs;
ok (!@garbage, "No commit with \\r or \\0 inside, filter worked");

like $logs[0]->message, qr/Published revision \d+/, "Log message matches";

like $logs[1]->message, qr/Begin editing no\.\d+/, "Log message ok";

like $logs[2]->message, qr/Imported HTML/, "Log for html ok";


($revision, $error) =
  $site->create_new_text({ uri => 'first-test-xxxxxxx',
                      title => 'Hello',
                      lang => 'hr',
                      textbody => qq{\r<p>http://my.org My "precious"</p>},
                    }, 'text');
ok ($revision->id);

$revision->edit({ body  => $revision->muse_body });

is read_file($revision->original_html),
  qq{<p>http://my.org My "precious"</p>\n},
  "Body filtered from \r";

my $tmpfh = File::Temp->new;
my $tmpfile = $tmpfh->filename;
diag "Logging in $tmpfile";
$revision->commit_version;
$uri = $revision->publish_text(sub { append_file($tmpfile, @_) });
my $logged = read_file($tmpfile);

ok ($logged, "Found log: " . $logged);

ok ($uri);

@logs = $archive_git->log;

ok (@logs == 6, "Two new revisions");
like $logs[0]->message, qr/Begin editing/, "No published found";

my $text = $site->titles->find({ f_class => 'text',
                                 uri => 'first-test' });

ok($text, "Text found");
is ($text->recent_changes_uri, undef, "No recent_changes_uri");

$site->cgit_integration(1);
$site->update;

$text = $site->titles->find({ f_class => 'text',
                              uri => 'first-test' });


is ($text->recent_changes_uri, '/git/0gitz0/log/f/ft/first-test.muse',
    "URI for cgit is ok");

