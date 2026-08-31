#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Test::More;
use Digest::SHA qw(sha256 sha256_hex);
use Encode qw(encode_utf8);
use File::Spec;
use File::Temp qw(tempdir);
use JSON::PP ();
use FindBin;

use lib "$FindBin::Bin/../../bin/lib";
use Orbit::Orbit7;

{
  package Local::SignupCrypto;

  use Digest::SHA qw(sha256 sha256_hex);
  use Encode qw(encode_utf8);

  sub new { return bless { counter => 0, hash_calls => 0 }, shift }

  sub random_bytes {
    my ($self, $length) = @_;
    my $bytes = '';
    $bytes .= sha256('signup-random-'.++$self->{counter}) while length($bytes) < $length;
    return substr($bytes, 0, $length);
  }

  sub hash_passphrase {
    my ($self, $passphrase) = @_;
    $self->{hash_calls}++;
    return '$argon2id$mock$'.sha256_hex(encode_utf8($passphrase));
  }

  sub verify_passphrase {
    my ($self, $phc, $passphrase) = @_;
    return $phc eq '$argon2id$mock$'.sha256_hex(encode_utf8($passphrase));
  }

  sub needs_rehash { return 0 }
}

{
  package Local::SignupCGI;

  sub new {
    my ($class, %args) = @_;
    return bless {
      params => $args{params} || {}, cookies => $args{cookies} || {},
      cgi_error => $args{cgi_error} || '',
    }, $class;
  }

  sub param {
    my ($self, $name) = @_;
    return keys %{$self->{params}} if !defined $name;
    return $self->{params}{$name};
  }

  sub cookie { my ($self, $name) = @_; return $self->{cookies}{$name} }
  sub cgi_error { return shift->{cgi_error} }
}

{
  package Local::UnreadablePolicyAuth;
  our @ISA = ('Orbit::Auth');

  sub _read_json {
    my ($self, $path) = @_;
    die "simulated unreadable policy\n" if $path =~ /POLICY\.json\z/;
    return $self->SUPER::_read_json($path);
  }
}

