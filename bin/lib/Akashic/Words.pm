#!/usr/bin/perl
# Version 1.0.1.0      27-Jun-2021
#*******************************************************************************
#
# Akashic::Words.pm
#
# Word/Phrase/Path Utility routines for the Akashic class
#
#*******************************************************************************
# History:
#   2021.06.27 earth.love oK Refactored
#*******************************************************************************
# Copyright 2021 Kevin Runner / Runchero Federation / PISA
#*******************************************************************************
# License: AGPLv3+: GNU Affero General Public License Version 3 or later
#*******************************************************************************
# This file is part of Akashic for Perl.
#
# Akashic for Perl is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Akashic for Perl is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Akashic for Perl.  If not, see <https://www.gnu.org/licenses/>.
#*******************************************************************************
#----------------------------------------#
# WORD / PHRASE / PATH Read Utilities
#----------------------------------------#
#
# GetWordDir <root> <word> [bRelPath]
#   - return directory of letters decomposed for WORD, including Root Directory
#   - bRelPath (1/0) Def:0;  1 - only return relative path, not full path from root
#   ex)  root = _ROOT  => /LOVE/earth.love/_ROOT/_WORDS/r/o/o/t/root
#        bRelPath = 1  => _WORDS/r/o/o/t/root
#
# GetPhraseDir <root> <words.in.a.phrase> [bRelPath]
#   - return directory of words decomposed for PHRASE, including Root directory
#   - bRelPath (1/0) Def:0;  1 - only return relative path, not full path from root
#   ex)  root = _ROOT  => /LOVE/earth.love/_ROOT/_PHRASES/word/phrase
#        bRelPath = 1  => _PHRASES/word/phrase
#
# GetPathDir <root> <word.path> [bRelPath]
#   - return directory of words decomposed for PATH, including Root directory
#   - bRelPath (1/0) Def:0;  1 - only return relative path, not full path from root
#   ex)  root = _ROOT  => /LOVE/earth.love/_ROOT/_PATHS/path/word
#        bRelPath = 1  => _PATHS/path/word
#
# GetTextDir <root> <text> [bRelPath]
#   - Returns the directory corresponding to the WORD/PHRASE/PATH of the <text> for the Root specified
#   - bRelPath (1/0) Def:0;  1 - only return relative path, not full path from root
#
# ExistsRootText <root> <text>
#   - Returns 1 if the text (word/phrase/path) EXISTS in the root directory; 0 if the text doesn't exist
#   - NULL text returns existance of Root directory
#
# FindPath <root> <word.path>
#   - Checks if the word.path exists in the PATHS directory under the root specified
#
# isWord <text>
#   - Returns 1 if [ .] is NOT Found in the text, 0 otherwise
#
# isPhrase <text>
#   - Returns 1 if space [ ] is Found in the text, and no dot [.], 0 otherwise
#
# isPath <text>
#   - Returns 1 if [.] is Found in the text, 0 otherwise
#
# GetTextType <text>
#   - Returns the text type ("Word"/"Phrase"/"Path"), or "" if none of those
#   Alias: GetWPP <text>
#   Alias: isText <text>
#
# StandardizeRoot <root>
#   - Returns the standardized Root name based on input
#   - Uppercase, No Trailing /, Periods Converted to Directory /
#
# GetWordFromFile <datafile>
#   - Returns the word/phrase/path from from fully qualified datafile
#
#*******************************************************************************
# END Usage Notes
#*******************************************************************************
package Akashic;

use strict;
use warnings;
use utf8;
use feature ':5.16';


