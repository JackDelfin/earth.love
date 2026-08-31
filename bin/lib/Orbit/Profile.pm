#!/usr/bin/perl

package Orbit::Profile;

use strict;
use warnings;
use utf8;

use Carp qw(croak);
use Cwd qw(abs_path);
use Encode qw(encode_utf8);
use Fcntl qw(:DEFAULT :flock);
use File::Basename qw(dirname);
use File::Spec;
use IO::Handle ();
use JSON::PP ();
use Unicode::Normalize qw(NFC);
use Orbit::Person;

our $VERSION = '0.1.0';

my $SCHEMA_VERSION = 1;
my $MAX_JSON_BYTES = 16 * 1024;
my $MAX_AVATAR_BYTES = 512 * 1024;
my $MAX_BIO = 500;
my $MAX_PRONOUNS = 32;
my $MAX_PERSON = 80;
my $MAX_EMAIL = 254;
my $MAX_URL = 200;
my $NOFOLLOW = eval { Fcntl::O_NOFOLLOW() } || 0;

my %AVATAR_MAGIC = (
  jpg  => qr/\A\xFF\xD8\xFF/,
  png  => qr/\A\x89PNG\r\n\x1a\n/,
  gif  => qr/\AGIF8[79]a/,
  webp => qr/\ARIFF.{4}WEBP/s,
);

sub new {
  my ($class, %args) = @_;
  croak 'domain_dir is required' if !defined($args{domain_dir}) || $args{domain_dir} eq '';
  croak 'domain_dir must be an existing directory' if !-d $args{domain_dir};
  croak 'domain_dir may not be a symbolic link' if -l $args{domain_dir};
  my $domain_dir = abs_path($args{domain_dir});
  croak 'could not resolve domain_dir' if !defined $domain_dir;

  return bless {
    domain_dir  => $domain_dir,
    profile_dir => File::Spec->catdir($domain_dir, '_ORBIT', '_PROFILE'),
    users_web   => File::Spec->catdir($domain_dir, '_WEB', '_USERS'),
  }, $class;
}

sub empty_profile {
  my ($self, $username) = @_;
  return {
    schema    => $SCHEMA_VERSION,
    username  => $username,
    bio       => '',
    pronouns  => '',
    url       => '',
    email     => '',
    person    => '',
    avatar    => '',
    updated_at => 0,
  };
}

sub read_public {
  my ($self, $username) = @_;
  return undef if !_valid_username($username);
  my $path = $self->_profile_path($username);
  return $self->empty_profile($username) if !-e $path;
  my $record = eval { $self->_read_json($path) };
  return $self->empty_profile($username) if ref($record) ne 'HASH';
  my $clean = $self->empty_profile($username);
  for my $field (qw(bio pronouns url email person avatar)) {
    $clean->{$field} = _as_text($record->{$field});
  }
  $clean->{updated_at} = ($record->{updated_at} || 0) =~ /\A[0-9]+\z/ ? 0 + $record->{updated_at} : 0;
  $clean->{avatar} = '' if ($clean->{avatar} ne '' && !$self->_avatar_exists($username, $clean->{avatar}));
  return $clean;
}

sub write_public {
  my ($self, $username, %fields) = @_;
  croak 'invalid username' if !_valid_username($username);
  my ($ok, $error, $normalized) = $self->validate_fields(\%fields);
  croak $error if !$ok;

  $self->_ensure_profile_dir;
  my $current = $self->read_public($username);
  my $now = time();
  my $record = {
    schema     => $SCHEMA_VERSION,
    username   => $username,
    bio        => $normalized->{bio},
    pronouns   => $normalized->{pronouns},
    url        => $normalized->{url},
    email      => $normalized->{email},
    person     => $normalized->{person},
    avatar     => $current->{avatar} // '',
    updated_at => $now,
  };
  $self->_write_json($self->_profile_path($username), $record);
  return $record;
}

sub validate_fields {
  my ($self, $fields) = @_;
  $fields = {} if ref($fields) ne 'HASH';
  my %out;
  for my $field (qw(bio pronouns url email person)) {
    my ($ok, $reason, $value) = $self->_validate_field($field, $fields->{$field});
    return (0, $reason, undef) if !$ok;
    $out{$field} = $value;
  }
  return (1, 'ok', \%out);
}

