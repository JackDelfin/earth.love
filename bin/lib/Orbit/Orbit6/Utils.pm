#!/usr/bin/perl
# Version 6.0.6.0      21-May-2021
#*****************************************************************************************
#*
#*  Package Name    :   Orbit::Utils
#*
#*  Description     :   Implements Utility Functions within Orbit
#*
#*****************************************************************************************
# History:
#   2021.04.29 earth.love oK Refactored
#   2021.04.24 earth.love oK Converted from PL/SQL Orbit package (2015.05.30 Ver 5.0.0.0)
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
package Orbit;   # Continuation of Orbit package

use strict;
use warnings;
use utf8;
use feature ':5.16';


#========================================================================================
#
#                                TOKEN subroutines
#
#========================================================================================


#******************************************************************************************
#*  Procedure Name  :   Get_Token
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Returns the value of a token after they have been loaded into memory
#******************************************************************************************
sub Orbit::Get_Token
{
  my ( $self, $Token ) = @_;

  # convert to uppercase before checking
  $Token =~ tr/[a-z]/[A-Z]/;

  if ($self->{_TOKENS}->{$Token}) {
    return $self->{_TOKENS}->{$Token}->getValue;
  }
  return "";
} #Get_Token


#******************************************************************************************
#*  Procedure Name  :   Get_Token_Number
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Returns the number value of a token
#******************************************************************************************
sub Orbit::Get_Token_Number
{
  my ( $self, $Token ) = @_;
  my $U = $self->{_Utils};

  # convert to uppercase before checking
  $Token =~ tr/[a-z]/[A-Z]/;

  if ($self->{_TOKENS}->{$Token}) {
    return $U->GetNumber($self->{_TOKENS}->{$Token}->getValue,0);
  }
  return "";
} #Get_Token_Number


#******************************************************************************************
#*  Procedure Name  :   Get_Token_Raw_Flag
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Returns the raw flag for the token indicating whether the token value
#*                      is in RAW format
#******************************************************************************************
sub Orbit::Get_Token_Raw_Flag
{
  my ( $self, $Token ) = @_;

  # convert to uppercase before checking
  $Token =~ tr/[a-z]/[A-Z]/;

  if ($self->{_TOKENS}->{$Token}) {
    return $self->{_TOKENS}->{$Token}->getRaw;
  }
  return "";
} #Get_Token_Raw_Flag


#******************************************************************************************
#*  Procedure Name  :   Get_Token_Raw
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Returns the Raw Token output with HTML characters escaped
#******************************************************************************************
sub Orbit::Get_Token_Raw
{
  my ( $self, $Token ) = @_;

  # convert to uppercase before checking
  $Token =~ tr/[a-z]/[A-Z]/;

  if ($self->{_TOKENS}->{$Token}) {
    return $self->{_TOKENS}->{$Token}->getRawValue;
  }
  return "";
} #Get_Token_Raw


#******************************************************************************************
#*  Procedure Name  :   Get_Token_Cache_Flag
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Returns the cache flag for the token indicating whether the token
#*                      can be cached
#******************************************************************************************
sub Orbit::Get_Token_Cache_Flag
  #          fv_token                       IN     VARCHAR2
  #         ) RETURN BINARY_INTEGER;
{
  my ( $self, $Token ) = @_;

  # convert to uppercase before checking
  $Token =~ tr/[a-z]/[A-Z]/;

  if ($self->{_TOKENS}->{$Token}) {
    return $self->{_TOKENS}->{$Token}->getCache;
  }
  return "";
} #Get_Token_Cache_Flag


#******************************************************************************************
#*  Procedure Name  :   Get_Token_Rec
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Returns all the columns in the token record
#******************************************************************************************
sub Orbit::Get_Token_Rec
{
  my ( $self, $Token, $Value, $Raw, $Cache ) = @_;

  # convert to uppercase before checking
  $Token =~ tr/[a-z]/[A-Z]/;

  if ($self->{_TOKENS}->{$Token}) {
    return ($self->{_TOKENS}->{$Token}->getValue, $self->{_TOKENS}->{$Token}->getRaw, $self->{_TOKENS}->{$Token}->getCache);
  }
  # Not a valid token
  return ("", "", "");

} #Get_Token_Rec


