#!/usr/bin/perl

package Orbit::Auth;

use strict;
use warnings;
use utf8;

use Carp qw(croak);
use Cwd qw(abs_path);
use Digest::SHA qw(sha256_hex);
use Encode qw(encode_utf8);
use Fcntl qw(:DEFAULT :flock);
use File::Basename qw(dirname);
use File::Spec;
use IO::Handle ();
use JSON::PP ();
use MIME::Base64 qw(encode_base64);
use Unicode::Normalize qw(NFC);

our $VERSION = '0.1.0';

my $SCHEMA_VERSION       = 1;
my $DEFAULT_IDLE         = 30 * 60;
my $DEFAULT_ABSOLUTE     = 8 * 60 * 60;
my $DEFAULT_TOUCH        = 5 * 60;
my $DEFAULT_MAX_SESSIONS = 10;
my $DEFAULT_RATE_WINDOW  = 15 * 60;
my $DEFAULT_LOCKOUT      = 15 * 60;
my $DEFAULT_ACCOUNT_MAX  = 5;
my $DEFAULT_IP_MAX       = 20;
my $DEFAULT_RESERVATION  = 5 * 60;
my $DEFAULT_AUDIT_BYTES  = 10 * 1024 * 1024;
my $DEFAULT_AUDIT_FILES  = 30;
my $RATE_LOCK_STRIPES    = 64;
my $ORPHAN_LOCK_STRIPES  = 64;
my $MAX_JSON_BYTES       = 1024 * 1024;
my $MAX_PASSPHRASE_BYTES = 1024;

my %VALID_ROLE   = map { $_ => 1 } qw(viewer editor admin);
my %VALID_STATUS = map { $_ => 1 } qw(incomplete active disabled);
my %RESERVED_USERNAME = map { $_ => 1 } qw(
  admin administrator anonymous apache api auth guest login logon logout
  nobody null orbit postmaster register root security session sessions
  support system user users webmaster www www-data
);
my %COMMON_PASSPHRASE = map { $_ => 1 } qw(
  123456789012345 passwordpassword qwertyqwertyqwerty
  letmeinletmeinletmein correcthorsebatterystaple
);

my $TEMP_SEQUENCE = 0;
my $AUDIT_SEQUENCE = 0;
my $NOFOLLOW = eval { Fcntl::O_NOFOLLOW() } || 0;
my $DIRECTORY = eval { Fcntl::O_DIRECTORY() } || 0;
# O_PATH is Linux UAPI value 010000000.  Older Perl Fcntl modules do not
# expose it even when the running kernel supports it.
my $PATH_ONLY = eval { Fcntl::O_PATH() };
$PATH_ONLY = 010000000 if !defined($PATH_ONLY) && $^O eq 'linux';
$PATH_ONLY ||= 0;

sub new {
  my ($class, %args) = @_;

  croak 'domain_dir is required' if !defined($args{domain_dir}) || $args{domain_dir} eq '';
  croak 'domain_dir must be an existing directory' if !-d $args{domain_dir};
  croak 'domain_dir may not be a symbolic link' if -l $args{domain_dir};

  my $domain_dir = abs_path($args{domain_dir});
  croak 'could not resolve domain_dir' if !defined $domain_dir;

  my $self = bless {
    domain_dir       => $domain_dir,
    auth_root        => File::Spec->catdir($domain_dir, '_ORBIT', '_AUTH'),
    now              => $args{now} || sub { time() },
    idle_timeout     => _positive_int($args{idle_timeout},     $DEFAULT_IDLE,         'idle_timeout'),
    absolute_timeout => _positive_int($args{absolute_timeout}, $DEFAULT_ABSOLUTE,     'absolute_timeout'),
    touch_interval   => _positive_int($args{touch_interval},   $DEFAULT_TOUCH,        'touch_interval'),
    max_sessions     => _positive_int($args{max_sessions},     $DEFAULT_MAX_SESSIONS, 'max_sessions'),
    rate_window      => _positive_int($args{rate_window},      $DEFAULT_RATE_WINDOW,  'rate_window'),
    lockout          => _positive_int($args{lockout},          $DEFAULT_LOCKOUT,      'lockout'),
    account_limit    => _positive_int($args{account_limit},    $DEFAULT_ACCOUNT_MAX,  'account_limit'),
    ip_limit         => _positive_int($args{ip_limit},         $DEFAULT_IP_MAX,       'ip_limit'),
    reservation_ttl  => _positive_int($args{reservation_ttl},  $DEFAULT_RESERVATION,  'reservation_ttl'),
    audit_max_bytes  => _positive_int($args{audit_max_bytes},  $DEFAULT_AUDIT_BYTES,  'audit_max_bytes'),
    audit_archives   => _nonnegative_int($args{audit_archives}, $DEFAULT_AUDIT_FILES,  'audit_archives'),
    crypto_provider  => $args{crypto_provider},
    initialized      => 0,
  }, $class;

  croak 'now must be a code reference' if ref($self->{now}) ne 'CODE';
  if (defined $self->{crypto_provider}) {
    for my $method (qw(random_bytes hash_passphrase verify_passphrase needs_rehash)) {
      croak "crypto_provider does not implement $method"
        if !$self->{crypto_provider}->can($method);
    }
  }

  return $self;
}

sub _nonnegative_int {
  my ($value, $default, $name) = @_;
  return $default if !defined $value;
  croak "$name must be a non-negative integer" if $value !~ /\A[0-9]+\z/;
  return 0 + $value;
}

sub _positive_int {
  my ($value, $default, $name) = @_;
  return $default if !defined $value;
  croak "$name must be a positive integer" if $value !~ /\A[1-9][0-9]*\z/;
  return 0 + $value;
}

sub dependencies_available {
  my ($self) = @_;
  return wantarray ? (1, []) : 1 if defined $self->{crypto_provider};

  my @missing;
  push @missing, 'Crypt::Argon2'  if !eval { require Crypt::Argon2; 1 };
  push @missing, 'Crypt::URandom' if !eval { require Crypt::URandom; 1 };
  return wantarray ? (!@missing, \@missing) : !@missing;
}

sub self_signup_enabled {
  my ($self) = @_;
  my $policy;
  my $read = eval {
    $self->_ensure_initialized;
    $policy = $self->_read_json(File::Spec->catfile($self->{auth_root}, 'POLICY.json'));
    1;
  };
  return 0 if !$read || ref($policy) ne 'HASH';
  return 0 if !defined($policy->{schema}) || ref($policy->{schema})
    || $policy->{schema} !~ /\A1\z/;
  return 0 if !exists($policy->{self_signup})
    || !JSON::PP::is_bool($policy->{self_signup});
  return $policy->{self_signup} ? 1 : 0;
}

sub set_self_signup {
  my ($self, $enabled) = @_;
  croak 'self-signup setting must be boolean'
    if !defined($enabled) || ref($enabled) || $enabled !~ /\A[01]\z/;
  $self->_ensure_initialized;
  return $self->_with_lock('policy:self-signup', sub {
    $self->_write_json(
      File::Spec->catfile($self->{auth_root}, 'POLICY.json'),
      {
        schema      => $SCHEMA_VERSION,
        self_signup => $enabled ? JSON::PP::true : JSON::PP::false,
      },
    );
    return $enabled ? 1 : 0;
  });
}

sub provision_self_signup {
  my ($self, $username, $passphrase) = @_;
  croak 'unknown self-signup option' if @_ != 3;
  $self->_ensure_initialized;
  return $self->_with_lock('policy:self-signup', sub {
    croak 'self-signup is disabled' if !$self->self_signup_enabled;
    return $self->provision_account(
      $username, $passphrase, role => 'viewer', must_change => 0,
    );
  });
}

sub initialize {
  my ($self) = @_;
  return $self if $self->{initialized};

  # 0022 yields the requested final modes at mkdir itself: _ORBIT is born
  # 0755, while every private directory is born 0700.  No directory needs a
  # pathname- or descriptor-based chmod after it can be renamed.
  _with_directory_umask(sub {
    croak 'directory-descriptor authentication hardening is unavailable'
      if !$PATH_ONLY || !$DIRECTORY || !$NOFOLLOW || !-d '/proc/self/fd';
    my $flags = $PATH_ONLY | $DIRECTORY | $NOFOLLOW;
    my $domain_fh = $self->_open_pinned_directory(
      'domain directory', $self->{domain_dir}, $self->{domain_dir}, $flags,
    );

    my $orbit_dir = File::Spec->catdir($self->{domain_dir}, '_ORBIT');
    my $orbit_fh = $self->_ensure_directory(
      $orbit_dir, 0755, 0, $domain_fh, $self->{domain_dir},
      'authentication parent', $flags,
    );
    $self->_guard_auth_parent_path;

    my $auth_fh = $self->_ensure_directory(
      $self->{auth_root}, 0700, 1, $orbit_fh, $orbit_dir,
      'authentication root', $flags,
    );
    my %pinned = ('' => $auth_fh);
    for my $parts (
      [qw(USERS)], [qw(PASSPHRASE)], [qw(SESSIONS)], [qw(LOCKS)],
      [qw(AUDIT)], [qw(RATELIMIT)], [qw(RATELIMIT ACCOUNT)],
      [qw(RATELIMIT IP)],
    ) {
      my @parent_parts = @$parts;
      my $name = pop @parent_parts;
      my $parent_key = join('/', @parent_parts);
      my $key = join('/', @$parts);
      my $parent_fh = $pinned{$parent_key};
      croak "missing pinned authentication parent for $key"
        if !defined($parent_fh);
      my $parent_path = File::Spec->catdir($self->{auth_root}, @parent_parts);
      my $path = File::Spec->catdir($parent_path, $name);
      $pinned{$key} = $self->_ensure_directory(
        $path, 0700, 1, $parent_fh, $parent_path,
        "authentication directory $key", $flags,
      );
    }

    # Keep the same descriptors that authorized initialization. Reopening the
    # path after creation would reintroduce a window in which a renamed parent
    # could redirect the pinned tree.
    $self->_assert_pinned_directory_matches(
      $domain_fh, $self->{domain_dir}, 'domain directory',
    );
    $self->_assert_pinned_directory_matches(
      $orbit_fh, $orbit_dir, 'authentication parent',
    );
    for my $key (
      '', qw(USERS PASSPHRASE SESSIONS LOCKS AUDIT RATELIMIT),
      'RATELIMIT/ACCOUNT', 'RATELIMIT/IP',
    ) {
      my @parts = $key eq '' ? () : split(m{/}, $key);
      my $path = @parts
        ? File::Spec->catdir($self->{auth_root}, @parts)
        : $self->{auth_root};
      my $label = $key eq ''
        ? 'authentication root'
        : "authentication directory $key";
      $self->_assert_pinned_directory_matches($pinned{$key}, $path, $label);
    }
    $self->{auth_root_fh} = $auth_fh;
    $self->{auth_dir_fh} = \%pinned;
  });

  $self->{initialized} = 1;
  return $self;
}

sub _with_secure_umask {
  my ($code) = @_;
  return _with_umask(0077, $code);
}

sub _with_directory_umask {
  my ($code) = @_;
  return _with_umask(0022, $code);
}

sub _with_umask {
  my ($mask, $code) = @_;
  my $old_umask = umask($mask);
  my ($result, $error);
  eval { $result = $code->(); 1 } or $error = $@ || 'secure filesystem operation failed';
  umask($old_umask);
  die $error if defined $error;
  return $result;
}

sub _ensure_initialized {
  my ($self) = @_;
  $self->initialize if !$self->{initialized};
  return;
}

sub _dir {
  my ($self, @parts) = @_;
  return File::Spec->catdir($self->{auth_root}, @parts);
}

sub _ensure_directory {
  my ($self, $path, $mode, $force_mode, $parent_fh, $parent_path, $label, $flags) = @_;
  $self->_assert_contained($path, $self->{domain_dir});
  croak "missing pinned parent for directory: $path"
    if !defined($parent_fh) || !defined(fileno($parent_fh));
  croak "missing expected parent for directory: $path"
    if !defined($parent_path) || $parent_path eq '';
  $label ||= "directory $path";
  $flags = $PATH_ONLY | $DIRECTORY | $NOFOLLOW if !defined $flags;

  my $relative = File::Spec->abs2rel($path, $parent_path);
  my @parts = grep { $_ ne '' && $_ ne '.' } File::Spec->splitdir($relative);
  croak "directory is not a direct child of its pinned parent: $path"
    if @parts != 1 || $parts[0] eq '..'
      || File::Spec->file_name_is_absolute($relative);

  # Validate the public name before and after the descriptor-relative
  # operation.  The parent descriptor prevents a substituted path or symlink
  # from redirecting mkdir into an attacker tree.  If that pinned parent is
  # itself renamed, post-validation rolls our newly created child back through
  # the same descriptor.
  $self->_assert_pinned_directory_matches($parent_fh, $parent_path, "parent of $label");
  my $parent_ref = '/proc/self/fd/' . fileno($parent_fh);
  my $open_path = File::Spec->catdir($parent_ref, $parts[0]);
  my @before = lstat($open_path);
  my $was_missing = !@before;
  my $created = 0;
  if (@before) {
    croak "refusing symbolic-link directory: $path" if -l _;
    croak "expected directory: $path" if !-d _;
  }
  else {
    if (mkdir($open_path, $mode)) {
      $created = 1;
    }
    else {
      my $mkdir_error = "$!";
      my @raced = lstat($open_path);
      croak "could not create directory $path: $mkdir_error" if !@raced;
      croak "refusing symbolic-link directory: $path" if -l _;
      croak "expected directory: $path" if !-d _;
    }
  }

  my ($directory_fh, @opened);
  my $verified = eval {
    my @candidate = lstat($open_path);
    croak "missing newly established directory: $path" if !@candidate;
    croak "refusing symbolic-link directory: $path" if -l _;
    croak "expected directory: $path" if !-d _;

    $directory_fh = $self->_open_pinned_directory(
      $label, $open_path, $open_path, $flags,
    );
    @opened = stat($directory_fh);
    croak "could not inspect $label" if !@opened;
    croak "$label changed while it was being established"
      if $candidate[0] != $opened[0] || $candidate[1] != $opened[1];

    my $private = $force_mode ? 1 : 0;
    croak "$label has unexpected ownership"
      if (($was_missing || $private) && $opened[4] != $>);
    croak "permissions on $path must be " . sprintf('%04o', $mode)
      if (($was_missing || $private) && ($opened[2] & 07777) != $mode);

    # A descriptor-relative mkdir cannot be redirected through a substituted
    # symlink, but its pinned parent can be renamed.  Verify containment before
    # retaining the new descriptor; a just-created empty directory is rolled
    # back below if either public name no longer identifies the pinned inode.
    $self->_assert_pinned_directory_matches(
      $parent_fh, $parent_path, "parent of $label",
    );
    $self->_assert_pinned_directory_matches($directory_fh, $path, $label);
    1;
  };
  if (!$verified) {
    my $error = $@ || "could not verify $label";
    if ($created) {
      my $rollback_error;
      eval {
        $self->_rollback_created_directory($open_path, \@opened, $path);
        1;
      } or $rollback_error = $@ || "could not roll back $path";
      $error .= "rollback failed: $rollback_error" if defined($rollback_error);
    }
    die $error;
  }
  return $directory_fh;
}