################################################################################
#
# GetWordDir <root> <word> [bRelPath]
#
#   - return directory of letters decomposed for WORD, including Root Directory
#   - bRelPath (1/0) Def:0;  1 - only return relative path, not full path from root
#
#   ex)  root = _ROOT  => /LOVE/earth.love/_ROOT/_WORDS/r/o/o/t/root/
#        bRelPath = 1  => _WORDS/r/o/o/t/root/
#
################################################################################
sub Akashic::GetWordDir
{
  my ( $self, $Root, $lWord, $bRelPath ) = @_;
  $bRelPath = 0 if (!defined($bRelPath) || $bRelPath ne '1');

  # Get the _WORDS path
  my $lPath = "";
  # See if we use full path or relative
  if (!$bRelPath) {
    $Root = $self->StandardizeRoot($Root);
    $lPath = $self->{_DomainDir}.$Root.'/'.$self->{_WORDS}.'/';
  } else {
    $lPath = $self->{_WORDS}.'/';
  }

  my $i = 0;
  my $letter = "";

  # Preprocess the WORD
  $lWord = $self->StandardLineTrim($lWord);
  $lWord = $self->ReplaceLinePunctuation($lWord, ' ');

  # Leave if not a WORD
  return "" if (!$self->isWord($lWord));

  # Make sure WORD is lowercase
  $lWord = $self->LowerCase($lWord);

  # Build the DEEP directory string
  for ($i=0; $i<length($lWord); $i++) {
    $letter = substr($lWord,$i,1);
    $lPath = $lPath."$letter/";
  }
  $lPath = $lPath.$lWord."/";
  return $lPath;
} #GetWordDir


################################################################################
#
# GetPhraseDir <root> <words.in.a.phrase> [bRelPath]
#
#   - return directory of words decomposed for PHRASE, including Root directory
#   - bRelPath (1/0) Def:0;  1 - only return relative path, not full path from root
#
#   ex)  root = _ROOT  => /LOVE/earth.love/_ROOT/_PHRASES/word/phrase/
#        bRelPath = 1  => _PHRASES/word/phrase/
#
################################################################################
sub Akashic::GetPhraseDir
{
  my ( $self, $Root, $lPhrase, $bRelPath ) = @_;
  $bRelPath = 0 if (!defined($bRelPath) || $bRelPath ne '1');

  # Get the _PHRASES path
  my $lPath = "";
  # See if we use full path or relative
  if (!$bRelPath) {
    $Root = $self->StandardizeRoot($Root);
    $lPath = $self->{_DomainDir}.$Root.'/'.$self->{_PHRASES}.'/';
  } else {
    $lPath = $self->{_PHRASES}.'/';
  }

  # Preprocess the PHRASE
  $lPhrase = $self->StandardLineTrim($lPhrase);
  $lPhrase = $self->ReplaceLinePunctuation($lPhrase, ' ');

  # Leave if not a PHRASE
  return "" if (!$self->isPhrase($lPhrase));

  # Make sure PHRASE is lowercase
  $lPhrase = $self->LowerCase($lPhrase);

  # Build an array of words in the phrase, separated by .
  my @lWORDS = split(' ', $lPhrase);

  # Build the PHRASE directory tree
  foreach my $lWord (@lWORDS) {
    $lPath = $lPath.$lWord.'/';
  }

  #clear up the array memory
  undef @lWORDS;

  # return the full path, ending in /
  return $lPath;
} #GetPhraseDir


