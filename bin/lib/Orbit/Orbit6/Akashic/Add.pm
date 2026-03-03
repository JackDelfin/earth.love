#!/usr/bin/perl
# Version 1.0.1.0      09-Jun-2021
#*******************************************************************************
#
# Orbit::Akashic::Add.pm
#
# Orbit configuration for Akashic Data Processing
#
#   ProcessAddData
#
#*******************************************************************************
# History:
#   2021.06.09 earth.love oK Created
#*******************************************************************************
# Copyright 2021 Kevin Runner / Runchero Federation / PISA
#*******************************************************************************
# License: AGPLv3+: GNU Affero General Public License Version 3 or later
#*******************************************************************************
# This file is part of Orbit for Perl.
#
# Orbit for Perl is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Orbit for Perl is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Orbit for Perl.  If not, see <https://www.gnu.org/licenses/>.
#*******************************************************************************
package Orbit;
use strict;
use warnings;

#
# Load the Akashic core and Utilities, and Earth addons
#
use Akashic::Write;
use Akashic::Write::Data;


################################################################################
#
# ProcessAddData()
#
# - Process Akashic Add Data transactions - Adds data files for a Word/Phrase/Path
#
################################################################################
sub Orbit::ProcessAddData
{
  my ( $self ) = @_;
  my $O = $self;
  my $A = $O->{_Akashic};
  my $U = $A->{_Utils};

  # Buffer the print output for Akashic package
  $self->BufUprint(1);

  my $root   = $O->Get_Token('ROOT');
  my $object = $O->Get_Token('OBJECT');
  $object    =~ tr/[a-z]/[A-Z]/;   # uppercase
  my $page   = $O->Get_Token('PAGE');
  $page      = 'el_add' if ($page eq "");
  my $action = $O->Get_Token('ACTION');
  my $word   = '';   # $name is used in this function for the main "WORD/PHRASE/PATH"

  #***************************************
  #
  # Step variables and processing
  #
  my $step   = $U->GetNumber($O->Get_Token('STEP'),0);
  $step = 0 if ($step eq "");
  my $steps  = $U->GetNumber($O->Get_Token('STEPS'),0);
  $steps = 0 if ($steps eq "");

  #***************************************
  #
  # Controls
  #

  # Default Process Data Fields boolean - default YES
  my $bProcessData = 1;

  # Check Required Fields boolean - default YES
  my $bCheckRequired = 1;

  # Steps processing boolean - default YES
  my $bSteps = 0;
  $bSteps = 1 if ($step > 0 && $step <= $steps);


  #***************************************
  #
  # Get the primary key for ADD - _name
  #
  my $name   = $O->Get_Token('_name');
  # Trim the input
  $name = $A->StandardLineTrim($name);

  #***************************************
  #
  # Check for Actions
  #
  #***************************************
  #
  # PREV - Previous Page
  #
  if ($action =~ /^PREV$/i) {
    # Unset action since we're performing it
    $O->Delete_Token('ACTION');
    $O->Set_Token('_PREV_', $name);

    # ::::::: Previous Page Directive :::::::

    # Collect Data on the page but don't process (save)
    $bProcessData = 0;

    # Ignore Steps
    $bSteps = 0;

    # Ignore Required Fields
    $bCheckRequired = 0;

    # Keep on page ADD, previous page
    $page = 'el_add';

  #***************************************
  #
  # CANCEL - Cancel Transaction Page
  #
  } elsif ($action =~ /^CANCEL$/i) {
    # Unset action since we're performing it
    $O->Delete_Token('ACTION');
    $O->Set_Token('_CANCELED_', $name);

    # Clear the words tokens
    $O->Delete_Token('WORD');
    $O->Delete_Token('_WORDFOUND_');
    $O->Delete_Token('_WORDTYPE_');
    $O->Delete_Token('_BADWORD_');
    $O->Delete_Token('_WORDDIR_');

    # Start Fresh at Root Show home: EL_SHOW_<ROOT>
    $O->Set_Token('OBJECT', $root);

    # Set the page to display
    # Goes to EL_SHOW_<root>, i.e. EL_SHOW_COMMS
    $page = 'el_show';
    $O->Set_Token('PAGE', $page);
    return $page;
  }

  #***************************************
  #
  # Check for access to this directory (done in Orbit::Akashic::Add
  #
  if (!$self->HasAccess($root, $object, $page, $action, $name)) {
    $self->RegisterError("UGH   NO    ACCESS       [$root, $object, $page, $action, $word]!\n\n");
    return 1;
  }

  #***************************************
  #
  # Make sure primary data exists
  #
  # It must also be a valid word/phrase/path for storage in Akashic
  #
  if ($name eq ""
    ||!$O->SetWordTokens($name, 1)
    ) {
    $O->RegisterError('#MSG[Name not specified]#') if ($name eq "");

    # Don't Process Data on the page
    $bProcessData = 0;
    # Ignore Steps
    $bSteps = 0;
    # Ignore Required Fields
    $bCheckRequired = 0;

    # Go back to the ADD page
    $page = 'el_add';
  }

  #***************************************
  #
  # Get the context directory for Word/Phrase/Path
  # - If it doesn't exist, not an ADD entry - go to the SHOW page
  #
  my $WordDir = $A->GetTextDir($Root, $name);
  if (!-d $WordDir) {
    $O->RegisterError('#MSG[Word does not exist]# [#word#]');
    $O->Set_Token('WORD', $name);
    # Set the page to display
    $page = 'el_show';
    $O->Set_Token('PAGE', $page);
    return $page;
  }

  #***************************************
  #
  # Initialize fields to AddData - overridden within Object code
  #
  # $WHO, $DataType, $Data, $Tags
  #
  my $WHO = $U->Timestamp()
       .'|'.$O->GetUser()
       .'|'.$O->Get_Token('ENV_REMOTE_ADDR')
       .'|'.$O->Get_Token('ENV_HTTP_USER_AGENT');
  my $DataType = $O->Get_Token('_DataType');
  my $Data     = $O->Get_Token('_Data');
  my $Tags     = $O->Get_Token('_Tags');
  
  my $Filename = "";

#**************************************************************************
# - Tags:    - Multiple may be specified on the same line space separated
#         CREATE  - Create the file ONCE only - never overwrite
#         ONELINE - File only contains 1 line
#         MULTI   - Multiple Lines are being specified in Data
#         DATA    - Create records in the DataType directory under Word
#         FILE    - Save data, ONELINE or MULTI, to a single file
#         UNIQUE  - Sort unique
#         HEADER  - A DataType Header specification is being supplied
#         NOWHO   - Don't record the WHO information in the file
#**************************************************************************

  ##########################################
  # ADD CAT
  #
  if      ($DataType eq 'CAT') {
    $Filename = $A->{_Data}->{'_CATS'};
    $Tags     = 'FILE MULTI NOWHO';

  #######
  # ADD DATE
  #
  } elsif ($DataType eq 'DATE') {

  #######
  # ADD DEF
  #
  } elsif ($DataType eq 'DEF') {
    $Filename = $U->Timestamp.'_'.$O->GetUser().'_'.$O->TransactionID;
    $Tags     = 'DATA';

  #######
  # ADD DIR
  #
  } elsif ($DataType eq 'DIR') {

  #######
  # ADD EVENT
  #
  } elsif ($DataType eq 'EVENT') {

  #######
  # ADD IMAGE
  #
  } elsif ($DataType eq 'IMAGE') {

    # Special for Add - image support
    my $Url      = $O->SetParamTokens('url', '', '', '');
    my $Tags     = $O->SetParamTokens('tags', '', '', '');

    # Add the Url Image to the word directory
    if ( $word ne ""
      && $DataType =~ /^.*IMAGE.*$/i
      && $Url ne ""
      ) {
      # Save the image
      my $msg = $O->{_Akashic}->SaveWordImageUrl($root, $word, $Url, $Tags);
      $O->RegisterError($msg) if ($msg ne "");
    }

  #######
  # ADD LINK
  #
  } elsif ($DataType eq 'LINK') {

  #######
  # ADD TEXT
  #
  } elsif ($DataType eq 'TEXT') {

  #######
  # USER DEFINED
  #
  } else {

  ##########################################
  }

  #***************************************
  #
  # Get the additional DATA fields passed in
  # Create an array of the form fields
  # ONLY ACCEPT COMMAS AS DELIMITERS IN THIS FIELD
  my $Fields = $O->Get_Token('FORMFIELDS');
  my @FIELDARR;
  @FIELDARR = split(',', $Fields) if ($Fields ne "");
  my %ARR;   # Hash array to assign datafile/value pairs

  my $datafile = "";
  my $value = "";

  #***************************************
  #
  # Check for required fields
  #
  if (@FIELDARR
    && ($bCheckRequired
      || $bProcessData)
      ) {
    # Loop through each Form field
    foreach my $ff (@FIELDARR) {
      next if ($ff eq "");   # no blank fields

      # Fix the datafile name
      $datafile = $ff;
      $datafile =~ s/_req$//i;        # take off trailing _req

      # Get the trimmed token value (without _req)
      $value = $A->StandardLineTrim( $O->Get_Token($datafile) );

      # Finish standardizing datafile name
      $datafile =~ tr/[a-z]/[A-Z]/;   # uppercase
      $datafile =~ s/^_//;            # take off leading _

      # Build the HASH array
      $ARR{$datafile} = $value;

#$O->Append_Token('_DEBUG_', "$name $page F:".%ARR.":: $datafile:$value\n");
#$O->Append_Token('_DEBUG_', "$name $page F:".%ARR.":: $ff: ".%ARR{$ff}."\n");

      #
      # Rest of logic is for Checking Required Fields
      #
      next if (!$bCheckRequired);

      next if (!($ff =~ /.*_req$/i));  # only if it contains _req

#$O->Append_Token('_DEBUG_', "$ff:($value) ");   # if ($ff eq 'desc');
      # check the input value
      next if ($value ne "");   # next if it contains content

      #
      # Show the required message
      #
      $O->RegisterError($U->initcap($datafile)." #MSG[is required]#");
      $page = 'el_new';    # go back to same NEW page

      $bProcessData = 0;   # Don't process the data
      $bSteps = 0;         # Don't check for next steps
      last;                # Only show the first required occurance
    } #foreach
  } #bCheckRequired

  #$O->Append_Token('_DEBUG_', "(".%ARR.")\n");
  #foreach my $ff (keys(%ARR)) {
  #  $O->Append_Token('_DEBUG_', "$name $page F:".%ARR.":: [$ff]: [".$ARR{$ff}."]\n");
  #}


  #***************************************
  #
  # Check Input Steps
  #
  if ($bSteps) {
    #
    # Increase the step
    #
    # Don't process the data until the last step
    if ($step < $steps) {
      $bProcessData = 0;
      $page = 'el_new';
      $step++;
      $O->Set_Token('STEP', $step);
    } else {
      $page = 'el_show';
      $O->Set_Token('WORD', $name);
      $O->Set_Token('_WORDFOUND_', $name);
    }
  }


  #***************************************
  #
  # DATA PROCESSING BELOW THIS LINE
  #
  #***************************************
  if ($bProcessData) {

    #
    # Add the phrase/word/path
    #
    if (!$A->AddData($root, $word, $DataType, $Filename, $WHO, $Data, $Tags )) {

      #
      # Successful
      #
      $O->RegisterSuccess('#MSG[Data Added]#');
      $self->GetUprintBuf();   # Reset print buf
      $page = 'el_show';
      $O->Set_Token('WORD', $name);

    } else {
      #
      # Error
      #
      $O->RegisterError('#MSG[Error adding Data:]# '.$self->GetUprintBuf());
      # Reset the step if needed
      $step-- if ($bSteps && $step ne "" && $step > 1);
      $O->Set_Token('STEP', $step);

      # Set the page to display
      $page = 'el_show';   # Stay on NEW page

      # indicate we couldn't create the header word
      $bProcessData = 0;
    }
  } #bProcessData


  #***************************************
  #
  # DATA PROCESSING ABOVE THIS LINE
  #
  #***************************************

  #***************************************
  # Time to wrap it up
  #***************************************

  # Free up the field array
  undef @FIELDARR;
  undef %ARR;

  $O->Set_Token('PAGE', $page);
  return $page;
} #ProcessAddData


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::Akashic::Add;
#******************************************************************************************
1;

#END Orbit::Akashic::Add;
