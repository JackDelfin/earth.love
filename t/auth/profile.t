#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Test::More;
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use FindBin;

use lib "$FindBin::Bin/../../bin/lib";
use Orbit::Profile;
require Orbit::User;

sub slurp {
  my ($path) = @_;
  open(my $fh, '<:raw', $path) or die "Unable to read $path: $!";
  local $/;
  return <$fh>;
}

my $repo = File::Spec->catdir($FindBin::Bin, '..', '..');
my $tmp = tempdir(CLEANUP => 1);
my $domain = File::Spec->catdir($tmp, 'earth.love');
make_path(File::Spec->catdir($domain, '_WEB'));
make_path(File::Spec->catdir($domain, '_ORBIT'));

my $profile = Orbit::Profile->new(domain_dir => $domain);

subtest 'public profile fields reject markup and unsafe URLs' => sub {
  my ($ok, $reason) = $profile->validate_fields({
    bio => 'Hello from earth.love',
    pronouns => 'they/them',
    url => 'https://example.test/me',
    email => 'river@example.test',
    person => 'Jane.Doe',
  });
  ok($ok, 'ordinary public profile fields are accepted') or diag($reason);

  ($ok, $reason) = $profile->validate_fields({ bio => '<script>alert(1)</script>' });
  ok(!$ok, 'HTML in bio is rejected');
  like($reason, qr/markup/i, 'markup rejection explains itself');

  ($ok, $reason) = $profile->validate_fields({ bio => 'Hello #OML[EL_SHOW]#' });
  ok(!$ok, 'OML delimiters in bio are rejected');

  ($ok, $reason) = $profile->validate_fields({ url => 'http://example.test/' });
  ok(!$ok, 'http URLs are rejected');

  ($ok, $reason) = $profile->validate_fields({ person => 'Jane Doe' });
  ok($ok, 'person pointers may be WordBase phrases') or diag($reason);

  ($ok, $reason) = $profile->validate_fields({ person => 'Jane.Doe' });
  ok($ok, 'person pointers may be WordBase paths') or diag($reason);

  ($ok, $reason) = $profile->validate_fields({ person => 'jane/doe' });
  ok(!$ok, 'person pointers cannot contain slashes');

  ($ok, $reason) = $profile->validate_fields({ email => 'not-an-email' });
  ok(!$ok, 'invalid email is rejected');
};

