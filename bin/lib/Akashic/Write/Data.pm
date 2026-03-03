#!/usr/bin/perl
# Version 1.0.1.0      20-June-2021
#*******************************************************************************
#
# Akashic::Write::Data.pm
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
# DATA MANAGEMENT
# - DATA FILE AND DATA FIELD PROCESSING
#----------------------------------------#
#
#*******************************************************************************
#
# AddTextFields() <Root> <Word> <data/value Array>
#
#   - Add the Text to the Akashic Data Store Root
#     with optional HASH Array of data/value pairs
#   - The %ARR hash contains the datafile name as the index, mixed case without extension
#
#*******************************************************************************
#
# AddData <Root> <Word> <DataType> <Filename> <WHO> <Data> <Tags>
#
# Add the DataType to the Root Word based on the Tags specified
#
#   - DataType - Indicates the type of Datafile we're processing: TEXT, LINKS, COMMS, etc.
#
#   - Filename - name of file to be appended to Timestamp in the INDEX directory (user defined)
#
#   - WHO      - Audit record specified, written after WHO:\n in the file (user defined)
#
#   - Data     - The actual data being processed (pure text)
#              - Data can be pre-processed to XML format with the $A->XML(field, value) function
#
#   - Tags:    - Multiple may be specified on the same line space separated
#
#         Data Type
#         ----------------------------------------------------------------------
#         ONELINE - Data is a single line.  Datafile is replaced, not appended.
#                   RECORD is an add-on option
#         MULTI   - Data is Multiple Lines (a list)                    (DEFAULT)
#                   Data lines are appended to the file and optionally sorted and kept unique
#                   RECORD is an add-on option
#         TEXT    - Data is Raw text with multiple lines
#                   If RECORD is specified, TEXT files are stored in XML format.
#         RECORD  - Data is in a delimited Record format, like GEO.dat: lat,long
#
#         Storage Location
#         ----------------------------------------------------------------------
#         DATA    - Create records in the DataType directory under Word
#         FILE    - Save data, ONELINE or MULTI, to a single file      (DEFAULT)
#
#         Additional Options
#         ----------------------------------------------------------------------
#         CREATE  - Create the file ONCE only - never overwrite
#         UNIQUE  - Sort unique
#         HEADER  - A DataType Header specification is being supplied
#         NOWHO   - Don't record the WHO information in the file
#
#*******************************************************************************
#
# AddArchive <Root> <Word> <DataType> <DataFilePath> <DataFileName>
#
# - Adds an archive file for the data being processed to _DATES/_ARCHIVES/YYYY/MM/DD/HH/MI
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
# DATA FILE AND DATA FIELD PROCESSING
################################################################################


################################################################################
#
# AddTextFields() <Root> <Word> <data/value Array>
#
#   - Add the Text to the Akashic Data Store Root
#     with optional HASH Array of data/value pairs
#   - The %ARR hash contains the datafile name (index), mixed case without extension
#
################################################################################
sub Akashic::AddTextFields
{
  my ( $self, $Root, $Word, %ARR ) = @_;

  my $A = $self;

  $Word = "" if (!defined($Word));
  return 0 if ($Word eq "");

  my $WordDir = $self->GetTextDir($Root, $Word);
  return 2 if ($WordDir eq "");

  # Leave if we can't add the phrase - GetUprintBuf has details
  if ($A->AddPhrase($Root, $Word, 0, 1)) {   # Add name without category bAddCat=0, with bAudit
    return 1;
  }
#$self->Uprint("<br>AddTextFields: $WordDir\n");   #TESTING

  # Create the audit records for the new word
  $A->AddIndexLine($WordDir, $A->{_Data}->{'_CREATED'},  $self->Timestamp(), 'CREATE ONELINE');
  $A->AddIndexLine($WordDir, $A->{_Data}->{'_UPDATED'},  $self->Timestamp(), 'ONELINE');

  #
  # Add the WORD/PHRASE/PATH .dat
  #
  if      ($A->isWord($Word)) {
    $A->AddIndexLine($WordDir, $A->{_Data}->{'_WORD'},   $Word, 'CREATE ONELINE');
  } elsif ($A->isPhrase($Word)) {
    $A->AddIndexLine($WordDir, $A->{_Data}->{'_PHRASE'}, $Word, 'CREATE ONELINE');
  } elsif ($A->isPath($Word)) {
    $A->AddIndexLine($WordDir, $A->{_Data}->{'_PATH'},   $Word, 'CREATE ONELINE');
  }

  # Leave if No additional fields are specified
  return 0 if ((keys %ARR) == 0);

  #
  # Loop through the Form Fields array and add the data element
  #
  my $value;   # from ARR
  foreach my $datafile (keys %ARR) {
    next if ($datafile eq "");
    # get the input value
    $value = $A->StandardLineTrim( $ARR{$datafile} );
    # Fix the form field for creating the datafile
    $datafile =~ tr/[a-z]/[A-Z]/;   # uppercase
    $datafile =~ s/^_//;            # take off leading _
    $datafile =~ s/_req$//i;        # take off trailing _req
    $datafile .= $A->{_DataExt};    # append the data extension
#$self->Uprint("<br>AddTextFields DATA: $datafile, $value\n");   #TESTING
    # Add the field to the word
    $A->AddIndexLine($WordDir, $datafile, $value, 'CREATE ONELINE');
  }

  return 0;   # Keep with same standard as AddPhrase 0 - successful
} #AddTextFields


