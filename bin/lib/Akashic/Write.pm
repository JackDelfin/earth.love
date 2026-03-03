#!/usr/bin/perl
# Version 1.0.1.0      06-June-2021
#*******************************************************************************
#
# Akashic::Write.pm
#
# Additions to the Akashic class for Writing and Saving data
#
#*******************************************************************************
# History:
#   2025.05.29 Added support for DOWN.dat creation in ROOT directory to support searches
#   2021.05.25 earth.love oK Refactored
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
# LINE MANAGEMENT
#----------------------------------------#
#
# ProcessLine <root> <text>
#   - Process a line of text for a Root, and create words from it
#
#----------------------------------------#
# WORD MANAGEMENT
#----------------------------------------#
# More: See doc/Concepts_WORDS.txt
#
# AddWord <root> <word> <bAddCat> <bAudit>
#   - Add a Word to the Root Wordbase
#   - Add to catalog file if bAddCat = 1 (default); 0 does not add to catalog file
#   - Set bAudit=1 to write the audit records for this item
#
# BuildWordDir <root> <word>
#   - build a directory of letters to compose a WORD w/o/r/d/word under a Root
#
#----------------------------------------#
# PHRASE MANAGEMENT
#----------------------------------------#
# More: See doc/Concepts_PHRASES.txt
#
# AddPhrase <root> <phrase> <bAddCat> <bAudit>
#   - Add the PHRASE to the PHRASES library
#   - This is an overloaded procedure, meaning it calls the appropriate process
#     based on the type of data: WORD PHRASE PATH
#   - Add to catalog file if bAddCat = 1 (default); 0 does not add to catalog file
#   - Set bAudit=1 to write the audit records for this item
#
# BuildPhraseDir <root> <phrase>
#   - Builds a directory of words in forward order in the PHRASES directory under a Root
#   ex) "This is My Phrase" => PHRASES/this/is/my/phrase
#
#----------------------------------------#
# PATH MANAGEMENT
#----------------------------------------#
# More: See doc/Concepts_PATHS.txt
#
# AddPath <root> <path> <bAddCat> <bAudit>
#   - Add the PATH to the PATHS library
#   - Paths contain dot [.] separators and follow domain name standards
#   - Add to catalog file if bAddCat = 1 (default); 0 does not add to catalog file
#   - Set bAudit=1 to write the audit records for this item
#   ex)  my.earth.love => PATHS/love/earth/my
#
# BuildPathDir <root> <path>
#   - Builds a directory of words in REVERSE order in the PATHS directory under a Root
#   ex)  "my.earth." => PATHS/this/is/my/path
#
#----------------------------------------#
# DATE MANAGEMENT
#----------------------------------------#
#
# BuildDateDir <TIMESTAMP> <bArchives>
#
#   - Make the _DATES directory based on the date specified in TIMESTAMP format
#   - Current date is used as default down to day level (YYYYMMDD)
#   - bArchives creates directory under _DATES/_ARCHIVES
#
#*******************************************************************************
package Akashic;

use strict;
use warnings;
use utf8;
use feature ':5.16';

#
# Load Akashic core and Utils
#
use Akashic::Utils;
use Akashic::Write::Catalog;


################################################################################
# LINE MANAGEMENT
################################################################################


