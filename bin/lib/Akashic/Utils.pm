#!/usr/bin/perl
# Version 1.0.1.0       7-Jul-2021
#*******************************************************************************
#
# Akashic::Utils.pm
#
# Utility routines for the Akashic class
#
#*******************************************************************************
# History:
#   2021.07.07 earth.love oK Touchup prior to release
#   2021.06.27 earth.love oK Refactored to Akashic::Data
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
# PROCESSING UTILITIES
#----------------------------------------#
# StandardLineTrim <text_line>
#   - Remove \n, multiple spaces, trim beginning and end spaces
#   - returns trimmed line
#
# ReplaceLinePunctuation <text_line> <delimiter>
#   - Remove punctuation and other marks to create a clean directory path
#   - The delimiter character is displayed between words (could be [ ._]), default space
#   - returns clean line delimted with <delimiter>
#
# LowerCase <text_line>
#   - Returns lowercase version of text
#   - Standardized as a function to allow for additional language support
#
#----------------------------------------#
# GENERAL UTILITIES
#----------------------------------------#
#
# FileAddSort <datafile> <line> [tags]
#   - Add a line (record) to the datafile in sorted order
#   - This keeps the datafile sorted as new records are added
#   - tags: -i     - Case Insensitive search
#           UNIQUE - Sort unique
#           APPEND - Don't sort, just append line
#
# grep1File <filename> <search> [tags]
#   - Search a file for a regular expression and return the FIRST occurance full line
#   - tags: -i - Case Insensitive search
#
# SaveImageUrl <filename> <imageUrl> <tags>
#   - Save an image defined by the imageUrl to the fully qualified filename
#   - tags: UPDATE - Update the image if it already exists
#
# SaveWordImageUrl <Root> <word> <imageUrl> <tags>
#   - Save an image defined by the imageUrl to the ROOT and WORD directory (calls SaveImageUrl)
#   - tags: UPDATE - Update the image if it already exists
#
#*******************************************************************************
package Akashic;

use strict;
use warnings;
use utf8;
use feature ':5.16';

#
# Load Akashic core
#
use Akashic;


################################################################################
# PROCESSING UTILITIES
################################################################################


################################################################################
#
# StandardLineTrim <text_line>
#
# - Remove \n, multiple spaces, trim beginning and end spaces
# - returns trimmed line
#
################################################################################
sub Akashic::StandardLineTrim
{
  my ( $self, $lTrim ) = @_;

  # Standard trimming for text documents
  $lTrim =~ s/\n//;       # Remove carriage return
  $lTrim =~ s/ [ ]*/ /g;  # Change multiple spaces to a single space
  $lTrim =~ s/ $//g;      # Trim end space
  $lTrim =~ s/^ //g;      # Trim beginning space

  return $lTrim;
} #StandardLineTrim


################################################################################
#
# ReplaceLinePunctuation <text_line> <delimiter>
#
# - Remove punctuation and other marks to create a clean directory path
# - The delimiter character is displayed between words (could be [ ._]), default space
# - returns clean line delimted with <delimiter>
#
################################################################################
sub Akashic::ReplaceLinePunctuation
{
  my ( $self, $lClean, $lDelimiter ) = @_;

  $lDelimiter = ' ' if (!defined($lDelimiter) || $lDelimiter eq "");

  # Remove carriage return
  $lClean =~ s/\n//g;

  # Check for NOT A PATH and remove [.]
  # NOTE: domain name rules, not an URL
  if (!$self->isPath($lClean)) {
    $lClean =~ tr/./ /;
  } else {
    # PATH found, no need for extra cleanup
    return $lClean;
  }

  # Replace punctuation and other marks with space and compress below
  $lClean =~ tr/_/ /;   # Replace Common delimeters, other than space
  $lClean =~ tr/{}()<>[]\\\/,:;/             /;
  $lClean =~ tr/!@#\$?%&*+/         /;
  # Allow ' and - as characters: Only max 2 "-" or 1 "'" within a word
  $lClean =~ tr/=~\^"`/     /;   # " on this line used to mess with TextPad formatting

  # Remove multiple spaces and trim ends
  $lClean =~ s/ [ ]*/ /g;
  $lClean =~ s/^ //;
  $lClean =~ s/ $//;

  # Change spaces to delimiter if defined. Only [ _.] allowed
  if ($lDelimiter eq ' ') {
    return $lClean;  # Most common scenario
  } elsif ($lDelimiter eq '.') {
    $lClean =~ tr/ /./;
  } elsif ($lDelimiter eq '_') {
    $lClean =~ tr/ /_/;
  }

  return $lClean;
} #ReplaceLinePunctuation


