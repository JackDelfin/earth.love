#!/usr/bin/perl
# Version 7.0.0.0      01-Jul-2021
#*****************************************************************************************
#*
#*  Package Name    :   Orbit::Tokens
#*
#*  Description     :   Implements Token Access Utility Functions within Orbit
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
# Functions Supported
#*****************************************
#-----------------------------------------
# Token Subroutines
#-----------------------------------------
#
# GetToken / Get_Token
#   - Returns the value of a token after they have been loaded into memory
# GetTokenNumber
#   - Returns the number value of a token
# GetTokenRawFlag
#   - Returns the raw flag for the token indicating whether the token value is in RAW format
# GetTokenRaw
#   - Returns the Raw Token output with HTML characters escaped
# GetTokenCacheFlag
#   - Returns the cache flag for the token indicating whether the token can be cached
# GetTokenRecursiveFlag
#   - Returns whether OML in the token value may be parsed recursively
# GetTokenRec
#   - Returns all the columns in the token record
#
# SetToken / Set_Token
#   - Sets the token name and value in memory ONLY
#   - If token already exists, it will be udpated
#   - Set fn_raw_flag to 1 to indicate the token is in RAW (.HTML) format.
#   - This prevents it from being changed to RAW again with a .RAW modifier
# SetTokenRaw
#   - Sets the token, storing the value in RAW format
# SetUntrustedToken
#   - Sets a request/environment-derived token that must remain non-recursive
#
# AppendToken / Append_Token
#   - Appends a string to the specified token, using Separator to separate
#
# DeleteToken / Delete_Token
#   - Deletes the token name and value from memory ONLY
#
# TokenExists
#   - Returns TRUE (1) if the Token exists in the hash, (0) if not
#
# isTokenSyntax
#   - Returns (1) if text is valid Token/Function name syntax, (0) if not
# isTokenModSyntax
#   - Returns (1) if text is valid Token.Modifier name syntax, (0) if not
# isTokenModifier
#   - Returns (1) if lText is a valid Token Modifier in OML
#
#-----------------------------------------
# CGI Subroutines
#-----------------------------------------
#
# getCGIParam
#   - Returns the CGI environment variable value
#
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
#*  Procedure Name  :   GetToken / Get_Token
#*
#*  Description     :   Returns the value of a token after they have been loaded into memory
#******************************************************************************************
sub Orbit::GetToken
{
  my ( $self, $Token ) = @_;

  # convert to uppercase before checking
  $Token =~ tr/[a-z]/[A-Z]/;

  if ($self->{_TOKENS}->{$Token}) {
    return $self->{_TOKENS}->{$Token}->getValue;
  }
  return "";
} #GetToken
*Get_Token = \&GetToken;


#******************************************************************************************
#*  Procedure Name  :   GetTokenNumber
#*
#*  Description     :   Returns the number value of a token
#******************************************************************************************
sub Orbit::GetTokenNumber
{
  my ( $self, $Token ) = @_;
  my $U = $self->{_Utils};

  # convert to uppercase before checking
  $Token =~ tr/[a-z]/[A-Z]/;

  if ($self->{_TOKENS}->{$Token}) {
    return $U->GetNumber($self->{_TOKENS}->{$Token}->getValue,0);
  }
  return "";
} #GetTokenNumber


#******************************************************************************************
#*  Procedure Name  :   GetTokenRawFlag
#*
#*  Description     :   Returns the raw flag for the token indicating whether the token value
#*                      is in RAW format
#******************************************************************************************
sub Orbit::GetTokenRawFlag
{
  my ( $self, $Token ) = @_;

  # convert to uppercase before checking
  $Token =~ tr/[a-z]/[A-Z]/;

  if ($self->{_TOKENS}->{$Token}) {
    return $self->{_TOKENS}->{$Token}->getRaw;
  }
  return "";
} #GetTokenRawFlag


#******************************************************************************************
#*  Procedure Name  :   GetTokenRaw
#*
#*  Description     :   Returns the Raw Token output with HTML characters escaped
#******************************************************************************************
sub Orbit::GetTokenRaw
{
  my ( $self, $Token ) = @_;

  # convert to uppercase before checking
  $Token =~ tr/[a-z]/[A-Z]/;

  if ($self->{_TOKENS}->{$Token}) {
    return $self->{_TOKENS}->{$Token}->getRawValue;
  }
  return "";
} #GetTokenRaw


#******************************************************************************************
#*  Procedure Name  :   GetTokenCacheFlag 
#*
#*  Description     :   Returns the cache flag for the token indicating whether the token
#*                      can be cached
#******************************************************************************************
sub Orbit::GetTokenCacheFlag
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
} #GetTokenCacheFlag


#******************************************************************************************
#*  Procedure Name  :   GetTokenRecursiveFlag
#*
#*  Description     :   Returns 1 only when a token may be parsed recursively.  Missing
#*                      tokens fail closed and return 0.
#******************************************************************************************
sub Orbit::GetTokenRecursiveFlag
{
  my ( $self, $Token ) = @_;

  $Token = '' if (!defined($Token));
  $Token =~ tr/[a-z]/[A-Z]/;

  if ($self->{_TOKENS}->{$Token}) {
    return $self->{_TOKENS}->{$Token}->getRecursive ? 1 : 0;
  }
  return 0;
} #GetTokenRecursiveFlag