################################################################################
#
# ProcessLine <root> <text>
#
# - Process a line of text and create words / phrases / paths from it
#
################################################################################
sub Akashic::ProcessLine
{
  my ( $self, $Root, $line ) = @_;

  # Standardize the Root
  $Root = $self->StandardizeRoot($Root);

  # Perform standard trim operations (remove \n, multiple spaces, begin/end spaces)
  $line = $self->StandardLineTrim($line);

  # Backup original line for Capitalization, CASE, and Punctuation
  my $lineORIG = $line;

  # Copy the line for punctuation removal
  my $lineNEW = $line;

  # Add catalog to word - default true
  my $bAddCat = 1;

  # Remove punctuation not used for indexing, returning
  # a space separated list of words without punctuation,
  # suitable for creating a directory tree with the words
  $lineNEW = $self->ReplaceLinePunctuation($lineNEW, ' ');

  # Reset the Vaild Phrase for this line
  $self->{_ValidPhrase} = "";

  # Check for an entire phrase on the line (ex. "high five") - index in PHRASES
  if ($self->{_LinePhrase} eq "1"
      # Make sure we have a phrase and not just a word.  A phrase contains space
      && $self->isPhrase($lineNEW)
      ) {
    # Save Capitalization to add to CASE.dat
    $self->{_ValidPhrase} = $lineNEW;
    # Add the phrase of words to the earth.love WORDS PHRASES PATHS Library
    $self->AddPhrase($Root, $self->{_ValidPhrase}, 1);   # Add to catalog
    # Change phrase to lowercase for indexing
    $self->{_ValidPhrase} = $self->LowerCase($self->{_ValidPhrase});
    # Add Phrase to NAME.dat and PHRASE.dat
    $self->AddCATLine($Root, $self->{_ValidPhrase}, $self->{_Data}->{'_NAME'}, $lineNEW, 'ONELINE');
    $self->AddCATLine($Root, $self->{_ValidPhrase}, $self->{_Data}->{'_PHRASE'}, $self->{_ValidPhrase}, '-i ONELINE');

    # Don't add catalog to individual words of a phrase since phrase is listed in the Catalog and Words are related to Phrase
    $bAddCat = 0;
  }

  # Compress: Change multiple spaces to single and create an array
  $lineNEW =~ s/ [ ]*/ /g;   # Change multiple spaces to a single space
  $lineNEW =~ s/ $//g;  # Trim end space
  $lineNEW =~ s/^ //g;  # Trim beginning space

  # $lineNEW still has correct case for all CAPS, Titles, or Names
  # Assign to $line before lowercasing
  $line = $lineNEW;

  # Change line to lowercase to index words.
  $line =~ tr/[A-Z]/[a-z]/;

  # Next iteration if line is blank (skip the rest of the loop)
  return 0 if ($line eq "");

  # Create the array with the split function based on space between words
  my @words = split(' ', $line);
  my $w="";
  my $bMultiQuote = 0;
  my $bMultiDash = 0;

  # Patch for '- in words
  # Check for multiple single-quotes and dashes' ('-) in words
  # - assume it is a hyphenated word or quote in a phrase or abbrev.
  # Reprocess line with that assumption
  foreach $w (@words)
  {
    # Check for multiple single quotes (') - replace and reprocess $line if found
    if ($w =~ /.*'.*'.*/) {
      $lineNEW = $line if ($lineNEW eq ""); # Only initialize $lineNEW if needed
      $lineNEW =~ tr/'/ /;
      $bMultiQuote = 1;
    }
    # Check for more than 3 dashes (-) or word beginning with a dash
    # Word ending with a dash could be hyphenation
    # - replace and reprocess $line if found
    # search-and-rescue cul-de-sac
    if ( $w =~ /.*-.*-.*-.*/
      || $w =~ /^-.*/
      || $w =~ /-/    # BUG 20210414 SPACE DASH SPACE
       ) {
      $lineNEW = $line if ($lineNEW eq "");
      $lineNEW =~ tr/-/ /;
      if ($w =~ /-/) {    # BUG 20210414 SPACE DASH SPACE
        # Don't raise warning
        $bMultiDash = 0;
      } else {
        $bMultiDash = 1;
      }
    }
  }

  # If exception found, change multiple spaces to single and RE-create the array
  if ($bMultiQuote || $bMultiDash) {
    $self->Uprint("\nSKIP:[QUOTE or DASH Rule][$line]");
    # Change multiple spaces to single
    $lineNEW =~ s/ [ ]*/ /g;
    $lineNEW =~ s/ $//g;
    $lineNEW =~ s/^ //g;
    # RE-create the array
    undef @words;
    @words = split(' ', $lineNEW);
  }

  # Process each word in the @words array and add it to library
  foreach my $w (@words)
  {
    # See if this word is PATH
    if ($self->isPath($w)) {
      # Add the PATH
      $self->AddPath($Root, $w, $bAddCat);
    } else {
      # Add the WORD
      $self->AddWord($Root, $w, $bAddCat);
    }
  }
  undef @words; # Clear array to free up memory
} #ProcessLine


################################################################################
# WORD MANAGEMENT
################################################################################
# More: See doc/Concepts_WORDS.txt
################################################################################