#******************************************************************************************
#*  Procedure Name  :   Set_Token
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Sets the token name and value in memory ONLY
#*                      If token already exists, it will be udpated
#*                      Set fn_raw_flag to 1 to indicate the token is in RAW format.
#*                      This prevents it from being changed to RAW again with a .RAW modifier
#******************************************************************************************
sub Orbit::Set_Token
{
  my ( $self, $Token, $Value, $bRaw, $bCache ) = @_;
  my $U = $self->{_Utils};

  # convert to uppercase before checking
  $Token =~ tr/[a-z]/[A-Z]/;

  # See if token exists in the array - then update
  if (defined($self->{_TOKENS}->{$Token})) {
    $self->{_TOKENS}->{$Token}->setValue($Value);
    $self->{_TOKENS}->{$Token}->setRaw($bRaw);
    $self->{_TOKENS}->{$Token}->setCache($bCache);
    # Leave since we found token and updated it
    return $Value;
  }

  # Add Token Statistic if turned on
  $self->AddStat("_Tokens: Set_Token") if ($self->GetLogStat());

  # Create the NEW Orbit::Token in the _TOKENS array
  $self->{_TOKENS}->{$Token} = Orbit::Token->new($Token, $Value, $bRaw, $bCache);

  return $Value;
} #Set_Token


#******************************************************************************************
#*  Procedure Name  :   Set_Token_Raw
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Sets the token, storing the value in RAW format
#******************************************************************************************
sub Orbit::Set_Token_Raw
  #          fv_token                       IN     VARCHAR2
  #         ,fv_value                       IN     LONG
  #         ,fn_cache_flag                  IN     BINARY_INTEGER DEFAULT NULL
{
  my ( $self, $Token, $Value, $Cache ) = @_;

  $Value = $self->getRawText($Value);
  $self->Set_Token($Token, $Value, 1, $Cache);

  return $Value;
} #Set_Token_Raw


#******************************************************************************************
#*  Procedure Name  :   Append_Token
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Appends a string to the specified token, using Separator to separate
#******************************************************************************************
sub Orbit::Append_Token
  #          fv_token                       IN     VARCHAR2
  #         ,fv_string                      IN     VARCHAR2
  #         ,fv_line_break                  IN     VARCHAR2  DEFAULT NULL
{
  my ( $self, $Token, $Value, $Separator ) = @_;

  $Separator = "" if (!defined($Separator));

  my $gv_buffer = $self->Get_Token($Token);
  # Only use line break if text is currently set
  if ($gv_buffer ne "") {
    $self->Set_Token($Token, $gv_buffer.$Separator.$Value);
  } else {
    $self->Set_Token($Token, $Value);
  }

  return 0;
} #Append_Token


#******************************************************************************************
#*  Procedure Name  :   Delete_Token
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Deletes the token name and value from memory ONLY
#******************************************************************************************
sub Orbit::Delete_Token
  #          fv_token                       IN     VARCHAR2
{
  my ( $self, $Token ) = @_;

  # convert to uppercase before checking
  $Token =~ tr/[a-z]/[A-Z]/;

  # Delete the token from the hash
  delete($self->{_TOKENS}->{$Token});

  return '';
} #Delete_Token


#******************************************************************************************
#*  Function Name   :   Token_Exists
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Returns TRUE (1) if the Token exists in the hash, (0) if not
#******************************************************************************************
sub Orbit::Token_Exists
{
  my ( $self, $Token ) = @_;

  # convert to uppercase before checking, no other mods
  $Token =~ tr/[a-z]/[A-Z]/;

  if ($self->{_TOKENS}->{$Token}) {
    return 1;
  }

  return 0;
} #Token_Exists