sub avatar_url {
  my ($self, $username, $filename) = @_;
  return '' if !_valid_username($username);
  $filename = $self->read_public($username)->{avatar} if (!defined($filename));
  return '' if !_valid_avatar_name($filename);
  return '/_USERS/'.$username.'/'.$filename;
}

sub save_avatar {
  my ($self, $username, $bytes) = @_;
  croak 'invalid username' if !_valid_username($username);
  croak 'avatar is empty' if !defined($bytes) || $bytes eq '';
  croak 'avatar is too large' if length($bytes) > $MAX_AVATAR_BYTES;
  my $ext = _avatar_extension($bytes);
  croak 'avatar must be a JPEG, PNG, GIF, or WebP image' if !$ext;

  my $dir = $self->_avatar_dir($username);
  $self->_ensure_directory($dir, 0755);
  my $name = 'avatar.'.$ext;
  my $path = File::Spec->catfile($dir, $name);
  $self->_assert_contained($path, $self->{users_web});
  $self->_write_bytes($path, $bytes, 0644);

  for my $old (qw(jpg png gif webp)) {
    next if $old eq $ext;
    my $other = File::Spec->catfile($dir, 'avatar.'.$old);
    next if !-e $other;
    unlink $other;
  }

  my $record = $self->read_public($username);
  $record->{avatar} = $name;
  $record->{updated_at} = time();
  $self->_ensure_profile_dir;
  $self->_write_json($self->_profile_path($username), $record);
  return $record;
}

sub clear_avatar {
  my ($self, $username) = @_;
  croak 'invalid username' if !_valid_username($username);
  my $dir = $self->_avatar_dir($username);
  if (-d $dir && !-l $dir) {
    for my $old (qw(jpg png gif webp)) {
      my $path = File::Spec->catfile($dir, 'avatar.'.$old);
      unlink $path if -f $path && !-l $path;
    }
  }
  my $record = $self->read_public($username);
  $record->{avatar} = '';
  $record->{updated_at} = time();
  $self->_ensure_profile_dir;
  $self->_write_json($self->_profile_path($username), $record);
  return $record;
}