################################################################################
#
# AddWord <root> <word> <bAddCat> <bAudit>
#
#   - Add a Word to the Root Wordbase
#   - Add to catalog file if bAddCat = 1 (default); 0 does not add to catalog file
#   - Set bAudit=1 to write the audit records for this item
#
################################################################################
sub Akashic::AddWord
{
  my ( $self, $Root, $lWord, $bAddCat, $bAudit ) = @_;

  $bAddCat = 1 if (!defined($bAddCat) || $bAddCat ne '0');   # Add Catalog - default 1
  $bAudit  = 0 if (!defined($bAudit) || $bAudit ne '1');     # Add Audit records - default 0

  # Preprocess the WORD
  $lWord = $self->StandardLineTrim($lWord);
  $lWord = $self->ReplaceLinePunctuation($lWord, ' ');

  # Don't show an error message if the word is blank
  return 0 if ($lWord eq "");

  # Leave if not a WORD
  if (!$self->isWord($lWord)) {
    $self->Uprint("AddWord: NOT a word [$lWord][$self->{_gCategory}]\n");
    return 1;
  }

  # Update stats count
  $self->{_gWordCnt}++;

  # Make sure word is lowercase
  $lWord = $self->LowerCase($lWord);

  # Get the decomposed directory for the word
  my $lWordDir = $self->GetWordDir($Root, $lWord);

  #
  # Check if decomposed Word directory exists, or else create it
  #
  if (!-d $lWordDir) {
    $self->{_gWordNewCnt}++;
    #
    # Create the directory tree for the word
    #
    if ($self->BuildWordDir($Root, $lWord) eq "") {
      $self->Uprint("AddWord: Error Building word [$lWord][$self->{_gCategory}]\n");
      # Leave if we had an error creating directory
      return 1;
    }

    # Show the directory just created
    $self->Uprint("\n[$lWord] => "."[".substr($lWordDir,index($lWordDir, $self->{_WORDS}))."] [$self->{_gCategory}]");
    $self->Uprint("\n") if ($self->{_gFiles} eq "STDIN");
  } else {
    $self->{_gWordDupeCnt}++;
    #
    # Word exists already - choose what to display
    #
    #$self->Uprint("")                      if ($self->{_gWordFoundText} eq 'SILENT'); # keep it silent if word exists (default)
    $self->Uprint(".")                     if ($self->{_gWordFoundText} eq 'BRIEF'); # keep it brief
    $self->Uprint("\n[$lWord] => exists.") if ($self->{_gWordFoundText} eq 'EXISTS'); # Show the word
    $self->Uprint("\n[$lWord]")            if ($self->{_gWordFoundText} eq 'SHOW'); # Show the word
  }

  #
  # Create the WORD.dat file to recognize this WORD directory
  #
  if (!-e $lWordDir.$self->{_Data}->{'_WORD'}) {
    if (open(WORD, ">:encoding(UTF-8)", $lWordDir.$self->{_Data}->{'_WORD'})) {
      print WORD $lWord;
      close(WORD);
    } else {
      $self->Uprint("Error creating Word: ".$lWordDir.$self->{_Data}->{'_WORD'}."\n");
    }
  }

  #
  # Category File
  # - Add the word to the Category File (CATS / $self->{_CatFile} default) if specified
  #
  if ($bAddCat) {
    $self->AddCATLine($Root, $lWord, $self->{_CatFile}, $self->{_gCategory}, '-i UNIQUE');  # Case-insensitive
    # Cross-link the Category
    $self->AddCATLine($Root, $self->{_gCategory}, $self->{_Data}->{'_CAT'}, $lWord, '-i UNIQUE');
  }
  #
  # Add the audit records if selected
  #
  if ($bAudit) {
    # Create the audit records for the new item
    $self->AddIndexLine($lWordDir, $self->{_Data}->{'_CREATED'},  $self->Timestamp(), 'CREATE ONELINE');
    $self->AddIndexLine($lWordDir, $self->{_Data}->{'_UPDATED'},  $self->Timestamp(), 'ONELINE');
  }

  return 0;
} #AddWord