#******************************************************************************************
#*  Function Name   :   isTokenSyntax
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Returns (1) if text is valid Token/Function name syntax, (0) if not
#******************************************************************************************
sub Orbit::isTokenSyntax
{
  my ( $self, $lText ) = @_;

  # blank is not a token, nor CR \n []
  if ( !$lText || $lText eq ""
     || $lText =~ /.*\n.*/         # No CR in token name
     || $lText =~ /.*[ \[\]].*/    # No Space or token tags in token name
     ) {
    return 0;
  }

  # Uppercase token name as convention for searching (case-insensitive when using)
  $lText =~ tr/[a-z]/[A-Z]/;

  # Check for Valid Token characters [A-Z0-9_]
  # if not, not a token.  A space would not be a token
  if (!($lText =~ /^[A-Z0-9_]*$/)) {
    return 0;
  }

  # Valid Token/Function
  return 1;
} #isTokenSyntax


#******************************************************************************************
#*  Function Name   :   isTokenModSyntax
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Returns (1) if text is valid Token.Modifier name syntax, (0) if not
#******************************************************************************************
sub Orbit::isTokenModSyntax
{
  my ( $self, $lText ) = @_;

  # blank is not a token, nor CR \n []
  if ( !$lText || $lText eq ""
     || $lText =~ /.*\n.*/         # No CR in token name
     || $lText =~ /.*[ \[\]].*/    # No Space or token tags in token name
     ) {
    return 0;
  }

  # Uppercase token name as convention for searching (case-insensitive when using)
  $lText =~ tr/[a-z]/[A-Z]/;

  # Check for Valid Token characters [A-Z0-9_.]
  # if not, not a token.  A space would not be a token
  if (!($lText =~ /^[A-Z0-9_\.]*$/)
    || $lText =~ /^\..*$/  # Can't begin with dot
    ) {
    return 0;
  }

  # Valid Token/Function
  return 1;
} #isTokenModSyntax


#******************************************************************************************
#*  Function Name   :   isOMLFunction
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Returns (1) if text is a valid OML Function Name (Orbit Markup Language)
#******************************************************************************************
sub Orbit::isOMLFunction
{
  my ( $self, $lText ) = @_;

  # Token Assignment uses function ASSIGN (without parsing) - #token=ASSIGN[]# #token=[]#
  return 0 if (!defined($lText) || $lText eq "");

  # Uppercase function name for searching
  $lText =~ tr/[a-z]/[A-Z]/;

  # Check for valid syntax first
  return 0 if (!$self->isTokenSyntax($lText));

  # Valid name for a function, now see if it exists in _FUNCTIONS hash
  # Check Function Hash - fast
  return 1 if (defined($self->{_OML_FUNCTIONS}->{$lText}));

  # Valid name for a function, now see if it exists in _FUNCTIONS hash
  # OLD WAY MUCH SLOWER
  #return 1 if (grep(/^$lText$/, %{$self->{_OML_FUNCTIONS}}));

  # NOT a Valid Function
  return 0;
} #isOMLFunction


#******************************************************************************************
#*  Function Name   :   isTokenModifier
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Returns (1) if lText is a valid Token Modifier in OML
#******************************************************************************************
sub Orbit::isTokenModifier
{
  my ( $self, $lText ) = @_;

  # blank is NOT a Token
  return 0 if (!defined($lText) || $lText eq "");

  # Lowercase Token Modifiers for searching
  $lText =~ tr/[A-Z]/[a-z]/;

  # Check for valid Token Modifier syntax first
  if (!$self->isTokenModSyntax("token".$lText)
     || !($lText =~ /^\..*/)  # Must start with a DOT
     ) {
    return 0;
  }

  # Valid name for a function, now see if it exists in _FUNCTIONS hash
  if (grep(/^$lText$/, %{$self->{_TOKEN_MODIFIERS}})) {
    return 1;
  }

  # NOT a Valid Token Modifier
  return 0;
} #isTokenModifier