################################################################################
#
# AddData <Root> <Word> <DataType> <Filename> <WHO> <Data> <Tags>
#
# Add the DataType to the Root Word based on the Tags specified
#
#   - DataType - Indicates the type of Datafile we're processing: TEXT, LINKS, COMMS, etc.
#
#   - Filename - name of file to be appended to Timestamp in the INDEX directory (user defined)
#
#   - WHO      - Audit record specified, written after WHO:\n in the file (user defined)
#
#   - Data     - The actual data being processed (pure text)
#              - Data can be pre-processed to XML format with the $A->XML(field, value) function
#
#   - Tags:    - Multiple may be specified on the same line space separated
#
#         Data Type
#         ----------------------------------------------------------------------
#         ONELINE - Data is a single line.  Datafile is replaced, not appended.
#                   RECORD is an add-on option
#         MULTI   - Data is Multiple Lines (a list)                    (DEFAULT)
#                   Data lines are appended to the file and optionally sorted and kept unique
#                   RECORD is an add-on option
#         TEXT    - Data is Raw text with multiple lines
#                   If RECORD is specified, TEXT files are stored in XML format.
#         RECORD  - Data is in a delimited Record format, like GEO.dat: lat,long
#
#         Storage Location
#         ----------------------------------------------------------------------
#         DATA    - Create records in the DataType directory under Word
#         FILE    - Save data, ONELINE or MULTI, to a single file      (DEFAULT)
#
#         Additional Options
#         ----------------------------------------------------------------------
#         CREATE  - Create the file ONCE only - never overwrite
#         UNIQUE  - Sort unique
#         HEADER  - A DataType Header specification is being supplied
#         NOWHO   - Don't record the WHO information in the file
#
################################################################################
sub Akashic::AddData
{
  my ( $self, $Root, $Word, $DataType, $Filename, $WHO, $Data, $Tags ) = @_;

  # Defaults
  $Root     = '_ROOT' if (!defined($Root) || $Root eq '');
  $Word     = '_ROOT' if (!defined($Word) || $Word eq '');
  $DataType = ''      if (!defined($DataType));
  $Filename = ''      if (!defined($Filename));
  $WHO      = ''      if (!defined($WHO));
  $Data     = ''      if (!defined($Data));
  $Tags     = ''      if (!defined($Tags));
  $Tags =~ tr/[a-z]/[A-Z]/;   # Uppercase Tags

  # Check for DataType index file - must be specified
  if ($DataType eq '') {
    $self->Uprint("AddData: Error: DataType not specified for [$Root][$Word][$Filename]"); 
    return 1;
  }
  
  #
  # Set the Root
  #
  $self->SetVar('Root', $Root);
  
  #
  # Get the Text directory or Root home directory
  #
  my $WordDir = "";
  # Look for a TREE
  if       ($Word =~ /_TREES\/.*/) {
    $WordDir = $self->{_RootDir}.$Word;
  # Look for ROOT
  } elsif  ($Word eq "_ROOT") {
    $WordDir = $self->{_RootDir};
  # Look for DOMAIN
  } elsif  ($Word eq "_DOM") {
    $WordDir = $self->{_DomainDir};
  } else {
    # Must be a Root Word until something changes
    $WordDir = $self->GetTextDir($Root, $Word);
  }
  
  # Make sure directory exists
  if (!-d $WordDir) {
    $self->Uprint("AddData: Error: Word Directory [$WordDir] does not exist");
    return 1;
  }

  my $DataFileName = "";   # Filename only
  my $DataFilePath = "";   # FULL directory path with filename

  #
  # Check for DATA Storage option
  #
  # Make the DATATYPE directory under the word: <ROOT>/<WordDir>/<DATATYPE>
  #
  if ($Tags =~ /.*DATA.*/) {
    # Make sure the DataType directory exists
    if (!-d $WordDir.$DataType) {
      if (!mkdir $WordDir.$DataType) {
        $self->Uprint("AddData: Error creating $WordDir.$DataType\n");
        return 1;
      }
    }
    
    #
    # Get the DataFileName (without directory) to receive the WRITE DATA
    # - DataFile is FULL directory and filename
    #
    $DataFileName = $self->Timestamp();
    if ($Filename ne "") {
      $DataFileName .= '_'.$Filename;
    }

    #
    # Get the fully structured DataFile path - under DataType
    #
    $DataFilePath = $WordDir.$DataType.'/'.$DataFileName;

    #
    # Check CREATE option
    #
    if ($Tags =~ /.*CREATE.*/ && -e $DataFilePath) {
      $self->Uprint('AddData: DATA Error: $DataFileName already exists and CREATE specified');
      return 1;
    }

  } else {
    #
    # DEFAULT TO FILE Storage - Single File - if Tags don't contain DATA
    #
    # Not using the DATATYPE Directory - just one file
    #
    $DataFileName = $Filename;

    # Get the fully structured DataFilePath path
    $DataFilePath = $WordDir.$DataFileName;

    # Check CREATE option
    if ($Tags =~ /.*CREATE.*/ && -e $DataFilePath) {
      $self->Uprint('AddData: Error: $DataFileName already exists and CREATE specified');
      return 1;
    }

    #
    # Add the data to the file - ONELINE / MULTI
    #
    if ($Tags =~ /.*MULTI.*/
      ||$Tags =~ /.*ONELINE.*/
      ) {
      #
      # Add the data to the index file
      #
      $self->AddIndexLine($WordDir, $DataFileName, $Data, $Tags);

    } else {
      #
      # Replace the contents of the data file
      #
      if (!open(FILE, '>:encoding(UTF-8)', $DataFilePath)) {
        $self->Uprint("AddData: Error: Could not open [$DataFilePath] for writing!\n");
        return 1;
      }
      $Data =~ s/\r//g;   # Remove extra CR from Windows (0D0A)
      print FILE $Data;
      close(FILE);
    }
$self->Uprint("<br>AddData: Saved: Root[$Root] Word[$Word] DataType[$DataType] <br>DataFilePath[$DataFilePath] <br>DataFileName[$DataFileName]<br> Data:[$Data]<br>");   #TESTING

  }
  

  #
  # Update Stats
  #
  $self->AddStat('AddData: DataType: '.$DataType.' '.$Tags);
  $self->AddStat('AddData: Root    : '.$Root);
  $self->AddStat('AddData: Summary (Root DataType Tags): '.$Root.' '.$DataType.' '.$Tags);
  
  #
  # Add the Transaction to the Archives
  #
  if ($self->AddArchive($Root, $Word, $DataType, $DataFilePath, $DataFileName)) {
    $self->Uprint("AddArchive Error\n");   #TESTING
    return 1;
  }

  $self->Uprint("AddData: Saved: Root[$Root] Word[$Word] DataType[$DataType] DataFilePath[$DataFilePath]\n");   #TESTING

  return 0;
} #AddData