################################################################################
#
# LowerCase <text_line>
#
# - Returns lowercase version of text
# - Standardized as a function to allow for additional language support
#
################################################################################
sub Akashic::LowerCase
{
  my ( $self, $lLower ) = @_;

  # Lowercase the word
  $lLower =~ tr/[A-Z]/[a-z]/;
  return $lLower;
} #LowerCase


################################################################################
# GENERAL UTILITIES
################################################################################


################################################################################
#
# FileAddSort <datafile> <line> [tags]
#
# - Add a line (record) to the datafile in sorted order
# - This keeps the datafile sorted as new records are added
# - tags: -i     - Case Insensitive search
#         UNIQUE - Sort unique
#         APPEND - Don't sort, just append line
#
################################################################################
sub Akashic::FileAddSort
{
  my ( $self, $Datafile, $Line, $Tags ) = @_;

  # Tags  # -i (case insensitive)
  $Tags = "" if (!defined($Tags));
  $Line = "" if (!defined($Line));

  # Remove trailing CR if present
  $Line =~ s/\n//;

  # Leave if the file doesn't exist and no data to add
  return "" if (!-e $Datafile && $Line eq "");

  # Create file if it doesn't exist
  if (!-e $Datafile) {
    open(DFILE, '>:encoding(UTF-8)', $Datafile)
      or die "FileAddSort: ERROR: Could not create $Datafile!\n";
    print DFILE $Line."\n";
    close(DFILE);
    return 1;
  } else {
    # Append only if APPEND Directive or global bSortData == 0 (not sorting real-time)
    if ($Line ne ""
      &&($Tags =~ /^.*APPEND.*$/i
        || !$self->{_bSortData}
        )
      ) {
      # See if APPEND is specified - just append line for sorting later
      open(DFILE, '>>:encoding(UTF-8)', $Datafile)
        or die "FileAddSort: APPEND ERROR: Could not create $Datafile!\n";
      print DFILE $Line."\n";
      close(DFILE);
      return 1;
    }
  }

  my @DATA;
  my $i = 0;
  my $bProcessed = 0;
  my $bUnique = 0;
  my $bCaseInsensitive = 0;
  my $prevrow = "";
  my $LineLower = "";
  my $rowLower = "";

  $bUnique = 1          if ($Tags =~ /.*UNIQUE.*/i);
  $bCaseInsensitive = 1 if ($Tags =~ /.*-i.*/i);
  $bProcessed = 1       if ($Line eq "");

  # Check for case insensitive search - lowercase line for comparison
  if ($Line ne "" && $bCaseInsensitive) {
    $LineLower = $Line;
    $LineLower =~ tr/[A-Z]/[a-z]/;   # Lowercase
  }

  # open the file with a lock
#  if (!open(DFILE, '+<', $Datafile)) {   # UTF-8 Fix
  if (!open(DFILE, '+<:encoding(UTF-8)', $Datafile)) {
    $self->Uprint("FileAddSort: ERROR: Could not open $Datafile!\n");
    return 0;
  }
  #
  # Read the sorted file and store in DATA array
  #
  foreach my $row (sort <DFILE>) {
    # Remove trailing CR if present
    $row =~ s/\n//;
    next if ($row eq "");
    # See if line has been processed
    if (!$bProcessed) {
      if ($bCaseInsensitive) {
        $rowLower = $row;
        $rowLower =~ tr/[A-Z]/[a-z]/;   # Lowercase
        # Add if Line should be before Row (case insensitive)
        if ($LineLower le $rowLower) {
          $DATA[$i++] = $Line;   # Use input Line as official version
          $bProcessed = 1;
          $prevrow = $LineLower;
        }
      } else {
        # Add if Line should be before Row
        if ($Line le $row) {
          $DATA[$i++] = $Line;
          $bProcessed = 1;
          $prevrow = $Line;
        }
      }
    }
    # Add only unique rows if specified
    if ($bUnique) {
      if ($bCaseInsensitive) {
        $rowLower = $row;
        $rowLower =~ tr/[A-Z]/[a-z]/;   # Lowercase
        # Add if Row is not repeated (case insensitive)
        if ($rowLower ne $prevrow) {
          $DATA[$i++] = $row;
        }
        $prevrow = $rowLower;
      } else {
        if ($row ne $prevrow) {
          $DATA[$i++] = $row;
        }
        $prevrow = $row;
      }
    } else {
      $DATA[$i++] = $row;
    }
  }
  close(DFILE);

  # Add the line to the array if not processed (sorted last)
  if (!$bProcessed) {
    $DATA[@DATA] = $Line;
  }

  # Open the file for writing from the beginning
  if (open(DFILE, '>:encoding(UTF-8)', $Datafile)) {
    # Loop through all records of the sorted array
    foreach my $row (sort {$a <=> $b}(keys @DATA)) {
      print DFILE $DATA[$row]."\n";
    }
    close(DFILE);
  } else {
    $self->Uprint("FileAddSort: ERROR: Could not open $Datafile for writing!\n");
  }

  undef @DATA;

  return 1;
} #FileAddSort


