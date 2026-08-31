#!/usr/bin/perl
# Version 1.0.0.0      17-Aug-2026
#*******************************************************************************
# Local, per-domain Orbit account administration.
#*******************************************************************************
use strict;
use warnings;
use utf8;
use feature ':5.16';

use Cwd qw(realpath);
use FindBin;
use Getopt::Long qw(GetOptionsFromArray);
use lib "$FindBin::Bin/../lib";
use Orbit::Auth;

binmode(STDIN,  ':encoding(UTF-8)') or die "Unable to decode terminal input as UTF-8\n";
binmode(STDOUT, ':encoding(UTF-8)') or die "Unable to configure UTF-8 output\n";
binmode(STDERR, ':encoding(UTF-8)') or die "Unable to configure UTF-8 error output\n";

sub usage {
  die <<'USAGE';
Usage:
  eluser init DOMAIN_DIR
  eluser maintain DOMAIN_DIR
  eluser create DOMAIN_DIR USER [--role viewer|editor|admin] [--person PERSON]
  eluser reset DOMAIN_DIR USER
  eluser disable DOMAIN_DIR USER
  eluser enable DOMAIN_DIR USER
  eluser role DOMAIN_DIR USER --role viewer|editor|admin
  eluser revoke DOMAIN_DIR USER

Run this as the web application's runtime user so the private 0700 store is
owned by that user. Root execution is refused.
Passphrases are read from an un-echoed TTY and are never accepted as arguments.
USAGE
}

my $command = shift(@ARGV) // '';
my $domain_arg = shift(@ARGV) // '';
my $username = '';
$username = shift(@ARGV) // '' if ($command !~ /^(?:init|maintain)$/);

my $role;
my $person;
GetOptionsFromArray(
  \@ARGV,
  'role=s'      => \$role,
  'person=s'    => \$person,
) or usage();
usage() if (@ARGV || $command !~ /^(?:init|maintain|create|reset|disable|enable|role|revoke)$/);
usage() if ($domain_arg eq '' || ($command !~ /^(?:init|maintain)$/ && $username eq ''));
die "--role is valid only with create or role\n"
  if (defined($role) && $command ne 'create' && $command ne 'role');
die "--person is valid only with create\n"
  if (defined($person) && $command ne 'create');
die "Refusing to create root-owned authentication data; run as the CGI runtime user\n"
  if ($< == 0 || $> == 0);

my $domain_dir = realpath($domain_arg);
die "Domain directory does not exist: $domain_arg\n"
  if (!defined($domain_dir) || !-d $domain_dir);

my $auth = Orbit::Auth->new(domain_dir => $domain_dir);

# Only commands that create a passphrase need the hashing/random providers.
# Account state and session maintenance remain available during a crypto
# package outage (and are useful recovery operations in exactly that case).
if ($command eq 'create' || $command eq 'reset') {
  my ($deps, $missing) = $auth->dependencies_available();
  die "Required credential dependencies are unavailable: ".join(', ', @$missing)."\n"
    if (!$deps);
}

if ($command eq 'init') {
  _require_ok($auth->initialize(), 'initialize authentication storage');
  print "Initialized private authentication storage for $domain_dir\n";
  exit 0;
}

if ($command eq 'maintain') {
  my $summary = $auth->maintain;
  print "Authentication maintenance: "
    ."$summary->{sessions_removed} sessions removed, "
    ."$summary->{rate_buckets_removed} rate buckets removed, "
    ."$summary->{rate_buckets_rewritten} rate buckets refreshed, "
    ."$summary->{errors} unsafe records retained\n";
  exit($summary->{errors} ? 2 : 0);
}

my ($valid_user, $user_error) = $auth->validate_username($username);
die "Invalid username: ".($user_error || 'invalid format')."\n" if (!$valid_user);
$username = $valid_user if (!ref($valid_user) && $valid_user ne '1');

if ($command eq 'create') {
  $role = 'viewer' if (!defined($role));
  _validate_role($role);
  my $passphrase = _read_new_passphrase('Passphrase: ', 'Confirm passphrase: ');
  my $result = $auth->provision_account(
    $username,
    $passphrase,
    role => $role,
    (defined($person) && $person ne '' ? (person => $person) : ()),
  );
  _require_ok($result, "create account $username");
  print "Created $username with role $role\n";
  exit 0;
}

if ($command eq 'reset') {
  my $passphrase = _read_new_passphrase('Temporary passphrase: ', 'Confirm temporary passphrase: ');
  _require_ok(
    $auth->reset_passphrase($username, $passphrase, must_change => 1),
    "reset passphrase for $username",
  );
  print "Reset $username; all sessions revoked and passphrase change required\n";
  exit 0;
}

if ($command eq 'disable') {
  _require_ok($auth->update_account($username, status => 'disabled'), "disable $username");
  print "Disabled $username\n";
  exit 0;
}

if ($command eq 'enable') {
  my $account = $auth->read_account($username);
  die "Unable to enable $username: account does not exist\n" if (!defined($account));
  die "Unable to enable $username: account must be disabled first\n"
    if (($account->{status} // '') ne 'disabled');

  _require_ok($auth->update_account($username, status => 'active'), "enable $username");
  print "Enabled $username\n";
  exit 0;
}

if ($command eq 'role') {
  die "The role command requires --role viewer|editor|admin\n" if (!defined($role));
  _validate_role($role);
  _require_ok($auth->update_account($username, role => $role), "change role for $username");
  print "Role for $username is $role; a role change revokes all sessions\n";
  exit 0;
}

_require_ok($auth->bump_auth_version($username), "invalidate sessions for $username");
$auth->revoke_all_sessions($username, reason => 'administrator_revoke');
print "Revoked all sessions for $username and advanced its authentication version\n";
exit 0;


sub _validate_role {
  my ( $value ) = @_;
  die "Role must be viewer, editor, or admin\n"
    if (!defined($value) || $value !~ /^(?:viewer|editor|admin)$/);
}


sub _read_new_passphrase {
  my ( $first_prompt, $second_prompt ) = @_;
  die "A terminal is required to read a passphrase\n" if (!-t STDIN);
  eval { require Term::ReadKey; 1 }
    or die "Term::ReadKey is required to read passphrases safely\n";

  my ($first, $second);
  eval {
    Term::ReadKey::ReadMode('noecho');
    print STDERR $first_prompt;
    $first = <STDIN>;
    print STDERR "\n$second_prompt";
    $second = <STDIN>;
    Term::ReadKey::ReadMode('restore');
    print STDERR "\n";
    1;
  } or do {
    my $error = $@ || 'unable to read passphrase';
    eval { Term::ReadKey::ReadMode('restore'); };
    print STDERR "\n";
    die $error;
  };

  $first = '' if (!defined($first));
  $second = '' if (!defined($second));
  $first =~ s/\r?\n\z//;
  $second =~ s/\r?\n\z//;
  die "Passphrases do not match\n" if ($first ne $second);
  return $first;
}


sub _require_ok {
  my ( $result, $operation ) = @_;
  return 1 if (ref($result) eq 'HASH' && $result->{'ok'});
  return 1 if (ref($result) eq 'HASH' && !exists($result->{'ok'}));
  return 1 if (ref($result) && ref($result) ne 'HASH');
  return 1 if (!ref($result) && $result);
  my $error = ref($result) eq 'HASH' ? ($result->{'error'} // 'unknown error') : 'unknown error';
  die "Unable to $operation: $error\n";
}
