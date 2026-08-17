#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Test::More;
use File::Spec;
use File::Temp qw(tempdir);
use Digest::SHA qw(sha256 sha256_hex);
use Encode qw(encode_utf8);
use Fcntl qw(:DEFAULT :flock);
use JSON::PP ();
use POSIX qw(_exit);
use FindBin;

use lib "$FindBin::Bin/../../bin/lib";
use Orbit::Auth;

{
  package Local::MockCrypto;

  use Digest::SHA qw(sha256 sha256_hex);
  use Encode qw(encode_utf8);

  sub new {
    my ($class, %args) = @_;
    return bless {
      random_counter => 0,
      verify_calls   => 0,
      random_seed    => defined($args{random_seed}) ? $args{random_seed} : 'default',
    }, $class;
  }

  sub random_bytes {
    my ($self, $length) = @_;
    my $bytes = '';
    while (length($bytes) < $length) {
      $bytes .= sha256($self->{random_seed} . '-mock-random-' . ++$self->{random_counter});
    }
    return substr($bytes, 0, $length);
  }

  sub hash_passphrase {
    my ($self, $passphrase) = @_;
    return '$argon2id$mock$' . sha256_hex(encode_utf8($passphrase));
  }

  sub verify_passphrase {
    my ($self, $phc, $passphrase) = @_;
    $self->{verify_calls}++;
    return $phc eq $self->hash_passphrase($passphrase) ? 1 : 0;
  }

  sub needs_rehash { return 0 }
}

{
  package Local::BlockingCrypto;

  our @ISA = qw(Local::MockCrypto);

  sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    $self->{signal_fh} = $args{signal_fh};
    $self->{continue_fh} = $args{continue_fh};
    $self->{blocked_once} = 0;
    return $self;
  }

  sub verify_passphrase {
    my ($self, $phc, $passphrase) = @_;
    my $verified = $self->SUPER::verify_passphrase($phc, $passphrase);
    if ($verified && !$self->{blocked_once}++) {
      syswrite($self->{signal_fh}, 'V') == 1 or die "could not signal verification: $!";
      my $byte = '';
      sysread($self->{continue_fh}, $byte, 1) == 1 or die "could not await verification release: $!";
    }
    return $verified;
  }
}

{
  package Local::OrderedCrypto;

  our @ISA = qw(Local::MockCrypto);

  sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    $self->{hash_calls} = 0;
    $self->{order} = [];
    return $self;
  }

  sub hash_passphrase {
    my ($self, $passphrase) = @_;
    $self->{hash_calls}++;
    push @{$self->{order}}, 'hash';
    return '$argon2id$mock$' . Digest::SHA::sha256_hex(Encode::encode_utf8($passphrase));
  }

  sub verify_passphrase {
    my ($self, $phc, $passphrase) = @_;
    $self->{verify_calls}++;
    push @{$self->{order}}, 'verify';
    my $expected = '$argon2id$mock$' . Digest::SHA::sha256_hex(Encode::encode_utf8($passphrase));
    return $phc eq $expected ? 1 : 0;
  }

  sub reset_trace {
    my ($self) = @_;
    $self->{hash_calls} = 0;
    $self->{verify_calls} = 0;
    $self->{order} = [];
    return;
  }
}

{
  package Local::BlockingTouchAuth;

  our @ISA = qw(Orbit::Auth);

  sub arm_touch {
    my ($self, $signal_fh, $continue_fh) = @_;
    $self->{_test_touch_signal_fh} = $signal_fh;
    $self->{_test_touch_continue_fh} = $continue_fh;
    $self->{_test_touch_blocked} = 0;
    return $self;
  }

  sub _write_json {
    my ($self, $path, $data) = @_;
    if (!$self->{_test_touch_blocked}
        && ref($data) eq 'HASH'
        && defined($data->{last_seen})
        && defined($data->{created_at})
        && $data->{last_seen} > $data->{created_at}
        && $path =~ m{/SESSIONS/}) {
      $self->{_test_touch_blocked} = 1;
      syswrite($self->{_test_touch_signal_fh}, 'T') == 1
        or die "could not signal session touch: $!";
      my $byte = '';
      sysread($self->{_test_touch_continue_fh}, $byte, 1) == 1
        or die "could not await touch release: $!";
    }
    return $self->SUPER::_write_json($path, $data);
  }
}

{
  package Local::TracingAuth;

  our @ISA = qw(Orbit::Auth);

  sub _with_lock {
    my ($self, $key, $code) = @_;
    push @{$self->{_test_lock_trace}}, $key;
    return $self->SUPER::_with_lock($key, $code);
  }

  sub take_lock_trace {
    my ($self) = @_;
    my @trace = @{$self->{_test_lock_trace} || []};
    $self->{_test_lock_trace} = [];
    return @trace;
  }
}

{
  package Local::FailingAccountWriteAuth;

  our @ISA = qw(Orbit::Auth);

  sub fail_on_account_write {
    my ($self, $number) = @_;
    $self->{_test_account_write_number} = $number;
    $self->{_test_account_write_count} = 0;
    return $self;
  }

  sub _write_json {
    my ($self, $path, $data) = @_;
    if (defined($self->{_test_account_write_number}) && $path =~ m{/USERS/[^/]+\.json\z}) {
      $self->{_test_account_write_count}++;
      die "injected account write failure\n"
        if $self->{_test_account_write_count} == $self->{_test_account_write_number};
    }
    return $self->SUPER::_write_json($path, $data);
  }
}

{
  package Local::FailingAuditAuth;

  our @ISA = qw(Orbit::Auth);

  sub fail_next_audit {
    my ($self) = @_;
    $self->{_test_fail_next_audit} = 1;
    return $self;
  }

  sub audit {
    my ($self, %event) = @_;
    if (delete $self->{_test_fail_next_audit}) {
      die "injected audit failure\n";
    }
    return $self->SUPER::audit(%event);
  }
}

sub mode_of {
  my ($path) = @_;
  return (stat($path))[2] & 07777;
}

sub slurp {
  my ($path) = @_;
  open(my $fh, '<:raw', $path) or die "could not open $path: $!";
  local $/;
  my $value = <$fh>;
  close($fh) or die "could not close $path: $!";
  return $value;
}