################################################################################
#
# BuildWordDir <root> <word>
#
#   - build a directory of letters to compose a WORD w/o/r/d/word under a Root
#
################################################################################
sub Akashic::BuildWordDir
{
  my ( $self, $Root, $lWord ) = @_;

  # Get the _WORDS path
  my $lPath = "";
  $Root = $self->StandardizeRoot($Root);
  $lPath = $self->{_DomainDir}.$Root.'/'.$self->{_WORDS}.'/';
  my $RootPath = $self->{_DomainDir}.$Root.'/';
  
  my $i = 0;
  my $CurDir = "";
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
    # Get the next letter
    $letter = substr($lWord,$i,1);

    # Special add for top of tree
    if ($i == 0) {
      # If DOWN.dat already exists, it's already in INDEX.dat
      if (!-e $lPath.$self->{_Data}->{'_DOWN'}) {
        # Add DOWN.dat to INDEX.dat only if _DOWN doesn't exist
        $self->AddIndexLine($lPath, $self->{_Data}->{'_INDEX'}, $self->{_Data}->{'_DOWN'}, 'UNIQUE');
      }
      # Add the word to DOWN.dat keeping track of all words below
      $self->AddIndexLine($lPath, $self->{_Data}->{'_DOWN'}, $lWord, 'UNIQUE');
      # Add to DOWN.dat in Root (Above _WORDS _PHRASES _PATHS)
      $self->AddIndexLine($RootPath, $self->{_Data}->{'_DOWN'}, $lWord, 'UNIQUE');
    }

    # Keep current directory for INDEX
    $CurDir = $lPath;
    # Append the letter to path
    $lPath = $lPath."$letter/";
    # Create directory if needed
    if (!-d $lPath) {
      # Add the directory we're creating to index before we create and go deeper
      # Add ./letter directory to INDEX.dat
      $self->AddIndexLine($CurDir, $self->{_Data}->{'_INDEX'}, './'.$letter, 'UNIQUE');

      # Make the directory
      unless (mkdir "$lPath") {
        $self->Uprint("\nBuildWordDir: Error creating [$lPath][$self->{_gCategory}]\n");
        return "";
      }
    }
    # If DOWN.dat already exists, it's already in INDEX.dat
    if (!-e $lPath.$self->{_Data}->{'_DOWN'}) {
      # Add DOWN.dat to INDEX.dat
      $self->AddIndexLine($lPath, $self->{_Data}->{'_INDEX'}, $self->{_Data}->{'_DOWN'}, 'UNIQUE');
    }
    # Add the word to DOWN.dat keeping track of all words below
    $self->AddIndexLine($lPath, $self->{_Data}->{'_DOWN'}, $lWord, 'UNIQUE');
  }
  # Add the word directory to INDEX.dat
  $self->AddIndexLine($lPath, $self->{_Data}->{'_INDEX'}, './'.$lWord, 'UNIQUE');

  # Create the "word" directory on the end
  $lPath .= $lWord."/";
  # Create directory if needed
  if (!-d $lPath) {
      unless (mkdir "$lPath") {
        $self->Uprint("\nBuildWordDir: Error creating [$lPath][$self->{_gCategory}]\n");
        return "";
      }
  }

  return $lPath;
} #BuildWordDir


################################################################################
# PHRASE MANAGEMENT
################################################################################
# More: See doc/Concepts_PHRASES.txt
################################################################################


