#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use Test::More;

use lib 'bin/lib';
use Akashic;
use Akashic::Process;
use Orbit::Akashic::New;

{
  package Local::RootUtils;
  sub GetNumber {
    my ($self, $value, $default) = @_;
    return defined($value) && $value =~ /\A\d+\z/ ? $value : $default;
  }
}

{
  package Local::RootAkashic;
  sub new {
    bless {
      get_text_dir    => 0,
      create_word_base => 0,
      _Utils          => bless({}, 'Local::RootUtils'),
    }, shift;
  }
  sub StandardLineTrim {
    my ($self, $value) = @_;
    $value = '' if !defined($value);
    $value =~ s/\A\s+//;
    $value =~ s/\s+\z//;
    return $value;
  }
  sub GetTextDir {
    $_[0]->{get_text_dir}++;
    die 'GetTextDir must not run for an invalid ROOT name';
  }
  sub CreateWordBase {
    my ($self, @args) = @_;
    $self->{create_word_base}++;
    $self->{create_args} = \@args;
    return 0;
  }
}

{
  package Local::RootRequestOrbit;
  our @ISA = qw(Orbit);

  sub new {
    my ($class, $code, %overrides) = @_;
    return bless {
      _Akashic => Local::RootAkashic->new,
      _Utils    => bless({}, 'Local::RootUtils'),
      tokens    => {
        ROOT   => 'PUBLIC',
        OBJECT => 'ROOT',
        PAGE   => 'el_new',
        ACTION => '',
        STEP   => '',
        STEPS  => '',
        FORMFIELDS => '_code_req,_name_req,_short_req,_desc,_color',
        _code  => $code,
        _name  => 'Public Root',
        _short => 'Public',
        _desc  => 'Public root description',
        _color => 'green',
        %overrides,
      },
      errors => [],
    }, $class;
  }

  sub BufUprint { return 1 }
  sub Get_Token { return $_[0]->{tokens}{$_[1]} // '' }
  sub Set_Token { $_[0]->{tokens}{$_[1]} = $_[2]; return 1 }
  sub Delete_Token { delete $_[0]->{tokens}{$_[1]}; return 1 }
  sub RegisterError { push @{$_[0]->{errors}}, $_[1]; return 1 }
  sub AuthorizeMutationRequest { return (1, 1) }
  sub SetWordTokens { die 'SetWordTokens must not run for a ROOT name' }
}

subtest 'elnew rejects unsafe ROOT names before any storage lookup' => sub {
  for my $name (
    '',
    '../OUTSIDE',
    'PUBLIC/../OUTSIDE',
    '_ORBIT',
    'PUBLIC._PRIVATE',
    '/ABSOLUTE',
    'PUBLIC//CHILD',
    'PUBLIC\\CHILD',
    'PUBLIC CHILD',
    'PUBLIC#CHILD',
    'PUBLIC.CHILD_2',
    '123',
    'PUBLIC.2',
    ('A' x 161),
  ) {
    my $orbit = Local::RootRequestOrbit->new($name);
    is($orbit->ProcessNewRecords(), 'el_new', "unsafe ROOT [$name] returns to the form");
    is($orbit->{_Akashic}{get_text_dir}, 0, 'GetTextDir was not called');
    is($orbit->{_Akashic}{create_word_base}, 0, 'CreateWordBase was not called');
    ok(@{$orbit->{errors}}, 'the invalid request registers an error');
  }

  my $orbit = Local::RootRequestOrbit->new('projects.local');
  is($orbit->_NormalizePublicRootName('projects.local'), 'PROJECTS.LOCAL',
    'valid dotted nested public ROOT is normalized');
  is($orbit->_NormalizePublicRootName('projects/local'), 'PROJECTS.LOCAL',
    'valid slash-separated nested public ROOT is normalized');
  is($orbit->_NormalizePublicRootName('PUBLIC-NAME.CHILD-2'), 'PUBLIC-NAME.CHILD-2',
    'safe public identifier characters remain supported');
  ok(!defined($orbit->_NormalizePublicRootName('123.PUBLIC')),
    'a public ROOT segment must begin with a letter');

  for my $invalid_fields (
    { _name => '' },
    { _name => "Bad\nName" },
    { _short => '' },
  ) {
    my $invalid = Local::RootRequestOrbit->new('PUBLIC', %$invalid_fields);
    is($invalid->ProcessNewRecords(), 'el_new', 'invalid display metadata returns to the form');
    is($invalid->{_Akashic}{create_word_base}, 0,
      'invalid display metadata cannot reach root storage');
  }

  my $valid = Local::RootRequestOrbit->new(
    'projects.local',
    _name => 'Local Projects', _short => 'Projects',
    _desc => 'Projects near this community', _color => 'blue',
  );
  is($valid->ProcessNewRecords(), 'el_show', 'a realistic ROOT form creates the root');
  is($valid->{_Akashic}{get_text_dir}, 0,
    'ROOT creation does not perform an unrelated word lookup');
  is_deeply(
    $valid->{_Akashic}{create_args},
    [ 'PROJECTS.LOCAL', 'ROOT', 'Local Projects', 'Projects',
      'Projects near this community', 'blue' ],
    'directory code and human metadata reach the correct storage arguments',
  );
  is($valid->{tokens}{ROOT}, 'PROJECTS.LOCAL', 'new ROOT token uses the validated directory code');

  my $previous = Local::RootRequestOrbit->new('PROJECTS', _name => 'Projects');
  $previous->{tokens}{ACTION} = 'PREV';
  is($previous->ProcessNewRecords(), 'el_new', 'previous-step action stays on the form');
  is($previous->{_Akashic}{create_word_base}, 0, 'previous-step action cannot create a root');

  my $cancel = Local::RootRequestOrbit->new('../OUTSIDE');
  $cancel->{tokens}{ACTION} = 'CANCEL';
  is($cancel->ProcessNewRecords(), 'el_show', 'cancel leaves the form without validating or writing a root');
  is($cancel->{_Akashic}{get_text_dir}, 0, 'cancel does not perform a storage lookup');
  is($cancel->{_Akashic}{create_word_base}, 0, 'cancel does not create a root');
};

subtest 'CreateWordBase confines roots to canonical domain directories' => sub {
  my $tmp = tempdir(CLEANUP => 1);
  my $domain = File::Spec->catdir($tmp, 'earth.love');
  make_path($domain);

  my $akashic = Akashic->new(0);
  $akashic->SetVar('DomainDir', $domain);

  is($akashic->_NormalizeRootForCreate('langs.eng'), 'LANGS/ENG',
    'storage normalizes a valid nested root');
  is($akashic->_NormalizeRootForCreate('_ORBIT.MSG'), '_ORBIT/MSG',
    'trusted build-tool system roots remain supported');

  for my $root (
    '../OUTSIDE',
    'PUBLIC/../OUTSIDE',
    '/ABSOLUTE',
    'PUBLIC//CHILD',
    'PUBLIC\\CHILD',
    'PUBLIC CHILD',
    "PUBLIC\0CHILD",
  ) {
    ok($akashic->CreateWordBase($root, 'ROOT', 'Unsafe root'),
      "storage rejects unsafe root [$root]");
  }
  ok(!-e File::Spec->catdir($tmp, 'OUTSIDE'),
    'traversal did not create a directory outside the domain');

  is($akashic->CreateWordBase('PROJECTS.LOCAL', 'ROOT', 'Local projects'), 0,
    'valid nested root is created');
  for my $child (qw(_WORDS _PHRASES _PATHS _TREES _TEMPLATES _DATES)) {
    ok(-d File::Spec->catdir($domain, 'PROJECTS', 'LOCAL', $child),
      "nested root child $child was created inside the domain");
  }

  $akashic->SetVar('WORDS', '_MYWORDS');
  is($akashic->CreateWordBase('CUSTOM-CHILDREN', 'ROOT', 'Custom children'), 0,
    'root creation honors a configured child namespace');
  ok(-d File::Spec->catdir($domain, 'CUSTOM-CHILDREN', '_MYWORDS'),
    'configured WORDS directory is created');
  ok(!-e File::Spec->catdir($domain, 'CUSTOM-CHILDREN', '_WORDS'),
    'the default WORDS directory is not substituted for its configured name');

  $akashic->SetVar('WORDS', '../OUTSIDE-CHILD');
  ok($akashic->CreateWordBase('UNSAFE-CHILDREN', 'ROOT', 'Unsafe children'),
    'a configured child path is rejected');
  ok(!-e File::Spec->catdir($domain, 'UNSAFE-CHILDREN'),
    'unsafe child configuration is rejected before the root is written');
  ok(!-e File::Spec->catdir($domain, 'OUTSIDE-CHILD'),
    'unsafe child configuration cannot escape the new root');
  $akashic->SetVar('WORDS', '_WORDS');

  my $outside = File::Spec->catdir($tmp, 'outside-root');
  make_path($outside);
  my $link = File::Spec->catdir($domain, 'LINKED');
  if (!symlink($outside, $link)) {
    diag("symlinks unavailable: $!");
  } else {
    ok($akashic->CreateWordBase('LINKED.CHILD', 'ROOT', 'Linked child'),
      'root creation rejects an existing symlink component');
    ok(!-e File::Spec->catdir($outside, 'CHILD'),
      'symlink target outside the domain was not modified');

    $akashic->SetVar('Root', 'LINKED/OTHER');
    ok($akashic->MakeRootDir(), 'MakeRootDir independently rejects the symlink component');
    ok(!-e File::Spec->catdir($outside, 'OTHER'),
      'direct MakeRootDir did not follow the symlink');

    my $child_root = File::Spec->catdir($domain, 'CHILD-LINK');
    make_path($child_root);
    my $child_link = File::Spec->catdir($child_root, '_WORDS');
    symlink($outside, $child_link) or die "create fixed-child symlink: $!";
    ok($akashic->CreateWordBase('CHILD-LINK', 'ROOT', 'Child link'),
      'root creation rejects a symlinked fixed child namespace');
  }
};

done_testing();