sub pipe_write {
  my ($fh, $value) = @_;
  my $offset = 0;
  while ($offset < length($value)) {
    my $written = syswrite($fh, $value, length($value) - $offset, $offset);
    die "could not write test pipe: $!" if !defined($written) || $written == 0;
    $offset += $written;
  }
  return;
}

sub pipe_read_byte {
  my ($fh) = @_;
  my $byte = '';
  my $read = sysread($fh, $byte, 1);
  die "could not read test pipe: $!" if !defined($read) || $read != 1;
  return $byte;
}

sub pipe_read_line {
  my ($fh) = @_;
  my $line = '';
  while (1) {
    my $byte = '';
    my $read = sysread($fh, $byte, 1);
    die "could not read test pipe: $!" if !defined $read;
    last if $read == 0 || $byte eq "\n";
    $line .= $byte;
  }
  return $line;
}

sub lock_path {
  my ($domain_dir, $key) = @_;
  return File::Spec->catfile(
    $domain_dir, '_ORBIT', '_AUTH', 'LOCKS', sha256_hex(encode_utf8($key)) . '.lock',
  );
}

sub probe_lock {
  my ($path) = @_;
  sysopen(my $fh, $path, O_RDWR) or die "could not open test lock $path: $!";
  my $acquired = flock($fh, LOCK_EX | LOCK_NB) ? 1 : 0;
  close($fh) or die "could not close test lock $path: $!";
  return $acquired;
}

my $domain = tempdir(CLEANUP => 1);
my $now = 1_700_000_000;
my $crypto = Local::MockCrypto->new;
my $auth = Orbit::Auth->new(
  domain_dir      => $domain,
  now             => sub { $now },
  crypto_provider => $crypto,
  max_sessions    => 3,
);

ok($auth->initialize, 'private store initializes');
my $auth_root = File::Spec->catdir($domain, '_ORBIT', '_AUTH');
for my $relative (qw(USERS PASSPHRASE SESSIONS RATELIMIT LOCKS AUDIT)) {
  my $path = File::Spec->catdir($auth_root, $relative);
  ok(-d $path, "$relative directory exists");
  is(mode_of($path), 0700, "$relative directory is mode 0700");
}

subtest 'username and passphrase policy' => sub {
  for my $valid (qw(jane jane-doe editor7 a00)) {
    ok($auth->validate_username($valid), "$valid is accepted");
  }
  for my $invalid ('ab', 'Jane', 'jane_doe', '-jane', 'jane-', 'jane--doe', 'admin', '../jane') {
    ok(!$auth->validate_username($invalid), "$invalid is rejected");
  }

  ok($auth->validate_passphrase('  leading and trailing spaces  '), 'leading and trailing spaces are permitted');
  ok(!$auth->validate_passphrase('short pass'), 'short passphrase is rejected');
  ok(!$auth->validate_passphrase('passwordpassword'), 'common passphrase is rejected');
  ok(!$auth->validate_passphrase("valid passphrase\nwith newline"), 'control characters are rejected');
  ok(!$auth->validate_passphrase('x' x 129), 'passphrase character cap is enforced');
};

subtest 'incomplete accounts fail closed until credential creation' => sub {
  my $error = '';
  eval { $auth->create_account('active-user', status => 'active') };
  $error = $@;
  like($error, qr/cannot create an active account/, 'active account cannot be created without credential');

  my $account = $auth->create_account('jane-doe', role => 'viewer');
  is($account->{status}, 'incomplete', 'new account starts incomplete');
  my $account_path = File::Spec->catfile($auth_root, 'USERS', 'jane-doe.json');
  is(mode_of($account_path), 0600, 'account record is mode 0600');

  $account = $auth->create_credential('jane-doe', '  leading and trailing spaces  ');
  is($account->{status}, 'active', 'credential promotes incomplete account to active');
  ok($auth->verify_passphrase('jane-doe', '  leading and trailing spaces  '), 'exact passphrase verifies');
  ok(!$auth->verify_passphrase('jane-doe', 'leading and trailing spaces'), 'whitespace is not trimmed');
  my $credential_path = File::Spec->catfile($auth_root, 'PASSPHRASE', 'jane-doe.json');
  is(mode_of($credential_path), 0600, 'credential record is mode 0600');
  unlike(slurp($credential_path), qr/leading and trailing/, 'credential file does not contain passphrase');
};

subtest 'NFC normalization is consistent' => sub {
  my $decomposed = "Cafe\x{301} passphrase with enough length";
  my $composed   = "Caf\x{e9} passphrase with enough length";
  $auth->provision_account('unicode-user', $decomposed);
  ok($auth->verify_passphrase('unicode-user', $composed), 'canonically equivalent Unicode verifies');
};

subtest 'pre-session login nonce is opaque and compared exactly' => sub {
  my $nonce = $auth->issue_login_nonce;
  like($nonce, qr/\A[A-Za-z0-9_-]{43}\z/, 'login nonce is 256-bit base64url');
  ok($auth->verify_login_nonce($nonce, $nonce), 'matching cookie and form nonce are accepted');
  ok(!$auth->verify_login_nonce($nonce, $nonce . 'x'), 'different nonce is rejected');
  ok(!$auth->verify_login_nonce('', ''), 'empty values are rejected');
  ok(!$auth->verify_login_nonce(undef, $nonce), 'missing cookie is rejected');
};

subtest 'session restoration uses fresh account state and bounded touches' => sub {
  my $created = $auth->create_session('jane-doe', ip => '127.0.0.1', user_agent => 'test');
  like($created->{token}, qr/\A[A-Za-z0-9_-]{43}\z/, 'session token is 256-bit base64url');
  like($created->{csrf_token}, qr/\A[A-Za-z0-9_-]{43}\z/, 'CSRF secret is 256-bit base64url');
  unlike(slurp(File::Spec->catfile($auth_root, 'SESSIONS', sha256_hex($created->{token}) . '.json')),
    qr/\Q$created->{token}\E/, 'raw bearer token is not stored');

  my $restored = $auth->restore_session($created->{token});
  ok($restored->{ok}, 'session restores');
  is($restored->{role}, 'viewer', 'initial role restored');
  ok($auth->verify_csrf($restored, $created->{csrf_token}), 'correct CSRF value accepted');
  ok(!$auth->verify_csrf($restored, $created->{csrf_token} . 'x'), 'wrong CSRF value rejected');

  $auth->update_account('jane-doe', role => 'editor');
  $restored = $auth->restore_session($created->{token});
  is($restored->{role}, 'editor', 'role is reloaded from fresh account state');

  my $initial_seen = $restored->{session}{last_seen};
  $now += 299;
  $restored = $auth->restore_session($created->{token});
  is($restored->{session}{last_seen}, $initial_seen, 'session is not touched before five minutes');
  $now += 1;
  $restored = $auth->restore_session($created->{token});
  is($restored->{session}{last_seen}, $now, 'session is touched at five minutes');

  return $created;
};