subtest 'profile records stay inside the domain and ignore path tricks' => sub {
  ok(!defined($profile->read_public('../etc/passwd')), 'traversal usernames are ignored');
  ok(!defined($profile->read_public('river-editor/../admin')), 'slash usernames are ignored');
  eval { $profile->write_public('../etc/passwd', bio => 'no'); 1 };
  ok($@, 'write refuses an invalid username');

  my $saved = $profile->write_public(
    'river-editor',
    bio => 'Lives on earth.',
    pronouns => 'they/them',
    url => 'https://example.test/river',
    email => 'river@example.test',
    person => 'Jane Doe',
  );
  is($saved->{bio}, 'Lives on earth.', 'bio is stored');
  is($saved->{person}, 'jane doe', 'person phrases are stored in WordBase form');

  my $json = File::Spec->catfile($domain, '_ORBIT', '_PROFILE', 'river-editor.json');
  ok(-f $json && !-l $json, 'profile JSON is a regular file in _ORBIT/_PROFILE');
  unlike(slurp($json), qr/[<>#]/, 'stored JSON does not contain markup');

  my $outside = File::Spec->catfile($tmp, 'outside.json');
  open(my $fh, '>', $outside) or die "Unable to write $outside: $!";
  print {$fh} '{"bio":"leaked"}\n';
  close($fh);
  unlink $json or die "Unable to replace profile JSON: $!";
  symlink($outside, $json) or die "Unable to symlink profile JSON: $!";
  my $record = $profile->read_public('river-editor');
  is($record->{bio}, '', 'a symlink profile file is treated as empty rather than followed');
  is(slurp($outside), '{"bio":"leaked"}\n', 'symlink target is left untouched');
};

subtest 'avatars require image magic and stay under _WEB/_USERS' => sub {
  $profile->write_public('river-editor', bio => '', pronouns => '', url => '', email => '', person => '');
  eval { $profile->save_avatar('river-editor', '<html>not-an-image</html>'); 1 };
  like($@, qr/JPEG, PNG, GIF, or WebP/i, 'HTML is not accepted as an avatar');

  my $too_large = "\x89PNG\r\n\x1a\n" . ('A' x (512 * 1024));
  eval { $profile->save_avatar('river-editor', $too_large); 1 };
  like($@, qr/too large/i, 'oversized avatars are rejected');

  my $png = "\x89PNG\r\n\x1a\n" . ('P' x 64);
  my $saved = $profile->save_avatar('river-editor', $png);
  is($saved->{avatar}, 'avatar.png', 'PNG magic is stored as avatar.png');
  is($profile->avatar_url('river-editor'), '/_USERS/river-editor/avatar.png', 'avatar URL is web-served under /_USERS');
  my $path = File::Spec->catfile($domain, '_WEB', '_USERS', 'river-editor', 'avatar.png');
  ok(-f $path && !-l $path, 'avatar is a regular file in the public user directory');
  is(slurp($path), $png, 'avatar bytes are stored unchanged');

  unlink $path or die "Unable to replace avatar: $!";
  symlink('/etc/passwd', $path) or die "Unable to symlink avatar: $!";
  my $record = $profile->read_public('river-editor');
  is($record->{avatar}, '', 'a symlink avatar is ignored');

  $profile->save_avatar('river-editor', "GIF89a" . ('G' x 32));
  ok(-f File::Spec->catfile($domain, '_WEB', '_USERS', 'river-editor', 'avatar.gif'), 'GIF avatars are accepted');
  ok(!-e $path, 'previous avatar extension is removed');

  $profile->clear_avatar('river-editor');
  is($profile->read_public('river-editor')->{avatar}, '', 'clearing removes the avatar pointer');
};

subtest 'account templates and install wiring include the new routes' => sub {
  my $header = slurp(File::Spec->catfile($repo, 'bin', '_TEMPLATES', 'EL_HEADER.oml'));
  like($header, qr/#MSG\[Log on\]#/, 'logged-off header still offers Log on');
  like($header, qr/class="el-account"/, 'logged-on header uses an account menu');
  like($header, qr/#_ORBIT#elprofile/, 'account menu links to the public profile');
  like($header, qr/#_ORBIT#elsettings\?tab=profile/, 'account menu links to settings');
  like($header, qr/#_ORBIT#eladmin/, 'account menu links admins to administration');
  like($header, qr/#EQUAL\[#AUTH_IS_ADMIN#\]\[1\]/, 'Admin is shown only to administrators');
  like($header, qr/#MSG\[Switch account\]#/, 'account menu includes switch account');
  like($header, qr/#MSG\[Log off\]#/, 'account menu includes log off');
  unlike($header, qr/class="w3-bar/, 'account menu is not clipped inside a w3-bar');
  unlike($header, qr/<script/i, 'header account menu does not introduce script');

  my $user_pm = slurp(File::Spec->catfile($repo, 'bin', 'lib', 'Orbit', 'User.pm'));
  unlike($user_pm, qr/sub Orbit::Person\b/, 'User.pm does not shadow the Orbit::Person class');
  like($user_pm, qr/'Orbit::Person'->new/, 'person lookup is constructed with a quoted class name');
  unlike($user_pm, qr/sub Orbit::Profile\b/, 'User.pm does not shadow the Orbit::Profile class');
  like($user_pm, qr/'Orbit::Profile'->new/, 'profile storage is constructed with a quoted class name');

  {
    package Orbit;
    my $constructed = eval { 'Orbit::Profile'->new(domain_dir => $domain) };
    Test::More::ok(defined($constructed) && ref($constructed) eq 'Orbit::Profile',
      'quoted Orbit::Profile->new works from package Orbit');
  }

  my $orbit = bless { _DomainDir => $domain }, 'Orbit';
  my $svc = $orbit->_ProfileService;
  ok(defined($svc) && ref($svc) eq 'Orbit::Profile',
    'settings storage helper constructs Orbit::Profile');
  my $saved = $svc->write_public(
    'river-editor',
    bio => 'Saved from the settings helper',
    pronouns => '', url => '', email => '', person => '',
  );
  is($saved->{bio}, 'Saved from the settings helper', 'profile writes succeed through the settings helper');

  my $settings = slurp(File::Spec->catfile($repo, 'bin', '_TEMPLATES', 'EL_SETTINGS.oml'));
  like($settings, qr/#MSG\[Public Profile\]#/, 'settings includes the Public Profile tab');
  like($settings, qr/name="person"/, 'Public Profile can edit the linked person');
  like($settings, qr/<select[^>]*name="person"/, 'linked person is chosen from existing records');
  like($settings, qr/#MSG\[Create and link a person\]#/, 'settings offers create-and-link when allowed');
  unlike($settings, qr/placeholder="Jane\.Doe"/, 'linked person is no longer a free-text stub');
  like($settings, qr/name="email"/, 'Public Profile can edit email');
  like($settings, qr/name="bio"/, 'Public Profile can edit bio');
  like($settings, qr/name="pronouns"/, 'Public Profile can edit pronouns');
  like($settings, qr/name="url"/, 'Public Profile can edit URL');
  like($settings, qr/name="avatar"/, 'Public Profile can edit the profile picture');
  unlike($settings, qr/onchange=/, 'settings does not rely on inline JavaScript for preview');

  my $public = slurp(File::Spec->catfile($repo, 'bin', '_TEMPLATES', 'EL_PROFILE.oml'));
  like($public, qr/#PROFILE_PERSON_URL/, 'public profile can link to the Person record');
  like($public, qr/#MSG\[Edit profile\]#/, 'own profile offers Edit profile');
  like($public, qr/elsettings\?tab=profile/, 'Edit profile uses the same settings page');

  my $propagator = slurp(File::Spec->catfile($repo, 'bin', 'tools', 'PROPOGATE_earthlove.pl'));
  like($propagator, qr/elprofile\.pl/, 'propagator installs the public profile CGI');
  like($propagator, qr/elsettings\.pl/, 'propagator installs the settings CGI');
  like($propagator, qr/eladmin\.pl/, 'propagator installs the admin CGI');
  like($propagator, qr/Orbit\/Profile\.pm/, 'propagator installs the profile library');
  like($propagator, qr/Orbit\/Person\.pm/, 'propagator installs the person lookup library');

  my $sync = slurp(File::Spec->catfile($repo, 'bin', 'setup', 'el_sync_auth_templates.sh'));
  like($sync, qr/EL_PROFILE\.oml/, 'template sync publishes the profile page');
  like($sync, qr/EL_SETTINGS\.oml/, 'template sync publishes the settings page');
  like($sync, qr/EL_ADMIN\.oml/, 'template sync publishes the admin page');
  like($sync, qr/PERSONS\/EL_NEW_PERSON\.oml/, 'template sync publishes the person create form');
  like($sync, qr/PERSONS\/EL_SHOW_PERSON\.oml/, 'template sync publishes the person page');
};

done_testing;