sub _rollback_created_directory {
  my ($self, $open_path, $opened, $public_path) = @_;
  croak "cannot identify newly created directory for rollback: $public_path"
    if ref($opened) ne 'ARRAY' || !@$opened;
  my @current = lstat($open_path);
  return if !@current;
  croak "refusing to roll back a substituted directory: $public_path"
    if -l _ || !-d _
      || $current[0] != $opened->[0] || $current[1] != $opened->[1];
  rmdir($open_path)
    or croak "could not roll back newly created directory $public_path: $!";
  return;
}

sub _assert_pinned_directory_matches {
  my ($self, $fh, $path, $label) = @_;
  my @expected = lstat($path);
  croak "missing $label: $path" if !@expected;
  croak "refusing symbolic-link $label: $path" if -l _;
  croak "expected $label directory: $path" if !-d _;
  my @opened = stat($fh);
  croak "could not inspect pinned $label" if !@opened;
  croak "$label changed during authentication initialization"
    if $expected[0] != $opened[0] || $expected[1] != $opened[1];
  croak "pinned $label is not a directory" if !-d $fh;
  return;
}

sub _assert_contained {
  my ($self, $path, $root) = @_;
  my $absolute = File::Spec->canonpath(File::Spec->rel2abs($path));
  my $base     = File::Spec->canonpath(File::Spec->rel2abs($root));
  my $relative = File::Spec->abs2rel($absolute, $base);
  croak "path escapes authentication root: $path"
    if File::Spec->file_name_is_absolute($relative)
      || $relative eq File::Spec->updir
      || $relative =~ /\A\.\.(?:[\\\/]|\z)/;
  return;
}

sub _guard_auth_path {
  my ($self, $path) = @_;
  $self->_assert_contained($path, $self->{auth_root});
  $self->_guard_auth_parent_path;

  croak "missing authentication root: $self->{auth_root}" if !lstat $self->{auth_root};
  croak "refusing symbolic-link authentication root: $self->{auth_root}" if -l _;
  croak "expected authentication root directory: $self->{auth_root}" if !-d _;

  my $relative = File::Spec->abs2rel($path, $self->{auth_root});
  my @parts = File::Spec->splitdir($relative);
  pop @parts;

  my $current = $self->{auth_root};
  for my $part (@parts) {
    next if $part eq '' || $part eq '.';
    croak "unsafe path component in $path" if $part eq '..';
    $current = File::Spec->catdir($current, $part);
    croak "missing authentication directory: $current" if !lstat $current;
    croak "refusing symbolic-link directory: $current" if -l _;
    croak "expected directory: $current" if !-d _;
  }
  return;
}

sub _guard_auth_parent_path {
  my ($self) = @_;
  my @parents = (
    [ 'domain directory', $self->{domain_dir} ],
    [ 'authentication parent', File::Spec->catdir($self->{domain_dir}, '_ORBIT') ],
  );
  for my $entry (@parents) {
    my ($label, $path) = @$entry;
    croak "missing $label: $path" if !lstat $path;
    croak "refusing symbolic-link $label: $path" if -l _;
    croak "expected $label directory: $path" if !-d _;
  }
  return;
}

sub _pin_auth_root {
  my ($self) = @_;
  return if defined($self->{auth_dir_fh});
  croak 'directory-descriptor authentication hardening is unavailable'
    if !$PATH_ONLY || !$DIRECTORY || !$NOFOLLOW || !-d '/proc/self/fd';

  $self->_guard_auth_parent_path;
  my $flags = $PATH_ONLY | $DIRECTORY | $NOFOLLOW;
  my $domain_fh = $self->_open_pinned_directory(
    'domain directory', $self->{domain_dir}, $self->{domain_dir}, $flags,
  );
  my $domain_ref = '/proc/self/fd/' . fileno($domain_fh);
  my $orbit_path = File::Spec->catdir($self->{domain_dir}, '_ORBIT');
  my $orbit_fh = $self->_open_pinned_directory(
    'authentication parent', $orbit_path,
    File::Spec->catdir($domain_ref, '_ORBIT'), $flags,
  );
  my $orbit_ref = '/proc/self/fd/' . fileno($orbit_fh);
  my $auth_fh = $self->_open_pinned_directory(
    'authentication root', $self->{auth_root},
    File::Spec->catdir($orbit_ref, '_AUTH'), $flags,
  );

  my %pinned = ('' => $auth_fh);
  for my $parts (
    [qw(USERS)], [qw(PASSPHRASE)], [qw(SESSIONS)], [qw(LOCKS)],
    [qw(AUDIT)], [qw(RATELIMIT)], [qw(RATELIMIT ACCOUNT)],
    [qw(RATELIMIT IP)],
  ) {
    my @parent_parts = @$parts;
    my $name = pop @parent_parts;
    my $parent_key = join('/', @parent_parts);
    my $key = join('/', @$parts);
    my $parent_fh = $pinned{$parent_key};
    croak "missing pinned authentication parent for $key"
      if !defined($parent_fh);
    my $parent_ref = '/proc/self/fd/' . fileno($parent_fh);
    my $expected = File::Spec->catdir($self->{auth_root}, @$parts);
    $pinned{$key} = $self->_open_pinned_directory(
      "authentication directory $key", $expected,
      File::Spec->catdir($parent_ref, $name), $flags,
    );
  }

  $self->{auth_root_fh} = $auth_fh;
  $self->{auth_dir_fh} = \%pinned;
  return;
}

sub _open_pinned_directory {
  my ($self, $label, $expected_path, $open_path, $flags) = @_;
  my @expected = lstat($expected_path);
  croak "missing $label: $expected_path" if !@expected;
  croak "refusing symbolic-link $label: $expected_path" if -l _;
  croak "expected $label directory: $expected_path" if !-d _;

  sysopen(my $fh, $open_path, $flags)
    or croak "could not pin $label: $!";
  my @opened = stat($fh);
  croak "could not inspect pinned $label" if !@opened;
  croak "$label changed while it was being pinned"
    if $expected[0] != $opened[0] || $expected[1] != $opened[1];
  croak "pinned $label is not a directory" if !-d $fh;
  return $fh;
}

sub _pinned_auth_path {
  my ($self, $path) = @_;
  $self->_assert_contained($path, $self->{auth_root});
  $self->_pin_auth_root if !defined($self->{auth_dir_fh});
  my $relative = File::Spec->abs2rel($path, $self->{auth_root});
  my @parts = grep { $_ ne '' && $_ ne '.' } File::Spec->splitdir($relative);
  croak "unsafe pinned authentication path: $path" if grep { $_ eq '..' } @parts;

  my $exact_key = join('/', @parts);
  if (defined(my $exact_fh = $self->{auth_dir_fh}{$exact_key})) {
    return '/proc/self/fd/' . fileno($exact_fh);
  }

  my $name = pop @parts;
  my $directory_key = join('/', @parts);
  my $directory_fh = $self->{auth_dir_fh}{$directory_key};
  croak "authentication path does not use a pinned directory: $path"
    if !defined($name) || !defined($directory_fh);
  return File::Spec->catfile('/proc/self/fd/' . fileno($directory_fh), $name);
}

sub validate_username {
  my ($self, $username) = @_;
  my ($valid, $reason) = (1, 'ok');
  if (!defined $username || ref($username)) {
    ($valid, $reason) = (0, 'missing');
  }
  elsif (length($username) < 3 || length($username) > 32) {
    ($valid, $reason) = (0, 'length');
  }
  elsif ($username !~ /\A[a-z][a-z0-9]*(?:-[a-z0-9]+)*\z/) {
    ($valid, $reason) = (0, 'format');
  }
  elsif ($RESERVED_USERNAME{$username}) {
    ($valid, $reason) = (0, 'reserved');
  }
  return wantarray ? ($valid, $reason) : $valid;
}