subtest 'session cap removes the oldest session' => sub {
  my @sessions;
  for (1 .. 4) {
    $now++;
    push @sessions, $auth->create_session('jane-doe');
  }
  ok(!$auth->restore_session($sessions[0]{token})->{ok}, 'oldest of four capped sessions is gone');
  for my $index (1 .. 3) {
    ok($auth->restore_session($sessions[$index]{token})->{ok}, "retained session $index restores");
  }
  my @stored = glob(File::Spec->catfile($auth_root, 'SESSIONS', '*.json'));
  my $jane_count = 0;
  for my $path (@stored) {
    my $record = JSON::PP->new->utf8->decode(slurp($path));
    $jane_count++ if ($record->{username} || '') eq 'jane-doe';
  }
  is($jane_count, 3, 'configured session cap is enforced on disk');
};

subtest 'passphrase change revokes all sessions' => sub {
  my $one = $auth->create_session('jane-doe');
  $now++;
  my $two = $auth->create_session('jane-doe');
  my $changed = $auth->change_passphrase(
    'jane-doe',
    '  leading and trailing spaces  ',
    'a completely different passphrase',
  );
  ok($changed->{ok}, 'passphrase changes with correct old value');
  ok(!$auth->restore_session($one->{token})->{ok}, 'first session revoked after passphrase change');
  ok(!$auth->restore_session($two->{token})->{ok}, 'second session revoked after passphrase change');
  ok($auth->verify_passphrase('jane-doe', 'a completely different passphrase'), 'new passphrase verifies');
  ok(!$auth->verify_passphrase('jane-doe', '  leading and trailing spaces  '), 'old passphrase no longer verifies');
};

subtest 'passphrase changes verify first and share bounded account/IP admission' => sub {
  my $other_domain = tempdir(CLEANUP => 1);
  my $change_now = 1_810_000_000;
  my $ordered = Local::OrderedCrypto->new(random_seed => 'ordered-change');
  my $limited = Orbit::Auth->new(
    domain_dir => $other_domain,
    now => sub { $change_now },
    crypto_provider => $ordered,
    account_limit => 2,
    ip_limit => 2,
  );
  $limited->provision_account('change-limited', 'current bounded passphrase');
  $limited->provision_account('change-other', 'other bounded passphrase');
  $ordered->reset_trace;

  my $first = $limited->change_passphrase(
    'change-limited', 'wrong current passphrase', 'first proposed replacement',
    ip => '203.0.113.210', user_agent => 'test-agent',
  );
  is($first->{error}, 'invalid_credentials', 'wrong current passphrase is rejected');
  is_deeply($ordered->{order}, ['verify'], 'new passphrase is not hashed before current verification succeeds');

  $ordered->reset_trace;
  my $second = $limited->change_passphrase(
    'change-limited', 'another wrong passphrase', 'second proposed replacement',
    ip => '203.0.113.210',
  );
  is($second->{error}, 'invalid_credentials', 'second wrong current passphrase is rejected');
  is_deeply($ordered->{order}, ['verify'], 'each admitted failure performs only the current-password verification');

  $ordered->reset_trace;
  my $account_blocked = $limited->change_passphrase(
    'change-limited', 'current bounded passphrase', 'blocked proposed replacement',
    ip => '203.0.113.211',
  );
  is($account_blocked->{error}, 'throttled', 'account limit blocks even a correct current passphrase');
  is_deeply($ordered->{order}, [], 'account throttle rejects before Argon2 work');

  my $ip_blocked = $limited->change_passphrase(
    'change-other', 'other bounded passphrase', 'other proposed replacement',
    ip => '203.0.113.210',
  );
  is($ip_blocked->{error}, 'throttled', 'shared IP limit also protects the change endpoint');
  is_deeply($ordered->{order}, [], 'IP throttle rejects before Argon2 work');

  $change_now += 901;
  $ordered->reset_trace;
  my $success = $limited->change_passphrase(
    'change-limited', 'current bounded passphrase', 'accepted replacement passphrase',
    ip => '203.0.113.211',
  );
  ok($success->{ok}, 'change succeeds after the bounded lockout expires');
  is_deeply($ordered->{order}, ['verify', 'hash'], 'successful change verifies current before hashing replacement');
  ok($limited->verify_passphrase('change-limited', 'accepted replacement passphrase'), 'replacement credential is installed');
};

subtest 'forced passphrase change requires a canonical secret rotation' => sub {
  my $other_domain = tempdir(CLEANUP => 1);
  my $ordered = Local::OrderedCrypto->new(random_seed => 'forced-rotation');
  my $rotation = Orbit::Auth->new(
    domain_dir => $other_domain,
    now => sub { $now },
    crypto_provider => $ordered,
  );
  my $decomposed = "Temporary Cafe\x{301} reset passphrase";
  my $composed = "Temporary Caf\x{e9} reset passphrase";
  $rotation->provision_account(
    'forced-rotate', $decomposed, must_change => 1,
  );
  my $before_version = $rotation->read_account('forced-rotate')->{auth_version};
  $ordered->reset_trace;

  my $reused = $rotation->change_passphrase(
    'forced-rotate', $decomposed, $composed, ip => '203.0.113.212',
  );
  is($reused->{error}, 'passphrase_reuse', 'canonically equivalent replacement is rejected');
  is_deeply($ordered->{order}, [], 'reuse is rejected without spending Argon2 capacity');
  my $account = $rotation->read_account('forced-rotate');
  is($account->{must_change}, 1, 'forced-change flag remains set');
  is($account->{auth_version}, $before_version, 'reuse does not rotate authentication state');
  ok($rotation->verify_passphrase('forced-rotate', $composed), 'temporary credential remains effective only as the current secret');
};