################################################################################
#
# GetPathDir <root> <word.path> [bRelPath]
#
#   - return directory of words decomposed for PATH, including Root directory
#   - bRelPath (1/0) Def:0;  1 - only return relative path, not full path from root
#
#   ex)  root = _ROOT  => /LOVE/earth.love/_ROOT/_PATHS/path/word/
#        bRelPath = 1  => _PATHS/path/word/
#
################################################################################
sub Akashic::GetPathDir
{
  my ( $self, $Root, $lPath, $bRelPath ) = @_;
  $bRelPath = 0 if (!defined($bRelPath) || $bRelPath ne '1');

  # Get the _PATHS path
  my $lPathDir = "";
  # See if we use full path or relative
  if (!$bRelPath) {
    $Root = $self->StandardizeRoot($Root);
    $lPathDir = $self->{_DomainDir}.$Root.'/'.$self->{_PATHS}.'/';
  } else {
    $lPathDir = $self->{_PATHS}.'/';
  }

  # Preprocess the PATH
  $lPath = $self->StandardLineTrim($lPath);
  $lPath = $self->ReplaceLinePunctuation($lPath, ' ');

  # Leave if not a PATH
  return "" if (!$self->isPath($lPath));

  # Make sure PATH is lowercase
  $lPath = $self->LowerCase($lPath);

  # Build an array of words in the path, separated by .
  my @lWORDS = split('\.', $lPath);
  my $lWordCnt = scalar(@lWORDS);

  # Avoid infinite loop below
  return "" if ($lWordCnt == 0);

  # Build the PATH directory tree in reverse order
  for (my $i=$lWordCnt-1; $i>=0; $i--) {
    $lPathDir = $lPathDir.$lWORDS[$i].'/';
  }

  #clear up the array memory
  undef @lWORDS;

  # return the full path, ending in /
  return $lPathDir;
} #GetPathDir


################################################################################
#
# GetTextDir <root> <text> [bRelPath]
#
#   - Returns the directory corresponding to the WORD/PHRASE/PATH of the <text> for the Root specified
#   - bRelPath (1/0) Def:0;  1 - only return relative path, not full path from root
#
################################################################################
sub Akashic::GetTextDir
{
  my ( $self, $Root, $Text, $bRelPath ) = @_;
  $bRelPath = 0 if (!defined($bRelPath) || $bRelPath ne '1');
  
  # Return buffered TextDir if Text is same as _gWordCache
  # Don't use cache for Relative Path
  if (!$bRelPath
    && $self->{_gWordCache} eq $Text
    && $Root eq $self->{_Root}         # ROOT has to be the same as well
    ) {
    return $self->{_gWordDirCache};
  }

  my $TextDir = "";

  #
  # Get the appropriate type of object: WORD PHRASE PATH
  #
  # WORD
  if ($self->isWord($Text)) {
    $TextDir = $self->GetWordDir($Root, $Text, $bRelPath);
  # PHRASE
  } elsif ($self->isPhrase($Text)) {
    $TextDir = $self->GetPhraseDir($Root, $Text, $bRelPath);
  # PATH
  } elsif ($self->isPath($Text)) {
    $TextDir = $self->GetPathDir($Root, $Text, $bRelPath);
  }

  # Set the Word Cache if not showing Relative Path - only Full Paths
  if (!$bRelPath) {
    $self->{_gWordCache} = $Text;
    $self->{_gWordDirCache} = $TextDir;
  }

  return $TextDir;
} #GetTextDir


################################################################################
#
# ExistsRootText <root> <text>
#
#   - Returns 1 if the text (word/phrase/path) EXISTS in the root directory; 0 if the text doesn't exist
#   - NULL text returns existance of Root directory
#
################################################################################
sub Akashic::ExistsRootText
{
  my ( $self, $Root, $Text ) = @_;

  return 0 if (!defined($Root) || $Root eq "");
  
  $Text = "_ROOT" if (!defined($Text) || $Text eq "");   # Blank Root is _ROOT to search for root existance

  #
  # Standardize Root
  #
  $Root = $self->StandardizeRoot($Root);
  my $RootDir = $self->{_DomainDir}.$Root.'/';
  
  # Leave if RootDir doesn't exist
  return 0 if (!-d $RootDir);

  # Successful if text was blank or _ROOT
  return 1 if ($Text eq "_ROOT");
  
  # Now check the Text directory (_WORDS _PHRASES _PATHS) under Root
  return 1 if ($self->GetTextDir($Root, $Text) ne "");
  
  # Text doesn't exist in this Root
  return 0;

} #ExistsRootText