{
  package Local::SignupAuth;

  sub new {
    my ($class, %args) = @_;
    return bless {
      enabled => $args{enabled} ? 1 : 0,
      admitted => exists($args{admitted}) ? $args{admitted} : 1,
      nonce => 'n' x 43,
      set_calls => [], provision_calls => [], session_calls => [], audits => [],
    }, $class;
  }

  sub self_signup_enabled { return shift->{enabled} }
  sub set_self_signup {
    my ($self, $enabled) = @_;
    $self->{enabled} = $enabled ? 1 : 0;
    push @{$self->{set_calls}}, $self->{enabled};
    return $self->{enabled};
  }
  sub issue_login_nonce { return shift->{nonce} }
  sub verify_login_nonce {
    my ($self, $cookie, $candidate) = @_;
    return defined($cookie) && defined($candidate)
      && $cookie eq $self->{nonce} && $candidate eq $self->{nonce};
  }
  sub verify_csrf {
    my ($self, $session, $candidate) = @_;
    return defined($candidate) && $candidate eq ($session->{csrf_secret} // '');
  }
  sub admit_self_signup {
    my ($self, $ip) = @_;
    $self->{last_admission_ip} = $ip;
    return $self->{admitted} ? { allowed => 1 } : { allowed => 0, retry_after => 900 };
  }
  sub validate_username {
    my ($self, $username) = @_;
    return 0 if !defined($username) || $username eq 'register';
    return $username =~ /\A[a-z][a-z0-9]*(?:-[a-z0-9]+)*\z/
      && length($username) >= 3 && length($username) <= 32;
  }
  sub validate_passphrase {
    my ($self, $passphrase) = @_;
    return defined($passphrase) && !ref($passphrase)
      && length($passphrase) >= 15 && length($passphrase) <= 128
      && $passphrase !~ /[\x00-\x1f\x7f#<>]/;
  }
  sub provision_self_signup {
    my ($self, @args) = @_;
    push @{$self->{provision_calls}}, \@args;
    return { username => $args[0], role => 'viewer', must_change => 0, status => 'active' };
  }
  sub create_session {
    my ($self, @args) = @_;
    push @{$self->{session_calls}}, \@args;
    return { token => 's' x 43 };
  }
  sub list_accounts { return [] }
  sub audit {
    my ($self, %event) = @_;
    push @{$self->{audits}}, \%event;
    return 1;
  }
}

{
  package Local::SignupOrbit;
  our @ISA = ('Orbit');

  sub RegisterError {
    my ($self, $message) = @_;
    $self->{_LastRegisteredError} = $message;
    return 1;
  }
  sub RegisterSuccess {
    my ($self, $message) = @_;
    $self->{_LastRegisteredSuccess} = $message;
    return 1;
  }
  sub ShowPage {
    my ($self, $template) = @_;
    $self->{_LastTemplate} = $template;
    return 'template';
  }
  sub _RenderAuthError {
    my ($self, $status, $message) = @_;
    $self->{_LastAuthError} = [$status, $message];
    return 'error';
  }
  sub _EmitRedirect {
    my ($self, $location, $cookies) = @_;
    $self->{_LastRedirect} = [$location, $cookies];
    return 'redirect';
  }
  sub _PublishAdminPage {
    my ($self) = @_;
    $self->_PublishSelfSignupPolicy();
    return 'admin';
  }
}

sub handler_orbit {
  my (%args) = @_;
  return bless {
    _TOKENS => {}, _Utils => CoreUtils->new(), _TOKEN_MODIFIERS => {},
    _OML_FUNCTIONS => {}, _FN_GROUPS_LOADED => {}, _BackupExt => '_BACK',
    _RecursiveCount => 0, _RecursiveMax => 100, _ParseMax => 1000,
    _StatsCnt => 0, _STATS => {}, _bLogStats => 0,
    _cgi => $args{cgi} || Local::SignupCGI->new(),
    _Auth => $args{auth} || Local::SignupAuth->new(),
    _Session => $args{session}, _SessionToken => '',
    _User => $args{user} // '', _Role => $args{role} // 'anonymous',
    _MustChange => $args{must_change} ? 1 : 0,
    _ResponseCookies => [], _ResponseStatus => '200 OK',
  }, 'Local::SignupOrbit';
}

sub write_policy_bytes {
  my ($path, $bytes) = @_;
  open(my $fh, '>:raw', $path) or die "open $path: $!";
  print {$fh} $bytes or die "write $path: $!";
  close($fh) or die "close $path: $!";
}

sub slurp_file {
  my ($path) = @_;
  open(my $fh, '<:raw', $path) or die "open $path: $!";
  local $/;
  my $bytes = <$fh>;
  close($fh) or die "close $path: $!";
  return $bytes;
}

subtest 'policy storage defaults off and accepts only a JSON boolean' => sub {
  my $domain = tempdir(CLEANUP => 1);
  my $crypto = Local::SignupCrypto->new;
  my $auth = Orbit::Auth->new(domain_dir => $domain, crypto_provider => $crypto);
  my $policy = File::Spec->catfile($domain, '_ORBIT', '_AUTH', 'POLICY.json');

  ok(!$auth->self_signup_enabled, 'missing policy defaults to disabled');
  ok(!-e $policy, 'reading the default does not manufacture an enabled policy');

  my $unreadable = Local::UnreadablePolicyAuth->new(
    domain_dir => $domain, crypto_provider => Local::SignupCrypto->new,
  );
  ok(!$unreadable->self_signup_enabled, 'unreadable policy fails closed');

  is($auth->set_self_signup(1), 1, 'policy can be enabled explicitly');
  ok($auth->self_signup_enabled, 'enabled policy is read back');
  is((stat($policy))[2] & 07777, 0600, 'policy record is mode 0600');
  open(my $fh, '<:raw', $policy) or die "open $policy: $!";
  local $/;
  my $stored = JSON::PP->new->decode(<$fh>);
  close($fh) or die "close $policy: $!";
  ok(JSON::PP::is_bool($stored->{self_signup}), 'stored value is a real JSON boolean');

  write_policy_bytes($policy, "not json\n");
  ok(!$auth->self_signup_enabled, 'corrupt policy fails closed');
  write_policy_bytes($policy, qq|{"schema":1,"self_signup":"false"}\n|);
  ok(!$auth->self_signup_enabled, 'string false is not treated as enabled');
  write_policy_bytes($policy, qq|{"schema":1,"self_signup":"1"}\n|);
  ok(!$auth->self_signup_enabled, 'string one is not treated as enabled');
  write_policy_bytes($policy, qq|{"schema":1,"self_signup":1}\n|);
  ok(!$auth->self_signup_enabled, 'numeric one is not treated as enabled');
  write_policy_bytes($policy, qq|{"schema":1,"self_signup":true,"future":"ignored"}\n|);
  ok($auth->self_signup_enabled, 'unknown keys do not weaken a valid boolean policy');

  is($auth->set_self_signup(0), 0, 'policy can be disabled explicitly');
  ok(!$auth->self_signup_enabled, 'disabled policy is read back');
  eval { $auth->set_self_signup('false') };
  like($@, qr/must be boolean/, 'setter rejects truthy strings');
};

subtest 'policy-locked public provisioning is viewer-only' => sub {
  my $domain = tempdir(CLEANUP => 1);
  my $crypto = Local::SignupCrypto->new;
  my $auth = Orbit::Auth->new(domain_dir => $domain, crypto_provider => $crypto);
  my $passphrase = 'a sufficiently long signup phrase';

  eval { $auth->provision_self_signup('closed-user', $passphrase) };
  like($@, qr/self-signup is disabled/, 'missing policy prevents provisioning');
  is($crypto->{hash_calls}, 0, 'disabled policy is checked before hashing');

  $auth->set_self_signup(1);
  my $account = $auth->provision_self_signup('public-user', $passphrase);
  is($account->{role}, 'viewer', 'self-signup always provisions a viewer');
  ok(!$account->{must_change}, 'self-signup does not force a change of chosen passphrase');
  eval { $auth->provision_self_signup('admin-user', $passphrase, role => 'admin') };
  like($@, qr/unknown self-signup option/, 'callers cannot inject an administrator role');
  eval { $auth->provision_self_signup('editor-user', $passphrase, role => 'editor') };
  like($@, qr/unknown self-signup option/, 'callers cannot inject an editor role');

  $auth->set_self_signup(0);
  my $before = $crypto->{hash_calls};
  eval { $auth->provision_self_signup('later-user', $passphrase) };
  like($@, qr/self-signup is disabled/, 'turning policy off blocks later provisioning');
  is($crypto->{hash_calls}, $before, 'disabled recheck still occurs before hashing');
};

subtest 'signup admission consumes the existing IP bucket before hashing' => sub {
  my $domain = tempdir(CLEANUP => 1);
  my $crypto = Local::SignupCrypto->new;
  my $auth = Orbit::Auth->new(
    domain_dir => $domain, crypto_provider => $crypto,
    ip_limit => 2, account_limit => 2,
  );
  ok($auth->admit_self_signup('192.0.2.44')->{allowed}, 'first signup work unit is admitted');
  ok($auth->admit_self_signup('192.0.2.44')->{allowed}, 'second signup work unit is admitted');
  ok(!$auth->admit_self_signup('192.0.2.44')->{allowed}, 'spent IP bucket throttles later work');
  is($crypto->{hash_calls}, 0, 'admission itself performs no passphrase hashing');
};

subtest 'admin toggle requires role, live session, POST, and CSRF' => sub {
  local %ENV = %ENV;
  $ENV{HTTPS} = 'on';
  $ENV{REQUEST_SCHEME} = 'https';
  $ENV{SERVER_PORT} = 443;
  $ENV{REQUEST_METHOD} = 'POST';
  my $csrf = 'c' x 43;

  my $auth = Local::SignupAuth->new;
  my $orbit = handler_orbit(
    auth => $auth, role => 'editor', user => 'river-editor',
    session => { csrf_secret => $csrf },
    cgi => Local::SignupCGI->new(params => {
      csrf_token => $csrf, admin_action => 'self_signup', enabled => 1,
    }),
  );
  is($orbit->HandleAdmin, 'error', 'non-admin cannot change the policy');
  is_deeply($auth->{set_calls}, [], 'non-admin request never reaches policy storage');

  $auth = Local::SignupAuth->new;
  $orbit = handler_orbit(
    auth => $auth, role => 'admin', user => 'sky-watcher',
    session => { csrf_secret => $csrf }, must_change => 1,
    cgi => Local::SignupCGI->new(params => {
      csrf_token => $csrf, admin_action => 'self_signup', enabled => 1,
    }),
  );
  is($orbit->HandleAdmin, 'error', 'must-change administrator cannot change the policy');
  is_deeply($auth->{set_calls}, [], 'must-change gate precedes policy storage');

  $auth = Local::SignupAuth->new;
  $orbit = handler_orbit(
    auth => $auth, role => 'admin', user => 'sky-watcher',
    session => { csrf_secret => $csrf },
    cgi => Local::SignupCGI->new(params => {
      admin_action => 'self_signup', enabled => 1,
    }),
  );
  is($orbit->HandleAdmin, 'error', 'administrator still needs CSRF');
  is_deeply($auth->{set_calls}, [], 'bad CSRF cannot change policy');

  $auth = Local::SignupAuth->new;
  $orbit = handler_orbit(
    auth => $auth, role => 'admin', user => 'sky-watcher',
    session => { csrf_secret => $csrf },
    cgi => Local::SignupCGI->new(params => {
      csrf_token => $csrf, admin_action => 'self_signup', enabled => 1,
    }),
  );
  is($orbit->HandleAdmin, 'admin', 'administrator can enable self-signup');
  is_deeply($auth->{set_calls}, [1], 'enable is an explicit boolean update');
  is($auth->{audits}[-1]{event}, 'auth.self_signup', 'toggle is audited');
  is($auth->{audits}[-1]{username}, 'sky-watcher', 'toggle audit records the actor');
  is($auth->{audits}[-1]{action}, 'enabled', 'toggle audit records the new state');

  $orbit->{_cgi} = Local::SignupCGI->new(params => {
    csrf_token => $csrf, admin_action => 'self_signup', enabled => 0,
  });
  is($orbit->HandleAdmin, 'admin', 'administrator can disable self-signup in one POST');
  is_deeply($auth->{set_calls}, [1, 0], 'disable is an explicit boolean update');
  is($auth->{audits}[-1]{action}, 'disabled', 'disable state is audited');
};

subtest 'public signup handler fails closed and provisions no elevated role' => sub {
  local %ENV = %ENV;
  $ENV{HTTPS} = 'on';
  $ENV{REQUEST_SCHEME} = 'https';
  $ENV{SERVER_PORT} = 443;
  $ENV{REMOTE_ADDR} = '198.51.100.20';
  $ENV{HTTP_USER_AGENT} = 'signup-test';
  my $nonce = 'n' x 43;
  my $passphrase = 'a sufficiently long signup phrase';

  $ENV{REQUEST_METHOD} = 'GET';
  my $auth = Local::SignupAuth->new(enabled => 0);
  my $orbit = handler_orbit(auth => $auth);
  is($orbit->HandleSignup, 'error', 'GET is rejected while policy is off');
  is_deeply($orbit->{_LastAuthError}, [403, 'Account creation is not available.'],
    'disabled response is generic and forbidden');
  ok(!defined($orbit->{_LastTemplate}), 'disabled GET exposes no signup form');

  $auth = Local::SignupAuth->new(enabled => 1);
  $orbit = handler_orbit(auth => $auth);
  is($orbit->HandleSignup, 'template', 'enabled GET renders the dedicated form');
  is($orbit->{_LastTemplate}, 'EL_SIGNUP', 'only the signup template is rendered');
  is($orbit->Get_Token('LOGIN_CSRF_TOKEN'), $nonce, 'signup form receives pre-session CSRF');

  $orbit = handler_orbit(auth => $auth, user => 'already-here', role => 'viewer');
  is($orbit->HandleSignup, 'redirect', 'logged-on visitor is redirected away from signup');

  $ENV{REQUEST_METHOD} = 'POST';
  $auth = Local::SignupAuth->new(enabled => 0);
  $orbit = handler_orbit(
    auth => $auth,
    cgi => Local::SignupCGI->new(params => {
      login_csrf_token => $nonce, username => 'forged-user',
      passphrase => $passphrase, confirm_passphrase => $passphrase,
    }, cookies => { '__Host-el_login_csrf' => $nonce }),
  );
  is($orbit->HandleSignup, 'error', 'forged POST is rejected while policy is off');
  is(scalar @{$auth->{provision_calls}}, 0, 'disabled POST cannot provision');

  $auth = Local::SignupAuth->new(enabled => 1);
  $orbit = handler_orbit(
    auth => $auth,
    cgi => Local::SignupCGI->new(params => {
      login_csrf_token => $nonce, username => 'csrf-user',
      passphrase => $passphrase, confirm_passphrase => $passphrase,
    }),
  );
  is($orbit->HandleSignup, 'error', 'missing signup CSRF cookie is rejected');
  is(scalar @{$auth->{provision_calls}}, 0, 'CSRF failure precedes provisioning');

  for my $case (
    [ 'register', $passphrase, $passphrase, 'reserved username' ],
    [ 'mismatch-user', $passphrase, 'a different long signup phrase', 'confirmation mismatch' ],
  ) {
    $auth = Local::SignupAuth->new(enabled => 1);
    $orbit = handler_orbit(
      auth => $auth,
      cgi => Local::SignupCGI->new(params => {
        login_csrf_token => $nonce, username => $case->[0],
        passphrase => $case->[1], confirm_passphrase => $case->[2],
      }, cookies => { '__Host-el_login_csrf' => $nonce }),
    );
    is($orbit->HandleSignup, 'template', "$case->[3] safely redisplays the form");
    is($orbit->{_LastRegisteredError},
      'Account creation failed. Check your username and passphrase and try again.',
      "$case->[3] receives the generic browser error");
    is(scalar @{$auth->{provision_calls}}, 0, "$case->[3] cannot provision");
  }

  $auth = Local::SignupAuth->new(enabled => 1, admitted => 0);
  $orbit = handler_orbit(
    auth => $auth,
    cgi => Local::SignupCGI->new(params => {
      login_csrf_token => $nonce, username => 'throttled-user',
      passphrase => $passphrase, confirm_passphrase => $passphrase,
    }, cookies => { '__Host-el_login_csrf' => $nonce }),
  );
  is($orbit->HandleSignup, 'template', 'IP throttle fails closed before provisioning');
  is(scalar @{$auth->{provision_calls}}, 0, 'throttled request performs no provisioning');

  $auth = Local::SignupAuth->new(enabled => 1);
  $orbit = handler_orbit(
    auth => $auth,
    cgi => Local::SignupCGI->new(params => {
      login_csrf_token => $nonce, username => 'new-viewer', role => 'admin',
      must_change => 1, passphrase => $passphrase, confirm_passphrase => $passphrase,
    }, cookies => { '__Host-el_login_csrf' => $nonce }),
  );
  is($orbit->HandleSignup, 'redirect', 'valid enabled signup creates a session');
  is(scalar @{$auth->{provision_calls}}, 1, 'account is provisioned once');
  is_deeply($auth->{provision_calls}[0], ['new-viewer', $passphrase],
    'client role and must-change fields never reach provisioning');
  is($orbit->{_LastRedirect}[0], '/o/page', 'successful signup returns to the site');
  like($orbit->{_LastRedirect}[1][0], qr/^__Host-el_sid=s{43};/,
    'successful signup emits the normal secure session cookie');
};

subtest 'templates expose signup only through the trusted policy token' => sub {
  my $templates = File::Spec->catdir($FindBin::Bin, '..', '..', 'bin', '_TEMPLATES');
  my $admin = slurp_file(File::Spec->catfile($templates, 'EL_ADMIN.oml'));
  my $signup = slurp_file(File::Spec->catfile($templates, 'EL_SIGNUP.oml'));
  my $header = slurp_file(File::Spec->catfile($templates, 'EL_HEADER.oml'));
  my $logon = slurp_file(File::Spec->catfile($templates, 'EL_LOGON.oml'));

  like($admin, qr/name="admin_action" value="self_signup"/,
    'admin page owns the self-signup policy action');
  like($admin, qr/name="enabled" value="1".*name="enabled" value="0"/s,
    'admin page has explicit one-POST enable and disable controls');
  like($header, qr/AUTH_SELF_SIGNUP.*href="#_ORBIT#elsignup"/s,
    'anonymous header discovery is policy-token gated');
  like($logon, qr/AUTH_SELF_SIGNUP.*href="#_ORBIT#elsignup"/s,
    'logon discovery is policy-token gated');
  unlike($signup, qr/<script\b/i, 'signup template contains no JavaScript');
  like($header, qr/\.el-field-checked:has\(input:not\(:placeholder-shown\):invalid\)/,
    'unmet create-field requirements are highlighted without JavaScript');
  like($signup, qr/<ul id="signup-username-help" class="el-field-rules">/,
    'signup shows username rules before the field');
  like($signup, qr/id="signup-passphrase-help" class="el-field-hint"/,
    'signup shows passphrase length before the field');
  like($signup, qr/pattern="\[A-Za-z\]\[A-Za-z0-9\]\*\(-\[A-Za-z0-9\]\+\)\*"/,
    'signup username pattern matches WordBase kebab-case');
  like($logon, qr/id="auth-username-help" class="el-field-hint"/,
    'logon shows the username format before the field');
  unlike($logon, qr/15 to 128 characters/,
    'logon does not show create-account passphrase rules');
  like($admin, qr/<ul id="admin-username-help" class="el-field-rules">/,
    'admin create shows username rules before the field');
  like($admin, qr/id="admin-passphrase-help" class="el-field-hint"/,
    'admin create shows passphrase length before the field');
  my $passwd = slurp_file(File::Spec->catfile($templates, 'EL_CHANGE_PASSPHRASE.oml'));
  like($passwd, qr/id="auth-new-passphrase-help" class="el-field-hint"/,
    'passphrase change shows the new-passphrase rule before the field');
  unlike($passwd, qr/id="auth-current-passphrase-help"/,
    'the current passphrase is treated as a secret, not a create-account rule list');
  unlike($signup, qr/name="(?:role|must_change)"/, 'signup form cannot submit privilege fields');
  unlike($signup, qr/value="#(?:PASS|.*PASSPHRASE)/,
    'signup template never receives a passphrase token');
};

done_testing;