subtest 'credential replacement fails closed between its two records' => sub {
  $auth->provision_account('fault-reset', 'original fault injection passphrase');
  my $old_session = $auth->create_session('fault-reset');
  my $before = $auth->read_account('fault-reset')->{auth_version};

  my $faulting = Local::FailingAccountWriteAuth->new(
    domain_dir => $domain,
    now => sub { $now },
    crypto_provider => Local::MockCrypto->new(random_seed => 'fault-reset'),
  );
  $faulting->initialize;
  $faulting->fail_on_account_write(2);
  my $error = '';
  eval {
    $faulting->reset_passphrase(
      'fault-reset', 'replacement fault injection passphrase', must_change => 1,
    );
  };
  $error = $@;
  like($error, qr/injected account write failure/, 'fault injected after credential replacement');

  my $staged = $auth->read_account('fault-reset');
  is($staged->{status}, 'incomplete', 'interrupted account is fail-closed');
  cmp_ok($staged->{auth_version}, '>', $before, 'auth version advances before credential replacement');
  ok(ref($staged->{credential_transition}) eq 'HASH', 'recoverable transition metadata remains');
  ok(!$auth->restore_session($old_session->{token})->{ok}, 'old session is invalid despite skipped bulk unlink');
  ok($auth->verify_passphrase('fault-reset', 'replacement fault injection passphrase'), 'replacement credential may be present');
  ok(!$auth->authenticate('fault-reset', 'replacement fault injection passphrase')->{ok}, 'incomplete account cannot log in');

  my $recovered = $auth->reset_passphrase(
    'fault-reset', 'recovered fault injection passphrase', must_change => 1,
  );
  is($recovered->{status}, 'active', 'administrator reset recovers interrupted transition');
  ok(!exists($recovered->{credential_transition}), 'transition metadata clears after recovery');
};

subtest 'auth version and expiration failures are structured' => sub {
  my $versioned = $auth->create_session('jane-doe');
  $auth->bump_auth_version('jane-doe');
  my $result = $auth->restore_session($versioned->{token});
  is_deeply({ ok => $result->{ok}, reason => $result->{reason} },
    { ok => 0, reason => 'auth_version_changed' }, 'auth-version mismatch has explicit reason');

  my $expiring = $auth->create_session('jane-doe');
  $now += 1800;
  $result = $auth->restore_session($expiring->{token});
  is($result->{reason}, 'idle_expired', 'idle boundary expires session');
};

subtest 'account and IP failure buckets throttle independently' => sub {
  my $user = 'rate-user';
  my $ip = '192.0.2.9';
  for (1 .. 4) {
    my $state = $auth->record_login_failure($user, $ip);
    ok($state->{allowed}, "account attempt $_ remains allowed");
  }
  my $state = $auth->record_login_failure($user, $ip);
  ok(!$state->{allowed}, 'fifth account failure throttles');
  is($state->{retry_after}, 900, 'account throttle returns retry duration');

  $auth->record_login_success($user, $ip);
  ok($auth->check_rate_limit($user, '192.0.2.10')->{allowed}, 'success clears only account bucket');

  my $shared_ip = '198.51.100.7';
  for my $index (1 .. 20) {
    $auth->record_login_failure("ip-user-$index", $shared_ip);
  }
  ok(!$auth->check_rate_limit('unrelated-user', $shared_ip)->{allowed}, 'IP bucket throttles at twenty failures');
};

subtest 'account candidates are canonical and unknown names have bounded storage' => sub {
  my $other_domain = tempdir(CLEANUP => 1);
  my $other = Orbit::Auth->new(
    domain_dir => $other_domain,
    now => sub { $now },
    crypto_provider => Local::MockCrypto->new(random_seed => 'canonical-rate'),
  );
  $other->provision_account('case-user', 'canonical account rate passphrase');
  my $ip = '192.0.2.77';
  for my $candidate (qw(CASE-USER Case-User case-user CASE-user case-USER)) {
    $other->record_login_failure($candidate, $ip);
  }
  ok(!$other->check_rate_limit('case-user', '192.0.2.78')->{allowed},
    'ASCII case variants share the registered account bucket');

  my $unknown_ip = '198.51.100.88';
  for my $index (1 .. 40) {
    $other->authenticate("unknown-name-$index", 'wrong but deliberately long passphrase', ip => $unknown_ip);
  }
  my @account_files = glob(File::Spec->catfile(
    $other_domain, '_ORBIT', '_AUTH', 'RATELIMIT', 'ACCOUNT', '*.json',
  ));
  is(scalar(@account_files), 2,
    'forty unknown names add one IP-scoped ACCOUNT bucket, not forty files');
  ok(!-e lock_path($other_domain, 'user:unknown-name-1'),
    'unknown valid username does not allocate a per-user lock file');
};

subtest 'attacker-controlled rate and orphan lock namespaces are striped' => sub {
  my $other_domain = tempdir(CLEANUP => 1);
  my $striped = Orbit::Auth->new(
    domain_dir => $other_domain,
    now => sub { $now },
    crypto_provider => Local::MockCrypto->new(random_seed => 'striped-locks'),
  );
  $striped->initialize;
  for my $index (1 .. 200) {
    $striped->check_rate_limit("arbitrary-user-$index", "198.51.100.$index");
  }
  my $lock_dir = File::Spec->catdir($other_domain, '_ORBIT', '_AUTH', 'LOCKS');
  my @rate_locks = glob(File::Spec->catfile($lock_dir, '*.lock'));
  cmp_ok(scalar(@rate_locks), '<=', 64, 'all arbitrary account/IP subjects share 64 rate locks');

  my $orphan_removed = 0;
  for my $index (1 .. 100) {
    my $token = sprintf('%043d', $index);
    my $path = File::Spec->catfile(
      $other_domain, '_ORBIT', '_AUTH', 'SESSIONS', sha256_hex($token) . '.json',
    );
    open(my $fh, '>:raw', $path) or die $!;
    print {$fh} "not-json\n";
    close($fh) or die $!;
    $orphan_removed += $striped->revoke_session($token) ? 1 : 0;
  }
  is($orphan_removed, 100, 'all corrupt orphan sessions are removed');
  my @all_locks = glob(File::Spec->catfile($lock_dir, '*.lock'));
  cmp_ok(scalar(@all_locks), '<=', 128,
    'arbitrary orphan digests add at most 64 more striped locks');
};

