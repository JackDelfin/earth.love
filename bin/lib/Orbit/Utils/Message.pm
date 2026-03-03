#!/usr/bin/perl
# Version 7.0.0.0      01-Jul-2021
#*****************************************************************************************
#*
#*  Package Name    :   Orbit::Utils::Message
#*
#*  Description     :   Implements Message Utility Functions within Orbit
#*
#*****************************************************************************************
# History:
#   2021.06.27 earth.love oK Created
#*****************************************************************************************
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
#*****************************************************************************************
# Functions Supported
#*****************************************
#
# GetMessageText <MessageCode> [MessageText] [HelpText] [CommentText]
#
#   Parameters:
#       MessageCode - set if multiple contexts of MessageText
#                     or message text is larger than a phrase (over 80 characters)
#       MessageText - defaults to Message Code if not set
#       HelpText    - Help text associated with message
#       CommentText - Additional Comments to be stored with Message
#
#   - Gets the Message text for a message code in the current Akashic Domain
#   - This gets the message for the user's default language
#   - The Insert Messages setting (SetMSGInsertOn/Off) determines whether
#     new messages will be inserted into _ORBIT/MSG if they don't exist.
#   - The Translate Messages setting (SetMSGTranslateOn/Off) determines if
#     Translation is checked or not.
#   - If a Message Text does not exist, the Help and Comment text will be written only once,
#     only if Insert Messages is set TRUE;
#   - This is a good place for Easter Eggs, or special messages
#
#*****************************************************************************************
package Orbit;   # Continuation of Orbit package

use strict;
use warnings;
use utf8;
use feature ':5.16';

# Orbit packages
#use Orbit::Token;
use Akashic::Write;


#******************************************************************************************
# StandardizeMSGCode <MessageCode>
#   - Standardize the Message Code for reference
#******************************************************************************************
sub StandardizeMSGCode
{
  my ($self, $MSGCode) = @_;
  my $A = $self->{_Akashic};
  return "" if (!defined($MSGCode) || $MSGCode eq '');
  $MSGCode = substr($MSGCode, 0, 80);   # Maximum 80 characters
  $MSGCode = $A->StandardLineTrim($MSGCode);
  $MSGCode = $A->ReplaceLinePunctuation($MSGCode);
  $MSGCode =~ tr/[A-Z]/[a-z]/;   # Lowercase MessageCode
  return $MSGCode;
} #StandardizeMSGCode

