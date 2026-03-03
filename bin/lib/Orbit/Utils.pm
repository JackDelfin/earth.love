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
#   2025.05.29 oK - Use 3 digit random number at end of Transaction ID
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
# Functions Supported
#*****************************************
#-----------------------------------------
# Utility Message Subroutines
#-----------------------------------------
#
# RegisterError
#   - Sets the ERROR_TEXT token to the specified string
# RegisterSuccess
#   - Sets the SUCCESS_TEXT token to the specified string
# RegisterMessage
#   - Sets the MESSAGE_TEXT token to the specified string
# AppendError
#   - Appends a string to the ERROR_TEXT token, using Separator to separate
# AppendSuccess
#   - Appends a string to the SUCCESS_TEXT token, using Separator to separate
# AppendMessage
#   - Appends a string to the MESSAGE_TEXT token, using Separator to separate
# SetHeaderMessage [Text]
#   - Sets the HEADER_MESSAGE global token to be a combination of:
#     ERROR_TEXT, MESSAGE_TEXT, or SUCCESS_TEXT, whichever is set
#   - The PROMPT_ERROR and PROMPT_SUCCESS tokens will be used if set
#   - Optionally take a Message argument and set as Message Text
#
#-----------------------------------------
# Utility Functions
#-----------------------------------------
#
# GetDatabaseName
#   - Returns the database name from the internal Domain and Domain Dir
#
# GetColumnNames <Headers>
#   - Sets the _COLUMNS array from a delimited list of column names in Headers
#
# TransactionID
#   - Returns a unique transaction ID.  Used in #TRANSACTION_ID[]# function
#
# IsNumber <text>
#   - Determines if string is a valid number.  NULL is NOT a number
#
#*****************************************************************************************
package Orbit;   # Continuation of Orbit package

use strict;
use warnings;
use utf8;
use feature ':5.16';

# Orbit packages
#use Core::Utils;
#use Core::Numbers;
#use Core::Math;
#use Core::Search;
#use Core::Strings;
#use Orbit::Token;


#******************************************************************************************
#*  Procedure Name  :   RegisterError
#*
#*  Description     :   Sets the ERROR_TEXT token to the specified string
#******************************************************************************************
sub Orbit::RegisterError
{
  my ( $self, $String ) = @_;

  $self->Set_Token('ERROR_TEXT', $String);
} #RegisterError


#******************************************************************************************
#*  Procedure Name  :   RegisterSuccess
#*
#*  Description     :   Sets the SUCCESS_TEXT token to the specified string
#******************************************************************************************
sub Orbit::RegisterSuccess
{
  my ( $self, $String ) = @_;

  $self->Set_Token('SUCCESS_TEXT', $String);
} #RegisterSuccess


#******************************************************************************************
#*  Procedure Name  :   RegisterMessage
#*
#*  Description     :   Sets the MESSAGE_TEXT token to the specified string
#******************************************************************************************
sub Orbit::RegisterMessage
{
  my ( $self, $String ) = @_;

  $self->Set_Token('MESSAGE_TEXT', $String);
} #RegisterMessage


#******************************************************************************************
#*  Procedure Name  :   AppendError
#*
#*  Description     :   Appends a string to the ERROR_TEXT token, using Separator to separate
#******************************************************************************************
sub Orbit::AppendError
{
  my ( $self, $String, $Separator ) = @_;
  $Separator = "<br>\n" if (!defined($Separator));
  $self->Append_Token('ERROR_TEXT', $String, $Separator);
} #AppendError


#******************************************************************************************
#*  Procedure Name  :   AppendSuccess
#*
#*  Description     :   Appends a string to the SUCCESS_TEXT token, using Separator to separate
#******************************************************************************************
sub Orbit::AppendSuccess
{
  my ( $self, $String, $Separator ) = @_;
  $Separator = "<br>\n" if (!defined($Separator));
  $self->Append_Token('SUCCESS_TEXT', $String, $Separator);
} #AppendSuccess


#******************************************************************************************
#*  Procedure Name  :   AppendMessage
#*
#*  Description     :   Appends a string to the MESSAGE_TEXT token, using Separator to separate
#******************************************************************************************
sub Orbit::AppendMessage
{
  my ( $self, $String, $Separator ) = @_;
  $Separator = "<br>\n" if (!defined($Separator));
  $self->Append_Token('MESSAGE_TEXT', $String, $Separator);
} #AppendMessage