################################################################################
#
# AddPhrase <root> <phrase> <bAddCat> <bAudit>
#   - Add the PHRASE to the PHRASES library
#   - This is an overloaded procedure, meaning it calls the appropriate process
#     based on the type of data: WORD PHRASE PATH
#   - Add to catalog file if bAddCat = 1 (default); 0 does not add to catalog file
#   - Set bAudit=1 to write the audit records for this item
#
################################################################################
sub Akashic::AddPhrase
{
  my ( $self, $Root, $lPhrase, $bAddCat, $bAudit ) = @_;

  $bAddCat = 1 if (!defined($bAddCat) || $bAddCat ne '0');
  $bAudit  = 0 if (!defined($bAudit) || $bAudit ne '1');     # Add Audit records - default 0

  # Preprocess the PHRASE
  $lPhrase = $self->StandardLineTrim($lPhrase);
  $lPhrase = $self->ReplaceLinePunctuation($lPhrase, ' ');

  # Check for a Word instead of a Phrase passed in
  if (!$self->isPhrase($lPhrase)) {
    if ($self->isWord($lPhrase)) {
      # No phrase delimiter found - calling AddWord
      #
      # AddWord
      #
      $self->AddWord($Root, $lPhrase);
      return 0;
    } elsif ($self->isPath($lPhrase)) {
      # Path delimiter [.] found
      #
      # AddPath
      #
      $self->AddPath($Root, $lPhrase);
      return 0;
    } else {
      # Leave if this is not a phrase
      return 1;
    }
  }

  # Update stats count
  $self->{_gPhraseCnt}++;

  # Make sure phrase is lowercase
  $lPhrase = $self->LowerCase($lPhrase);

  # Get the decomposed directory for the PHRASE
  my $lPhraseDir = $self->GetPhraseDir($Root, $lPhrase);

  # Check if decomposed Phrase directory exists, or else create it
  if (!-d $lPhraseDir) {
    $self->{_gPhraseNewCnt}++;
    #
    # Create the directory tree for the word
    #
    if ($self->BuildPhraseDir($Root, $lPhrase) eq "") {
      # Error creating directory
      $self->Uprint("AddPhrase: Error creating [$lPhrase][$self->{_gCategory}]\n");
      return 1;
    }
    # Show the directory just created
    $self->Uprint("\n[PHRASE:$lPhrase] => "."[".substr($lPhraseDir,index($lPhraseDir, $self->{_PHRASES}))."] [$self->{_gCategory}]");
    $self->Uprint("\n") if ($self->{_gFiles} eq "STDIN"); # Reset cursor to next line for manual input
  } else {
    $self->{_gPhraseDupeCnt}++;
    #
    # Phrase exists already - choose what to display
    #
    #$self->Uprint("")            if ($self->{_gWordFoundText} eq 'SILENT'); # keep it silent if word exists (default)
    $self->Uprint(".")            if ($self->{_gWordFoundText} eq 'BRIEF'); # keep it brief
    $self->Uprint("\n[$lPhrase] => exists.") if ($self->{_gWordFoundText} eq 'EXISTS'); # Show the word
    $self->Uprint("\n[$lPhrase]") if ($self->{_gWordFoundText} eq 'SHOW'); # Show the word
  }

  #
  # Create the PHRASE.dat file to recognize this PHRASE directory
  #
  if (!-e $lPhraseDir.$self->{_Data}->{'_PHRASE'}) {
	# DEV NOTE: ADD UTF-8 Syntax
    if (open(PHRASE, ">:encoding(UTF-8)", $lPhraseDir.$self->{_Data}->{'_PHRASE'})) {
      print PHRASE $lPhrase;
      close(PHRASE);
    } else {
      $self->Uprint("Error creating Phrase: ".$lPhraseDir.$self->{_Data}->{'_PHRASE'}."\n");
    }
  }
  #
  # Category File
  # - Add the phrase to the Category File (CATS / $self->{_CatFile} default) if specified
  #
  if ($bAddCat) {
    $self->AddCATLine($Root, $lPhrase, $self->{_CatFile}, $self->{_gCategory}, '-i UNIQUE');  # Case-insensitive
    # Cross-link the Category
    $self->AddCATLine($Root, $self->{_gCategory}, $self->{_Data}->{'_CAT'}, $lPhrase, '-i UNIQUE');
  }
  #
  # Add the audit records if selected
  #
  if ($bAudit) {
    # Create the audit records for the new item
    $self->AddIndexLine($lPhraseDir, $self->{_Data}->{'_CREATED'},  $self->Timestamp(), 'CREATE ONELINE');
    $self->AddIndexLine($lPhraseDir, $self->{_Data}->{'_UPDATED'},  $self->Timestamp(), 'ONELINE');
  }

  return 0;
} #AddPhrase


