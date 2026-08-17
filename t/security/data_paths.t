#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Cwd qw(abs_path);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use Test::More;

use lib 'bin/lib';
use Akashic;
use Akashic::Data;

sub write_file {
  my ($path, $contents) = @_;
  open(my $fh, '>:raw', $path) or die "open $path: $!";
  print {$fh} $contents;
  close($fh) or die "close $path: $!";
}

my $tmp = tempdir(CLEANUP => 1);
my $domain = File::Spec->catdir($tmp, 'earth.love');
make_path(
  File::Spec->catdir($domain, '_ROOT'),
  File::Spec->catdir($domain, 'PUBLIC'),
  File::Spec->catdir($domain, 'LANGS', 'ENG'),
  File::Spec->catdir($domain, '_ORBIT', '_AUTH'),
);

write_file(File::Spec->catfile($domain, 'DOMAIN.dat'), "earth.love\n");
write_file(File::Spec->catfile($domain, '_ROOT', 'INDEX.dat'), "root index\n");
write_file(File::Spec->catfile($domain, 'PUBLIC', 'NAME.dat'), "Public\n");
write_file(File::Spec->catfile($domain, 'PUBLIC', 'PAGE.html'), "<p>public</p>\n");
write_file(File::Spec->catfile($domain, 'LANGS', 'ENG', 'NAME.dat'), "English\n");
write_file(File::Spec->catfile($domain, '_ORBIT', '_AUTH', 'SECRET.dat'), "private\n");

my $A = Akashic->new(0);
$A->SetVar('DomainDir', $domain);

subtest 'legitimate virtual and public roots resolve' => sub {
  is(
    $A->GetWordDataFileDir('_DOM', '_ROOT', 'DOMAIN.dat'),
    abs_path(File::Spec->catfile($domain, 'DOMAIN.dat')),
    '_DOM resolves a direct domain data file',
  );
  is(
    $A->GetWordDataFileDir('_ROOT', '_ROOT', 'index'),
    abs_path(File::Spec->catfile($domain, '_ROOT', 'INDEX.dat')),
    'missing extension defaults to upper-case .dat filename',
  );
  is(
    $A->GetWordDataFileDir('PUBLIC', '_ROOT', 'NAME.dat'),
    abs_path(File::Spec->catfile($domain, 'PUBLIC', 'NAME.dat')),
    'public root file resolves',
  );
  is(
    $A->GetWordDataFileDir('langs.eng', '_ROOT', 'NAME.dat'),
    abs_path(File::Spec->catfile($domain, 'LANGS', 'ENG', 'NAME.dat')),
    'nested dotted public root resolves',
  );
  is(
    $A->GetWordDataFileDir('LANGS/ENG', '_ROOT', 'NAME.dat'),
    abs_path(File::Spec->catfile($domain, 'LANGS', 'ENG', 'NAME.dat')),
    'nested slash public root resolves',
  );
  is(
    $A->GetWordDataFileDir('PUBLIC', '_ROOT', 'PAGE.html'),
    abs_path(File::Spec->catfile($domain, 'PUBLIC', 'PAGE.html')),
    'documented alternate extension resolves',
  );
  is(
    $A->GetWordDataFileDir('PUBLIC', '_ROOT', 'NAME.dat', 1),
    'PUBLIC/NAME.dat',
    'relative-path API remains compatible for root data',
  );
};

subtest 'legitimate word, phrase, and path directories resolve' => sub {
  my @fixtures = (
    [ 'rose',        $A->GetWordDir('PUBLIC', 'rose', 1) ],
    [ 'red rose',    $A->GetPhraseDir('PUBLIC', 'red rose', 1) ],
    [ 'rose.garden', $A->GetPathDir('PUBLIC', 'rose.garden', 1) ],
  );

  for my $fixture (@fixtures) {
    my ($word, $relative_dir) = @{$fixture};
    my $dir = File::Spec->catdir($domain, 'PUBLIC', split(m{/}, $relative_dir));
    make_path($dir);
    write_file(File::Spec->catfile($dir, 'TEXT.dat'), "$word text\n");

    is(
      $A->GetWordDataFileDir('PUBLIC', $word, 'TEXT.dat'),
      abs_path(File::Spec->catfile($dir, 'TEXT.dat')),
      "$word data resolves beneath its public root",
    );
    is(
      $A->GetWordDataFileDir('PUBLIC', $word, 'TEXT.dat', 1),
      $relative_dir.'TEXT.dat',
      "$word relative-path result remains root-relative",
    );
  }
};

