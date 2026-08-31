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
use Orbit::Person;
use Orbit::Auth;
use Orbit::Profile;
require Orbit::User;

{
  package Local::PersonCrypto;
  sub new { bless {}, shift }
  sub random_bytes { return "\x11" x $_[1] }
  sub hash_passphrase { return '$argon2id$mock$'.$_[1] }
  sub verify_passphrase { return $_[1] eq '$argon2id$mock$'.$_[2] }
  sub needs_rehash { return 0 }
}

sub write_file {
  my ($path, $contents) = @_;
  open(my $fh, '>:utf8', $path) or die "Unable to write $path: $!";
  print {$fh} $contents;
  close($fh) or die "Unable to close $path: $!";
}

sub make_person {
  my ($domain, $word, $name) = @_;
  my $persons = File::Spec->catdir($domain, 'PERSONS');
  my $dir;
  if ($word =~ /\./) {
    $dir = File::Spec->catdir($persons, '_PATHS', reverse split(/\./, $word));
  }
  elsif ($word =~ / /) {
    $dir = File::Spec->catdir($persons, '_PHRASES', split(/ /, $word));
  }
  else {
    $dir = File::Spec->catdir($persons, '_WORDS', split(//, $word), $word);
  }
  make_path($dir);
  write_file(File::Spec->catfile($dir, 'PERSON.dat'), $word."\n");
  write_file(File::Spec->catfile($dir, 'NAME.dat'), $name."\n");
  return $dir;
}

my $tmp = tempdir(CLEANUP => 1);
my $domain = File::Spec->catdir($tmp, 'earth.love');
make_path(File::Spec->catdir($domain, 'PERSONS'));
make_path(File::Spec->catdir($domain, '_ORBIT'));
make_path(File::Spec->catdir($domain, '_WEB'));

make_person($domain, 'jane doe', 'Jane Doe');
make_person($domain, 'madonna', 'Madonna');
make_path(File::Spec->catdir($domain, 'PERSONS', '_WORDS', 'j', 'a', 'n', 'e', 'jane'));
write_file(File::Spec->catfile($domain, 'PERSONS', '_WORDS', 'j', 'a', 'n', 'e', 'jane', 'WORD.dat'), "jane\n");
write_file(File::Spec->catfile($domain, 'PERSONS', 'DOWN.dat'), join("\n",
  'jane doe',
  'jane',
  'doe',
  'madonna',
  'nobody here',
)."\n");

my $people = Orbit::Person->new(domain_dir => $domain);

subtest 'person words match WordBase grammar' => sub {
  is(Orbit::Person->normalize('Jane Doe'), 'jane doe', 'phrases are lowercased');
  is(Orbit::Person->normalize('Jane.Doe'), 'jane.doe', 'paths keep their dots');
  is(Orbit::Person->normalize('jane_doe'), 'jane doe', 'underscores become phrase spaces');
  is(Orbit::Person->normalize(''), '', 'an empty pointer unlinks');
  ok(!defined(Orbit::Person->normalize('jane/doe')), 'slashes are rejected');
  ok(!defined(Orbit::Person->normalize('jane doe!')), 'punctuation is rejected');
};

subtest 'lookup lists only created PERSONS records' => sub {
  ok($people->exists('Jane Doe'), 'a created phrase exists');
  ok($people->exists('madonna'), 'a created word exists');
  ok(!$people->exists('jane'), 'component words without PERSON.dat are not people');
  ok(!$people->exists('nobody here'), 'DOWN.dat names without a record are ignored');
  is($people->display_name('jane doe'), 'Jane Doe', 'NAME.dat is the public name');

  my $list = $people->list_records;
  is_deeply(
    [ map { $_->{word} } @$list ],
    [ 'jane doe', 'madonna' ],
    'the picker lists created people and not index debris',
  );
  is($list->[0]{name}, 'Jane Doe', 'the picker shows the Person full name');
  like($list->[0]{url}, qr/w=jane\+doe/, 'the Person URL uses the WordBase word');
};

subtest 'linking requires an unclaimed existing person' => sub {
  my $auth = Orbit::Auth->new(
    domain_dir => $domain,
    now => sub { 1_700_000_000 },
    crypto_provider => Local::PersonCrypto->new(),
  );
  ok($auth->initialize, 'auth store initializes');
  $auth->provision_account('river-editor', 'a unique editor passphrase', role => 'editor');
  $auth->provision_account('sky-watcher', 'a unique admin passphrase', role => 'admin');

  my $orbit = bless {
    _DomainDir => $domain,
    _Auth      => $auth,
    _User      => 'river-editor',
    _Role      => 'editor',
  }, 'Orbit';

  my $word = $orbit->_AssertPersonLinkable('river-editor', 'Jane Doe');
  is($word, 'jane doe', 'an existing unclaimed person can be linked');
  eval { $orbit->_AssertPersonLinkable('river-editor', 'missing person'); 1 };
  like($@, qr/not been created/i, 'missing people cannot be typed in');

  $orbit->_BindPersonToUser('river-editor', 'Jane Doe');
  is($auth->read_account('river-editor')->{person}, 'jane doe', 'the account stores the Person word');
  my $profile = Orbit::Profile->new(domain_dir => $domain);
  is($profile->read_public('river-editor')->{person}, 'jane doe', 'the public profile stores the same pointer');

  eval { $orbit->_BindPersonToUser('sky-watcher', 'Jane Doe'); 1 };
  like($@, qr/already linked/i, 'a second account cannot claim the same person');

  my $claimed = $orbit->_ClaimedPersonMap($auth->list_accounts);
  is($claimed->{'jane doe'}, 'river-editor', 'the reverse map follows the Auth person pointer');

  my $options = $orbit->_UserSelectOptions('', $auth->list_accounts);
  like($options, qr/value="sky-watcher"/, 'unlinked users appear in the person-page picker');
  like($options, qr/value="river-editor"/, 'already-linked users still appear for administrators');
  like($options, qr/Jane Doe/, 'linked users show their current Person');

  my $before_auth = bless { _Root => 'PERSONS' }, 'Orbit';
  is(
    $before_auth->_PublishPersonPageIfCurrent(),
    0,
    'Person-page tokens wait until Auth exists',
  );

  $orbit->{_Root} = 'PERSONS';
  $orbit->{_tok} = {};
  my %page = (
    ROOT         => 'PERSONS',
    WORD         => 'jane doe',
    _WORDFOUND_  => '1',
  );
  no warnings qw(redefine once);
  local *Orbit::Get_Token = sub {
    my ($self, $name) = @_;
    return $self->{_tok}{$name} if defined($self->{_tok}) && exists $self->{_tok}{$name};
    return $page{$name} if exists $page{$name};
    return '';
  };
  local *Orbit::Set_Token = sub {
    my ($self, $name, $value) = @_;
    $self->{_tok}{$name} = defined($value) ? $value : '';
    return $self->{_tok}{$name};
  };
  local *Orbit::SetUntrustedToken = sub {
    my ($self, $name, $value) = @_;
    $self->{_tok}{$name} = defined($value) ? $value : '';
    return $self->{_tok}{$name};
  };

  ok($orbit->_PublishPersonPageIfCurrent(), 'Person-page tokens publish after Auth exists');
  is($orbit->{_tok}{PERSON_LINKED_USER}, 'river-editor', 'the Person page names the linked user');
  like(
    $orbit->{_tok}{PERSON_LINKED_PROFILE_URL},
    qr/elprofile\?u=river-editor/,
    'the Person page links to the user profile',
  );

  $page{WORD} = 'madonna';
  $orbit->{_tok} = {};
  ok($orbit->_PublishPersonPageIfCurrent('madonna'), 'an unlinked Person still publishes tokens');
  is($orbit->{_tok}{PERSON_LINKED_USER}, '', 'an unlinked Person has no user');
  like($orbit->{_tok}{PERSON_USER_OPTIONS}, qr/value="sky-watcher"/, 'the empty Person lists existing users');
  like($orbit->{_tok}{PERSON_USER_OPTIONS}, qr/value="river-editor"/, 'the empty Person lists already-linked users');
};

subtest 'templates offer lookup and create-and-link instead of free text' => sub {
  my $repo = File::Spec->catdir($FindBin::Bin, '..', '..');
  sub slurp_text {
    my ($path) = @_;
    open(my $fh, '<:raw', $path) or die "Unable to read $path: $!";
    local $/;
    return <$fh>;
  }
  my $settings = slurp_text(File::Spec->catfile($repo, 'bin', '_TEMPLATES', 'EL_SETTINGS.oml'));
  like($settings, qr/<select[^>]*name="person"/, 'settings uses a person picker');
  like($settings, qr/#MSG\[Create and link a person\]#/, 'settings can create and link a missing person');

  my $person_new = slurp_text(File::Spec->catfile($repo, 'bin', '_TEMPLATES', 'PERSONS', 'EL_NEW_PERSON.oml'));
  like($person_new, qr/name="link_user"/, 'person create keeps the link-to-account flag across steps');

  my $person_show = slurp_text(File::Spec->catfile($repo, 'bin', '_TEMPLATES', 'PERSONS', 'EL_SHOW_PERSON.oml'));
  like($person_show, qr/#MSG\[Link this person to my account\]#/, 'person page can link the signed-in user');
  like($person_show, qr/#MSG\[Create and link a user\]#/, 'person page can create a user for administrators');
  like($person_show, qr/name="username"/, 'person page lists existing users');

  my $admin = slurp_text(File::Spec->catfile($repo, 'bin', '_TEMPLATES', 'EL_ADMIN.oml'));
  like($admin, qr/#ADMIN_PERSON_OPTIONS#/, 'account creation picks from existing people');
  like($admin, qr/#MSG\[Create a person\]#/, 'administrators can create a missing person before linking');
};

done_testing;
