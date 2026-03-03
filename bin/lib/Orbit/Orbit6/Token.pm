#!/usr/bin/perl
# Version 6.0.6.0      21-May-2021
#*****************************************************************************************
#*
#*  Package Name    :   Orbit::Token
#*
#*  Description     :   Implements the Token Class for Orbit
#*
#*****************************************************************************************
# History:
#   2021.04.24 earth.love oK Created
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
package Orbit::Token;

use strict;
use warnings;
use utf8;
use feature ':5.16';

#========================================================================================
#
#                 PUBLIC FUNCTIONS / PROCEDURES
#
#========================================================================================


#******************************************************************************************
#*  Procedure Name  :   new
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Initializes the Orbit::Token package
#******************************************************************************************
sub Orbit::Token::new
{
  my $class = shift;   # class is the name of this package: Orbit::Token
  # Define the token structure (class variables)
  my $self = {
     _Name   => shift,   #token_name        VARCHAR2(8000)
     _Value  => shift,   #token_value       LONG
     _bRaw   => shift,   #raw_flag          BINARY_INTEGER
     _bCache => shift,   #cache_flag        BINARY_INTEGER
  };

  # Bless makes these variables available externally
  bless $self, $class;

  # Standardize the token parts
  $self->setName($self->{_Name});
  $self->setValue($self->{_Value});
  $self->setRaw($self->{_Raw});
  $self->setCache($self->{_Cache});

  return $self;
} #new


#******************************************************************************************
# Get/Set routines
#******************************************************************************************


#******************************************************************************************
# setName
#******************************************************************************************
sub Orbit::Token::setName {
  my ( $self, $Name ) = @_;
  $self->{_Name} = $Name if defined($Name);

  # Standardize the Token Name
  $self->checkName;

  return $self->{_Name};
} #setName
#******************************************************************************************
# getName
#******************************************************************************************
sub Orbit::Token::getName {
  my( $self ) = @_;
  return $self->{_Name};
} #getName
#******************************************************************************************
# checkName
# - Make sure a token name is valid
# - Token names are like variable names, but uppercase with underscore (_)
#******************************************************************************************
sub Orbit::Token::checkName {
  my ( $self ) = @_;

  # An unspecified Token Name is UNDEFINED
  $self->{_Name} = 'UNDEFINED' if (!defined($self->{_Name}) || $self->{_Name} eq "");
  # Uppercase token name as convention for searching (case-insensitive when using)
  $self->{_Name} =~ tr/[a-z]/[A-Z]/;
  # Also replace spaces with underscore _
  $self->{_Name} =~ tr/ /_/;

  # Check for Valid Token characters [A-Z0-9_]
  # Developers should be the only ones to see this message
  #
  if (!($self->{_Name} =~ /^[A-Z0-9_]*$/)) {
    return "Bad Token Name: Only [A-Z0-9_] [".$self->{_Name}."]\n";
  }

  return $self->{_Name};
} #checkName

#******************************************************************************************
# setValue
#******************************************************************************************
sub Orbit::Token::setValue {
  my ( $self, $Value ) = @_;
  $self->{_Value} = $Value if defined($Value);
  # Initialize Value if not specified
  $self->{_Value}  = '' if (!defined($self->{_Value}));
  return $self->{_Value};
} #SetValue
#******************************************************************************************
# getValue
#******************************************************************************************
sub Orbit::Token::getValue {
  my( $self ) = @_;
  return $self->{_Value};
} #getValue
#******************************************************************************************
# getRawValue
# - Replaces the characters &<>#" with HTML escaped characters
#******************************************************************************************
sub Orbit::Token::getRawValue {
  my( $self ) = @_;

  my $Text = $self->{_Value};

  $Text =~ s/&/&amp;/g;
  $Text =~ s/</&lt;/g;
  $Text =~ s/>/&gt;/g;
  $Text =~ s/#/&#035;/g;
  $Text =~ s/"/&quot;/g;

  return $Text;
} #getRawValue


#******************************************************************************************
# setRaw
#******************************************************************************************
sub Orbit::Token::setRaw {
  my ( $self, $bRaw ) = @_;
  $self->{_bRaw} = $bRaw if defined($bRaw);
  # Default to 0 if not specified
  $self->{_bRaw} = 0 if (!defined($self->{_bRaw}) || !($self->{_bRaw} =~ /^[01]$/));  # Make sure bRaw is boolean 0/1
  return $self->{_bRaw};
} #setRaw
#******************************************************************************************
# getRaw
#******************************************************************************************
sub Orbit::Token::getRaw {
  my( $self ) = @_;
  return $self->{_bRaw};
} #getRaw


#******************************************************************************************
# setCache
#******************************************************************************************
sub Orbit::Token::setCache {
  my ( $self, $bCache ) = @_;
  $self->{_bCache} = $bCache if defined($bCache);
  # Default to 0 if not specified
  $self->{_bCache} = 0 if (!defined($self->{_bCache}) || !($self->{_bCache} =~ /^[01]$/));  # Make sure bCache is boolean 0/1
  return $self->{_bCache};
} #setCache
#******************************************************************************************
# getCache
#******************************************************************************************
sub Orbit::Token::getCache {
  my( $self ) = @_;
  return $self->{_bCache};
} #getCache


#******************************************************************************************
# print - print the token values
# - bPrint 1 - Prints the value; 0 - returns value only, no print
#******************************************************************************************
sub Orbit::Token::print {
  my( $self, $bPrint ) = @_;
  $bPrint = 1 if (!defined($bPrint)|| $bPrint ne '0');
  my $msg = "Token:[".$self->{_Name}."][".$self->{_Value}."][".$self->{_bRaw}."][".$self->{_bCache}."]\n";
  print $msg if ($bPrint);
  return $msg;
} #print


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::Token;
#******************************************************************************************
1;


#END Orbit::Token
