#!/usr/bin/perl

package Orbit::Person;

use strict;
use warnings;
use utf8;

use Carp qw(croak);
use Cwd qw(abs_path);
use Encode qw(encode_utf8);
use Fcntl qw(:DEFAULT);
use File::Spec;
use Unicode::Normalize qw(NFC);

our $VERSION = '0.1.0';

my $MAX_WORD = 80;
my $MAX_LIST = 500;
my $MAX_DOWN_LINES = 4000;
my $MAX_DOWN_BYTES = 1 * 1024 * 1024;
my $MAX_NAME_BYTES = 4096;
my $NOFOLLOW = eval { Fcntl::O_NOFOLLOW() } || 0;

sub new {
  my ($class, %args) = @_;
  croak 'domain_dir is required' if !defined($args{domain_dir}) || $args{domain_dir} eq '';
  croak 'domain_dir must be an existing directory' if !-d $args{domain_dir};
  croak 'domain_dir may not be a symbolic link' if -l $args{domain_dir};
  my $domain_dir = abs_path($args{domain_dir});
  croak 'could not resolve domain_dir' if !defined $domain_dir;

  return bless {
    domain_dir  => $domain_dir,
    persons_dir => File::Spec->catdir($domain_dir, 'PERSONS'),
  }, $class;
}

sub normalize {
  my ($class, $value) = @_;
  return '' if !defined($value) || ref($value);
  my $word = eval { NFC("$value") };
  return undef if !defined $word;
  $word =~ s/\A\s+//;
  $word =~ s/\s+\z//;
  $word =~ s/\s+/ /g;
  return '' if $word eq '';
  $word =~ s/_/ /g if $word !~ /\./;
  $word =~ tr/A-Z/a-z/;
  return undef if !_valid_word($word);
  return $word;
}

sub valid_word {
  my ($class, $value) = @_;
  my $word = $class->normalize($value);
  return defined($word) && $word ne '' ? 1 : 0;
}

sub exists {
  my ($self, $value) = @_;
  my $word = $self->normalize($value);
  return 0 if !defined($word) || $word eq '';
  my $dir = $self->_text_dir($word);
  return 0 if !defined $dir;
  return $self->_is_person_dir($dir);
}

sub display_name {
  my ($self, $value) = @_;
  my $word = $self->normalize($value);
  return '' if !defined($word) || $word eq '';
  my $dir = $self->_text_dir($word);
  return _title_case($word) if !defined $dir;
  my $name = $self->_read_oneline(File::Spec->catfile($dir, 'NAME.dat'));
  return $name if $name ne '';
  return _title_case($word);
}

sub show_url {
  my ($self, $value) = @_;
  my $word = $self->normalize($value);
  return '' if !defined($word) || $word eq '';
  my $encoded = $word;
  $encoded =~ s/%/%25/g;
  $encoded =~ s/\+/%2B/g;
  $encoded =~ s/ /+/g;
  return '/o/elshow?r=PERSONS&o=PERSON&p=el_show&w='.$encoded;
}

sub list_records {
  my ($self) = @_;
  my $down = File::Spec->catfile($self->{persons_dir}, 'DOWN.dat');
  my $raw = $self->_read_bytes($down, $MAX_DOWN_BYTES);
  return [] if !defined $raw;

  my %seen;
  my @people;
  my $lines = 0;
  for my $line (split /\n/, $raw) {
    last if ++$lines > $MAX_DOWN_LINES;
    $line =~ s/\r\z//;
    my $word = $self->normalize($line);
    next if !defined($word) || $word eq '';
    next if $seen{$word}++;
    next if !$self->exists($word);
    push @people, {
      word => $word,
      name => $self->display_name($word),
      url  => $self->show_url($word),
    };
    last if @people >= $MAX_LIST;
  }
  return [ sort { lc($a->{name}) cmp lc($b->{name}) || $a->{word} cmp $b->{word} } @people ];
}

sub _valid_word {
  my ($word) = @_;
  return 0 if !defined($word) || ref($word) || $word eq '';
  return 0 if length($word) > $MAX_WORD;
  return 0 if $word =~ /[<>#`"'\/\\]/;
  return 0 if $word =~ /\.\./;
  return 0 if $word =~ /[\x00-\x1f\x7f]/;
  return 1 if $word =~ /\A[a-z0-9][a-z0-9_-]*(?: [a-z0-9][a-z0-9_-]*)+\z/;
  return 1 if $word =~ /\A[a-z0-9][a-z0-9_-]*(?:\.[a-z0-9][a-z0-9_-]*)+\z/;
  return 1 if $word =~ /\A[a-z0-9][a-z0-9_-]{0,79}\z/;
  return 0;
}

sub _text_dir {
  my ($self, $word) = @_;
  return undef if !_valid_word($word);
  my $root = $self->{persons_dir};
  my $dir;
  if ($word =~ /\./) {
    $dir = File::Spec->catdir($root, '_PATHS', reverse split(/\./, $word));
  }
  elsif ($word =~ / /) {
    $dir = File::Spec->catdir($root, '_PHRASES', split(/ /, $word));
  }
  else {
    $dir = File::Spec->catdir($root, '_WORDS', split(//, $word), $word);
  }
  return undef if !eval { $self->_assert_contained($dir, $root); 1 };
  return $dir;
}

sub _is_person_dir {
  my ($self, $dir) = @_;
  return 0 if !defined $dir;
  return 0 if !eval { $self->_assert_contained($dir, $self->{persons_dir}); 1 };
  return 0 if !-d $dir || -l $dir;
  for my $name (qw(PERSON.dat NAME.dat)) {
    my $path = File::Spec->catfile($dir, $name);
    next if !-f $path || -l $path;
    return 1 if eval { $self->_assert_contained($path, $self->{persons_dir}); 1 };
  }
  return 0;
}

sub _title_case {
  my ($word) = @_;
  $word =~ s/(^|[ .])([a-z])/ $1 . uc($2) /ge;
  return $word;
}

sub _read_oneline {
  my ($self, $path) = @_;
  my $raw = $self->_read_bytes($path, $MAX_NAME_BYTES);
  return '' if !defined $raw;
  $raw =~ s/\r\n/\n/g;
  $raw =~ s/\A\s+//;
  my ($line) = split /\n/, $raw, 2;
  $line = '' if !defined $line;
  $line =~ s/\s+\z//;
  return '' if $line eq '' || $line =~ /[<>#`"]/;
  my $text = eval { NFC($line) };
  return '' if !defined $text;
  return $text;
}

sub _read_bytes {
  my ($self, $path, $max) = @_;
  return undef if !defined $path || !-e $path;
  return undef if -l $path;
  return undef if !eval { $self->_assert_contained($path, $self->{persons_dir}); 1 };
  sysopen(my $fh, $path, O_RDONLY | $NOFOLLOW) or return undef;
  binmode($fh);
  my $raw = do { local $/; <$fh> };
  close $fh;
  return undef if !defined $raw || length($raw) > $max;
  return $raw;
}

sub _assert_contained {
  my ($self, $path, $root) = @_;
  my $absolute = File::Spec->canonpath(File::Spec->rel2abs($path));
  my $base     = File::Spec->canonpath(File::Spec->rel2abs($root));
  my $relative = File::Spec->abs2rel($absolute, $base);
  croak "path escapes person root: $path"
    if File::Spec->file_name_is_absolute($relative)
      || $relative eq File::Spec->updir
      || $relative =~ /\A\.\.(?:[\\\/]|\z)/;
  return;
}

1;