#******************************************************************************************
#* GetMessageText <MessageCode> [MessageText] [HelpText] [CommentText]
#*
#* - Gets the Message text for a message code in the current Akashic Domain
#* - This gets the message for the user's default language
#* - The Insert Messages setting (SetMSGInsertOn/Off) determines whether
#*   new messages will be inserted into _ORBIT/MSG if they don't exist.
#* - The Translate Messages setting (SetMSGTranslateOn/Off) determines if
#*   Translation is checked or not.
#* - The package setting for Insert Messages (SetInsertMSGOn/Off) determines
#*   whether new messages will be inserted into _ORBIT/MSG if they don't exist.
#* - If a Message Text does not exist, the Help and Comment text will be written only once,
#*   only if Insert Messages is set TRUE;
#* - This is a good place for Easter Eggs, or special messages
#
# Parameters:
#   MessageCode - set if multiple contexts of MessageText
#                 or message text is larger than a phrase (over 80 characters)
#   MessageText - defaults to Message Code if not set
#   HelpText    - Help text associated with message
#   CommentText - Additional Comments to be stored with Message
#******************************************************************************************
sub Orbit::GetMessageText
{
  my ( $self, $MessageCode, $MessageText, $HelpText, $CommentText ) = @_;
  my $A = $self->{_Akashic};

  $MessageCode = "" if (!defined($MessageCode));
  $MessageText = $MessageCode if (!defined($MessageText) || $MessageText eq "");
  $HelpText    = "" if (!defined($HelpText));
  $CommentText = "" if (!defined($CommentText));

  #
  # Leave if we're not translating #MSGTranslate[1/0]#
  #
  return $MessageText if (!$self->GetMSGTranslate());

  #
  # Get the Message Code for lookup
  #
  # Default message code to text if not set
  $MessageCode = $MessageText if ($MessageCode eq "");
  # Standardize the MessageCode
  $MessageCode = $self->StandardizeMSGCode($MessageCode);

  #
  # Get the Full Directory for the Message Code
  #
  my $MSGCodeRoot = $self->GetMessageCodeRoot();
  my $MSGCodeDir  = $self->GetMessageCodeDir();
  # Leave if MSG not setup - no _ORBIT/MSG/CODE found
  return $MessageText if (!-d $MSGCodeDir);

  #
  # Get the User Language = Translation directory
  #
  my $Lang = $self->{_Lang};

  # Get the relative path for the message Code (ie _WORDS/w/o/r/d/s/words)
  my $MSGRelPath = $A->GetTextDir("", $MessageCode, 1);   # no root, relative path

  #
  # See if we need to Insert the Message CODE
  #
  my $Codefile = $MSGCodeDir.$MSGRelPath.$A->{_Data}->{'_NAME'};
  if ( !-e $Codefile ) {
    # Message Code not found
    #
    # Leave if MSGInsert is TURNED OFF
    return $MessageText if (!$self->GetMSGInsert());
    
    #
    # Add Message Code to _ORBIT/MSG/CODE Root
    #
    $A->AddPhrase($MSGCodeRoot, $MessageCode, 0, 1);   # Root: _ORBIT/MSG/CODE, bAddCat=0, bAddAudit=1
    # Set the Message Text, Help Text, Comment Text if specified
    $A->AddIndexLine($MSGCodeDir.$MSGRelPath, $A->{_Data}->{'_NAME'}, $MessageText, 'CREATE');   # Create once, never overwrite
    $A->AddIndexLine($MSGCodeDir.$MSGRelPath, $A->{_Data}->{'_HELP'}, $HelpText,    'CREATE') if ($HelpText ne "");
    $A->AddIndexLine($MSGCodeDir.$MSGRelPath, $A->{_Data}->{'_DESC'}, $CommentText, 'CREATE') if ($CommentText ne "");
  }

  # Leave if we don't have a Lang to process
  return $MessageText if ($Lang eq "");

  # Get the Language Root Directory
  my $MSGLangRoot = $self->GetMessageLangRoot();
  my $MSGLangDir  = $self->GetMessageLangDir();
  # Switch out #lang# for User's Language _Lang
  $MSGLangRoot =~ s/#lang#/$Lang/ig;
  $MSGLangDir  =~ s/#lang#/$Lang/ig;

  # Leave if there isn't a translation directory for the Language
  return $MessageText if (!-d $MSGLangDir);

  #
  # Add the word to be translated to the translation directory
  # _USER/MSG/#lang#
  #
  # Make sure a NAME.dat exists, else create
  my $msg = "";
  my $Langfile = $MSGLangDir.$MSGRelPath.$A->{_Data}->{'_NAME'};
  if ( !-e $Langfile ) {
    if (!$self->GetMSGInsert()) {  # MSG Insert is TURNED ON
      # Get the base Code Message Text since Translation File or Directory doesn't exist
      $msg = $A->GetFile($Codefile);
      $msg =~ s/\n$//;   # Remove trailing CR
      $MessageText = $msg if ($msg ne "");
      return $MessageText;
    }
    #
    # Add Message to be Translated (MessageCode) to _ORBIT/MSG/#lang# Root
    #
    $A->AddPhrase($MSGLangRoot, $MessageCode, 0, 1);   # Root: _ORBIT/MSG/CODE, bAddCat=0, bAddAudit=1
    # Set the Message Text, Help Text, Comment Text if specified
    $A->AddIndexLine($MSGLangDir.$MSGRelPath, $A->{_Data}->{'_NAME'}, $MessageText, 'CREATE');   # Create once, never overwrite
    $A->AddIndexLine($MSGLangDir.$MSGRelPath, $A->{_Data}->{'_HELP'}, $HelpText,    'CREATE') if ($HelpText ne "");
    $A->AddIndexLine($MSGLangDir.$MSGRelPath, $A->{_Data}->{'_DESC'}, $CommentText, 'CREATE') if ($CommentText ne "");
  } else {
    # Translation Directory exists, get the Translated text finally from NAME.dat
    $msg = $A->GetFile($Langfile);
    $msg =~ s/\n$//;   # Remove trailing CR
    $MessageText = $msg if ($msg ne "");
  }
  
  return $MessageText;
} #GetMessageText


#========================================================================================
# END UTILITY FUNCTIONS IMPLEMENTATION
#========================================================================================


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::Utils::Message;
#******************************************************************************************
1;


#END Orbit::Utils::Message Package