#******************************************************************************************
#*  Procedure Name  :   GetTokenRec
#*
#*  Description     :   Returns all the columns in the token record
#******************************************************************************************
sub Orbit::GetTokenRec
{
  my ( $self, $Token, $Value, $Raw, $Cache, $Recursive ) = @_;

  # convert to uppercase before checking
  $Token =~ tr/[a-z]/[A-Z]/;

  if ($self->{_TOKENS}->{$Token}) {
    return ($self->{_TOKENS}->{$Token}->getValue, $self->{_TOKENS}->{$Token}->getRaw, $self->{_TOKENS}->{$Token}->getCache, $self->{_TOKENS}->{$Token}->getRecursive);
  }
  # Not a valid token
  return ("", "", "", "");

} #GetTokenRec


#******************************************************************************************
#*  Procedure Name  :   SetToken / Set_Token
#*
#*  Description     :   Sets the token name and value in memory ONLY
#*                      If token already exists, it will be udpated
#*                      Set fn_raw_flag to 1 to indicate the token is in RAW format.
#*                      This prevents it from being changed to RAW again with a .RAW modifier
#******************************************************************************************
sub Orbit::SetToken
{
  my ( $self, $Token, $Value, $bRaw, $bCache, $bRecursive ) = @_;
  my $U = $self->{_Utils};

  # convert to uppercase before checking
  $Token =~ tr/[a-z]/[A-Z]/;

  # See if token exists in the array - then update
  if (defined($self->{_TOKENS}->{$Token})) {
    $self->{_TOKENS}->{$Token}->setValue($Value);
    $self->{_TOKENS}->{$Token}->setRaw($bRaw);
    $self->{_TOKENS}->{$Token}->setCache($bCache);
    # An ordinary update must not accidentally promote request-derived data back
    # to recursive OML.  Promotion requires an explicit recursive flag.
    $self->{_TOKENS}->{$Token}->setRecursive($bRecursive) if defined($bRecursive);
    # Leave since we found token and updated it
    return $Value;
  }

  # Add Token Statistic if turned on
  $self->AddStat("_Tokens: Set_Token") if ($self->GetLogStat());

  # Create the NEW Orbit::Token in the _TOKENS array
  $self->{_TOKENS}->{$Token} = Orbit::Token->new($Token, $Value, $bRaw, $bCache, $bRecursive);

  return $Value;
} #Set_Token
*Set_Token = \&SetToken;


#******************************************************************************************
#*  Procedure Name  :   SetUntrustedToken / Set_Untrusted_Token
#*
#*  Description     :   Stores request/environment-derived text without permitting its
#*                      contents to become executable OML during recursive token parsing.
#******************************************************************************************
sub Orbit::SetUntrustedToken
{
  my ( $self, $Token, $Value, $bRaw, $bCache ) = @_;
  return $self->SetToken($Token, $Value, $bRaw, $bCache, 0);
} #SetUntrustedToken
*Set_Untrusted_Token = \&SetUntrustedToken;


#******************************************************************************************
#*  Procedure Name  :   SetTrustedToken / Set_Trusted_Token
#*
#*  Description     :   Explicitly promotes an internally generated token value when a
#*                      caller intentionally needs historical recursive OML expansion.
#******************************************************************************************
sub Orbit::SetTrustedToken
{
  my ( $self, $Token, $Value, $bRaw, $bCache ) = @_;
  return $self->SetToken($Token, $Value, $bRaw, $bCache, 1);
} #SetTrustedToken
*Set_Trusted_Token = \&SetTrustedToken;


#******************************************************************************************
#*  Procedure Name  :   SetTokenRaw
#*
#*  Description     :   Sets the token, storing the value in RAW format
#******************************************************************************************
sub Orbit::SetTokenRaw
  #          fv_token                       IN     VARCHAR2
  #         ,fv_value                       IN     LONG
  #         ,fn_cache_flag                  IN     BINARY_INTEGER DEFAULT NULL
{
  my ( $self, $Token, $Value, $Cache ) = @_;

  $Value = $self->getRawText($Value);
  $self->Set_Token($Token, $Value, 1, $Cache);

  return $Value;
} #SetTokenRaw


#******************************************************************************************
#*  Procedure Name  :   AppendToken / Append_Token
#*
#*  Description     :   Appends a string to the specified token, using Separator to separate
#******************************************************************************************
sub Orbit::AppendToken
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
} #AppendToken
*Append_Token = \&AppendToken;


#******************************************************************************************
#*  Procedure Name  :   DeleteToken / Delete_Token
#*
#*  Description     :   Deletes the token name and value from memory ONLY
#******************************************************************************************
sub Orbit::DeleteToken
  #          fv_token                       IN     VARCHAR2
{
  my ( $self, $Token ) = @_;

  # convert to uppercase before checking
  $Token =~ tr/[a-z]/[A-Z]/;

  # Delete the token from the hash
  delete($self->{_TOKENS}->{$Token});

  return '';
} #DeleteToken
*Delete_Token = \&DeleteToken;


#******************************************************************************************
#*  Function Name   :   TokenExists
#*
#*  Description     :   Returns TRUE (1) if the Token exists in the hash, (0) if not
#******************************************************************************************
sub Orbit::TokenExists
{
  my ( $self, $Token ) = @_;

  # convert to uppercase before checking, no other mods
  $Token =~ tr/[a-z]/[A-Z]/;

  if ($self->{_TOKENS}->{$Token}) {
    return 1;
  }

  return 0;
} #TokenExists


#******************************************************************************************
#*  Function Name   :   isTokenSyntax
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
#*  Function Name   :   isTokenModifier
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
#* getCGIParam
#*
#* - Returns the CGI environment variable value
#******************************************************************************************
sub Orbit::getCGIParam
{
  my ( $self, $Param ) = @_;

  my $Value = $self->{_cgi}->param($Param);

  return $Value;
} #getCGIParam


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::Tokens;
#******************************************************************************************
1;


#END Orbit::Tokens Package