################################################################################
#
# BuildPhraseDir <root> <phrase>
#
#   - Builds a directory of words in forward order in the PHRASES directory under a Root
#
#   ex)  "This is My Phrase" => _PHRASES/this/is/my/phrase
#
# DEV NOTE:
#   The following sanitation functions are called within the procedure by default:
#     StandardLineTrim()
#     ReplaceLinePunctuation()
################################################################################
sub Akashic::BuildPhraseDir
{
  my ( $self, $Root, $lPhrase ) = @_;

  # Get the _PHRASES path
  my $lPath = "";
  $Root = $self->StandardizeRoot($Root);
  $lPath = $self->{_DomainDir}.$Root.'/'.$self->{_PHRASES}.'/';
  my $RootPath = $self->{_DomainDir}.$Root.'/';

  my $CurDir = "";
  my $lWord = "";

  # Preprocess the PHRASE
  $lPhrase = $self->StandardLineTrim($lPhrase);
  $lPhrase = $self->ReplaceLinePunctuation($lPhrase, ' ');

  # Leave if not a PHRASE
  return "" if (!$self->isPhrase($lPhrase));

  # Make sure PHRASE is lowercase
  $lPhrase = $self->LowerCase($lPhrase);

  # Build an array of words in the phrase, separated by .
  my @lWORDS = split(' ', $lPhrase);

  #
  # Build the PHRASE directory tree FIRST
  #
  my $i=0;
  foreach $lWord (@lWORDS) {
    # Special add for top of tree
    if ($i == 0) {
      # If DOWN.dat already exists, it's already in INDEX.dat
      if (!-e $lPath.$self->{_Data}->{'_DOWN'}) {
        # Add DOWN.dat to INDEX.dat
        $self->AddIndexLine($lPath, $self->{_Data}->{'_INDEX'}, $self->{_Data}->{'_DOWN'}, 'UNIQUE');
      }
      # Add the word to DOWN.dat keeping track of all words below
      $self->AddIndexLine($lPath, $self->{_Data}->{'_DOWN'}, $lPhrase, 'UNIQUE');
      # Add to DOWN.dat in Root (Above _WORDS _PHRASES _PATHS)
      $self->AddIndexLine($RootPath, $self->{_Data}->{'_DOWN'}, $lPhrase, 'UNIQUE');
    }

    $i++;
    $CurDir = $lPath;
    # Append the next word to path
    $lPath = $lPath.$lWord.'/';
    if (!-d $lPath) {
      # Add the directory we're creating to index before we create and go deeper
      # Add ./Phrase directory to INDEX.dat
      $self->AddIndexLine($CurDir, $self->{_Data}->{'_INDEX'}, './'.$lWord, 'UNIQUE');

      # Make the directory
      unless (mkdir "$lPath") {
        $self->Uprint("\nBuildPhraseDir: Error creating [$lPath][$self->{_gCategory}]\n");
        return "";
      }
    }
    # Don't add DOWN.dat for exact phrase since no words below it
    if ($i != @lWORDS) {
      # If DOWN.dat already exists, it's already in INDEX.dat
      if (!-e $lPath.$self->{_Data}->{'_DOWN'}) {
        # Add DOWN.dat to INDEX.dat
        $self->AddIndexLine($lPath, $self->{_Data}->{'_INDEX'}, $self->{_Data}->{'_DOWN'}, 'UNIQUE');
      }
      # Add the phrase to DOWN.dat keeping track of all phrases below
      $self->AddIndexLine($lPath, $self->{_Data}->{'_DOWN'}, $lPhrase, 'UNIQUE');
    }
  }

  #
  # Build the WORDS directories for WORDS in the phrase
  #
  foreach $lWord (@lWORDS) {
    # Add the word to the WORDS directory after building the PHRASE - don't add to catalog
    $self->AddWord($Root, $lWord, 0);

    # Add the Phrase to the PHRASES list (Phrases the word is on)
    $self->AddCATLine($Root, $lWord, $self->{_Data}->{'_PHRASES'}, $lPhrase, '-i UNIQUE');
  }

  #clear up the array memory
  undef @lWORDS;

  # return the full path, ending in /
  return $lPath;
} #BuildPhraseDir


################################################################################
# PATH MANAGEMENT
################################################################################
# More: See doc/Concepts_PATHS.txt
################################################################################


