#!/usr/bin/perl
# Version 1.0.1.0      20-June-2021
#*******************************************************************************
#
# Akashic::Write::Catalog.pm
#
# Additions to the Akashic class for Writing and Saving data
#
#*******************************************************************************
# History:
#   2021.06.20 earth.love oK Created
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
# CATEGORY MANAGEMENT
#----------------------------------------#
#
# SetCategory <Root>
#   - Create the environment specified Category as a Word if not using FileName base
#
# SetFileCategory <Root> <Filename>
# - Sets the Global Category based on filename and adds the PHRASE/WORD/PATH
#
# AddCATLine <Root> <Word> <CatFile> <Data> [Tags]
#   - Add the Data to the catalog/category file (default CATS.dat)
#     in the WORDS/PHRASES/PATHS directory (create if necessary) under Root specified
#   - Checks for blank data and will not create the file or word if no data present
#   - Tags: -i      - Case Insensitive search
#           CREATE  - Create the file ONCE only - never overwrite
#           ONELINE - File only contains 1 line
#           UNIQUE  - Sort unique
#
#----------------------------------------#
# INDEX MANAGEMENT
#----------------------------------------#
#
# AddIndexLine <Directory> <DataType> <Data> [Tags]
#   - Add the Data to the Index file specified (ie DOWN.dat, UP.dat, INDEX.dat)
#     in the fully qualified <dir>
#   - Tags: -i      - Case Insensitive search
#           CREATE  - Create the file ONCE only - never overwrite
#           ONELINE - File only contains 1 line
#           UNIQUE  - Sort unique
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


################################################################################
# CATEGORY MANAGEMENT
################################################################################


################################################################################
#
# SetCategory <Root>
#
# - Create the environment specified Category as a Word if not using FileName base
#
################################################################################
sub Akashic::SetCategory
{
  my ( $self, $Root ) = @_;

  #
  # Create the environment specified Category as a Word if not using FileName base
  #
  if ($self->{_Category} ne '#FILEBASE#' && $self->{_Category} ne "") {
    # Use environment or User Configured Category
    $self->{_gCategory} = $self->{_Category};   # Category contains original Case
    # Add the $self->{_gCategory} to the WORDS/PHRASES Library
    $self->AddPhrase($Root, $self->{_gCategory}, 0);   # bAddCat=0 - don't add category to itself
    # Store the original case in the CASE.dat file
    $self->AddCATLine($Root, $self->{_gCategory}, $self->{_Data}->{'_NAME'}, $self->{_Category}, 'ONELINE');
  }
} #SetCategory


################################################################################
#
# SetFileCategory <Root> <filename>
#
# - Sets the Global Category based on filename and adds the PHRASE/WORD/PATH
#
################################################################################
sub Akashic::SetFileCategory
{
  my ( $self, $Root, $lFile ) = @_;

  #
  # Check for File Category cross-reference option
  #
  if ($self->{_Category} eq '#FILEBASE#') {   # SPECIAL ASSIGN FOR ELCATEGORY
    $lFile =~ s/^.*\///;            # Remove directory prefix from fully qualified file
    $lFile =~ s/\.[A-Za-z0-9]*$//;  # Remove file extension
    $lFile =~ s/\./ /g;             # Replace periods with space (Domain files)
    # Preprocess the File Category
    $lFile = $self->StandardLineTrim($lFile);
    $lFile = $self->ReplaceLinePunctuation($lFile, ' ');
    # Assign the Global Category
    $self->{_gFileCategory} = $lFile;
    $self->{_gCategory} = $lFile;
    # Add the $FileCategory to the WORDS/PHRASES Library - AddWord will index later
    $self->AddPhrase($Root, $self->{_gFileCategory}, 0);   # bAddCat=0 - don't add category to itself
  }
} #SetFileCategory


