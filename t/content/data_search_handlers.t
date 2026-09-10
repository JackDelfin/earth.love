#!/usr/bin/perl

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Copy qw(copy);
use File::Find;
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use FindBin;
use Test::More;

use CGI;
use lib File::Spec->catdir($FindBin::Bin, '..', '..', 'bin', 'lib');
use Orbit::Orbit7;

my @with_newline = qw(CATS DATE DATES DEF DOWN LINKS);
my @without_newline = qw(PATH PATHS PHRASE PHRASES WORD WORDS);
my @handlers = (@with_newline, @without_newline);
my %has_newline = map { $_ => 1 } @with_newline;
my $original_body = "#INC[EL_TOKENS_SEARCH]#\n#INCLUDEIF[#word.EXISTS#][EL_SEARCH_RESULTS]#";
my $core = 'EL_SHOW_DATA_SEARCH_CORE';
my @boxes = ([CATS => 'Categories'], [PHRASES => 'Phrases'],
  [LINKS => 'Links'], [WORDS => 'Words']);

my $repo = abs_path(File::Spec->catdir($FindBin::Bin, '..', '..'));
my $source_templates = File::Spec->catdir($repo, 'bin', '_TEMPLATES');
my $temporary = tempdir(CLEANUP => 1);
my $domain = File::Spec->catdir($temporary, 'handlers.example');
my $document_root = File::Spec->catdir($domain, '_WEB');
my $templates = File::Spec->catdir($domain, '_ROOT', '_TEMPLATES');
my $root_templates = File::Spec->catdir($templates, 'PERSONS');
my $rootdir = File::Spec->catdir($domain, 'PERSONS');
my $word = 'handlerprobe';
my $worddir = File::Spec->catdir($rootdir, '_WORDS', split(//, $word), $word);

sub slurp {
  my ($path) = @_;
  open(my $fh, '<:raw', $path) or die "read $path: $!";
  local $/;
  my $text = <$fh>;
  close($fh) or die "close $path: $!";
  return $text;
}

sub write_file {
  my ($path, $text) = @_;
  make_path((File::Spec->splitpath($path))[1]);
  open(my $fh, '>:raw', $path) or die "write $path: $!";
  print {$fh} $text;
  close($fh) or die "close $path: $!";
}

sub copy_tree {
  my ($src, $dst) = @_;
  find({
    no_chdir => 1,
    wanted => sub {
      my $rel = File::Spec->abs2rel($File::Find::name, $src);
      return if ($rel eq '.');
      my $target = File::Spec->catfile($dst, $rel);
      if (-d $File::Find::name) {
        make_path($target);
      } elsif (-f $File::Find::name) {
        make_path((File::Spec->splitpath($target))[1]);
        copy($File::Find::name, $target) or die "copy $File::Find::name: $!";
      }
    },
  }, $src);
}

subtest 'all twelve wrappers preserve their exact newline endings' => sub {
  for my $handler (@handlers) {
    my $name = 'EL_SHOW_DATA_'.$handler;
    my $ending = $has_newline{$handler} ? "\n" : '';
    is(slurp(File::Spec->catfile($source_templates, $name.'.oml')),
      '#INC['.$core.']#'.$ending, "$name contains only the core include with its original ending");
  }
  is(slurp(File::Spec->catfile($source_templates, $core.'.oml')), $original_body,
    'the core loads search tokens then conditionally includes results, without a final newline');
};

subtest 'TREE, TREES, INDEX, and CAT retain their distinct source' => sub {
  my %expected = (
    TREE => "#INCLUDEIF[#word.EXISTS#][EL_SEARCH_RESULTS]#\n",
    TREES => "#INCLUDEIF[#word.EXISTS#][EL_SEARCH_RESULTS]#\n",
    INDEX => "#INC[EL_TOKENS_SEARCH]#\n#INCLUDEIF![#word.EXISTS#][EL_SEARCH_RESULTS]#",
    CAT => "#INC[EL_TOKENS_SEARCH]#\n#INCLUDEIF[#word.EXISTS#][EL_SHOW_CAT]#",
  );
  for my $handler (sort keys %expected) {
    is(slurp(File::Spec->catfile($source_templates, 'EL_SHOW_DATA_'.$handler.'.oml')),
      $expected{$handler}, "$handler remains byte-for-byte unchanged");
  }
};

make_path($document_root, $templates, $worddir,
  map { File::Spec->catdir($domain, 'LANGS', 'ENG', $_) }
    qw(_WORDS _PHRASES _PATHS _TREES _TEMPLATES _DATES));
copy_tree($source_templates, $templates);
write_file(File::Spec->catfile($rootdir, 'NAME.dat'), "People\n");
write_file(File::Spec->catfile($worddir, 'WORD.dat'), $word."\n");

# Real WordBase data exists at both the root and the word, so empty-WORD
# assertions exercise the include guard even when root results are available.
for my $box (@boxes) {
  my $datafile = $box->[0];
  write_file(File::Spec->catfile($rootdir, $datafile.'.dat'),
    lc($datafile)." root fixture\n");
  write_file(File::Spec->catfile($worddir, $datafile.'.dat'),
    lc($datafile)." word fixture\n");
}

# Keep the old bodies only in the temporary fixture for a parser comparison.
write_file(File::Spec->catfile($templates, 'DATA_SEARCH_BEFORE.oml'), $original_body);
write_file(File::Spec->catfile($templates, 'DATA_SEARCH_BEFORE_NL.oml'), $original_body."\n");

sub orbit_for_word {
  my ($search_word) = @_;
  my $query = 'r=PERSONS&o=WORD&p=el_show&w='.$search_word;
  CGI->initialize_globals() if CGI->can('initialize_globals');
  local %ENV = (
    GATEWAY_INTERFACE => 'CGI/1.1',
    REQUEST_METHOD => 'GET',
    DOCUMENT_ROOT => $document_root,
    QUERY_STRING => $query,
    REQUEST_URI => '/o/page?'.$query,
    HTTP_HOST => 'handlers.example',
    REQUEST_SCHEME => 'https',
    HTTPS => 'on',
    SERVER_PORT => '443',
    REMOTE_ADDR => '192.0.2.10',
  );
  my $orbit = Orbit->new();
  $orbit->{_TEMPLATEDIRS} = { 0 => $root_templates.'/', 1 => $templates.'/' };
  $orbit->SetCommandLineOn();
  $orbit->SetPrintOutputOff();
  $orbit->Parse('#INC[EL_TOKENS]#', 0);
  return $orbit;
}

subtest 'root-first lookup resolves wrappers and the distinct shared core' => sub {
  my $orbit = orbit_for_word('');
  for my $handler (@handlers) {
    my $name = 'EL_SHOW_DATA_'.$handler;
    my $shared_wrapper = File::Spec->catfile($templates, $name.'.oml');
    is($orbit->SearchTemplateDirs($name), $shared_wrapper,
      "$name resolves the shipped wrapper with root-first lookup");

    # Also exercise a root-local copy ahead of the shared template library.
    my $root_wrapper = File::Spec->catfile($root_templates, $name.'.oml');
    copy($shared_wrapper, $root_wrapper) or die "copy $shared_wrapper: $!";
    is($orbit->SearchTemplateDirs($name), $root_wrapper,
      "$name prefers a root-local wrapper");
    is($orbit->SearchTemplateDirs($core), File::Spec->catfile($templates, $core.'.oml'),
      "$name resolves the core without selecting its wrapper again");
  }
};

# Observe includes while delegating to the real resolver and parser. In
# particular, EL_GET_DATA and its WordBase reads are never replaced.
sub with_lookups {
  my ($render) = @_;
  my @lookups;
  my $resolve = Orbit->can('SearchTemplateDirs');
  no warnings 'redefine';
  local *Orbit::SearchTemplateDirs = sub {
    my ($orbit, $name) = @_;
    push @lookups, $name;
    return $resolve->(@_);
  };
  my $html = $render->() // '';
  return ($html, \@lookups);
}

sub render_handler {
  my ($orbit, $name) = @_;
  # Use the same output buffer as ShowPage so nested OML! output is captured.
  local $orbit->{_Output} = '';
  $orbit->Parse('#INC['.$name.']#caller continues', 1);
  return $orbit->{_Output};
}

subtest 'real parser preserves empty and nonempty WORD behavior for every handler' => sub {
  for my $handler (@handlers) {
    for my $search_word ('', $word) {
      my $name = 'EL_SHOW_DATA_'.$handler;
      subtest "$name WORD=[$search_word]" => sub {
        my $orbit = orbit_for_word($search_word);
        my ($html, $lookups) = with_lookups(sub {
          render_handler($orbit, $name);
        });
        my @sequence = ($name, $core, 'EL_TOKENS_SEARCH');
        push @sequence, 'EL_SEARCH_RESULTS' if ($search_word ne '');
        my %wanted = map { $_ => 1 } ($name, $core, 'EL_TOKENS_SEARCH', 'EL_SEARCH_RESULTS');
        is_deeply([grep { $wanted{$_} } @$lookups], \@sequence,
          'the wrapper loads the core, search tokens, and conditional results in order');
        like($orbit->Get_Token('_DATA_HEAD_'), qr/<h3>#_DATA_MSG_#<\/h3>#NEXT_PREV#/,
          'real search tokens are loaded for both empty and nonempty WORD');
        unlike($html, qr/(?:IF)?INCLUDE: Template not found|!!HALT_EXECUTION!!/,
          'includes complete without parser errors');
        like($html, qr/caller continues\z/, 'parsing returns to the caller');

        if ($search_word eq '') {
          like($html, qr/\A\s*caller continues\z/, 'empty WORD renders no results');
          is(scalar(grep { $_ eq 'EL_GET_DATA' } @$lookups), 0,
            'empty WORD never requests result data');
        } else {
          is(scalar(grep { $_ eq 'EL_GET_DATA' } @$lookups), 4,
            'nonempty WORD loads all four result boxes through real EL_GET_DATA');
          for my $box (@boxes) {
            my ($datafile, $label) = @$box;
            like($html, qr/<h3>\Q$label\E<\/h3>/, "$datafile has its search-token heading");
            my $row = lc($datafile).' word fixture';
            like($html, qr/\Q$row\E/, "$datafile renders its WordBase fixture");
          }
          unlike($html, qr/root fixture/, 'results use the requested word rather than root data');
        }

        my $before = orbit_for_word($search_word);
        my $before_name = 'DATA_SEARCH_BEFORE'.($has_newline{$handler} ? '_NL' : '');
        is($html, render_handler($before, $before_name),
          'extraction preserves the original body output exactly');
      };
    }
  }
};

done_testing();