subtest 'concurrent login reservations atomically cap account and IP work' => sub {
  my $other_domain = tempdir(CLEANUP => 1);
  my $rate_now = 1_800_000_000;
  my $coordinator = Orbit::Auth->new(
    domain_dir => $other_domain,
    now => sub { $rate_now },
    crypto_provider => Local::MockCrypto->new(random_seed => 'reservation-parent'),
    account_limit => 2,
    ip_limit => 2,
  );
  $coordinator->initialize;

  pipe(my $start_r, my $start_w) or die "pipe failed: $!";
  pipe(my $result_r, my $result_w) or die "pipe failed: $!";
  my @children;
  for my $index (1 .. 8) {
    my $pid = fork();
    die "fork failed: $!" if !defined $pid;
    if ($pid == 0) {
      close($start_w);
      close($result_r);
      my $byte = '';
      sysread($start_r, $byte, 1) == 1 or die "could not await reservation start: $!";
      my $child = Orbit::Auth->new(
        domain_dir => $other_domain,
        now => sub { $rate_now },
        crypto_provider => Local::MockCrypto->new(random_seed => "reservation-$index"),
        account_limit => 2,
        ip_limit => 2,
      );
      my $reservation = eval {
        $child->_reserve_login_attempt('parallel-unknown', '203.0.113.90');
      };
      my $line = $@ ? "E:$@" : ($reservation->{allowed} ? 'A' : 'D');
      $line =~ s/\s+/ /g;
      pipe_write($result_w, "$line\n");
      _exit(0);
    }
    push @children, $pid;
  }
  close($start_r);
  close($result_w);
  pipe_write($start_w, 'S' x @children);
  close($start_w);

  my @results = map { pipe_read_line($result_r) } @children;
  close($result_r);
  for my $pid (@children) {
    waitpid($pid, 0);
    is($?, 0, "reservation child $pid exits cleanly");
  }
  is(scalar(grep { $_ eq 'A' } @results), 2, 'exactly two concurrent attempts are admitted');
  is(scalar(grep { $_ eq 'D' } @results), 6, 'remaining concurrent attempts are denied');
  is(scalar(grep { /^E:/ } @results), 0, 'no reservation operation fails internally');
  my $status = $coordinator->check_rate_limit('parallel-unknown', '203.0.113.90');
  ok(!$status->{allowed}, 'outstanding reservations consume admission capacity');
  is($status->{account_in_flight}, 2, 'both admitted reservations remain accounted for');
};

subtest 'authenticate is generic and uses dummy verification' => sub {
  $auth->provision_account('login-user', 'valid login passphrase here');
  my $before = $crypto->{verify_calls};
  my $unknown = $auth->authenticate('unknown-user', 'wrong but long passphrase', ip => '203.0.113.1');
  is($unknown->{error}, 'invalid_credentials', 'unknown user receives generic failure');
  cmp_ok($crypto->{verify_calls}, '>', $before, 'unknown user performs dummy password verification');

  my $bad = $auth->authenticate('login-user', 'wrong but long passphrase', ip => '203.0.113.2');
  is($bad->{error}, 'invalid_credentials', 'bad password receives same generic failure');

  my $good = $auth->authenticate('login-user', 'valid login passphrase here', ip => '203.0.113.2');
  ok($good->{ok}, 'valid credentials authenticate');
  is($good->{account}{must_change}, 0, 'successful result includes fresh account state');
  ok($auth->restore_session($good->{token})->{ok}, 'authenticated session restores');
};

subtest 'account lockout does not become a username timing oracle' => sub {
  my $other_domain = tempdir(CLEANUP => 1);
  my $timing_crypto = Local::MockCrypto->new(random_seed => 'timing-shape');
  my $timing = Orbit::Auth->new(
    domain_dir => $other_domain,
    now => sub { $now },
    crypto_provider => $timing_crypto,
    account_limit => 2,
    ip_limit => 8,
  );
  $timing->provision_account('known-timing', 'known timing account passphrase');

  my $probe_ip = '203.0.113.140';
  for my $index (1 .. 2) {
    $timing->authenticate(
      "unknown-mask-$index", 'wrong timing probe passphrase', ip => $probe_ip,
    );
  }

  my $before = $timing_crypto->{verify_calls};
  my $unknown = $timing->authenticate(
    'unknown-mask-probe', 'wrong timing probe passphrase', ip => $probe_ip,
  );
  is($unknown->{error}, 'invalid_credentials',
    'an unknown name behind its shared account lock stays generic');
  is($timing_crypto->{verify_calls} - $before, 1,
    'locked unknown bucket still pays exactly one dummy verification while IP capacity remains');

  $before = $timing_crypto->{verify_calls};
  my $known = $timing->authenticate(
    'known-timing', 'wrong timing probe passphrase', ip => $probe_ip,
  );
  is($known->{error}, $unknown->{error}, 'known and unknown probes return the same failure');
  is($timing_crypto->{verify_calls} - $before, 1,
    'known probe has the same one-verification work shape');

  $timing->provision_account('locked-timing', 'locked timing account passphrase');
  my $lock_ip = '203.0.113.141';
  for (1 .. 2) {
    $timing->authenticate(
      'locked-timing', 'wrong timing probe passphrase', ip => $lock_ip,
    );
  }
  $before = $timing_crypto->{verify_calls};
  my $locked = $timing->authenticate(
    'locked-timing', 'locked timing account passphrase', ip => '203.0.113.142',
  );
  ok(!$locked->{ok}, 'a correct passphrase cannot bypass an account lockout');
  is($locked->{error}, 'invalid_credentials', 'locked account failure remains generic');
  is($timing_crypto->{verify_calls} - $before, 1,
    'locked real account uses one dummy verification from a fresh IP');
};