subtest 'filenames and extensions cannot become paths' => sub {
  my @bad_files = (
    '../SECRET.dat',
    '../../_ORBIT/_AUTH/SECRET.dat',
    '/etc/passwd',
    'subdir/NAME.dat',
    'subdir\\NAME.dat',
    '.hidden',
    'NAME.dat.bak',
    'NAME.pl',
    "NAME\0.dat",
    "NAME\n.dat",
  );
  for my $i (0 .. $#bad_files) {
    my $bad_file = $bad_files[$i];
    is(
      $A->GetWordDataFileDir('PUBLIC', '_ROOT', $bad_file),
      '',
      'rejects unsafe data filename case '.($i + 1),
    );
  }
};

subtest 'private and malformed roots are not data roots' => sub {
  for my $bad_root (
    '_ORBIT',
    '_ORBIT._AUTH',
    '_ORBIT/_AUTH',
    '../_ORBIT',
    'PUBLIC/../_ORBIT',
    '/PUBLIC',
    'PUBLIC//CHILD',
    'PUBLIC\\CHILD',
  ) {
    is(
      $A->GetWordDataFileDir($bad_root, '_ROOT', 'SECRET.dat'),
      '',
      "rejects private or malformed root [$bad_root]",
    );
  }
};

subtest 'canonical containment rejects symlink redirection' => sub {
  my $outside = File::Spec->catfile($tmp, 'outside.dat');
  write_file($outside, "outside\n");

  my $file_link = File::Spec->catfile($domain, 'PUBLIC', 'LEAK.dat');
  if (!symlink($outside, $file_link)) {
    plan skip_all => "symlinks unavailable: $!";
  }

  is(
    $A->GetWordDataFileDir('PUBLIC', '_ROOT', 'LEAK.dat'),
    '',
    'direct data-file symlink is rejected',
  );

  my $outside_root = File::Spec->catdir($tmp, 'OUTSIDE_ROOT');
  make_path($outside_root);
  write_file(File::Spec->catfile($outside_root, 'NAME.dat'), "outside root\n");
  symlink($outside_root, File::Spec->catdir($domain, 'OUTSIDE_LINK'))
    or die "symlink outside root: $!";
  is(
    $A->GetWordDataFileDir('OUTSIDE_LINK', '_ROOT', 'NAME.dat'),
    '',
    'public-looking root symlink cannot escape the domain',
  );

  symlink(File::Spec->catdir($domain, '_ORBIT'), File::Spec->catdir($domain, 'PRIVATE_LINK'))
    or die "symlink private root: $!";
  is(
    $A->GetWordDataFileDir('PRIVATE_LINK', '_ROOT', 'SECRET.dat'),
    '',
    'public-looking root symlink cannot redirect into a private domain root',
  );

  my $domain_link = File::Spec->catdir($tmp, 'earth-link');
  symlink($domain, $domain_link) or die "symlink domain: $!";
  my $ViaTrustedDomainLink = Akashic->new(0);
  $ViaTrustedDomainLink->SetVar('DomainDir', $domain_link);
  is(
    $ViaTrustedDomainLink->GetWordDataFileDir('PUBLIC', '_ROOT', 'NAME.dat'),
    abs_path(File::Spec->catfile($domain, 'PUBLIC', 'NAME.dat')),
    'a trusted DomainDir symlink still resolves safely',
  );
};

subtest 'non-regular and oversized files are rejected' => sub {
  my $large = File::Spec->catfile($domain, 'PUBLIC', 'LARGE.dat');
  open(my $large_fh, '>:raw', $large) or die "open $large: $!";
  truncate($large_fh, 8 * 1024 * 1024 + 1) or die "truncate $large: $!";
  close($large_fh) or die "close $large: $!";

  is(
    $A->GetWordDataFileDir('PUBLIC', '_ROOT', 'LARGE.dat'),
    '',
    'files larger than the read ceiling are rejected',
  );
  is(
    $A->GetWordDataFileDir('PUBLIC', '_ROOT', 'MISSING.dat'),
    '',
    'missing files are rejected',
  );
};

done_testing();