################################################################################
#
# AddPath <root> <path> <bAddCat> <bAudit>
#
#   - Add the PATH to the PATHS library
#   - Paths contain dot [.] separators and follow domain name standards
#   - Add to catalog file if bAddCat = 1 (default); 0 does not add to catalog file
#   - Set bAudit=1 to write the audit records for this item
#   ex)  my.earth.love => PATHS/love/earth/my
#
################################################################################
sub Akashic::AddPath
{
  my ( $self, $Root, $lPath, $bAddCat, $bAudit ) = @_;

  $bAddCat = 1 if (!defined($bAddCat) || $bAddCat ne '0');
  $bAudit  = 0 if (!defined($bAudit) || $bAudit ne '1');     # Add Audit records - default 0

  # Preprocess the PATH
  $lPath = $self->StandardLineTrim($lPath);
  $lPath = $self->ReplaceLinePunctuation($lPath, ' ');

  # Check for a Path
  if (!$self->isPath($lPath)) {
      # Leave if this is not a Path
    return 1;
  }

  # Update stats count
  $self->{_gPathCnt}++;

  # Make sure path is lowercase
  $lPath = $self->LowerCase($lPath);

  # Get the decomposed directory for the PATH
  my $lPathDir = $self->GetPathDir($Root, $lPath);

  # Check if decomposed Path directory exists, or else create it
  if (!-d $lPathDir) {
    $self->{_gPathNewCnt}++;
    #
    # Create the directory tree for the word
    #
    if ($self->BuildPathDir($Root, $lPath) eq "") {
      # Error creating Path directory
      $self->Uprint("\nBuildPathDir: Error creating [$lPath][$self->{_gCategory}]\n");
      return 1;
    }
    # Show the directory just created
    $self->Uprint("\n[PATH:$lPath] => "."[".substr($lPathDir,index($lPathDir, $self->{_PATHS}))."] [$self->{_gCategory}]");
    $self->Uprint("\n") if ($self->{_gFiles} eq "STDIN"); # Reset cursor to next line for manual input
  } else {
    $self->{_gPathDupeCnt}++;
    #
    # Path exists already - choose what to display
    #
    #$self->Uprint("")            if ($self->{_gWordFoundText} eq 'SILENT'); # keep it silent if word exists (default)
    $self->Uprint(".")            if ($self->{_gWordFoundText} eq 'BRIEF'); # keep it brief
    $self->Uprint("\n[$lPath] => exists.") if ($self->{_gWordFoundText} eq 'EXISTS'); # Show the word
    $self->Uprint("\n[$lPath]") if ($self->{_gWordFoundText} eq 'SHOW'); # Show the word
  }

  #
  # Create the PATH.dat file to recognize this PATH directory
  #
  if (!-e $lPathDir.$self->{_Data}->{'_PATH'}) {
    if (open(PATH, ">:encoding(UTF-8)", $lPathDir.$self->{_Data}->{'_PATH'})) {
      print PATH $lPath;
      close(PATH);
    } else {
      $self->Uprint("Error creating Path: ".$lPathDir.$self->{_Data}->{'_PATH'}."\n");
    }
  }
  #
  # Category File
  # - Add the Path to the Category File (CATS / $self->{_CatFile} default) if specified
  #
  if ($bAddCat) {
    $self->AddCATLine($Root, $lPath, $self->{_CatFile}, $self->{_gCategory}, '-i UNIQUE');  # Case-insensitive
    # Cross-link the Category
    $self->AddCATLine($Root, $self->{_gCategory}, $self->{_Data}->{'_CAT'}, $lPath, '-i UNIQUE');
  }
  #
  # Add the audit records if selected
  #
  if ($bAudit) {
    # Create the audit records for the new item
    $self->AddIndexLine($lPathDir, $self->{_Data}->{'_CREATED'},  $self->Timestamp(), 'CREATE ONELINE');
    $self->AddIndexLine($lPathDir, $self->{_Data}->{'_UPDATED'},  $self->Timestamp(), 'ONELINE');
  }

  return 0;
} #AddPath


################################################################################
#
# BuildPathDir <root> <path>
#
#   - Builds a directory of words in REVERSE order in the PATHS directory under a Root
#   ex)  "my.earth." => PATHS/this/is/my/path
#
# DEV NOTE:
#   The following sanitation functions are called within the procedure by default:
#     StandardLineTrim()
#     ReplaceLinePunctuation()
################################################################################
sub Akashic::BuildPathDir
{
  my ( $self, $Root, $lPath ) = @_;

  # Get the _WORDS path
  my $lPathDir = "";
  $Root = $self->StandardizeRoot($Root);
  $lPathDir = $self->{_DomainDir}.$Root.'/'.$self->{_PATHS}.'/';
  my $RootPath = $self->{_DomainDir}.$Root.'/';

  my $CurDir = "";
  my $lWord = "";

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

  #
  # Build the PATH directory tree in REVERSE order
  #
  for (my $i=$lWordCnt-1; $i>=0; $i--) {
    # Special add for top of tree
    if ($i == $lWordCnt-1) {
      # If DOWN.dat already exists, it's already in INDEX.dat
      if (!-e $lPathDir.$self->{_Data}->{'_DOWN'}) {
        # Add DOWN.dat to INDEX.dat
        $self->AddIndexLine($lPathDir, $self->{_Data}->{'_INDEX'}, $self->{_Data}->{'_DOWN'}, 'UNIQUE');
      }
      # Add the word to DOWN.dat keeping track of all words below
      $self->AddIndexLine($lPathDir, $self->{_Data}->{'_DOWN'}, $lPath, 'UNIQUE');
    }

    $CurDir = $lPathDir;
    # Add the next word to path
    $lPathDir = $lPathDir.$lWORDS[$i].'/';
    if (!-d $lPathDir) {
      # Add the directory we're creating to index before we create and go deeper
      # Add ./Path directory to INDEX.dat
      $self->AddIndexLine($CurDir, $self->{_Data}->{'_INDEX'}, './'.$lWORDS[$i], 'UNIQUE');

      # Make the directory
      unless (mkdir "$lPathDir") {
        $self->Uprint("\nBuildPathDir: Error creating [$lPathDir]\n");
        return "";
      }
    }
    # Don't add DOWN.dat for exact path since no paths below it
    if ($i > 0) {
      # If DOWN.dat already exists, it's already in INDEX.dat
      if (!-e $lPathDir.$self->{_Data}->{'_DOWN'}) {
        # Add DOWN.dat to INDEX.dat
        $self->AddIndexLine($lPathDir, $self->{_Data}->{'_INDEX'}, $self->{_Data}->{'_DOWN'}, 'UNIQUE');
      }
      # Add the path to DOWN.dat keeping track of all paths below
      $self->AddIndexLine($lPathDir, $self->{_Data}->{'_DOWN'}, $lPath, 'UNIQUE');
      # Add to DOWN.dat in Root (Above _WORDS _PHRASES _PATHS)
      $self->AddIndexLine($RootPath, $self->{_Data}->{'_DOWN'}, $lPath, 'UNIQUE');
    }
  }

  #
  # Add the Words in the PATH to the WORDS directories
  # Doesn't need to be in reverse order, only for consistency
  #
  for (my $i=$lWordCnt-1; $i>=0; $i--) {
    # Add the word to the WORDS directory after building the PATH, don't add to catalog
    $self->AddWord($Root, $lWORDS[$i], 0);

    # Add the Path to the words PATHS list (Paths the word is on)
    $self->AddCATLine($Root, $lWORDS[$i], $self->{_Data}->{'_PATHS'}, $lPath, 'UNIQUE');
  }

  #clear up the array memory
  undef @lWORDS;

  # return the full path, ending in /
  return $lPathDir;
} #BuildPathDir