subtest 'successful-login audit failure revokes the provisional session' => sub {
  my $other_domain = tempdir(CLEANUP => 1);
  my $failing = Local::FailingAuditAuth->new(
    domain_dir => $other_domain,
    now => sub { $now },
    crypto_provider => Local::MockCrypto->new(random_seed => 'audit-failure'),
  );
  $failing->provision_account('audit-user', 'successful audit failure passphrase');
  $failing->fail_next_audit;
  my $error = '';
  eval {
    $failing->authenticate(
      'audit-user', 'successful audit failure passphrase', ip => '203.0.113.111',
    );
  };
  $error = $@;
  like($error, qr/injected audit failure/, 'audit failure is returned instead of a login result');
  my @sessions = glob(File::Spec->catfile(
    $other_domain, '_ORBIT', '_AUTH', 'SESSIONS', '*.json',
  ));
  is(scalar(@sessions), 0, 'provisional bearer session is removed before the failure propagates');
};

subtest 'post-commit audit failures preserve truthful credential and revocation results' => sub {
  my $other_domain = tempdir(CLEANUP => 1);
  my $failing = Local::FailingAuditAuth->new(
    domain_dir => $other_domain,
    now => sub { $now },
    crypto_provider => Local::MockCrypto->new(random_seed => 'post-commit-audit'),
  );
  $failing->provision_account('commit-user', 'original committed passphrase');
  my $old_session = $failing->create_session('commit-user');

  my @warnings;
  local $SIG{__WARN__} = sub { push @warnings, @_ };
  $failing->fail_next_audit;
  my $changed = $failing->change_passphrase(
    'commit-user', 'original committed passphrase', 'replacement committed passphrase',
    ip => '203.0.113.213',
  );
  ok($changed->{ok}, 'committed password change remains a success when its first post-commit audit fails');
  is($changed->{warning}, 'post_commit_failure', 'caller receives an explicit post-commit warning');
  like(join('', @warnings), qr/passphrase change committed with post-commit failure/,
    'audit failure remains visible to server operations');
  ok($failing->verify_passphrase('commit-user', 'replacement committed passphrase'), 'replacement remains installed');
  ok(!$failing->restore_session($old_session->{token})->{ok}, 'revoked pre-change session remains revoked');

  @warnings = ();
  my $live = $failing->create_session('commit-user');
  $failing->fail_next_audit;
  ok($failing->revoke_session($live->{token}), 'committed logout returns success despite audit failure');
  like(join('', @warnings), qr/session revocation committed but audit failed/,
    'logout audit failure is emitted as an operational warning');
  ok(!$failing->restore_session($live->{token})->{ok}, 'session remains removed after audit failure');

  @warnings = ();
  $failing->fail_next_audit;
  my $session_error = '';
  eval { $failing->create_session('commit-user') };
  $session_error = $@;
  like($session_error, qr/injected audit failure/, 'unaudited newly created bearer is not returned');
  my @stored = glob(File::Spec->catfile(
    $other_domain, '_ORBIT', '_AUTH', 'SESSIONS', '*.json',
  ));
  is(scalar(@stored), 0, 'session whose creation audit failed is rolled back');
};

subtest 'credential reset cannot interleave verification and session mint' => sub {
  $auth->provision_account('race-login', 'original concurrent passphrase');

  pipe(my $verified_r, my $verified_w) or die "pipe failed: $!";
  pipe(my $continue_r, my $continue_w) or die "pipe failed: $!";
  pipe(my $auth_result_r, my $auth_result_w) or die "pipe failed: $!";

  my $auth_pid = fork();
  die "fork failed: $!" if !defined $auth_pid;
  if ($auth_pid == 0) {
    close($verified_r);
    close($continue_w);
    close($auth_result_r);
    my $hook_crypto = Local::BlockingCrypto->new(
      random_seed => 'race-auth-child', signal_fh => $verified_w, continue_fh => $continue_r,
    );
    my $child_auth = Orbit::Auth->new(
      domain_dir => $domain, now => sub { $now }, crypto_provider => $hook_crypto,
    );
    my $result = eval {
      $child_auth->authenticate(
        'race-login', 'original concurrent passphrase', ip => '192.0.2.200',
      );
    };
    my $payload = $@ ? "ERROR:$@" : ($result->{ok} ? $result->{token} : "FAIL:$result->{error}");
    pipe_write($auth_result_w, $payload . "\n");
    _exit(0);
  }
  close($verified_w);
  close($continue_r);
  close($auth_result_w);

  is(pipe_read_byte($verified_r), 'V', 'login pauses immediately after old credential verifies');

  pipe(my $reset_probe_r, my $reset_probe_w) or die "pipe failed: $!";
  pipe(my $reset_result_r, my $reset_result_w) or die "pipe failed: $!";
  my $reset_pid = fork();
  die "fork failed: $!" if !defined $reset_pid;
  if ($reset_pid == 0) {
    close($reset_probe_r);
    close($reset_result_r);
    my $user_lock = lock_path($domain, 'user:race-login');
    pipe_write($reset_probe_w, probe_lock($user_lock) ? 'U' : 'B');
    my $result = eval {
      $auth->reset_passphrase('race-login', 'replacement concurrent passphrase', must_change => 1);
    };
    pipe_write($reset_result_w, ($@ ? "ERROR:$@" : 'DONE') . "\n");
    _exit(0);
  }
  close($reset_probe_w);
  close($reset_result_w);

  is(pipe_read_byte($reset_probe_r), 'B', 'credential reset observes the login user lock held');
  pipe_write($continue_w, 'C');
  my $minted_token = pipe_read_line($auth_result_r);
  my $reset_result = pipe_read_line($reset_result_r);
  waitpid($auth_pid, 0);
  is($?, 0, 'concurrent authentication child exits cleanly');
  waitpid($reset_pid, 0);
  is($?, 0, 'concurrent reset child exits cleanly');
  like($minted_token, qr/\A[A-Za-z0-9_-]{43}\z/, 'verified login mints before queued reset runs');
  is($reset_result, 'DONE', 'queued credential reset completes');
  ok(!$auth->restore_session($minted_token)->{ok}, 'queued reset revokes the just-minted session');
  ok($auth->verify_passphrase('race-login', 'replacement concurrent passphrase'), 'replacement credential is installed');
};