#******************************************************************************************
#* SetHeaderMessage [Text]
#*
#* - Sets the HEADER_MESSAGE global token to be a combination of:
#*   ERROR_TEXT, MESSAGE_TEXT, or SUCCESS_TEXT, whichever is set
#* - The PROMPT_ERROR and PROMPT_SUCCESS tokens will be used if set
#* - Optionally take a Message argument and set as Message Text
#******************************************************************************************
sub Orbit::SetHeaderMessage
{
  my ( $self, $Text ) = @_;
  $Text = "" if (!defined($Text));

  #-- First reset the header message
  $self->Set_Token('HEADER_MESSAGE', "");
  #-- Get the ERROR_TEXT
  my $gv_buffer = $self->Get_Token('ERROR_TEXT');
  if ($gv_buffer ne "") {
    $self->Append_Token('HEADER_MESSAGE',
        '#PROMPT_ERROR#'.
        '<B><I>'.$gv_buffer.'</I></B>');
  }
  #-- Get the MESSAGE_TEXT
  $gv_buffer = $self->Get_Token('MESSAGE_TEXT').$Text;
  if ($gv_buffer ne "") {
    $self->Append_Token('HEADER_MESSAGE',
        '<B><I>'.$gv_buffer.'</I></B>');
  }
  #-- Get the SUCCESS_TEXT
  $gv_buffer = $self->Get_Token('SUCCESS_TEXT');
  if ($gv_buffer ne "") {
    $self->Append_Token('HEADER_MESSAGE',
        '#PROMPT_SUCCESS#'.
        '<B><I>'.$gv_buffer.'</I></B>');
  }

  return 0;
} #SetHeaderMessage


#========================================================================================
#
#                            UTILITY FUNCTIONS IMPLEMENTATION
#
#========================================================================================


#******************************************************************************************
# GetDatabaseName
#
# - Returns the database name from the internal Domain and Domain Dir
#******************************************************************************************
sub Orbit::GetDatabaseName
{
  my ( $self ) = @_;
  return "" if (!defined($self->{_DomainDir}));
  return $self->{_Domain}.':'.$self->{_DomainDir};
} #GetDatabaseName


#******************************************************************************************
# GetColumnNames <Headers>
#
# - Sets the _COLUMNS array from a delimited list of column names in Headers
#******************************************************************************************
sub Orbit::GetColumnNames
{
  my ( $self, $Headers ) = @_;
  use Core::Search;

  my $U = $self->{_Utils};

  #
  # RESET the Column Headers if nothing passed in
  #
  if (!defined($Headers) || $Headers eq "") {
    undef $self->{_COLUMNS};
    $self->{_COLUMNS} = {};
    return 0;
  }

  my @arrR;

  # Find the delimiter in the headers
  my $delim = $U->GetDelimiters($Headers);

  # Check for Delimiter
  # None means just one Header column
  if ($delim eq "") {
    # Set one column header and return
    $self->{_COLUMNS}->{0} = $Headers;
    return 0;
  }

  @arrR = split(/$delim/, $Headers);

  #
  # Set the Orbit class Columns array
  #
  my $i=0;
  foreach my $col (@arrR) {
    $i++;
    $self->{_COLUMNS}->{$i} = $col;
  }
  undef @arrR;
  return 0;
} #GetColumnNames


#******************************************************************************************
# TransactionID
#
# - Returns a unique transaction ID.  Used in #TRANSACTION_ID[]# function
#******************************************************************************************
sub Orbit::TransactionID
{
  my ( $self ) = @_;

  my ( $Sec,$Min,$Hour, $MonthDay,$Month,$Year, $WeekDay,$YearDay,$IsDST) = localtime();
  # Use 3 digit random number at end of Transaction ID since milliseconds is not returning
  my $id = sprintf("%d%02d%02d%02d%02d%02d%03d"
                    ,$Year+1900, $Month+1, $MonthDay
                    ,$Hour, $Min, $Sec, int(rand(999)));

  # Get the milliseconds - not working - use RANDOM instead
  #use Time::HiRes qw(time);
  # Log the start Time
  #my $Time = time();
  #my $ms = $Time*1000 - int($Time*1000);
  #my $ms3 = sprintf("%03d", $ms);
  
  # Add milliseconds to date time
  #$id .= $ms3;

  # If user is present, add that as well
  $id .= '_'.$self->{_User} if ($self->{_User} ne '');
  
  return $id;
} #TransactionID


#******************************************************************************************
# IsNumber <text>
#
# - Determines if string is a valid number. NULL is NOT a number
#******************************************************************************************/
sub Orbit::IsNumber
{
  my ( $self, $String ) = @_;
  # Null is not a number
  return 0 if (!defined($String) || $String eq "");
  return ($String =~ /^[-]*[0-9]*[\.]*[0-9]*$/)?1:0;
} #IsNumber


#========================================================================================
# END UTILITY FUNCTIONS IMPLEMENTATION
#========================================================================================


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::Utils;
#******************************************************************************************
1;


#END Orbit::Utils Package