sub validate_passphrase {
  my ($self, $passphrase) = @_;
  my ($valid, $reason) = (1, 'ok');
  if (!defined $passphrase || ref($passphrase)) {
    ($valid, $reason) = (0, 'missing');
  }
  else {
    my $normalized = eval { NFC($passphrase) };
    if (!defined $normalized || $@) {
      ($valid, $reason) = (0, 'unicode');
    }
    elsif ($normalized =~ /[\p{Cc}\p{Cs}]/) {
      ($valid, $reason) = (0, 'control_character');
    }
    elsif ($normalized =~ /[\#<>]/) {
      ($valid, $reason) = (0, 'markup');
    }
    elsif (length($normalized) < 15) {
      ($valid, $reason) = (0, 'too_short');
    }
    elsif (length($normalized) > 128) {
      ($valid, $reason) = (0, 'too_long');
    }
    elsif (length(encode_utf8($normalized)) > $MAX_PASSPHRASE_BYTES) {
      ($valid, $reason) = (0, 'too_many_bytes');
    }
    elsif ($COMMON_PASSPHRASE{lc $normalized}) {
      ($valid, $reason) = (0, 'common');
    }
  }
  return wantarray ? ($valid, $reason) : $valid;
}

sub _validated_username {
  my ($self, $username) = @_;
  my ($valid, $reason) = $self->validate_username($username);
  croak "invalid username ($reason)" if !$valid;
  return $username;
}

sub _new_passphrase {
  my ($self, $passphrase) = @_;
  my ($valid, $reason) = $self->validate_passphrase($passphrase);
  croak "invalid passphrase ($reason)" if !$valid;
  return NFC($passphrase);
}

sub _verification_passphrase {
  my ($self, $passphrase) = @_;
  return undef if !defined $passphrase || ref($passphrase);
  my $normalized = eval { NFC($passphrase) };
  return undef if !defined $normalized || $@;
  return undef if $normalized =~ /[\p{Cc}\p{Cs}]/;
  return undef if length(encode_utf8($normalized)) > $MAX_PASSPHRASE_BYTES;
  return $normalized;
}

sub create_account {
  my ($self, $username, %attrs) = @_;
  $self->_ensure_initialized;
  $username = $self->_validated_username($username);
  _validate_account_attrs(\%attrs, 1);
  croak 'create_account cannot create an active account without a credential'
    if defined($attrs{status}) && $attrs{status} eq 'active';

  return $self->_with_lock("user:$username", sub {
    croak "account already exists: $username" if defined $self->_read_json($self->_account_path($username));
    my $now = $self->_now;
    my $account = {
      schema       => $SCHEMA_VERSION,
      username     => $username,
      role         => defined($attrs{role}) ? $attrs{role} : 'viewer',
      status       => defined($attrs{status}) ? $attrs{status} : 'incomplete',
      person       => defined($attrs{person}) && $attrs{person} ne '' ? $attrs{person} : undef,
      must_change  => $attrs{must_change} ? 1 : 0,
      auth_version => 1,
      created_at   => $now,
      updated_at   => $now,
      last_logon   => undef,
    };
    $self->_write_json($self->_account_path($username), $account);
    return $account;
  });
}

sub provision_account {
  my ($self, $username, $passphrase, %attrs) = @_;
  $self->_ensure_initialized;
  $username = $self->_validated_username($username);
  _validate_account_attrs(\%attrs, 1);
  my $final_status = delete($attrs{status}) || 'active';
  croak 'provisioned account status must be active or disabled'
    if $final_status ne 'active' && $final_status ne 'disabled';
  my $normalized = $self->_new_passphrase($passphrase);
  my $phc = $self->_crypto->hash_passphrase($normalized);
  $self->_dummy_phc; # Pre-warm equal-cost verification before the account becomes active.

  my $account = $self->_with_lock("user:$username", sub {
    croak "account already exists: $username" if defined $self->_read_json($self->_account_path($username));
    croak "credential already exists: $username" if defined $self->_read_json($self->_credential_path($username));
    my $now = $self->_now;
    my $record = {
      schema       => $SCHEMA_VERSION,
      username     => $username,
      role         => defined($attrs{role}) ? $attrs{role} : 'viewer',
      status       => 'incomplete',
      person       => defined($attrs{person}) && $attrs{person} ne '' ? $attrs{person} : undef,
      must_change  => $attrs{must_change} ? 1 : 0,
      auth_version => 1,
      created_at   => $now,
      updated_at   => $now,
      last_logon   => undef,
      credential_transition => {
        kind          => 'provision',
        target_status => $final_status,
        started_at    => $now,
      },
    };
    $self->_write_json($self->_account_path($username), $record);
    $self->_write_json($self->_credential_path($username), {
      schema     => $SCHEMA_VERSION,
      username   => $username,
      phc        => $phc,
      created_at => $now,
      updated_at => $now,
    });
    $record->{status} = $final_status;
    delete $record->{credential_transition};
    $record->{updated_at} = $self->_now;
    $self->_write_json($self->_account_path($username), $record);
    return $record;
  });
  $self->audit(event => 'account.create', result => 'success', username => $username);
  return $account;
}

sub read_account {
  my ($self, $username) = @_;
  $self->_ensure_initialized;
  $username = $self->_validated_username($username);
  return $self->_read_account_unchecked($username);
}

sub list_accounts {
  my ($self) = @_;
  $self->_ensure_initialized;
  my $dir = $self->_dir('USERS');
  $self->_guard_auth_path(File::Spec->catfile($dir, 'placeholder.json'));
  my $safe_dir = $self->_pinned_auth_path($dir);
  opendir(my $dh, $safe_dir) or croak "could not open account directory: $!";
  my @accounts;
  while (my $name = readdir $dh) {
    next if $name !~ /\A([a-z][a-z0-9]*(?:-[a-z0-9]+)*)\.json\z/;
    my $username = $1;
    next if !$self->validate_username($username);
    next if @accounts >= 500;
    my $account = eval { $self->read_account($username) };
    next if $@ || ref($account) ne 'HASH';
    my $sessions = eval { scalar $self->_sessions_for_user($username) };
    $sessions = 0 if !defined $sessions;
    push @accounts, {
      username    => $account->{username},
      role        => $account->{role},
      status      => $account->{status},
      must_change => $account->{must_change} ? 1 : 0,
      person      => defined($account->{person}) ? $account->{person} : '',
      last_logon  => $account->{last_logon},
      created_at  => $account->{created_at} || 0,
      updated_at  => $account->{updated_at} || 0,
      sessions    => 0 + $sessions,
    };
  }
  closedir($dh) or croak "could not close account directory: $!";
  return [ sort { $a->{username} cmp $b->{username} } @accounts ];
}

sub _read_account_unchecked {
  my ($self, $username) = @_;
  my $account = $self->_read_json($self->_account_path($username));
  return undef if !defined $account;
  croak "corrupt account record for $username"
    if ref($account) ne 'HASH'
      || ($account->{schema} || 0) != $SCHEMA_VERSION
      || !defined($account->{username})
      || $account->{username} ne $username
      || !$VALID_ROLE{$account->{role} || ''}
      || !$VALID_STATUS{$account->{status} || ''}
      || ($account->{auth_version} || 0) !~ /\A[1-9][0-9]*\z/;
  return $account;
}

sub update_account {
  my ($self, $username, %attrs) = @_;
  $self->_ensure_initialized;
  $username = $self->_validated_username($username);
  _validate_account_attrs(\%attrs, 0);
  croak 'no account attributes supplied' if !keys %attrs;

  my $changed = $self->_with_lock("user:$username", sub {
    my $record = $self->_read_account_unchecked($username);
    croak "account does not exist: $username" if !defined $record;
    if (defined($attrs{status}) && $attrs{status} eq 'active') {
      croak 'an account cannot be activated without a credential'
        if !defined $self->_read_json($self->_credential_path($username));
    }
    my $invalidate_sessions = grep {
      exists($attrs{$_}) && $record->{$_} ne $attrs{$_}
    } qw(role status);
    for my $field (keys %attrs) {
      $record->{$field} = $field eq 'must_change' ? ($attrs{$field} ? 1 : 0) : $attrs{$field};
    }
    $record->{person} = undef if exists($attrs{person}) && (!defined($attrs{person}) || $attrs{person} eq '');
    $record->{auth_version} = 1 + ($record->{auth_version} || 0)
      if $invalidate_sessions;
    $record->{updated_at} = $self->_now;
    $self->_write_json($self->_account_path($username), $record);
    my ($revoked, $cleanup_error) = (0, undef);
    if ($invalidate_sessions) {
      eval {
        $revoked = $self->_revoke_all_sessions_user_locked($username);
        1;
      } or $cleanup_error = $@ || 'session cleanup failed';
    }
    return {
      account => $record,
      invalidated_sessions => $invalidate_sessions ? 1 : 0,
      revoked => $revoked,
      cleanup_error => $cleanup_error,
    };
  });

  # The account record is the authoritative invalidation boundary: it is
  # replaced with the new auth_version before session files are removed.  If
  # physical cleanup or either audit later fails, no old session can become
  # valid again after a disable/enable or role-change sequence.
  my @post_commit_errors;
  if ($changed->{invalidated_sessions}) {
    if (defined($changed->{cleanup_error})) {
      push @post_commit_errors, $changed->{cleanup_error};
      eval {
        $self->audit(
          event => 'session.revoke_all', result => 'failure', username => $username,
          reason => 'account_security_update_cleanup_failed',
        );
        1;
      } or push @post_commit_errors, $@ || 'session cleanup failure audit failed';
    }
    else {
      eval {
        $self->_audit_revoke_all(
          $username, $changed->{revoked}, 'account_security_update',
        );
        1;
      } or push @post_commit_errors, $@ || 'session invalidation audit failed';
    }
  }
  eval {
    $self->audit(event => 'account.update', result => 'success', username => $username);
    1;
  } or push @post_commit_errors, $@ || 'account update audit failed';
  warn 'account update committed with post-commit failure: '
    . join('; ', @post_commit_errors)
    if @post_commit_errors;
  return $changed->{account};
}

sub _validate_account_attrs {
  my ($attrs, $creating) = @_;
  my %allowed = map { $_ => 1 } qw(role status person must_change);
  for my $field (keys %$attrs) {
    croak "unknown account attribute: $field" if !$allowed{$field};
  }
  croak 'invalid role' if defined($attrs->{role}) && !$VALID_ROLE{$attrs->{role}};
  croak 'invalid account status' if defined($attrs->{status}) && !$VALID_STATUS{$attrs->{status}};
  if (defined($attrs->{person}) && $attrs->{person} ne '') {
    require Orbit::Person;
    my $word = Orbit::Person->normalize($attrs->{person});
    croak 'invalid person pointer' if !defined($word) || $word eq '';
    $attrs->{person} = $word;
  }
  return;
}

sub bump_auth_version {
  my ($self, $username) = @_;
  $self->_ensure_initialized;
  $username = $self->_validated_username($username);
  return $self->_with_lock("user:$username", sub {
    my $account = $self->_read_account_unchecked($username);
    croak "account does not exist: $username" if !defined $account;
    $account->{auth_version} = 1 + ($account->{auth_version} || 0);
    $account->{updated_at} = $self->_now;
    $self->_write_json($self->_account_path($username), $account);
    return $account->{auth_version};
  });
}

sub create_credential {
  my ($self, $username, $passphrase) = @_;
  $self->_ensure_initialized;
  $username = $self->_validated_username($username);
  my $normalized = $self->_new_passphrase($passphrase);
  my $phc = $self->_crypto->hash_passphrase($normalized);
  $self->_dummy_phc;

  my $account = $self->_with_lock("user:$username", sub {
    my $record = $self->_read_account_unchecked($username);
    croak "account does not exist: $username" if !defined $record;
    croak "credential already exists: $username" if defined $self->_read_json($self->_credential_path($username));
    my $target_status = $record->{status};
    if ($record->{status} eq 'incomplete') {
      $target_status = 'active';
      if (ref($record->{credential_transition}) eq 'HASH'
          && $VALID_STATUS{$record->{credential_transition}{target_status} || ''}
          && $record->{credential_transition}{target_status} ne 'incomplete') {
        $target_status = $record->{credential_transition}{target_status};
      }
    }
    my $now = $self->_now;
    $self->_write_json($self->_credential_path($username), {
      schema     => $SCHEMA_VERSION,
      username   => $username,
      phc        => $phc,
      created_at => $now,
      updated_at => $now,
    });
    if ($record->{status} eq 'incomplete') {
      $record->{status} = $target_status;
      delete $record->{credential_transition};
      $record->{updated_at} = $now;
      $self->_write_json($self->_account_path($username), $record);
    }
    return $record;
  });
  $self->audit(event => 'credential.create', result => 'success', username => $username);
  return $account;
}

sub verify_passphrase {
  my ($self, $username, $passphrase) = @_;
  $self->_ensure_initialized;
  return 0 if !$self->validate_username($username);
  my $normalized = $self->_verification_passphrase($passphrase);
  return 0 if !defined $normalized;
  my $credential = $self->_read_credential($username);
  return 0 if !defined $credential;
  return $self->_crypto->verify_passphrase($credential->{phc}, $normalized) ? 1 : 0;
}

sub reset_passphrase {
  my ($self, $username, $passphrase, %opts) = @_;
  $self->_ensure_initialized;
  $username = $self->_validated_username($username);
  my $normalized = $self->_new_passphrase($passphrase);
  my $phc = $self->_crypto->hash_passphrase($normalized);
  my $must_change = exists($opts{must_change}) ? ($opts{must_change} ? 1 : 0) : 1;
  croak 'unknown reset_passphrase option' if grep { $_ ne 'must_change' } keys %opts;

  my $changed = $self->_with_lock("user:$username", sub {
    my $record = $self->_read_account_unchecked($username);
    croak "account does not exist: $username" if !defined $record;
    my $old = $self->_read_credential($username);
    my $now = $self->_now;

    # Stage the account first.  If either later file replacement fails, logins
    # fail closed and every old session has a stale auth_version.  A subsequent
    # administrator reset can safely recover the incomplete transition.
    my $target_status = $record->{status} eq 'incomplete' ? 'active' : $record->{status};
    if (ref($record->{credential_transition}) eq 'HASH'
        && $VALID_STATUS{$record->{credential_transition}{target_status} || ''}
        && $record->{credential_transition}{target_status} ne 'incomplete') {
      $target_status = $record->{credential_transition}{target_status};
    }
    $record->{auth_version} = 1 + ($record->{auth_version} || 0);
    $record->{must_change} = $must_change;
    $record->{status} = 'incomplete';
    $record->{updated_at} = $now;
    $record->{credential_transition} = {
      kind => 'reset', target_status => $target_status, started_at => $now,
    };
    $self->_write_json($self->_account_path($username), $record);

    $self->_write_json($self->_credential_path($username), {
      schema     => $SCHEMA_VERSION,
      username   => $username,
      phc        => $phc,
      created_at => defined($old) ? $old->{created_at} : $now,
      updated_at => $now,
    });
    $record->{status} = $target_status;
    delete $record->{credential_transition};
    $record->{updated_at} = $now;
    $self->_write_json($self->_account_path($username), $record);
    my $revoked = $self->_revoke_all_sessions_user_locked($username);
    return { account => $record, revoked => $revoked };
  });
  $self->_audit_revoke_all($username, $changed->{revoked}, 'credential_reset');
  $self->audit(event => 'credential.reset', result => 'success', username => $username);
  return $changed->{account};
}

sub change_passphrase {
  my ($self, $username, $old_passphrase, $new_passphrase, %context) = @_;
  $self->_ensure_initialized;
  $self->_crypto; # Fail closed before consulting credential state.
  croak 'unknown change_passphrase option'
    if grep { $_ ne 'ip' && $_ ne 'user_agent' && $_ ne 'request_id' } keys %context;

  $username = $self->_validated_username($username);
  my $ip = defined($context{ip}) ? $context{ip} : '';
  my $ua = defined($context{user_agent}) ? $context{user_agent} : '';
  my $old_normalized = $self->_verification_passphrase($old_passphrase);
  my $new_normalized = $self->_new_passphrase($new_passphrase);

  # A forced reset must actually rotate the temporary credential.  Compare the
  # canonical forms so decomposed/composed Unicode spellings cannot clear
  # must_change while leaving the effective secret unchanged.
  if (defined($old_normalized) && _constant_time_equal($old_normalized, $new_normalized)) {
    $self->audit(
      event => 'credential.change', result => 'denied', username => $username,
      ip => $ip, user_agent => $ua, reason => 'passphrase_reuse',
      request_id => $context{request_id},
    );
    return { ok => 0, error => 'passphrase_reuse' };
  }

  # A passphrase change is another expensive credential-verification endpoint.
  # Reserve the same account/IP capacity used by logon before doing Argon2 work,
  # so a valid session and CSRF token cannot bypass CPU/concurrency limits.
  my $admission = $self->_reserve_login_attempt($username, $ip);
  if (!$admission->{allowed} || !$admission->{credential_allowed}) {
    if ($admission->{allowed}) {
      # Account-only lockouts are masked during public logon, but this caller is
      # already authenticated.  Release the IP-only reservation without paying
      # a dummy hash or extending the account lockout.
      $self->_finish_login_attempt($admission, 'abort');
    }
    $self->audit(
      event => 'credential.change', result => 'throttled', username => $username,
      ip => $ip, user_agent => $ua, reason => 'rate_limited',
      request_id => $context{request_id},
    );
    return {
      ok => 0, error => 'throttled',
      retry_after => ($admission->{retry_after} || 1),
    };
  }

  my ($changed, $attempt_error);
  eval {
    $changed = $self->_with_lock("user:$username", sub {
      my $record = $self->_read_account_unchecked($username);
      return undef if !defined($record) || $record->{status} ne 'active';
      my $credential = $self->_read_credential($username);
      return undef if !defined $credential;

      # Verify the current secret before hashing attacker-selected new input.
      # Invalidly shaped current values still receive the one reserved verify;
      # they can never be accepted afterward.
      my $verified = $self->_crypto->verify_passphrase(
        $credential->{phc}, defined($old_normalized) ? $old_normalized : '',
      ) ? 1 : 0;
      return undef if !$verified || !defined($old_normalized);

      my $new_phc = $self->_crypto->hash_passphrase($new_normalized);
      my $now = $self->_now;

      $record->{auth_version} = 1 + ($record->{auth_version} || 0);
      $record->{must_change} = 0;
      $record->{status} = 'incomplete';
      $record->{updated_at} = $now;
      $record->{credential_transition} = {
        kind => 'change', target_status => 'active', started_at => $now,
      };
      $self->_write_json($self->_account_path($username), $record);

      $self->_write_json($self->_credential_path($username), {
        schema     => $SCHEMA_VERSION,
        username   => $username,
        phc        => $new_phc,
        created_at => $credential->{created_at},
        updated_at => $now,
      });
      $record->{status} = 'active';
      delete $record->{credential_transition};
      $record->{updated_at} = $now;
      $self->_write_json($self->_account_path($username), $record);
      my $revoked = $self->_revoke_all_sessions_user_locked($username);
      return { account => $record, revoked => $revoked };
    });
    1;
  } or $attempt_error = $@ || 'passphrase change attempt failed';

  if (defined $attempt_error) {
    eval { $self->_finish_login_attempt($admission, 'abort') };
    die $attempt_error;
  }

  if (!defined $changed) {
    my $after = $self->_finish_login_attempt($admission, 'failure');
    $self->audit(
      event => 'credential.change', result => 'failure', username => $username,
      ip => $ip, user_agent => $ua, reason => 'invalid_credentials',
      request_id => $context{request_id},
    );
    return {
      ok => 0, error => 'invalid_credentials',
      ($after->{allowed} ? () : (retry_after => $after->{retry_after})),
    };
  }

  # The credential replacement and session revocation above are irreversible.
  # A later rate-state or audit failure must not make the caller believe the old
  # passphrase/session still works.  Preserve the operational alert in server
  # logs while returning the committed state so the browser can rotate cleanly.
  my @post_commit_errors;
  eval { $self->_finish_login_attempt($admission, 'success'); 1 }
    or push @post_commit_errors, $@ || 'rate finalization failed';
  eval { $self->_audit_revoke_all($username, $changed->{revoked}, 'credential_change'); 1 }
    or push @post_commit_errors, $@ || 'session revocation audit failed';
  eval {
    $self->audit(
      event => 'credential.change', result => 'success', username => $username,
      ip => $ip, user_agent => $ua, request_id => $context{request_id},
    );
    1;
  } or push @post_commit_errors, $@ || 'credential change audit failed';
  warn 'passphrase change committed with post-commit failure: '
    . join('; ', @post_commit_errors)
    if @post_commit_errors;
  return {
    ok => 1, account => $changed->{account},
    (@post_commit_errors ? (warning => 'post_commit_failure') : ()),
  };
}

sub _read_credential {
  my ($self, $username) = @_;
  my $credential = $self->_read_json($self->_credential_path($username));
  return undef if !defined $credential;
  croak "corrupt credential record for $username"
    if ref($credential) ne 'HASH'
      || ($credential->{schema} || 0) != $SCHEMA_VERSION
      || ($credential->{username} || '') ne $username
      || !defined($credential->{phc})
      || $credential->{phc} !~ /\A\$argon2id\$/;
  return $credential;
}

sub authenticate {
  my ($self, $username, $passphrase, %context) = @_;
  $self->_ensure_initialized;
  $self->_crypto; # Fail closed before consulting account state.

  my $ip = defined($context{ip}) ? $context{ip} : '';
  my $ua = defined($context{user_agent}) ? $context{user_agent} : '';
  croak 'unknown authenticate option'
    if grep { $_ ne 'ip' && $_ ne 'user_agent' && $_ ne 'request_id' } keys %context;

  my $admission = $self->_reserve_login_attempt($username, $ip);
  if (!$admission->{allowed}) {
    $self->audit(
      event => 'auth.login', result => 'throttled', username => $username,
      ip => $ip, user_agent => $ua, reason => 'rate_limited', request_id => $context{request_id},
    );
    return { ok => 0, error => 'throttled', retry_after => $admission->{retry_after} };
  }

  my $normalized = $self->_verification_passphrase($passphrase);

  # An account bucket may be locked while the shared IP bucket still has
  # capacity.  Returning before Argon2 in that case makes the shared unknown-
  # user bucket a username oracle: locked unknown names are fast while a real,
  # not-yet-locked account is slow.  Consume the already-reserved IP capacity
  # with exactly one dummy verification, but never consult credentials or mint
  # a session.  The IP bucket remains the hard pre-hash CPU/concurrency gate.
  if (!$admission->{credential_allowed}) {
    my $verification_error;
    eval {
      my $dummy = $self->_dummy_phc;
      $self->_crypto->verify_passphrase(
        $dummy, defined($normalized) ? $normalized : '',
      );
      1;
    } or $verification_error = $@ || 'masked authentication attempt failed';

    if (defined $verification_error) {
      eval { $self->_finish_login_attempt($admission, 'abort') };
      die $verification_error;
    }

    $self->_finish_login_attempt($admission, 'failure');
    $self->audit(
      event => 'auth.login', result => 'failure', username => $username,
      ip => $ip, user_agent => $ua, reason => 'account_rate_limited',
      request_id => $context{request_id},
    );
    return { ok => 0, error => 'invalid_credentials' };
  }

  my $attempt;
  my $provisional_created;
  my $attempt_error;
  eval {
    my ($pre_account, $pre_error);
    if ($self->validate_username($username)) {
      $pre_account = eval { $self->_read_account_unchecked($username) };
      $pre_error = $@;
    }

    if (defined($pre_account) && !$pre_error) {
      # Only persisted accounts get a per-user lock.  Unknown attacker-chosen
      # names never create an unbounded lock-file namespace.  The account is
      # re-read after locking, so this preliminary existence check grants no
      # authority and credential changes cannot interleave verification/minting.
      $attempt = $self->_with_lock("user:$username", sub {
        my ($account, $credential, $internal_reason);
        my $account_error;
        $account = eval { $self->_read_account_unchecked($username) };
        $account_error = $@;
        $internal_reason = 'account_unavailable' if $account_error;
        if (defined($account) && $account->{status} eq 'active') {
          my $credential_error;
          $credential = eval { $self->_read_credential($username) };
          $credential_error = $@;
          $internal_reason = 'credential_unavailable' if $credential_error || !defined($credential);
        }
        else {
          $internal_reason ||= defined($account) ? 'account_inactive' : 'unknown_account';
        }

        my $phc = defined($credential) ? $credential->{phc} : $self->_dummy_phc;
        my $verified = eval {
          $self->_crypto->verify_passphrase($phc, defined($normalized) ? $normalized : '')
        } ? 1 : 0;
        $verified = 0 if !defined($credential) || !defined($account) || !defined($normalized);
        return { verified => 0, reason => ($internal_reason || 'invalid_credentials') }
          if !$verified;

        if ($self->_crypto->needs_rehash($credential->{phc})) {
          $credential->{phc} = $self->_crypto->hash_passphrase($normalized);
          $credential->{updated_at} = $self->_now;
          $self->_write_json($self->_credential_path($username), $credential);
        }

        $self->_record_last_logon_user_locked($account);
        my $created = $self->_create_session_user_locked(
          $username, $account, ip => $ip, user_agent => $ua,
        );
        $provisional_created = $created;
        return { verified => 1, account => $account, created => $created };
      });
    }
    else {
      # Invalid and unknown identifiers still pay one Argon2 verification, but
      # cannot be used as per-user lock or account path names.
      my $dummy = $self->_dummy_phc;
      eval { $self->_crypto->verify_passphrase($dummy, defined($normalized) ? $normalized : '') };
      $attempt = {
        verified => 0,
        reason => !$self->validate_username($username) ? 'invalid_username'
          : ($pre_error ? 'account_unavailable' : 'unknown_account'),
      };
    }
    1;
  } or $attempt_error = $@ || 'authentication attempt failed';

  if (defined $attempt_error) {
    eval { $self->_finish_login_attempt($admission, 'abort') };
    eval { $self->revoke_session($provisional_created->{token}, reason => 'login_transaction_failure') }
      if ref($provisional_created) eq 'HASH' && defined($provisional_created->{token});
    die $attempt_error;
  }

  if (!$attempt->{verified}) {
    $self->_finish_login_attempt($admission, 'failure');
    $self->audit(
      event => 'auth.login', result => 'failure', username => $username,
      ip => $ip, user_agent => $ua, reason => $attempt->{reason},
      request_id => $context{request_id},
    );
    return { ok => 0, error => 'invalid_credentials' };
  }

  my $finish_error;
  eval { $self->_finish_login_attempt($admission, 'success'); 1 }
    or $finish_error = $@ || 'could not finalize authentication admission';
  if (defined $finish_error) {
    # A caller must never receive a bearer session when rate-limit state could
    # not be finalized.  Best-effort revocation leaves the operation fail closed.
    eval { $self->revoke_session($attempt->{created}{token}, reason => 'rate_finalize_failure') };
    die $finish_error;
  }
  my $created = $attempt->{created};
  my $audit_error;
  eval {
    $self->_audit_session_create($username, $created, ip => $ip, user_agent => $ua);
    $self->audit(
      event => 'auth.login', result => 'success', username => $username,
      ip => $ip, user_agent => $ua, request_id => $context{request_id},
      session_digest => $created->{session}{session_digest},
    );
    1;
  } or $audit_error = $@ || 'could not audit successful authentication';
  if (defined $audit_error) {
    eval { $self->revoke_session($created->{token}, reason => 'login_audit_failure') };
    die $audit_error;
  }
  return { ok => 1, account => $attempt->{account}, %$created };
}

sub _record_last_logon_user_locked {
  my ($self, $account) = @_;
  return if !defined $account;
  $account->{last_logon} = $self->_now;
  $account->{updated_at} = $self->_now;
  $self->_write_json($self->_account_path($account->{username}), $account);
  return;
}

sub create_session {
  my ($self, $username, %context) = @_;
  $self->_ensure_initialized;
  $username = $self->_validated_username($username);
  croak 'unknown create_session option'
    if grep { $_ ne 'ip' && $_ ne 'user_agent' } keys %context;
  my $created = $self->_with_lock("user:$username", sub {
    my $account = $self->_read_account_unchecked($username);
    croak 'cannot create a session for an inactive account'
      if !defined($account) || $account->{status} ne 'active';
    return $self->_create_session_user_locked($username, $account, %context);
  });
  my $audit_error;
  eval { $self->_audit_session_create($username, $created, %context); 1 }
    or $audit_error = $@ || 'session creation audit failed';
  if (defined $audit_error) {
    # Do not return an unaudited bearer token.  Best-effort removal makes a
    # direct session creation failure transactional from the caller's view.
    eval { $self->revoke_session($created->{token}, reason => 'session_audit_failure') };
    die $audit_error;
  }
  return $created;
}

sub _create_session_user_locked {
  my ($self, $username, $account, %context) = @_;
  my ($token, $csrf, $session);
  $self->_with_lock("sessions:$username", sub {
    for (1 .. 5) {
      $token = _base64url($self->_random_bytes(32));
      my $digest = sha256_hex($token);
      my $candidate = $self->_pinned_auth_path($self->_session_path($digest));
      next if -e $candidate || -l $candidate;
      $csrf = _base64url($self->_random_bytes(32));
      my $now = $self->_now;
      $session = {
        schema              => $SCHEMA_VERSION,
        session_digest      => $digest,
        username            => $username,
        auth_version        => $account->{auth_version},
        created_at          => $now,
        last_seen           => $now,
        idle_expires_at     => $now + $self->{idle_timeout},
        absolute_expires_at => $now + $self->{absolute_timeout},
        csrf_secret         => $csrf,
        ip_hash             => _bounded_digest($context{ip}),
        user_agent_hash     => _bounded_digest($context{user_agent}),
      };
      $self->_write_json($self->_session_path($digest), $session);
      last;
    }
    croak 'could not allocate a unique session token' if !defined $session;
    $self->_enforce_session_cap_unlocked($username, $session->{session_digest});
    return;
  });
  return { token => $token, csrf_token => $csrf, session => $session };
}

sub _audit_session_create {
  my ($self, $username, $created, %context) = @_;
  $self->audit(
    event => 'session.create', result => 'success', username => $username,
    ip => $context{ip}, user_agent => $context{user_agent},
    session_digest => $created->{session}{session_digest},
  );
  return;
}

sub restore_session {
  my ($self, $token, %opts) = @_;
  $self->_ensure_initialized;
  croak 'unknown restore_session option'
    if grep { $_ ne 'touch' && $_ ne 'ip' && $_ ne 'user_agent' } keys %opts;
  return { ok => 0, reason => 'invalid_token' }
    if !defined($token) || ref($token) || $token !~ /\A[A-Za-z0-9_-]{40,128}\z/;

  my $digest = sha256_hex($token);
  my $path = $self->_session_path($digest);
  my $session = eval { $self->_read_json($path) };
  return { ok => 0, reason => 'corrupt' } if $@;
  return { ok => 0, reason => 'not_found' } if !defined $session;
  return { ok => 0, reason => 'corrupt' } if !$self->_valid_session_record($session, $digest);
  my $username = $session->{username};
  my $touch = exists($opts{touch}) ? $opts{touch} : 1;
  my $outcome = $self->_with_lock("user:$username", sub {
    my ($account, $account_error);
    $account = eval { $self->_read_account_unchecked($username) };
    $account_error = $@;

    return $self->_with_lock("sessions:$username", sub {
      # Always re-read after taking the common per-user sessions lock.  This is
      # the lock used by touch, revoke, revoke-all, creation, and cap eviction.
      my $fresh = $self->_read_json($path);
      return { ok => 0, reason => 'not_found' } if !defined $fresh;
      if (!$self->_valid_session_record($fresh, $digest) || $fresh->{username} ne $username) {
        $self->_safe_unlink($path);
        return { ok => 0, reason => 'corrupt', removed => 1 };
      }

      my $now = $self->_now;
      my $reason;
      $reason = 'absolute_expired' if $now >= $fresh->{absolute_expires_at};
      $reason ||= 'idle_expired' if $now >= $fresh->{idle_expires_at};
      $reason ||= 'account_missing' if $account_error || !defined $account;
      $reason ||= 'account_inactive' if defined($account) && $account->{status} ne 'active';
      $reason ||= 'auth_version_changed'
        if defined($account) && $fresh->{auth_version} != $account->{auth_version};
      if (defined $reason) {
        $self->_safe_unlink($path);
        return { ok => 0, reason => $reason, removed => 1 };
      }

      if ($touch && $now - $fresh->{last_seen} >= $self->{touch_interval}) {
        $fresh->{last_seen} = $now;
        my $idle = $now + $self->{idle_timeout};
        $fresh->{idle_expires_at} = $idle < $fresh->{absolute_expires_at}
          ? $idle : $fresh->{absolute_expires_at};
        $self->_write_json($path, $fresh);
      }
      return { ok => 1, account => $account, session => $fresh };
    });
  });

  if (!$outcome->{ok}) {
    $self->_audit_session_revoke($username, $digest, $outcome->{reason}) if $outcome->{removed};
    return { ok => 0, reason => $outcome->{reason} };
  }

  # Role and status intentionally come from the fresh account record, never the session.
  # csrf_token is a response-only alias used by the Orbit facade; it is not persisted.
  my $account = $outcome->{account};
  my $returned_session = {
    %{$outcome->{session}}, csrf_token => $outcome->{session}{csrf_secret},
  };
  return {
    ok       => 1,
    reason   => 'ok',
    username => $account->{username},
    role     => $account->{role},
    status   => $account->{status},
    account  => $account,
    session  => $returned_session,
  };
}

sub _valid_session_record {
  my ($self, $session, $digest) = @_;
  return 0 if ref($session) ne 'HASH';
  return 0 if ($session->{schema} || 0) != $SCHEMA_VERSION;
  return 0 if ($session->{session_digest} || '') ne $digest;
  return 0 if !$self->validate_username($session->{username});
  return 0 if ($session->{auth_version} || 0) !~ /\A[1-9][0-9]*\z/;
  for my $field (qw(created_at last_seen idle_expires_at absolute_expires_at)) {
    return 0 if !defined($session->{$field}) || $session->{$field} !~ /\A[0-9]+(?:\.[0-9]+)?\z/;
  }
  return 0 if !defined($session->{csrf_secret})
    || $session->{csrf_secret} !~ /\A[A-Za-z0-9_-]{40,128}\z/;
  return 1;
}

sub verify_csrf {
  my ($self, $session_or_restore, $candidate) = @_;
  return 0 if !defined($candidate) || ref($candidate);
  return 0 if length($candidate) < 40 || length($candidate) > 128;
  my $session = $session_or_restore;
  if (ref($session_or_restore) eq 'HASH' && exists $session_or_restore->{session}) {
    $session = $session_or_restore->{session};
  }
  return 0 if ref($session) ne 'HASH' || !defined($session->{csrf_secret});
  return _constant_time_equal($session->{csrf_secret}, $candidate);
}

# Login happens before a server-side session exists, so its form uses a
# short-lived double-submit nonce instead of the session CSRF secret.  The
# caller puts the same opaque value in a host-only cookie and the form.  Keep
# generation and comparison behind the crypto boundary so tests can inject a
# deterministic provider without weakening production entropy.
sub issue_login_nonce {
  my ($self) = @_;
  my $bytes = $self->_random_bytes(32);
  return _base64url($bytes);
}

sub verify_login_nonce {
  my ($self, $cookie, $candidate) = @_;
  return 0 if !defined($cookie) || !defined($candidate)
    || ref($cookie) || ref($candidate);
  return 0 if $cookie !~ /\A[A-Za-z0-9_-]{43}\z/
    || $candidate !~ /\A[A-Za-z0-9_-]{43}\z/;
  return _constant_time_equal($cookie, $candidate);
}

sub _constant_time_equal {
  my ($left, $right) = @_;
  return 0 if !defined($left) || !defined($right) || ref($left) || ref($right);
  my $difference = length($left) ^ length($right);
  my $length = length($left) > length($right) ? length($left) : length($right);
  for my $index (0 .. $length - 1) {
    my $a = $index < length($left)  ? ord(substr($left,  $index, 1)) : 0;
    my $b = $index < length($right) ? ord(substr($right, $index, 1)) : 0;
    $difference |= $a ^ $b;
  }
  return $difference == 0 ? 1 : 0;
}

sub revoke_session {
  my ($self, $token, %opts) = @_;
  $self->_ensure_initialized;
  croak 'unknown revoke_session option' if grep { $_ ne 'reason' } keys %opts;
  return 0 if !defined($token) || ref($token) || $token !~ /\A[A-Za-z0-9_-]{40,128}\z/;
  my $digest = sha256_hex($token);
  my $path = $self->_session_path($digest);
  my $session = eval { $self->_read_json($path) };
  my $read_error = $@;
  return 0 if !defined($session) && !$read_error;

  my $username = ref($session) eq 'HASH' && $self->validate_username($session->{username})
    ? $session->{username} : undef;
  my $removed;
  if (defined $username) {
    $removed = $self->_with_lock("user:$username", sub {
      return $self->_with_lock("sessions:$username", sub {
        my $safe_path = $self->_pinned_auth_path($path);
        return 0 if !-e $safe_path && !-l $safe_path;
        $self->_safe_unlink($path);
        return 1;
      });
    });
  }
  else {
    # A malformed legacy/orphan record has no safe per-user lock key.  It can
    # never be restored; remove only this digest path under a fixed striped
    # orphan lock.  Attacker-chosen bearer values cannot grow LOCKS without
    # bound.
    $removed = $self->_with_lock($self->_orphan_lock_key($digest), sub {
      my $safe_path = $self->_pinned_auth_path($path);
      return 0 if !-e $safe_path && !-l $safe_path;
      $self->_safe_unlink($path);
      return 1;
    });
  }
  if ($removed) {
    eval { $self->_audit_session_revoke($username, $digest, $opts{reason}); 1 }
      or warn 'session revocation committed but audit failed: '
        . ($@ || 'unknown audit failure');
  }
  return $removed;
}

sub revoke_all_sessions {
  my ($self, $username, %opts) = @_;
  $self->_ensure_initialized;
  $username = $self->_validated_username($username);
  croak 'unknown revoke_all_sessions option'
    if grep { $_ ne 'reason' && $_ ne 'except_token' } keys %opts;
  my $except_digest = defined($opts{except_token}) ? sha256_hex($opts{except_token}) : undef;
  my $count = $self->_with_lock("user:$username", sub {
    return $self->_revoke_all_sessions_user_locked($username, $except_digest);
  });
  eval { $self->_audit_revoke_all($username, $count, $opts{reason}); 1 }
    or warn 'session revocation committed but audit failed: '
      . ($@ || 'unknown audit failure');
  return $count;
}

sub _revoke_all_sessions_user_locked {
  my ($self, $username, $except_digest) = @_;
  return $self->_with_lock("sessions:$username", sub {
    my $removed = 0;
    for my $item ($self->_sessions_for_user($username)) {
      next if defined($except_digest) && $item->{digest} eq $except_digest;
      $self->_safe_unlink($item->{path});
      $removed++;
    }
    return $removed;
  });
}

sub _audit_revoke_all {
  my ($self, $username, $count, $reason) = @_;
  $self->audit(
    event => 'session.revoke_all', result => 'success', username => $username,
    reason => $reason, count => $count,
  );
  return;
}

sub _audit_session_revoke {
  my ($self, $username, $digest, $reason) = @_;
  $self->audit(
    event => 'session.revoke', result => 'success', username => $username,
    reason => $reason, session_digest => $digest,
  );
  return;
}

sub _enforce_session_cap_unlocked {
  my ($self, $username, $new_digest) = @_;
  my @sessions = sort {
    $a->{session}{created_at} <=> $b->{session}{created_at}
      || $a->{digest} cmp $b->{digest}
  } $self->_sessions_for_user($username);
  while (@sessions > $self->{max_sessions}) {
    my $oldest = shift @sessions;
    if ($oldest->{digest} eq $new_digest && @sessions) {
      push @sessions, $oldest;
      $oldest = shift @sessions;
    }
    $self->_safe_unlink($oldest->{path});
  }
  return;
}

sub _sessions_for_user {
  my ($self, $username) = @_;
  my $dir = $self->_dir('SESSIONS');
  $self->_guard_auth_path(File::Spec->catfile($dir, 'placeholder'));
  my $safe_dir = $self->_pinned_auth_path($dir);
  opendir(my $dh, $safe_dir) or croak "could not open session directory: $!";
  my @items;
  while (my $name = readdir $dh) {
    next if $name !~ /\A([0-9a-f]{64})\.json\z/;
    my $digest = $1;
    my $path = File::Spec->catfile($dir, $name);
    my $session = eval { $self->_read_json($path) };
    next if $@ || ref($session) ne 'HASH' || ($session->{username} || '') ne $username;
    push @items, { digest => $digest, path => $path, session => $session };
  }
  closedir($dh) or croak "could not close session directory: $!";
  return @items;
}

sub check_rate_limit {
  my ($self, $username, $ip) = @_;
  $self->_ensure_initialized;
  my $account_key = $self->_login_account_rate_subject($username, $ip);
  my $ip_key = _rate_subject($ip);
  return $self->_with_rate_locks($account_key, $ip_key, sub {
    my $now = $self->_now;
    my $account = $self->_load_rate_state('ACCOUNT', $account_key, $now);
    my $address = $self->_load_rate_state('IP', $ip_key, $now);
    return $self->_combined_rate_status($account, $address, $now);
  });
}

sub admit_self_signup {
  my ($self, $ip) = @_;
  $self->_ensure_initialized;
  my $ip_key = _rate_subject($ip);
  return $self->_with_lock($self->_rate_lock_key('IP', $ip_key), sub {
    my $now = $self->_now;
    my $address = $self->_load_rate_state('IP', $ip_key, $now);
    my $status = $self->_bucket_status($address, $self->{ip_limit}, $now);
    return $status if !$status->{allowed};

    # Count the request before the caller can begin Argon2 work.  This makes
    # the existing per-IP bucket a hard sequential as well as concurrent gate
    # for public account creation.
    $self->_append_rate_failure($address, $self->{ip_limit}, $now);
    $self->_store_rate_state('IP', $ip_key, $address, $now);
    my $after = $self->_bucket_status($address, $self->{ip_limit}, $now);
    return { %$after, allowed => 1 };
  });
}

sub record_login_failure {
  my ($self, $username, $ip) = @_;
  $self->_ensure_initialized;
  my $account_key = $self->_login_account_rate_subject($username, $ip);
  my $ip_key = _rate_subject($ip);
  return $self->_with_rate_locks($account_key, $ip_key, sub {
    my $now = $self->_now;
    my $account = $self->_load_rate_state('ACCOUNT', $account_key, $now);
    my $address = $self->_load_rate_state('IP', $ip_key, $now);
    $self->_append_rate_failure($account, $self->{account_limit}, $now);
    $self->_append_rate_failure($address, $self->{ip_limit}, $now);
    $self->_store_rate_state('ACCOUNT', $account_key, $account, $now);
    $self->_store_rate_state('IP', $ip_key, $address, $now);
    return $self->_combined_rate_status($account, $address, $now);
  });
}

sub record_login_success {
  my ($self, $username, $ip) = @_;
  $self->_ensure_initialized;
  my $account_key = _account_rate_subject($username);
  return 0 if !$self->validate_username($account_key);
  my $known_account = eval { $self->_read_account_unchecked($account_key) };
  return 0 if $@ || !defined($known_account) || $known_account->{status} ne 'active';
  my $ip_key = _rate_subject($ip);
  $self->_with_rate_locks($account_key, $ip_key, sub {
    my $now = $self->_now;
    my $account = $self->_load_rate_state('ACCOUNT', $account_key, $now);
    my $address = $self->_load_rate_state('IP', $ip_key, $now);
    $account->{failures} = [];
    $account->{locked_until} = 0;
    $self->_store_rate_state('ACCOUNT', $account_key, $account, $now);
    $self->_store_rate_state('IP', $ip_key, $address, $now);
    return 1;
  });
  return 1;
}

sub _reserve_login_attempt {
  my ($self, $username, $ip) = @_;
  $self->_ensure_initialized;
  my $ip_key = _rate_subject($ip);

  # Consult the hard pre-hash IP gate before resolving whether the submitted
  # username has an account bucket.  Besides avoiding needless account I/O for
  # a blocked source, this guarantees retry_after reflects only source-IP state
  # and cannot disclose a separately locked real account.
  my $initial_ip_status = $self->_with_lock(
    $self->_rate_lock_key('IP', $ip_key),
    sub {
      my $now = $self->_now;
      my $address = $self->_load_rate_state('IP', $ip_key, $now);
      return $self->_bucket_status($address, $self->{ip_limit}, $now);
    },
  );
  return {
    allowed => 0,
    retry_after => $initial_ip_status->{retry_after},
    ip_count => $initial_ip_status->{count},
    ip_in_flight => $initial_ip_status->{in_flight},
  } if !$initial_ip_status->{allowed};

  my $account_key = $self->_login_account_rate_subject($username, $ip);
  return $self->_with_rate_locks($account_key, $ip_key, sub {
    my $now = $self->_now;
    my $account = $self->_load_rate_state('ACCOUNT', $account_key, $now);
    my $address = $self->_load_rate_state('IP', $ip_key, $now);
    my $status = $self->_combined_rate_status($account, $address, $now);
    my $account_status = $self->_bucket_status($account, $self->{account_limit}, $now);
    my $ip_status = $self->_bucket_status($address, $self->{ip_limit}, $now);

    # Only the shared IP limit may reject before expensive verification.  If
    # just the account bucket is blocked, admit a masked dummy verification so
    # known and unknown usernames have the same expensive response shape.
    return {
      allowed => 0,
      retry_after => $ip_status->{retry_after},
      ip_count => $ip_status->{count},
      ip_in_flight => $ip_status->{in_flight},
    } if !$ip_status->{allowed};
    my $credential_allowed = $account_status->{allowed} ? 1 : 0;

    my $reservation_id;
    for (1 .. 5) {
      my $candidate = _base64url($self->_random_bytes(16));
      next if exists($account->{reservations}{$candidate})
        || exists($address->{reservations}{$candidate});
      $reservation_id = $candidate;
      last;
    }
    croak 'could not allocate a unique login reservation' if !defined $reservation_id;
    my $expires = $now + $self->{reservation_ttl};
    $account->{reservations}{$reservation_id} = $expires
      if $credential_allowed;
    $address->{reservations}{$reservation_id} = $expires;
    $self->_store_rate_state('ACCOUNT', $account_key, $account, $now);
    $self->_store_rate_state('IP', $ip_key, $address, $now);
    return {
      %$status,
      allowed        => 1,
      credential_allowed => $credential_allowed,
      account_reserved   => $credential_allowed,
      reservation_id => $reservation_id,
      account_key    => $account_key,
      ip_key         => $ip_key,
    };
  });
}

sub _finish_login_attempt {
  my ($self, $reservation, $outcome) = @_;
  croak 'invalid login reservation' if ref($reservation) ne 'HASH'
    || !$reservation->{allowed}
    || !defined($reservation->{reservation_id})
    || $reservation->{reservation_id} !~ /\A[A-Za-z0-9_-]{20,64}\z/
    || !defined($reservation->{account_key})
    || !defined($reservation->{ip_key})
    || !defined($reservation->{credential_allowed})
    || $reservation->{credential_allowed} !~ /\A[01]\z/
    || !defined($reservation->{account_reserved})
    || $reservation->{account_reserved} !~ /\A[01]\z/;
  croak 'invalid login reservation outcome'
    if !defined($outcome) || $outcome !~ /\A(?:success|failure|abort)\z/;

  my $account_key = _account_rate_subject($reservation->{account_key});
  my $ip_key = $reservation->{ip_key};
  my $reservation_id = $reservation->{reservation_id};
  return $self->_with_rate_locks($account_key, $ip_key, sub {
    my $now = $self->_now;
    my $account = $self->_load_rate_state('ACCOUNT', $account_key, $now);
    my $address = $self->_load_rate_state('IP', $ip_key, $now);
    delete $account->{reservations}{$reservation_id}
      if $reservation->{account_reserved};
    delete $address->{reservations}{$reservation_id};

    if ($outcome eq 'failure') {
      $self->_append_rate_failure($account, $self->{account_limit}, $now)
        if $reservation->{credential_allowed};
      $self->_append_rate_failure($address, $self->{ip_limit}, $now);
    }
    elsif ($outcome eq 'success') {
      croak 'masked login reservation cannot succeed'
        if !$reservation->{credential_allowed};
      # A successful credential verification clears only that account's failed
      # history.  Other in-flight reservations and the shared-IP history stay.
      $account->{failures} = [];
      $account->{locked_until} = 0;
    }

    $self->_store_rate_state('ACCOUNT', $account_key, $account, $now);
    $self->_store_rate_state('IP', $ip_key, $address, $now);
    return $self->_combined_rate_status($account, $address, $now);
  });
}

sub _append_rate_failure {
  my ($self, $state, $limit, $now) = @_;
  push @{$state->{failures}}, $now;
  splice(@{$state->{failures}}, 0, @{$state->{failures}} - $limit)
    if @{$state->{failures}} > $limit;
  $state->{locked_until} = $now + $self->{lockout}
    if @{$state->{failures}} >= $limit;
  return;
}

sub _login_account_rate_subject {
  my ($self, $username, $ip) = @_;
  my $candidate = _account_rate_subject($username);
  if ($self->validate_username($candidate)) {
    my $account = eval { $self->_read_account_unchecked($candidate) };
    return $candidate if !$@ && defined $account;
  }

  # Nonexistent identifiers share a five-attempt account bucket per source IP.
  # This preserves the tighter account limit without creating one persistent
  # ACCOUNT file for every attacker-chosen username candidate.
  my $ip_key = _rate_subject($ip);
  return '<unknown-ip>:' . sha256_hex(encode_utf8($ip_key));
}

sub _load_rate_state {
  my ($self, $type, $key, $now) = @_;
  $key = $type eq 'ACCOUNT' ? _account_rate_subject($key) : _rate_subject($key);
  my $path = $self->_rate_path($type, $key);
  my $state = $self->_read_json($path);
  if (!defined $state) {
    return {
      schema => $SCHEMA_VERSION,
      subject_digest => sha256_hex(encode_utf8($key)),
      failures => [], reservations => {}, locked_until => 0,
    };
  }

  croak "corrupt rate-limit record: $path"
    if ref($state) ne 'HASH'
      || ($state->{schema} || 0) != $SCHEMA_VERSION
      || ($state->{subject_digest} || '') ne sha256_hex(encode_utf8($key))
      || ref($state->{failures}) ne 'ARRAY'
      || (defined($state->{reservations}) && ref($state->{reservations}) ne 'HASH')
      || !defined($state->{locked_until})
      || $state->{locked_until} !~ /\A[0-9]+(?:\.[0-9]+)?\z/;
  for my $failure (@{$state->{failures}}) {
    croak "corrupt rate-limit record: $path"
      if !defined($failure) || ref($failure) || $failure !~ /\A[0-9]+(?:\.[0-9]+)?\z/;
  }
  $state->{reservations} ||= {};
  for my $id (keys %{$state->{reservations}}) {
    my $expires = $state->{reservations}{$id};
    croak "corrupt rate-limit record: $path"
      if $id !~ /\A[A-Za-z0-9_-]{20,64}\z/
        || !defined($expires) || ref($expires)
        || $expires !~ /\A[0-9]+(?:\.[0-9]+)?\z/;
  }

  my @recent = grep { $_ > $now - $self->{rate_window} } @{$state->{failures}};
  my %active = map { $_ => $state->{reservations}{$_} }
    grep { $state->{reservations}{$_} > $now } keys %{$state->{reservations}};
  $state->{failures} = \@recent;
  $state->{reservations} = \%active;
  $state->{locked_until} = 0 if $state->{locked_until} <= $now;
  return $state;
}

sub _store_rate_state {
  my ($self, $type, $key, $state, $now) = @_;
  $key = $type eq 'ACCOUNT' ? _account_rate_subject($key) : _rate_subject($key);
  my $path = $self->_rate_path($type, $key);
  if (!@{$state->{failures}}
      && !keys(%{$state->{reservations}})
      && ($state->{locked_until} || 0) <= $now) {
    my $safe_path = $self->_pinned_auth_path($path);
    $self->_safe_unlink($path) if -e $safe_path || -l $safe_path;
    return;
  }
  $state->{updated_at} = $now;
  $self->_write_json($path, $state);
  return;
}

sub _bucket_status {
  my ($self, $state, $limit, $now) = @_;
  my $failure_count = scalar @{$state->{failures}};
  my $reservation_count = scalar keys %{$state->{reservations}};
  my $total = $failure_count + $reservation_count;
  my $locked_remaining = ($state->{locked_until} || 0) > $now
    ? $state->{locked_until} - $now : 0;
  my $capacity_remaining = 0;
  if ($total >= $limit) {
    my @release_times = sort { $a <=> $b } (
      map { $_ + $self->{rate_window} } @{$state->{failures}},
      values %{$state->{reservations}},
    );
    my $release_index = $total - $limit;
    $capacity_remaining = $release_times[$release_index] - $now
      if defined $release_times[$release_index] && $release_times[$release_index] > $now;
  }
  my $blocked = $locked_remaining > 0 || $total >= $limit;
  my $remaining = $locked_remaining > $capacity_remaining
    ? $locked_remaining : $capacity_remaining;
  return {
    allowed => $blocked ? 0 : 1,
    retry_after => $blocked ? int($remaining + 0.999) : 0,
    count => $failure_count,
    in_flight => $reservation_count,
  };
}

sub _combined_rate_status {
  my ($self, $account_state, $ip_state, $now) = @_;
  my $account = $self->_bucket_status($account_state, $self->{account_limit}, $now);
  my $address = $self->_bucket_status($ip_state, $self->{ip_limit}, $now);
  my $allowed = $account->{allowed} && $address->{allowed};
  my $retry = $account->{retry_after} > $address->{retry_after}
    ? $account->{retry_after} : $address->{retry_after};
  return {
    allowed           => $allowed ? 1 : 0,
    retry_after       => $allowed ? 0 : $retry,
    account_count     => $account->{count},
    ip_count          => $address->{count},
    account_in_flight => $account->{in_flight},
    ip_in_flight      => $address->{in_flight},
  };
}

sub _with_rate_locks {
  my ($self, $account_key, $ip_key, $code) = @_;
  $account_key = _account_rate_subject($account_key);
  $ip_key = _rate_subject($ip_key);
  my %seen;
  my @locks = sort grep { !$seen{$_}++ } (
    $self->_rate_lock_key('ACCOUNT', $account_key),
    $self->_rate_lock_key('IP', $ip_key),
  );
  my $acquire;
  $acquire = sub {
    my ($index) = @_;
    return $code->() if $index >= @locks;
    return $self->_with_lock($locks[$index], sub { $acquire->($index + 1) });
  };
  return $acquire->(0);
}

sub maintain {
  my ($self, %opts) = @_;
  $self->_ensure_initialized;
  croak 'unknown maintain option' if keys %opts;
  my $summary = {
    sessions_removed => 0,
    rate_buckets_removed => 0,
    rate_buckets_rewritten => 0,
    errors => 0,
  };

  $self->_maintain_sessions($summary);
  $self->_maintain_rate_buckets($summary);
  eval {
    $self->_with_lock('audit-log', sub {
      $self->_prune_audit_archives_unlocked;
      return;
    });
    1;
  } or $summary->{errors}++;

  $self->audit(
    event => 'auth.maintenance',
    result => $summary->{errors} ? 'failure' : 'success',
    reason => $summary->{errors} ? 'retained_unsafe_records' : 'complete',
    count => $summary->{sessions_removed} + $summary->{rate_buckets_removed},
  );
  return $summary;
}

sub _maintain_sessions {
  my ($self, $summary) = @_;
  my $dir = $self->_dir('SESSIONS');
  $self->_guard_auth_path(File::Spec->catfile($dir, 'placeholder'));
  my $safe_dir = $self->_pinned_auth_path($dir);
  opendir(my $dh, $safe_dir) or croak "could not open session directory: $!";
  my @digests;
  while (my $name = readdir $dh) {
    push @digests, $1 if $name =~ /\A([0-9a-f]{64})\.json\z/;
  }
  closedir($dh) or croak "could not close session directory: $!";

  for my $digest (@digests) {
    my $path = $self->_session_path($digest);
    my ($initial, $initial_error);
    $initial = eval { $self->_read_json($path) };
    $initial_error = $@;
    my $username = ref($initial) eq 'HASH' && $self->validate_username($initial->{username})
      ? $initial->{username} : undef;
    my $removed = 0;
    my $ok = eval {
      if (defined $username && !$initial_error) {
        $removed = $self->_with_lock("user:$username", sub {
          return $self->_with_lock("sessions:$username", sub {
            my $safe_path = $self->_pinned_auth_path($path);
            return 0 if !-e $safe_path && !-l $safe_path;
            my $fresh = $self->_read_json($path);
            return 0 if !$self->_session_needs_cleanup_user_locked($fresh, $digest);
            return $self->_safe_unlink($path);
          });
        });
      }
      else {
        # Corrupt/unattributable records cannot be restored.  A fixed stripe
        # coordinates cleanup without allocating a lock per attacker digest.
        $removed = $self->_with_lock($self->_orphan_lock_key($digest), sub {
          my $safe_path = $self->_pinned_auth_path($path);
          return 0 if !-e $safe_path && !-l $safe_path;
          my ($fresh, $read_error);
          $fresh = eval { $self->_read_json($path) };
          $read_error = $@;
          return 0 if !$read_error && $self->_valid_session_record($fresh, $digest);
          return $self->_safe_unlink($path);
        });
      }
      1;
    };
    if (!$ok) {
      $summary->{errors}++;
      next;
    }
    $summary->{sessions_removed} += $removed ? 1 : 0;
  }
  return;
}

sub _session_needs_cleanup_user_locked {
  my ($self, $session, $digest) = @_;
  return 1 if !$self->_valid_session_record($session, $digest);
  my $now = $self->_now;
  return 1 if $now >= $session->{absolute_expires_at}
    || $now >= $session->{idle_expires_at};
  my $account = eval { $self->_read_account_unchecked($session->{username}) };
  return 1 if $@
    || !defined($account)
    || $account->{status} ne 'active'
    || $session->{auth_version} != $account->{auth_version};
  return 0;
}

sub _maintain_rate_buckets {
  my ($self, $summary) = @_;
  my $now = $self->_now;
  for my $type (qw(ACCOUNT IP)) {
    my $dir = $self->_dir('RATELIMIT', $type);
    $self->_guard_auth_path(File::Spec->catfile($dir, 'placeholder'));
    my $safe_dir = $self->_pinned_auth_path($dir);
    opendir(my $dh, $safe_dir) or croak "could not open rate-limit directory: $!";
    my @digests;
    while (my $name = readdir $dh) {
      push @digests, $1 if $name =~ /\A([0-9a-f]{64})\.json\z/;
    }
    closedir($dh) or croak "could not close rate-limit directory: $!";

    for my $digest (@digests) {
      my $path = File::Spec->catfile($dir, "$digest.json");
      my ($removed, $rewritten) = (0, 0);
      my $ok = eval {
        $self->_with_lock($self->_rate_lock_key_for_digest($digest), sub {
          my $safe_path = $self->_pinned_auth_path($path);
          return if !-e $safe_path && !-l $safe_path;
          my $state = $self->_read_json($path);
          $self->_normalize_rate_state_for_maintenance($path, $state, $now);
          if (!@{$state->{failures}}
              && !keys(%{$state->{reservations}})
              && ($state->{locked_until} || 0) <= $now) {
            $removed = $self->_safe_unlink($path);
          }
          else {
            $state->{updated_at} = $now;
            $self->_write_json($path, $state);
            $rewritten = 1;
          }
          return;
        });
        1;
      };
      if (!$ok) {
        # Corrupt or symlinked buckets are retained so maintenance can never
        # erase rate-limit evidence it cannot safely validate.
        $summary->{errors}++;
        next;
      }
      $summary->{rate_buckets_removed} += $removed ? 1 : 0;
      $summary->{rate_buckets_rewritten} += $rewritten ? 1 : 0;
    }
  }
  return;
}

sub _normalize_rate_state_for_maintenance {
  my ($self, $path, $state, $now) = @_;
  croak "corrupt rate-limit record: $path"
    if ref($state) ne 'HASH'
      || ($state->{schema} || 0) != $SCHEMA_VERSION
      || ($state->{subject_digest} || '') !~ /\A[0-9a-f]{64}\z/
      || ref($state->{failures}) ne 'ARRAY'
      || (defined($state->{reservations}) && ref($state->{reservations}) ne 'HASH')
      || !defined($state->{locked_until})
      || $state->{locked_until} !~ /\A[0-9]+(?:\.[0-9]+)?\z/;
  for my $failure (@{$state->{failures}}) {
    croak "corrupt rate-limit record: $path"
      if !defined($failure) || ref($failure) || $failure !~ /\A[0-9]+(?:\.[0-9]+)?\z/;
  }
  $state->{reservations} ||= {};
  for my $id (keys %{$state->{reservations}}) {
    my $expires = $state->{reservations}{$id};
    croak "corrupt rate-limit record: $path"
      if $id !~ /\A[A-Za-z0-9_-]{20,64}\z/
        || !defined($expires) || ref($expires)
        || $expires !~ /\A[0-9]+(?:\.[0-9]+)?\z/;
  }
  my @recent = grep { $_ > $now - $self->{rate_window} } @{$state->{failures}};
  my %active = map { $_ => $state->{reservations}{$_} }
    grep { $state->{reservations}{$_} > $now } keys %{$state->{reservations}};
  $state->{failures} = \@recent;
  $state->{reservations} = \%active;
  $state->{locked_until} = 0 if $state->{locked_until} <= $now;
  return;
}

sub audit {
  my ($self, %event) = @_;
  $self->_ensure_initialized;
  my $name = defined($event{event}) && $event{event} =~ /\A[a-z0-9_.-]{1,64}\z/
    ? $event{event} : 'auth.unknown';
  my $record = {
    schema => $SCHEMA_VERSION,
    ts     => _iso8601($self->_now),
    event  => $name,
    result => _bounded_text($event{result}, 32),
  };
  $record->{username} = _bounded_text($event{username}, 64) if defined $event{username};
  $record->{ip} = _bounded_text($event{ip}, 64) if defined $event{ip};
  $record->{user_agent} = _bounded_text($event{user_agent}, 512) if defined $event{user_agent};
  $record->{reason} = _bounded_text($event{reason}, 64) if defined $event{reason};
  $record->{request_id} = _bounded_text($event{request_id}, 128) if defined $event{request_id};
  $record->{action} = _bounded_text($event{action}, 64) if defined $event{action};
  $record->{root} = _bounded_text($event{root}, 256) if defined $event{root};
  $record->{count} = 0 + $event{count} if defined($event{count}) && $event{count} =~ /\A\d+\z/;
  $record->{session_digest} = $event{session_digest}
    if defined($event{session_digest}) && $event{session_digest} =~ /\A[0-9a-f]{64}\z/;

  my $path = File::Spec->catfile($self->_dir('AUDIT'), 'auth.jsonl');
  my $line = $self->_json->encode($record) . "\n";
  $self->_guard_auth_path($path);
  my $safe_path = $self->_pinned_auth_path($path);
  $self->_with_lock('audit-log', sub {
    croak "refusing symbolic-link audit log: $path" if -l $safe_path;
    $self->_rotate_audit_unlocked($path, length($line));
    _with_secure_umask(sub {
      sysopen(my $fh, $safe_path, O_WRONLY | O_APPEND | O_CREAT | $NOFOLLOW, 0600)
        or croak "could not open audit log: $!";
      chmod(0600, $safe_path) or croak "could not set permissions on audit log: $!";
      flock($fh, LOCK_EX) or croak "could not lock audit log: $!";
      binmode($fh, ':raw');
      print {$fh} $line or croak "could not append audit log: $!";
      $fh->flush or croak "could not flush audit log: $!";
      $fh->sync or croak "could not sync audit log: $!";
      close($fh) or croak "could not close audit log: $!";
    });
    $self->_prune_audit_archives_unlocked;
    return;
  });
  return 1;
}

sub _rotate_audit_unlocked {
  my ($self, $path, $incoming_bytes) = @_;
  my $safe_path = $self->_pinned_auth_path($path);
  return if !lstat $safe_path;
  croak "refusing symbolic-link audit log: $path" if -l _;
  croak "expected regular audit log: $path" if !-f _;
  my $current_bytes = -s _;
  return if $current_bytes == 0
    || $current_bytes + $incoming_bytes <= $self->{audit_max_bytes};

  my $milliseconds = int($self->_now * 1000);
  my $archive;
  for (1 .. 100) {
    my $sequence = (++$AUDIT_SEQUENCE) % 1_000_000;
    my $name = sprintf('auth.%020d.%d.%06d.jsonl',
      $milliseconds, $$, $sequence);
    my $candidate = File::Spec->catfile($self->_dir('AUDIT'), $name);
    $self->_guard_auth_path($candidate);
    next if lstat $self->_pinned_auth_path($candidate);
    $archive = $candidate;
    last;
  }
  croak 'could not allocate an audit archive name' if !defined $archive;
  my $safe_archive = $self->_pinned_auth_path($archive);
  rename($safe_path, $safe_archive) or croak "could not rotate audit log: $!";
  chmod(0600, $safe_archive) or croak "could not set audit archive permissions: $!";
  return;
}

sub _prune_audit_archives_unlocked {
  my ($self) = @_;
  my $dir = $self->_dir('AUDIT');
  $self->_guard_auth_path(File::Spec->catfile($dir, 'placeholder'));
  my $safe_dir = $self->_pinned_auth_path($dir);
  opendir(my $dh, $safe_dir) or croak "could not open audit directory: $!";
  my @archives;
  while (my $name = readdir $dh) {
    next if $name !~ /\Aauth\.([0-9]{20})\.([0-9]+)\.([0-9]{6})\.jsonl\z/;
    my $path = File::Spec->catfile($dir, $name);
    my $safe_path = $self->_pinned_auth_path($path);
    croak "refusing symbolic-link audit archive: $path" if -l $safe_path;
    croak "expected regular audit archive: $path" if !-f $safe_path;
    push @archives, { name => $name, path => $path, mtime => (stat($safe_path))[9] || 0 };
  }
  closedir($dh) or croak "could not close audit directory: $!";
  @archives = sort {
    $a->{mtime} <=> $b->{mtime} || $a->{name} cmp $b->{name}
  } @archives;
  while (@archives > $self->{audit_archives}) {
    my $oldest = shift @archives;
    $self->_safe_unlink($oldest->{path});
  }
  return;
}

sub _bounded_text {
  my ($value, $limit) = @_;
  return '' if !defined $value || ref($value);
  $value = substr($value, 0, $limit);
  $value =~ s/[\x00-\x1f\x7f]/?/g;
  return $value;
}

sub _iso8601 {
  my ($epoch) = @_;
  my $seconds = int($epoch);
  my $milliseconds = int(($epoch - $seconds) * 1000);
  my @time = gmtime($seconds);
  return sprintf('%04d-%02d-%02dT%02d:%02d:%02d.%03dZ',
    $time[5] + 1900, $time[4] + 1, $time[3], $time[2], $time[1], $time[0], $milliseconds);
}

sub _crypto {
  my ($self) = @_;
  return $self->{crypto_provider} if defined $self->{crypto_provider};
  my ($available, $missing) = $self->dependencies_available;
  croak 'authentication crypto dependencies unavailable: ' . join(', ', @$missing)
    if !$available;
  $self->{crypto_provider} = Orbit::Auth::_Crypto->new;
  return $self->{crypto_provider};
}

sub _random_bytes {
  my ($self, $count) = @_;
  croak 'invalid secure-random byte count'
    if !defined($count) || $count !~ /\A[1-9][0-9]*\z/ || $count > 4096;
  my $bytes = $self->_crypto->random_bytes($count);
  croak 'authentication crypto provider returned the wrong number of random bytes'
    if !defined($bytes) || ref($bytes) || length($bytes) != $count;
  return $bytes;
}

sub _dummy_phc {
  my ($self) = @_;
  my $path = File::Spec->catfile($self->_dir('PASSPHRASE'), '.dummy.json');
  return $self->_with_lock('dummy-credential', sub {
    my $stored = $self->_read_json($path);
    return $stored->{phc}
      if ref($stored) eq 'HASH' && defined($stored->{phc}) && $stored->{phc} =~ /\A\$argon2id\$/;
    my $dummy_password = _base64url($self->_random_bytes(32));
    my $phc = $self->_crypto->hash_passphrase($dummy_password);
    $self->_write_json($path, { schema => $SCHEMA_VERSION, phc => $phc, created_at => $self->_now });
    return $phc;
  });
}

sub _base64url {
  my ($bytes) = @_;
  my $encoded = encode_base64($bytes, '');
  $encoded =~ tr{+/}{-_};
  $encoded =~ s/=+\z//;
  return $encoded;
}

sub _bounded_digest {
  my ($value) = @_;
  return undef if !defined($value) || $value eq '';
  $value = substr($value, 0, 1024);
  return sha256_hex(encode_utf8($value));
}

sub _rate_subject {
  my ($subject) = @_;
  return '<unknown>' if !defined($subject) || ref($subject);
  return substr($subject, 0, 256);
}

sub _account_rate_subject {
  my ($subject) = @_;
  my $key = _rate_subject($subject);
  $key =~ tr/A-Z/a-z/;
  return $key;
}

sub _account_path {
  my ($self, $username) = @_;
  return File::Spec->catfile($self->_dir('USERS'), "$username.json");
}

sub _credential_path {
  my ($self, $username) = @_;
  return File::Spec->catfile($self->_dir('PASSPHRASE'), "$username.json");
}

sub _session_path {
  my ($self, $digest) = @_;
  croak 'invalid session digest' if !defined($digest) || $digest !~ /\A[0-9a-f]{64}\z/;
  return File::Spec->catfile($self->_dir('SESSIONS'), "$digest.json");
}

sub _rate_path {
  my ($self, $type, $subject) = @_;
  croak 'invalid rate bucket type' if $type ne 'ACCOUNT' && $type ne 'IP';
  my $key = $type eq 'ACCOUNT' ? _account_rate_subject($subject) : _rate_subject($subject);
  my $digest = $self->_rate_bucket_digest($type, $key);
  return File::Spec->catfile($self->_dir('RATELIMIT', $type), "$digest.json");
}

sub _rate_bucket_digest {
  my ($self, $type, $subject) = @_;
  croak 'invalid rate bucket type' if $type ne 'ACCOUNT' && $type ne 'IP';
  my $key = $type eq 'ACCOUNT' ? _account_rate_subject($subject) : _rate_subject($subject);
  return sha256_hex(encode_utf8("$type\0$key"));
}

sub _rate_lock_key {
  my ($self, $type, $subject) = @_;
  my $digest = $self->_rate_bucket_digest($type, $subject);
  my $stripe = hex(substr($digest, 0, 8)) % $RATE_LOCK_STRIPES;
  return sprintf('rate:stripe:%02d', $stripe);
}

sub _rate_lock_key_for_digest {
  my ($self, $digest) = @_;
  croak 'invalid rate bucket digest' if !defined($digest) || $digest !~ /\A[0-9a-f]{64}\z/;
  my $stripe = hex(substr($digest, 0, 8)) % $RATE_LOCK_STRIPES;
  return sprintf('rate:stripe:%02d', $stripe);
}

sub _orphan_lock_key {
  my ($self, $digest) = @_;
  croak 'invalid orphan session digest' if !defined($digest) || $digest !~ /\A[0-9a-f]{64}\z/;
  my $stripe = hex(substr($digest, 0, 8)) % $ORPHAN_LOCK_STRIPES;
  return sprintf('session-orphan:stripe:%02d', $stripe);
}

sub _with_lock {
  my ($self, $key, $code) = @_;
  my $digest = sha256_hex(encode_utf8($key));
  my $path = File::Spec->catfile($self->_dir('LOCKS'), "$digest.lock");
  $self->_guard_auth_path($path);
  my $safe_path = $self->_pinned_auth_path($path);
  croak "refusing symbolic-link lock file: $path" if -l $safe_path;

  return _with_secure_umask(sub {
    sysopen(my $fh, $safe_path, O_RDWR | O_CREAT | $NOFOLLOW, 0600)
      or croak "could not open authentication lock: $!";
    chmod(0600, $safe_path) or croak "could not set lock permissions: $!";
    flock($fh, LOCK_EX) or croak "could not acquire authentication lock: $!";
    my ($result, $error);
    eval { $result = $code->(); 1 } or $error = $@ || 'locked operation failed';
    close($fh) or $error ||= "could not close authentication lock: $!";
    die $error if defined $error;
    return $result;
  });
}

sub _read_json {
  my ($self, $path) = @_;
  $self->_guard_auth_path($path);
  my $safe_path = $self->_pinned_auth_path($path);
  return undef if !lstat $safe_path;
  croak "refusing symbolic-link data file: $path" if -l _;
  croak "expected regular data file: $path" if !-f _;
  croak "authentication data file is too large: $path" if -s _ > $MAX_JSON_BYTES;
  sysopen(my $fh, $safe_path, O_RDONLY | $NOFOLLOW) or croak "could not open $path: $!";
  flock($fh, LOCK_SH) or croak "could not lock $path: $!";
  binmode($fh, ':raw');
  local $/;
  my $bytes = <$fh>;
  close($fh) or croak "could not close $path: $!";
  croak "empty JSON data file: $path" if !defined($bytes) || $bytes eq '';
  my $decoded = eval { $self->_json->decode($bytes) };
  croak "invalid JSON data file $path: $@" if $@;
  return $decoded;
}

sub _write_json {
  my ($self, $path, $data) = @_;
  my $bytes = $self->_json->encode($data) . "\n";
  croak 'authentication JSON record exceeds maximum size' if length($bytes) > $MAX_JSON_BYTES;
  $self->_guard_auth_path($path);
  my $safe_path = $self->_pinned_auth_path($path);
  croak "refusing symbolic-link data file: $path" if -l $safe_path;
  my $parent = dirname($path);
  my $temp = File::Spec->catfile($parent, sprintf('.auth-%d-%d.tmp', $$, ++$TEMP_SEQUENCE));
  $self->_guard_auth_path($temp);
  my $safe_temp = $self->_pinned_auth_path($temp);

  return _with_secure_umask(sub {
    sysopen(my $fh, $safe_temp, O_WRONLY | O_CREAT | O_EXCL | $NOFOLLOW, 0600)
      or croak "could not create temporary authentication file: $!";
    binmode($fh, ':raw');
    my $ok = eval {
      print {$fh} $bytes or die "could not write temporary authentication file: $!";
      $fh->flush or die "could not flush temporary authentication file: $!";
      $fh->sync or die "could not sync temporary authentication file: $!";
      close($fh) or die "could not close temporary authentication file: $!";
      chmod(0600, $safe_temp) or die "could not set authentication file permissions: $!";
      croak "refusing symbolic-link data file: $path" if -l $safe_path;
      rename($safe_temp, $safe_path) or die "could not install authentication file: $!";
      1;
    };
    my $error = $@;
    close($fh) if !$ok;
    unlink($safe_temp) if -f $safe_temp && !-l $safe_temp;
    die $error if !$ok;
    return 1;
  });
}

sub _safe_unlink {
  my ($self, $path) = @_;
  $self->_guard_auth_path($path);
  my $safe_path = $self->_pinned_auth_path($path);
  return 0 if !lstat $safe_path;
  croak "refusing to unlink symbolic link: $path" if -l _;
  croak "refusing to unlink non-file: $path" if !-f _;
  unlink($safe_path) or croak "could not remove authentication file $path: $!";
  return 1;
}

sub _json {
  my ($self) = @_;
  $self->{json} ||= JSON::PP->new->canonical(1)->utf8(1)->allow_nonref(0);
  return $self->{json};
}

sub _now {
  my ($self) = @_;
  my $now = $self->{now}->();
  croak 'clock returned an invalid time' if !defined($now) || $now !~ /\A[0-9]+(?:\.[0-9]+)?\z/;
  return 0 + $now;
}

package Orbit::Auth::_Crypto;

use strict;
use warnings;
use Encode qw(encode_utf8);

sub new { return bless {}, shift }

sub random_bytes {
  my ($self, $count) = @_;
  my $bytes = Crypt::URandom::urandom($count);
  die 'Crypt::URandom returned the wrong number of bytes'
    if !defined($bytes) || length($bytes) != $count;
  return $bytes;
}

sub hash_passphrase {
  my ($self, $passphrase) = @_;
  my $salt = Crypt::URandom::urandom(16);
  die 'Crypt::URandom returned an invalid Argon2 salt'
    if !defined($salt) || length($salt) != 16;
  return Crypt::Argon2::argon2id_pass(encode_utf8($passphrase), $salt, 2, '19M', 1, 32);
}

sub verify_passphrase {
  my ($self, $phc, $passphrase) = @_;
  return Crypt::Argon2::argon2id_verify($phc, encode_utf8($passphrase)) ? 1 : 0;
}

sub needs_rehash {
  my ($self, $phc) = @_;
  return 1 if !defined $phc;
  return 1 if $phc !~ /\A\$argon2id\$v=19\$m=19456,t=2,p=1\$([A-Za-z0-9+\/]{22})\$([A-Za-z0-9+\/]{43})\z/;
  return 0;
}

package Orbit::Auth;

1;

__END__

=pod

=head1 NAME

Orbit::Auth - private file-backed authentication for an Orbit domain

=head1 SYNOPSIS

  my $auth = Orbit::Auth->new(domain_dir => $domain_dir);
  $auth->initialize;

  my $account = $auth->provision_account(
    'river-editor', $passphrase, role => 'editor'
  );

  my $login = $auth->authenticate(
    'river-editor', $submitted_passphrase,
    ip => $remote_addr, user_agent => $user_agent,
  );

  my $restored = $auth->restore_session($cookie_value);

=head1 STORAGE AND SECURITY CONTRACT

Data lives below C<_ORBIT/_AUTH> in C<USERS>, C<PASSPHRASE>, C<SESSIONS>,
C<RATELIMIT>, C<LOCKS>, and C<AUDIT>, with domain policy in C<POLICY.json>.
Authentication directories are mode
0700 and files are mode 0600.  JSON replacement is same-directory and atomic;
read/modify/write operations use advisory locks.  Generated paths are bounded
by strict identifiers and every authentication path is checked for containment
and symbolic-link parents.  On the supported Linux hosts, private I/O is also
resolved below a pinned authentication-root directory descriptor so a parent
rename/symlink race cannot redirect a checked operation.  Operations needing
both account and session state
always acquire C<user:E<lt>nameE<gt>> before C<sessions:E<lt>nameE<gt>>; session
creation, touch, individual revocation, bulk revocation, and cap eviction all
coordinate on that same per-user sessions lock.

Login admission uses a fixed 64-stripe lock namespace and reserves capacity in
both the account and IP buckets before password hashing begins.  Unknown names
share an account-limit bucket scoped to their source IP, so attacker-controlled
identifiers cannot create unbounded account state or per-user lock files.
Malformed session cleanup similarly uses a fixed 64-stripe orphan namespace.

The default crypto provider is mandatory C<Crypt::Argon2> plus
C<Crypt::URandom>.  Password and session operations throw if either dependency
is unavailable.  C<crypto_provider> exists for deterministic tests; production
callers should never override it.

Passphrases are decoded Unicode strings supplied by the caller.  They are NFC
normalized but never trimmed.  New values must contain 15 through 128
characters, no control/surrogate characters, and no more than 1024 UTF-8
bytes.  Argon2id PHC strings use 19 MiB, two iterations, parallelism one, a
16-byte salt, and a 32-byte tag.

=head1 ACCOUNT API

=over

=item C<self_signup_enabled>, C<set_self_signup($boolean)>, C<provision_self_signup>

The policy is disabled when C<POLICY.json> is missing, unreadable, malformed,
or does not contain a real JSON boolean.  Policy replacement is protected and
atomic.  Public provisioning rechecks the policy while holding its lock and
always creates an active C<viewer> account without C<must_change>.

=item C<validate_username($value)>, C<validate_passphrase($value)>

Return a boolean in scalar context or C<($boolean, $reason)> in list context.

=item C<create_account($username, %attributes)>

Creates only an C<incomplete> or C<disabled> account.  It cannot create an
active account without a credential.

=item C<provision_account($username, $passphrase, %attributes)>

Hashes first, writes an incomplete account, writes its credential, and only
then marks it active (or disabled if requested).  An interrupted operation
therefore fails closed.  The staging record persists the requested final
status so recovery cannot accidentally activate an account intended to stay
disabled.

=item C<read_account>, C<list_accounts>, C<update_account>, C<bump_auth_version>

Account fields available to callers are role, status, optional person pointer,
and must_change.  Roles are viewer/editor/admin.  Authentication versions are
maintained internally.  A real role or status change advances auth_version and
revokes all sessions as part of the same per-user operation; setting a field to
its existing value does not invalidate sessions again.

=item C<create_credential>, C<verify_passphrase>, C<reset_passphrase>, C<change_passphrase>

Reset and change bump the account authentication version and revoke all of its
sessions.  C<change_passphrase> returns a structured generic failure when the
old passphrase does not match.

=back

=head1 LOGIN, SESSION, RATE, AND AUDIT API

=over

=item C<authenticate($username, $passphrase, %context)>

The login entry point.  It checks account and IP buckets before expensive
hashing, verifies a persistent dummy Argon2 hash for unknown/inactive accounts,
records failure or success, and creates a session.  Externally visible failures
are generic C<invalid_credentials> or C<throttled> results.

=item C<create_session>, C<restore_session>, C<revoke_session>, C<revoke_all_sessions>

The raw 256-bit bearer token is returned only to the caller; only its SHA-256
digest is stored and used as a filename.  Sessions have a 30-minute idle and
eight-hour absolute lifetime by default.  At most ten sessions per user are
kept.  Restore returns C<{ok =E<gt> 0, reason =E<gt> ...}> on failure.  On
success it returns fresh account role/status, verifies auth_version, and writes
a last-seen touch no more than once every five minutes.

=item C<verify_csrf($session_or_restore_result, $candidate)>

Constant-time comparison with the per-session CSRF secret.

=item C<issue_login_nonce>, C<verify_login_nonce($cookie, $candidate)>

Generate and verify the opaque 256-bit double-submit value used to protect the
pre-session login form from account-confusion attacks.

=item C<check_rate_limit>, C<record_login_failure>, C<record_login_success>

Maintain independent account (five failures) and IP (twenty failures) buckets
over 15 minutes with a 15-minute lockout.  A successful login clears only the
known, active account's failure history; C<record_login_success> returns false
for unknown or inactive names and never clears their shared bucket.
C<authenticate> atomically reserves capacity in both buckets before doing
expensive work; abandoned reservations expire after five minutes.
C<admit_self_signup> consumes IP capacity before public provisioning can begin
Argon2 work and returns a fail-closed throttled status when capacity is spent.

=item C<audit(%event)>

Appends one canonical JSON object to protected C<AUDIT/auth.jsonl>.  The API
accepts only bounded known fields and therefore never serializes passphrases,
cookies, raw session tokens, CSRF values, or request bodies.
The log rotates before exceeding 10 MiB and keeps 30 protected archives by
default; both values are constructor-configurable.

=item C<maintain>

Removes expired, revoked-by-account-state, and malformed session records under
the same ordered locks used online.  It also expires stale rate failures and
abandoned reservations and enforces audit retention.  Corrupt or symlinked rate
records are reported and retained fail closed.  Online maintenance never
deletes lock files.

=back

=cut