################################################################################
#
# grep1File <filename> <search> [tags]
#
# - Search a file for a regular expression and return the FIRST occurance full line
# - tags: -i - Case Insensitive search
#
################################################################################
sub Akashic::grep1File
{
  my ( $self, $gFile, $gSearch, $Tags ) = @_;

  # Tags  # -i (case insensitive)
  $Tags = "" if (!defined($Tags));
  # Leave if the file doesn't exist or no search term
  return "" if (!-e $gFile || $gSearch eq "");
  # Check for case insensitive search
  if ($Tags eq "-i") {
    $gSearch =~ tr/[A-Z]/[a-z]/;   # Lowercase
  }
  my $lineFound = "";
  # Open the file with UTF-8 encoding
#  open(GFILE, '<', $gFile) or die;   # UTF-8 Fix
  open(GFILE, '<:encoding(UTF-8)', $gFile) or die;
  while (<GFILE>) {
    $_ =~ s/\n//;
    # Check for case insensitive search
    if ($Tags eq "-i") {
      $_ =~ tr/[A-Z]/[a-z]/;   # Lowercase
    }
    if ($_ eq $gSearch) {
      $lineFound = $_;
      last;
    }
  }
  close(GFILE);
  return $lineFound;
} #grep1File


################################################################################
#
# SaveImageUrl <filename> <imageUrl> <tags>
#
# - Save an image defined by the imageUrl to the fully qualified filename
# - tags: UPDATE - Update the image if it already exists
#
################################################################################
sub Akashic::SaveImageUrl
{
  my ( $self, $File, $ImageUrl, $Tags ) = @_;

  # Tags  # -i (case insensitive)
  $Tags = "" if (!defined($Tags));

  # Leave if the file doesn't exist or no AddLine
  return "" if (!defined($File) || $File eq "" || !defined($ImageUrl) || $ImageUrl eq "");

  if (!($Tags =~ /^.*UPDATE.*$/i)
    && -e $File) {
    return "SaveImageUrl: File already exists and UPDATE not spedified";
  }

  # Use Image::Grab package
  # Example searching for file on website
  #my $pic = Image::Grab->new(SEARCH_URL => 'http://earth.love/index.html', REGEXP => '.*\.jpg');
  #use Image::Grab;
  #my $pic = Image::Grab->new();

  #$pic->url($ImageUrl);
  #$pic->grab;

  #open(IMAGE, ">".$File) || return "SaveImageUrl: ERROR: $File $!";
  #binmode IMAGE;   # for MSDOS derivations
  #print IMAGE $pic->image;
  #close(IMAGE);

  use LWP::Simple;

  #my $rc = getstore($ImageUrl, $File);

  my $contents = get($ImageUrl);
  open(IMAGE, ">".$File) || return "SaveImageUrl: ERROR: $File $!";
  binmode IMAGE;   # for MSDOS derivations
  print IMAGE $contents;
  close(IMAGE);

  return "";
} #SaveImageUrl


################################################################################
#
# SaveWordImageUrl <Root> <word> <imageUrl> <tags>
#
# - Save an image defined by the imageUrl to the ROOT and WORD directory (calls SaveImageUrl)
# - tags: UPDATE - Update the image if it already exists
#
################################################################################
sub Akashic::SaveWordImageUrl
{
  my ( $self, $Root, $Word, $ImageUrl, $Tags ) = @_;

  # Tags  # -i (case insensitive)
  $Tags = "" if (!defined($Tags));

  # Leave if the file doesn't exist or no AddLine
  return "" if (!defined($ImageUrl) || $ImageUrl eq "");
  return "" if (!defined($Root) || !defined($Word) || $Word eq "");

  # Set the Root variable in Akashic
  $self->SetVar('Root', $Root);

  # Get the context directory for Word/Phrase/Path
  my $WordDir = $self->GetTextDir($Root, $Word);

  # Make sure we have a valid word directory
  if ($WordDir eq "") {
    return "SaveWordImageUrl: ERROR: No directory found for root:($Root) word:($Word)\n";
  }

  return $self->SaveImageUrl($WordDir, $ImageUrl, $Tags);

} #SaveWordImageUrl


################################################################################
# END OF Akashic::Utils.pm
################################################################################
1;