subtest 'session touch and revoke-all cannot resurrect a session' => sub {
  $auth->provision_account('race-touch', 'session touch concurrent passphrase');
  my $created = $auth->create_session('race-touch');
  $now += 300;

  pipe(my $touch_signal_r, my $touch_signal_w) or die "pipe failed: $!";
  pipe(my $touch_continue_r, my $touch_continue_w) or die "pipe failed: $!";
  pipe(my $touch_result_r, my $touch_result_w) or die "pipe failed: $!";
  my $touch_pid = fork();
  die "fork failed: $!" if !defined $touch_pid;
  if ($touch_pid == 0) {
    close($touch_signal_r);
    close($touch_continue_w);
    close($touch_result_r);
    my $child = Local::BlockingTouchAuth->new(
      domain_dir => $domain,
      now => sub { $now },
      crypto_provider => Local::MockCrypto->new(random_seed => 'touch-child'),
    );
    $child->arm_touch($touch_signal_w, $touch_continue_r);
    my $result = eval { $child->restore_session($created->{token}) };
    pipe_write($touch_result_w, ($@ ? "ERROR:$@" : ($result->{ok} ? 'TOUCHED' : "FAIL:$result->{reason}")) . "\n");
    _exit(0);
  }
  close($touch_signal_w);
  close($touch_continue_r);
  close($touch_result_w);

  is(pipe_read_byte($touch_signal_r), 'T', 'restore pauses at the atomic touch write');

  pipe(my $revoke_probe_r, my $revoke_probe_w) or die "pipe failed: $!";
  pipe(my $revoke_result_r, my $revoke_result_w) or die "pipe failed: $!";
  my $revoke_pid = fork();
  die "fork failed: $!" if !defined $revoke_pid;
  if ($revoke_pid == 0) {
    close($revoke_probe_r);
    close($revoke_result_r);
    my $sessions_lock = lock_path($domain, 'sessions:race-touch');
    pipe_write($revoke_probe_w, probe_lock($sessions_lock) ? 'U' : 'B');
    my $count = eval { $auth->revoke_all_sessions('race-touch', reason => 'concurrency_test') };
    pipe_write($revoke_result_w, ($@ ? "ERROR:$@" : "REVOKED:$count") . "\n");
    _exit(0);
  }
  close($revoke_probe_w);
  close($revoke_result_w);

  is(pipe_read_byte($revoke_probe_r), 'B', 'touch holds the common per-user sessions lock');
  pipe_write($touch_continue_w, 'C');
  my $touch_result = pipe_read_line($touch_result_r);
  my $revoke_result = pipe_read_line($revoke_result_r);
  waitpid($touch_pid, 0);
  is($?, 0, 'touch child exits cleanly');
  waitpid($revoke_pid, 0);
  is($?, 0, 'revoke child exits cleanly');
  is($touch_result, 'TOUCHED', 'touch finishes before queued revocation');
  like($revoke_result, qr/\AREVOKED:[1-9][0-9]*\z/, 'queued revoke-all removes the session');
  is($auth->restore_session($created->{token})->{reason}, 'not_found', 'touch does not resurrect revoked session');
};

subtest 'all session mutations share ordered user and sessions locks' => sub {
  $auth->provision_account('lock-trace', 'ordered lock tracing passphrase');
  my $traced = Local::TracingAuth->new(
    domain_dir => $domain,
    now => sub { $now },
    crypto_provider => Local::MockCrypto->new(random_seed => 'trace'),
    max_sessions => 2,
  );

  my $first = $traced->create_session('lock-trace');
  my @trace = $traced->take_lock_trace;
  is_deeply([grep { /\A(?:user|sessions):/ } @trace],
    ['user:lock-trace', 'sessions:lock-trace'], 'session create and cap use user then sessions lock');

  $now += 300;
  ok($traced->restore_session($first->{token})->{ok}, 'traced session touches');
  @trace = $traced->take_lock_trace;
  is_deeply([grep { /\A(?:user|sessions|session:)/ } @trace],
    ['user:lock-trace', 'sessions:lock-trace'], 'touch uses the common ordered locks, not a digest lock');

  ok($traced->revoke_session($first->{token}), 'individual session revoke succeeds');
  @trace = $traced->take_lock_trace;
  is_deeply([grep { /\A(?:user|sessions|session:)/ } @trace],
    ['user:lock-trace', 'sessions:lock-trace'], 'individual revoke uses the same ordered locks');

  my $second = $traced->create_session('lock-trace');
  my $third = $traced->create_session('lock-trace');
  $traced->take_lock_trace;
  is($traced->revoke_all_sessions('lock-trace'), 2, 'revoke-all removes current sessions');
  @trace = $traced->take_lock_trace;
  is_deeply([grep { /\A(?:user|sessions|session:)/ } @trace],
    ['user:lock-trace', 'sessions:lock-trace'], 'revoke-all uses the same ordered locks');

  is($traced->revoke_session($second->{token}), 0, 'bare revoke of an already removed token is harmless');
  is($traced->revoke_session('not-a-session-token'), 0, 'bare revoke rejects malformed tokens without throwing');
};

subtest 'audit is protected, bounded, and excludes bearer values' => sub {
  $auth->audit(
    event => 'authz.deny', result => 'failure', username => 'jane-doe',
    action => 'edit', root => '/PUBLIC/PAGES', user_agent => "agent\nforged",
  );
  my $path = File::Spec->catfile($auth_root, 'AUDIT', 'auth.jsonl');
  ok(-f $path, 'central JSONL audit exists');
  is(mode_of($path), 0600, 'audit log is mode 0600');
  my @lines = grep { length } split /\n/, slurp($path);
  my $last = JSON::PP->new->utf8->decode($lines[-1]);
  is($last->{action}, 'edit', 'authorization action is logged');
  is($last->{root}, '/PUBLIC/PAGES', 'authorization root is logged');
  unlike($last->{user_agent}, qr/\n/, 'audit control characters are sanitized');
};