#*******************************************************************************
#
# AddArchive <Root> <Word> <DataType> <DataFilePath> <DataFileName>
#
# - Adds an archive file for the data being processed to _DATES/_ARCHIVES/YYYY/MM/DD/HH/MI
#
#*******************************************************************************
sub Akashic::AddArchive
{
  my ( $self, $Root, $Word, $DataType, $DataFilePath, $DataFileName ) = @_;

  # Defaults
  $Root     = '_ROOT' if (!defined($Root) || $Root eq '');
  $Word     = '_ROOT' if (!defined($Word) || $Word eq '');
  $DataType = ''      if (!defined($DataType));
  $DataFilePath = ''  if (!defined($DataFilePath));
  $DataFileName = ''  if (!defined($DataFileName));

  # Check for index file - must be specified
  if ($DataType eq '') {
    $self->Uprint("AddArchive: Error: DataType not specified for [$Root][$Word][$DataFileName]"); 
    return 1;
  }
  
  # Check the DataFilePath to copy
  if ($DataFilePath eq "" && !-e $DataFilePath) {
    $self->Uprint("AddArchive: Error: DataFilePath does not exist [$Root][$Word][$DataFilePath]"); 
    return 1;
  }
  
  # Make the Current Archive Date under the _DATES/_ARCHIVES directory
  my $ArchDir = $self->BuildDateDir(substr($self->Timestamp(), 0, 12), 1);
  
  # Make sure ROOT ARCHIVE directory exists
  if (!-d $ArchDir) {
    $self->Uprint("AddArchive: Error: Could not create Root Archive Directory [$Root][$ArchDir]\n");
    return 1;
  }

  #
  # Get the Archive Filename and Fully qualified ArchiveFile
  #
  my $ArchiveFilename = $Word.'_'.$DataType;
  if ($DataFileName ne "") {
    $ArchiveFilename .= '_'.$DataFileName;
  }
  my $ArchiveFile = $ArchDir.$ArchiveFilename;

  #
  # Copy the file to the Archives - all date and transaction stamped
  #
  use File::Copy;
  if (!copy($DataFilePath, $ArchiveFile)) {
    $self->Uprint("AddArchive: Error copying file [$DataFilePath][$ArchiveFile]\n");
    return 1;
  }
  
  # Successful copy
  return 0;
  
} #AddArchive


################################################################################
# END OF Akashic::Write::Data.pm
################################################################################
1;