################################################################################
#
# FindPath <root> <word.path>
#
# - Checks if the word.path exists in the PATHS directory
#
################################################################################
sub Akashic::FindPath
{
  my ( $self, $Root, $lPath ) = @_;

  # Check for a valid path
  if (!$self->isPath($lPath)) {
    return 0;
  }
  # See if the Path exists in the path tree
  if (-d $self->GetPathDir($Root, $lPath)) {
    # Found it
    return 1;
  }
} #FindPath


################################################################################
#
# isWord <text>
#
# - Returns 1 if [ .] is NOT Found in the text, 0 otherwise
#
################################################################################
sub Akashic::isWord
{
  my ( $A, $lText ) = @_;

  return 0 if (!defined($lText) || $lText eq "");

  # Check for [ .]
  if ($lText =~ /.*.[ \.]..*/
      || $lText eq ""
      # Max filename on Windows is 256, so being conservative with phrase size 80
      # to avoid filename overflow
      || length($lText) > 80
      )
  {
    return 0;
  }

  # Trim the input
  $lText = $A->StandardLineTrim($lText);

  # Replace all punctions and see if that is same as input
  my $lTextNEW = $A->ReplaceLinePunctuation($lText);
  # no change - so rest are valid UTF-8 characters
  return 1 if ($lText eq $lTextNEW);

  # else this is NOT a WORD
  return 0;

} #isWord


################################################################################
#
# isPhrase <text>
#
# - Returns 1 if space [ ] is Found in the text, and no dot [.], 0 otherwise
#
################################################################################
sub Akashic::isPhrase
{
  my ( $A, $lText ) = @_;

  # Trim the input
  $lText = $A->StandardLineTrim($lText);

  # Check for minimum of a space
  if ( !($lText =~ /.*.[ ]..*/)
    # Max filename on Windows is 256, so being conservative with phrase size 80
    # to avoid filename overflow
    || length($lText) > 80
    )  {
    return 0;
  }

  # Replace all punctions and see if that is same as input
  my $lTextNEW = $A->ReplaceLinePunctuation($lText);

  $lTextNEW =~ s/\./ /g;   # Distinguish phrase from path - remove .s
  # data changed - so something else is in the string other than valid UTF-8 characters
  return 0 if ($lText ne $lTextNEW);

  # Check for space [ ] and no dot [.]
  if ( $lText =~ /.*.[ ]..*/
    && !($lText =~ /.*.[\.]..*/)
    )  {
    return 1;
  }

  # else this is NOT a PHRASE
  return 0;

} #isPhrase


################################################################################
#
# isPath <text>
#
# - Returns 1 if [.] is Found in the text, 0 otherwise
#
################################################################################
sub Akashic::isPath
{
  my ( $self, $lText ) = @_;

  # Only trim beginning and trailing spaces
  $lText =~ s/\n//;          # Remove carriage return
  $lText =~ s/[ ]*$//g;      # Trim end space
  $lText =~ s/^[ ]*//g;      # Trim beginning space

  # Return NOT A PATH if syntax is not correct
  if ( $lText =~ /^\..*/      # . begining
    || $lText =~ /.*\.$/      # . ending
    || $lText =~ /.*[ ].*/    # Contains space
    || $lText =~ /^-.*/       # - beginning
    || $lText =~ /.*-$/       # - ending
    || $lText =~ /.*--.*/     # consecutive --
    || $lText =~ /.*\.\..*/   # consecutive ..
    || $lText =~ /.*\.-.*/    # .-
    || $lText =~ /.*-\..*/    # -.
    || !($lText =~ /.*[\.].*/) # must have content around dot
    # Max filename on Windows is 256, so being conservative with phrase size 80
    # to avoid filename overflow
    || length($lText) >= 81
     )
  {
    # Not a PATH
    return 0;
  }

  # Last check for any other non PATH characters other than [A-Z][a-z][0-9]-.
  # Strip off all valid PATH characters and make sure we have "" left
  $lText =~ tr/[a-z]/[A-Z]/;
  $lText =~ tr/ABCDEFGHIJKLMNOPQRSTUVWXYZ/                          /;
  $lText =~ tr/[0-9]/          /;
  $lText =~ s/ //g;      # Trim space

  # TLD should not contain a dash [-]
  if ($lText =~ /.*-$/) {
    return 0;  # can't have dash in TLD
  }
  $lText =~ tr/-./  /;
  $lText =~ s/ //g;      # Trim space
  if ($lText eq "") {
    # Definitely a PATH
    return 1;
  }

  # else this is NOT a PATH
  return 0;
} #isPath