################################################################################
#
# AddCATLine <Root> <Word> <CatFile> <Data> [Tags]
#
# - Add the Data to the catalog/category file (default CATS.dat)
#   in the WORDS/PHRASES/PATHS directory (create if necessary) under Root specified
# - Checks for blank data and will not create the file or word if no data present
# - Tags: -i      - Case Insensitive search
#         CREATE  - Create the file ONCE only - never overwrite
#         ONELINE - File only contains 1 line
#         UNIQUE  - Sort unique
#
################################################################################
sub Akashic::AddCATLine
{
  my ( $self, $Root, $lText, $lCatFile, $lData, $Tags ) = @_;

  # Tags  # -i (case insensitive)
  $Tags = "" if (!defined($Tags));
  
  # Standardize Root
  $Root = $self->StandardizeRoot($Root);

  my $lCatFilePath = "";

  # Leave if Data isn't specified (allows calling with NULL data and we handle it here)
  return 0 if ($lText eq "" || $lCatFile eq "" || !defined($lData) || $lData eq "");

  # Preprocess the TEXT
  $lText = $self->StandardLineTrim($lText);
  $lText = $self->ReplaceLinePunctuation($lText, ' ');

  # Make sure phrase is lowercase
  $lText = $self->LowerCase($lText);

  # Add the WORD/PHRASE/PATH for the Text input
  #
  # WORD
  if ($self->isWord($lText)) {
    # Get the full CatFilePath from the WORD Dir
    $lCatFilePath = $self->GetWordDir($Root, $lText);
    #
    # Add if it doesn't exist
    if (!-d $lCatFilePath) {
      if ($self->AddWord($Root, $lText, 0)) {   # 0 - don't add Cat
        # Error adding WORD directory
        $self->Uprint("\nAddCATLine.WORD: Error creating [$lCatFilePath][$self->{_gCategory}]\n");
        return 1;
      }
    }
  #
  # PHRASE
  } elsif ($self->isPhrase($lText)) {
    # Get the full CatFilePath from the WORD Dir
    $lCatFilePath = $self->GetPhraseDir($Root, $lText);
    #
    # Add if it doesn't exist
    if (!-d $lCatFilePath) {
      if ($self->AddPhrase($Root, $lText, 0)) {   # 0 - don't add Cat
        # Error adding PHRASE directory
        $self->Uprint("\nAddCATLine.PHRASE: Error creating [$lCatFilePath][$self->{_gCategory}]\n");
        return 1;
      }
    }
  #
  # PATH
  } elsif ($self->isPath($lText)) {
    # Get the full CatFilePath from the WORD Dir
    $lCatFilePath = $self->GetPathDir($Root, $lText);
    #
    # Add if it doesn't exist
    if (!-d $lCatFilePath) {
      if ($self->AddPath($Root, $lText, 0)) {   # 0 - don't add Cat
        # Error adding PATH directory
        $self->Uprint("\nAddCATLine.PATH: Error creating [$lText][$lCatFilePath][$self->{_gCategory}]\n");
        return 1;
      }
    }
  #
  # NOTHING
  } else {
    $self->Uprint("\nAddCATLine.NO.THING: NOT PROCESSED [$lText][$lCatFile][$lData][$self->{_gCategory}]\n");
    return 1;
  }

  # Append the CAT file to CatFilePath
  $lCatFilePath .= $lCatFile;

  $lData =~ s/\n//;  # remove Carriage Return if present

  # See if Cat file exists
  if (-e $lCatFilePath) {
    # Check for CREATE Tag
    # Only create the file if it doesn't exist based on the Tags
    if ($Tags =~ /^.*CREATE.*$/i) {
      return 0;
    }
    # Check for ONELINE Tag
    # Overwrite file if it only contains One Line
    if ($Tags =~ /^.*ONELINE.*$/i) {
      # Write the one line to the file and replace
      if (!open(CAT, '>:encoding(UTF-8)', $lCatFilePath)) {
        $self->Uprint("AddCATLine: Error: Could not open $lCatFilePath\n");
        return 1;
      }
      print CAT $lData."\n";
      close(CAT);
      # Update Stats
      $self->AddStat($lCatFile);
      return 0;
    }
  }

  #
  # Add the data to the file, and sort unique if specified
  #
  $self->FileAddSort($lCatFilePath, $lData, $Tags);

  # Update Stats
  $self->AddStat($lCatFile);

  return 0;
} #AddCATLine


################################################################################
# INDEX MANAGEMENT
################################################################################


################################################################################
#
# AddIndexLine <Directory> <DataType> <Data> [Tags]
#
# - Add the <data> to the Index file <datafile> specified (ie DOWN.dat, UP.dat, INDEX.dat)
#   in the fully qualified <dir>
# - Tags: -i      - Case Insensitive search
#         CREATE  - Create the file ONCE only - never overwrite
#         ONELINE - File only contains 1 line
#         UNIQUE  - Sort unique
#
################################################################################
sub Akashic::AddIndexLine
{
  my ( $self, $lDir, $DataType, $lData, $Tags ) = @_;

  # Tags  # -i (case insensitive)
  $Tags = "" if (!defined($Tags));

  # Leave if Data isn't specified (allows calling with NULL data and we handle it here)
  return 0 if ($lDir eq "" || $DataType eq "" || !defined($lData) || $lData eq "");

  # Make sure directory exists
  if (!-d $lDir) {
    $self->Uprint("AddIndexLine: Error: $lDir does not exist");
    return 1;
  }

  # remove Carriage Return if present
  $lData =~ s/\n//;

  my $DataTypePath = $lDir;
  # Add trailing / if needed
  $DataTypePath .= "/" if (substr($DataTypePath, length($DataTypePath)-1, 1) ne "/");

  # Append the DATA (INDEX CAT COMMS) DataType to DataTypePath
  $DataTypePath .= $DataType;

  # See if Cat file exists
  if (-e $DataTypePath) {
    # Check for CREATE Tag
    # Only create the file if it doesn't exist based on the Tags
    if ($Tags =~ /^.*CREATE.*$/i) {
      return 0;
    }
    # Check for ONELINE Tag
    # Overwrite file if it only contains One Line
    if ($Tags =~ /^.*ONELINE.*$/i) {
      # Write the one line to the file and replace
      open(CAT, '>:encoding(UTF-8)', $DataTypePath) or die;
      print CAT $lData."\n";
      close(CAT);
      # Update Stats
      $self->AddStat($DataType);
      return 0;
    }
  }

  #
  # Add the data to the Cat file, and sort unique if specified
  #
  $self->FileAddSort($DataTypePath, $lData, $Tags);

  # Update Stats
  $self->AddStat($DataType);

  return 0;
} #AddIndexLine


################################################################################
# END OF Akashic::Write::Catalog.pm
################################################################################
1;