subtest 'audit rotation is serialized and retains a bounded archive set' => sub {
  my $other_domain = tempdir(CLEANUP => 1);
  my $rotating = Orbit::Auth->new(
    domain_dir => $other_domain,
    now => sub { $now },
    crypto_provider => Local::MockCrypto->new(random_seed => 'audit-rotation'),
    audit_max_bytes => 320,
    audit_archives => 2,
  );
  $rotating->initialize;
  for my $index (1 .. 12) {
    $rotating->audit(
      event => 'auth.test', result => 'success', username => "rotation-$index",
      user_agent => 'x' x 180,
    );
  }
  my @writers;
  for my $index (1 .. 4) {
    my $pid = fork();
    die "fork failed: $!" if !defined $pid;
    if ($pid == 0) {
      my $child = Orbit::Auth->new(
        domain_dir => $other_domain,
        now => sub { $now },
        crypto_provider => Local::MockCrypto->new(random_seed => "audit-writer-$index"),
        audit_max_bytes => 320,
        audit_archives => 2,
      );
      my $ok = eval {
        $child->audit(
          event => 'auth.concurrent', result => 'success', username => "writer-$index",
          user_agent => 'y' x 180,
        );
        1;
      };
      _exit($ok ? 0 : 1);
    }
    push @writers, $pid;
  }
  for my $pid (@writers) {
    waitpid($pid, 0);
    is($?, 0, "concurrent audit writer $pid exits cleanly");
  }
  my $audit_dir = File::Spec->catdir($other_domain, '_ORBIT', '_AUTH', 'AUDIT');
  my @archives = glob(File::Spec->catfile($audit_dir, 'auth.*.jsonl'));
  is(scalar(@archives), 2, 'only the configured number of archives is retained');
  my $current = File::Spec->catfile($audit_dir, 'auth.jsonl');
  ok(-s $current, 'current audit log remains writable after rotations');
  for my $path ($current, @archives) {
    is(mode_of($path), 0600, 'audit segment is private');
    for my $line (grep { length } split /\n/, slurp($path)) {
      ok(eval { JSON::PP->new->utf8->decode($line); 1 }, 'every retained audit line is complete JSON');
    }
  }
};

subtest 'maintenance removes only safely classified stale authentication state' => sub {
  my $other_domain = tempdir(CLEANUP => 1);
  my $maintenance_now = 1_900_000_000;
  my $maintainer = Orbit::Auth->new(
    domain_dir => $other_domain,
    now => sub { $maintenance_now },
    crypto_provider => Local::MockCrypto->new(random_seed => 'maintenance'),
  );
  $maintainer->provision_account('maint-user', 'maintenance cleanup passphrase');
  my $expired = $maintainer->create_session('maint-user');
  $maintainer->record_login_failure('maint-user', '192.0.2.130');
  my $abandoned = $maintainer->_reserve_login_attempt('missing-maint-user', '192.0.2.131');
  ok($abandoned->{allowed}, 'an abandoned reservation is created for cleanup');

  $maintenance_now += 2_000;
  my $live = $maintainer->create_session('maint-user');
  my $session_dir = File::Spec->catdir($other_domain, '_ORBIT', '_AUTH', 'SESSIONS');
  my $corrupt_digest = sha256_hex('corrupt maintenance session');
  my $corrupt_session = File::Spec->catfile($session_dir, "$corrupt_digest.json");
  open(my $session_fh, '>:raw', $corrupt_session) or die $!;
  print {$session_fh} "not-json\n";
  close($session_fh) or die $!;

  my $rate_dir = File::Spec->catdir($other_domain, '_ORBIT', '_AUTH', 'RATELIMIT', 'ACCOUNT');
  my $corrupt_rate = File::Spec->catfile($rate_dir, sha256_hex('corrupt maintenance rate') . '.json');
  open(my $rate_fh, '>:raw', $corrupt_rate) or die $!;
  print {$rate_fh} "{}\n";
  close($rate_fh) or die $!;

  my $summary = $maintainer->maintain;
  cmp_ok($summary->{sessions_removed}, '>=', 2, 'expired and corrupt sessions are removed');
  cmp_ok($summary->{rate_buckets_removed}, '>=', 2, 'expired failures and reservations are removed');
  cmp_ok($summary->{errors}, '>=', 1, 'unsafe corrupt rate bucket is reported');
  ok(-f $corrupt_rate, 'unvalidated rate bucket is retained fail closed');
  is($maintainer->restore_session($expired->{token})->{reason}, 'not_found', 'expired session stays gone');
  ok($maintainer->restore_session($live->{token})->{ok}, 'fresh valid session is retained');
};

subtest 'symbolic-link data records are refused' => sub {
  my $target = File::Spec->catfile($domain, 'outside.json');
  open(my $fh, '>:raw', $target) or die $!;
  print {$fh} "{}\n";
  close($fh) or die $!;
  my $link = File::Spec->catfile($auth_root, 'USERS', 'evil.json');
  my $made = symlink($target, $link);
  SKIP: {
    skip 'symbolic links unavailable', 1 if !$made;
    my $error = '';
    eval { $auth->read_account('evil') };
    $error = $@;
    like($error, qr/symbolic-link data file/, 'symlink account record is rejected');
  }
};

subtest 'lexical containment rejects sibling-prefix directories' => sub {
  my $outside = $auth_root . '-sibling/file.json';
  my $error = '';
  eval { $auth->_assert_contained($outside, $auth_root) };
  $error = $@;
  like($error, qr/path escapes authentication root/, 'similar sibling prefix is outside the auth root');
  ok(eval { $auth->_assert_contained(File::Spec->catfile($auth_root, 'USERS', 'ok.json'), $auth_root); 1 },
    'ordinary descendant remains accepted');
};

subtest 'default provider dependency reporting fails closed' => sub {
  my $other_domain = tempdir(CLEANUP => 1);
  my $default = Orbit::Auth->new(domain_dir => $other_domain);
  my ($available, $missing) = $default->dependencies_available;
  if (!$available) {
    ok(@$missing, 'missing crypto dependencies are reported');
    my $error = '';
    eval { $default->provision_account('package-test', 'valid packaged passphrase') };
    $error = $@;
    like($error, qr/crypto dependencies unavailable/, 'credential operation fails closed');
  }
  else {
    pass('packaged crypto dependencies are available');
  }
};

subtest 'packaged Argon2 and URandom smoke test' => sub {
  my $other_domain = tempdir(CLEANUP => 1);
  my $default = Orbit::Auth->new(domain_dir => $other_domain);
  my ($available, $missing) = $default->dependencies_available;
  plan skip_all => 'packaged crypto unavailable: ' . join(', ', @$missing) if !$available;
  my $account = $default->provision_account('package-test', 'valid packaged passphrase');
  is($account->{status}, 'active', 'default provider provisions account');
  ok($default->verify_passphrase('package-test', 'valid packaged passphrase'), 'default Argon2 hash verifies');
};

done_testing;