################################################################################
#
# GetTextType <text>
#
#   - Returns the text type (Word/Phrase/Path), or "" if none of those
#
################################################################################
sub Akashic::GetTextType
{
  my ( $self, $Text ) = @_;

  #
  # Get the appropriate Word Type of object: WORD PHRASE PATH
  #
  # WORD
  if ($self->isWord($Text)) {
    return "Word";
  # PHRASE
  } elsif ($self->isPhrase($Text)) {
    return "Phrase";
  # PATH
  } elsif ($self->isPath($Text)) {
    return "Path";
  }
  return "";
} #GetTextType
# Alias - GetWPP, isText
*GetWPP = \&GetTextType;
*isText = \&GetTextType;   #$self->isText($Text) ne ""


################################################################################
#
# StandardizeRoot <root>
#
#   - Returns the standardized Root name based on input
#   - Uppercase, No Trailing /, Periods Converted to Directory /
#
################################################################################
sub Akashic::StandardizeRoot
{
  my ( $self, $Root ) = @_;
  return "_ROOT" if (!defined($Root) || $Root eq "");   # Use Domain Root if root is blank
  $Root =~ tr/[a-z]/[A-Z]/;   # uppercase root
  $Root =~ s/\./\//g;         # Change . to / per syntax of root
  $Root =~ s/\/$//g;          # Remove trailing /
  return $Root;
} #StandardizeRoot


################################################################################
#
# GetWordFromFile <datafile>
#
# - Returns the word/phrase/path from from fully qualified datafile
#
################################################################################
sub Akashic::GetWordFromFile
{
  my ( $self, $datafile ) = @_;

  return "" if (!defined($datafile) || $datafile eq "");

  # Strip off the DATAFILE.dat if it exists
  my $ext = $self->{_DataExt};
  if ($datafile =~ /^.*$ext$/) {
    $datafile =~ s/\/[A-Z_-]*$ext$//g;
  }

  # Check for WORD
  if      ($datafile =~ /^.*$self->{_WORDS}\/.*$/) {
    $datafile =~ s/^.*_WORDS\///g;     # Clip off prefix
    $datafile =~ s/\// /g;             # Change / to space
    # if last word is a letter, use path to get word
    if ($datafile =~ /^.* .$/) {
      $datafile =~ s/ //g;             # remove spaces to reconstruct word
    } else {
      $datafile =~ s/.* //g;           # Only get last word
    }
  # Check for PHRASE
  } elsif ($datafile =~ /^.*$self->{_PHRASES}\/.*$/) {
    $datafile =~ s/^.*_PHRASES\///g;   # Clip off prefix
    $datafile =~ s/\// /g;             # Change / to space
  # Check for PATH
  } elsif ($datafile =~ /^.*$self->{_PATHS}\/.*$/) {
    $datafile =~ s/^.*_PATHS\///g;     # Clip off prefix
    my @PATH = split("\/", $datafile);
    $datafile = "";
    # Reassemble the PATH
    foreach my $p (@PATH) {
      if ($datafile eq "") {
        $datafile = $p;
      } else {
        $datafile = $p.'.'.$datafile;
      }
    }
    undef @PATH;
  } else {
    # Unknown
    return "";
  }

  return $datafile;
} #GetWordFromFile


################################################################################
# END OF Akashic::Words.pm
################################################################################
1;