#******************************************************************************************
#*  Function Name   :   getCGIParam
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Returns the environment variable value
#******************************************************************************************
sub Orbit::getCGIParam
{
  my ( $self, $Param ) = @_;

  my $Value = $self->{_cgi}->param($Param);

  return $Value;
} #getCGIParam


#========================================================================================
# END TOKEN subroutines
#========================================================================================


#========================================================================================
#
#                            UTILITY FUNCTIONS IMPLEMENTATION
#
#========================================================================================


#******************************************************************************************
#*  Procedure Name  :   GetMessageText
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Gets the Message text for a message code in the current version
#*                      This gets the message for the user's default language first,
#*                      then for the country's default language
#*                      If the INSERT_MESSAGES_FLAG token = 1, then new messages will
#*                      be inserted into ORB_MESSAGES if they don't exist.
#*                      If they have not been changed in the table, they will be updated
#******************************************************************************************
sub Orbit::GetMessageText
  #          fv_message_code                IN            VARCHAR2
  #         ,fv_message_text                IN OUT NOCOPY LONG
  #         ,fv_help_text                   IN OUT NOCOPY VARCHAR2
  #         ,fv_comment_text                IN OUT NOCOPY VARCHAR2
{
  my ( $self, $MessageCode, $MessageText, $HelpText, $CommentText ) = @_;

  $MessageCode = "" if (!defined($MessageCode));
  $MessageText = "" if (!defined($MessageText));
  
  if ($MessageText eq "" && $MessageCode ne "") {
    return $MessageCode;
  }
  return $MessageText;
} #GetMessageText


#******************************************************************************************
#*  Procedure Name  :   LoadAccessGroups
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Loads all Access Groups for a user into tokens named SEC_<access_group_code>
#******************************************************************************************
sub Orbit::LoadAccessGroups
{
  my ( $self ) = @_;

  return "CODE";
} #LoadAccessGroups


#******************************************************************************************
#*  Function Name   :   HasAccess
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Returns 1 if the current user has access to the data specified
#*                      Returns 0 if the user is specifically denied access, but not personally
#*                      Returns 2 if the user has VIEW ONLY access to the page
#******************************************************************************************
sub Orbit::HasAccess
{
  my ( $self, $Root, $Object, $Page, $Action, $Word ) = @_;
  my $U = $self->{_Utils};

  # leave if user isn't defined
  return 0 if ($self->{_User} eq "");

  my $Access = "";

  # Check for buffered Access
  if ( $Root eq $self->{_Root}
    && $Object eq $self->{_Object}
    && $Page eq $self->{_Page}
    && $Action eq $self->{_Action}
    && $Word eq $self->{_Word}
    && $self->{_Access} ne ""
    ) {
    $Access = $self->{_Access};
  }

  #
  # Get User Access File: ACCESS.dat usually
  #
  #
  if ($self->{_Access} ne $Access) {
    my $AccessFile = $self->GetUserDir().$self->{_Data}->{'_ACCESS'};
    $Access = $U->GetFile($AccessFile);
  }

  $self->{_Access} = $Access;
  
  #
  # Check input parameters against access records
  #
  #######
  #######  CODE TO WRITE
  #######
  
  return 1;
} #HasAccess


#******************************************************************************************
#*  Function Name   :   GetUser
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Returns the User name - Set Externally
#******************************************************************************************
sub Orbit::GetUser
{
  my ( $self ) = @_;
  return $self->{_User};
} #GetUser


#******************************************************************************************
#*  Function Name   :   SetUser
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Sets 
#******************************************************************************************
sub Orbit::SetUser
{
  my ( $self, $User, $UserDir ) = @_;

  $User    = ""                       if (!defined($User));
  # Default User Directory to _UserDirDefault if not specified (ie ./_ORBIT/USERS/#user#/ACCESS.dat)
  $UserDir = $self->{_UserDirDefault} if (!defined($UserDir) || $UserDir eq "" || $UserDir eq '.');

  # Make sure User exists
  if ($User eq "") {
    $self->Uprint("SetUser: Error: No User. User Directory: [$UserDir]\n");
    return 1;
  }

  # Make sure User exists
  if (!-d $UserDir) {
    $self->Uprint("SetUser: Error: User Directory does not exist: [$UserDir]\n");
    return 1;
  }
  
  # Reset User and UserDir - this is where ACCESS.dat is stored, among other settings
  $self->{_User} = $User;
  $self->{_UserDir} = $UserDir;
  return 0;   # Successful
} #SetUser