################################################################################
# DATE MANAGEMENT
################################################################################


#*******************************************************************************
#
# BuildDateDir <TIMESTAMP> <bArchives>
#
#   - Make the _DATES directory based on the date specified in TIMESTAMP format
#   - Current date is used as default down to day level (YYYYMMDD)
#   - bArchives creates directory under _DATES/_ARCHIVES
#
#*******************************************************************************
sub Akashic::BuildDateDir
{
  my ($self, $Date, $bArchives) = @_;
  
  # Get the timestamp to get the YYYYMMDD in confident order
  # Default date to YYYYMMDD
  $Date = substr($self->Timestamp(), 0, 8) if (!defined($Date) || $Date eq "");

  $bArchives = 0 if (!defined($bArchives) || $bArchives ne '1');
  
  my $Year = substr($Date,0,4);
  my $Month= substr($Date,4,2);
  my $Day  = substr($Date,6,2);
  my $Hour = substr($Date,8,2);
  my $Min  = substr($Date,10,2);
  my $Sec  = substr($Date,12,2);
  
  #
  # Make the _DATES/_ARCHIVES/YYYY/MM/DD/HH24/MI/ROOT Archive Trail
  #
  my $DateDir = $self->{_RootDir}.$self->{_DATES};
  $DateDir .= '/_ARCHIVES/' if ($bArchives);   # Append _ARCHIVES if necessary
  
  mkdir($DateDir) if (!-d $DateDir);   # _DATES/_ARCHIVES/
  
  return $DateDir if ($Year eq "");
  $DateDir .= $Year.'/';
  mkdir($DateDir) if (!-d $DateDir);   # YYYY/
  
  return $DateDir if ($Month eq "");
  $DateDir .= $Month.'/';
  mkdir($DateDir) if (!-d $DateDir);   # MM/
  
  return $DateDir if ($Day eq "");
  $DateDir .= $Day.'/';
  mkdir($DateDir) if (!-d $DateDir);   # DD/
  
  return $DateDir if ($Hour eq "");
  $DateDir .= $Hour.'/';
  mkdir($DateDir) if (!-d $DateDir);   # HH24/
  
  return $DateDir if ($Min eq "");
  $DateDir .= $Min.'/';
  mkdir($DateDir) if (!-d $DateDir);   # MI/

  return $DateDir if ($Sec eq "");
  $DateDir .= $Sec.'/';
  mkdir($DateDir) if (!-d $DateDir);   # SS/

  return $DateDir;
} #BuildDateDir


################################################################################
# END OF Akashic::Write.pm
################################################################################
1;