sub _validate_field {
  my ($self, $field, $value) = @_;
  $value = '' if !defined $value;
  $value = NFC(_as_text($value));
  $value =~ s/\A\s+//;
  $value =~ s/\s+\z//;
  return (0, 'Profile text may not contain markup or template syntax.')
    if $value =~ /[<>#`"]/;

  if ($field eq 'bio') {
    return (0, 'Bio is too long.') if length($value) > $MAX_BIO;
    return (1, 'ok', $value);
  }
  if ($field eq 'pronouns') {
    return (0, 'Pronouns are too long.') if length($value) > $MAX_PRONOUNS;
    return (0, 'Pronouns may only use letters, spaces, slashes, and hyphens.')
      if $value ne '' && $value !~ /\A[\p{L}\p{M} \/'-]+\z/;
    return (1, 'ok', $value);
  }
  if ($field eq 'person') {
    my $word = Orbit::Person->normalize($value);
    return (0, 'Person record must be an existing WordBase name.')
      if !defined $word;
    return (1, 'ok', $word);
  }
  if ($field eq 'email') {
    return (0, 'Email is too long.') if length($value) > $MAX_EMAIL;
    return (0, 'Email address is not valid.')
      if $value ne '' && $value !~ /\A[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\z/;
    return (1, 'ok', $value);
  }
  if ($field eq 'url') {
    return (0, 'URL is too long.') if length($value) > $MAX_URL;
    return (0, 'URL must start with https://')
      if $value ne '' && $value !~ m{\Ahttps://[A-Za-z0-9._~:/?#\[\]\@!\$&'()*+,;=%-]+\z};
    return (1, 'ok', $value);
  }
  return (0, 'Unknown profile field.');
}

sub _valid_username {
  my ($username) = @_;
  return defined($username) && $username =~ /\A[a-z][a-z0-9]*(?:-[a-z0-9]+)*\z/
    && length($username) >= 3 && length($username) <= 32;
}

sub _valid_avatar_name {
  my ($name) = @_;
  return defined($name) && $name =~ /\Aavatar\.(?:jpg|png|gif|webp)\z/;
}

sub _avatar_extension {
  my ($bytes) = @_;
  for my $ext (sort keys %AVATAR_MAGIC) {
    return $ext if $bytes =~ $AVATAR_MAGIC{$ext};
  }
  return '';
}

sub _as_text {
  my ($value) = @_;
  return '' if !defined $value || ref $value;
  return "$value";
}

sub _profile_path {
  my ($self, $username) = @_;
  return File::Spec->catfile($self->{profile_dir}, $username.'.json');
}

sub _avatar_dir {
  my ($self, $username) = @_;
  return File::Spec->catdir($self->{users_web}, $username);
}

sub _avatar_exists {
  my ($self, $username, $filename) = @_;
  return 0 if !_valid_avatar_name($filename);
  my $path = File::Spec->catfile($self->_avatar_dir($username), $filename);
  return 0 if !eval { $self->_assert_contained($path, $self->{users_web}); 1 };
  return -f $path && !-l $path ? 1 : 0;
}

sub _ensure_profile_dir {
  my ($self) = @_;
  my $orbit = File::Spec->catdir($self->{domain_dir}, '_ORBIT');
  $self->_ensure_directory($orbit, 0755);
  $self->_ensure_directory($self->{profile_dir}, 0750);
  $self->_ensure_directory(File::Spec->catdir($self->{domain_dir}, '_WEB'), 0755);
  $self->_ensure_directory($self->{users_web}, 0755);
  return;
}

sub _ensure_directory {
  my ($self, $path, $mode) = @_;
  $self->_assert_contained($path, $self->{domain_dir});
  if (lstat $path) {
    croak "refusing symbolic-link directory: $path" if -l _;
    croak "expected directory: $path" if !-d _;
    return;
  }
  mkdir($path, $mode) or croak "could not create directory $path: $!" if !-d $path;
  croak "refusing symbolic-link directory: $path" if -l $path;
  return;
}

sub _assert_contained {
  my ($self, $path, $root) = @_;
  my $absolute = File::Spec->canonpath(File::Spec->rel2abs($path));
  my $base     = File::Spec->canonpath(File::Spec->rel2abs($root));
  my $relative = File::Spec->abs2rel($absolute, $base);
  croak "path escapes profile root: $path"
    if File::Spec->file_name_is_absolute($relative)
      || $relative eq File::Spec->updir
      || $relative =~ /\A\.\.(?:[\\\/]|\z)/;
  return;
}

sub _read_json {
  my ($self, $path) = @_;
  return undef if !-e $path;
  croak "refusing symbolic-link profile file: $path" if -l $path;
  $self->_assert_contained($path, $self->{profile_dir});
  sysopen(my $fh, $path, O_RDONLY | $NOFOLLOW)
    or croak "could not read $path: $!";
  binmode($fh);
  my $raw = do { local $/; <$fh> };
  close $fh;
  return undef if !defined $raw || length($raw) > $MAX_JSON_BYTES;
  my $json = eval { JSON::PP->new->utf8->decode($raw) };
  return $json;
}

sub _write_json {
  my ($self, $path, $record) = @_;
  $self->_assert_contained($path, $self->{profile_dir});
  my $encoded = JSON::PP->new->utf8->canonical->pretty->encode($record);
  $self->_write_bytes($path, $encoded, 0640);
  return 1;
}

sub _write_bytes {
  my ($self, $path, $bytes, $mode) = @_;
  my $dir = dirname($path);
  my $temp = File::Spec->catfile($dir, '.tmp-'.$$.'-'.time().'-'.int(rand(1_000_000)));
  $self->_assert_contained($temp, $self->{domain_dir});
  sysopen(my $fh, $temp, O_WRONLY | O_CREAT | O_EXCL | $NOFOLLOW, $mode)
    or croak "could not write $temp: $!";
  binmode($fh);
  print {$fh} $bytes or croak "could not write $temp: $!";
  $fh->flush or croak "could not flush $temp: $!";
  close $fh or croak "could not close $temp: $!";
  chmod($mode, $temp);
  rename($temp, $path) or do {
    unlink $temp;
    croak "could not replace $path: $!";
  };
  return 1;
}

1;