#******************************************************************************************
#*  Function Name   :   GetUserDir
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Returns the User directory location - Set Externally
#******************************************************************************************
sub Orbit::GetUserDir
{
  my ( $self ) = @_;
  return $self->{_UserDir};
} #GetUserDir


#******************************************************************************************
#*  Function Name   :   SetUserDir
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Sets the internal UserDir to that specified - Set Externally
#*                      Used for access to ACCESS.dat and other user settings
#******************************************************************************************
sub Orbit::SetUserDir
{
  my ( $self, $UserDir ) = @_;
  
  # Make sure UserDir exists
  if (!-d $UserDir) {
    $self->Uprint("SetUserDir: Error: User Directory does not exist: [$UserDir]\n");
    return 1;
  }
  
  # Reset UserDir - this is where ACCESS.dat is stored, among other settings
  $self->{_UserDir} = $UserDir;
  return 0;   # Successful
} #SetUserDir


#******************************************************************************************
#*  Function Name   :   GetDatabaseName
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Returns the database name from v$database
#******************************************************************************************
sub Orbit::GetDatabaseName
{
  my ( $self ) = @_;
  return "" if (!defined($self->{_DomainDir}));
  return $self->{_Domain}.':'.$self->{_DomainDir};
} #GetDatabaseName


#******************************************************************************************
#*  Function Name   :   GetColumnNames
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Sets the _COLUMNS array from a delimited list of column names
#******************************************************************************************
sub Orbit::GetColumnNames
{
  my ( $self, $lHeaders ) = @_;
  use Core::Search;

  my $U = $self->{_Utils};

  #
  # RESET the Column Headers if nothing passed in
  #
  if (!defined($lHeaders) || $lHeaders eq "") {
    undef $self->{_COLUMNS};
    $self->{_COLUMNS} = {};
    return "";
  }

  my @arrR;

  # Find the delimiter in the headers
  my $delim = $U->GetDelimiters($lHeaders);

  @arrR = split(/$delim/, $lHeaders);

  #
  # Set the Orbit class Columns array
  #
  my $i=0;
  foreach my $col (@arrR) {
    $i++;
    $self->{_COLUMNS}->{$i} = $col;
  }
  undef @arrR;

} #GetColumnNames


#******************************************************************************************
#*  Function Name   :   TransactionID
#*
#*  Scope           :   PRIVATE
#*
#*  Description     :   Returns a unique transaction ID.  Used in #TRANSACTION_ID[]# function
#******************************************************************************************
sub Orbit::TransactionID
{
  my ( $self ) = @_;

  my ( $Sec,$Min,$Hour, $MonthDay,$Month,$Year, $WeekDay,$YearDay,$IsDST) = localtime();
  my $id = sprintf("%d%02d%02d%02d%02d%02d"
                    ,$Year+1900, $Month+1, $MonthDay
                    ,$Hour, $Min, $Sec);

  # Get the milliseconds
  use Time::HiRes qw(time);
  # Log the start Time
  my $Time = time();
  my $ms = $Time*1000 - int($Time*1000);
  my $ms3 = sprintf("%03d", $ms);
  
  # Add milliseconds to date time
  $id .= $ms3;

  # If user is present, add that as well
  $id .= '_'.$self->{_User} if ($self->{_User} ne '');

  
  return $id;

} #TransactionID


#========================================================================================
# END UTILITY FUNCTIONS IMPLEMENTATION
#========================================================================================


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::Utils;
#******************************************************************************************
1;


#END Orbit::Utils Package
