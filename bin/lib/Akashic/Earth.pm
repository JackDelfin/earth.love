#!/usr/bin/perl
# Version 1.0.1.0      21-May-2021
#*******************************************************************************
#
# Akashic::Earth.pm - Additions to the Akashic class for earth.love requirements
#
#*******************************************************************************
# History:
#   2021.05.21 earth.love oK Created
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
# earth.love support functions
#----------------------------------------#
#
# GetEarthDomain <Root> <text>
# - Returns the FIRST earth domain associated with the word based on a pecking
#   order, for domains stored in the PATHS structure.
#
# ShowEarthDomains <Root> <text>
# - Shows all words in the line that have a corresponding domain name,
#   stored in the PATHS structure, for all of the e:POP earth domains
#
#*******************************************************************************
package Akashic;

use strict;
use warnings;
use utf8;
use feature ':5.16';

#
# Load Akashic core from Data perspective
#
use Akashic::Data;


################################################################################
#
# GetEarthDomain <Root> <text>
#
# - Returns the FIRST earth domain associated with the word based on a pecking
#   order, for domains stored in the PATHS structure.
#
#   Checks TLD's in the following order:
#     .EARTH s.EARTH es.EARTH .EARTH.LOVE .LIFE .LOVE .LAND .WORLD .SPACE
#     101.Earth|Life|Love|Land|World|Space
#     DIG.com DIG.earth
#
# - Only One corresponding domain name will be returned, in Mixed Case if available
#
# Ex)  line => "words word god food science"
# Output:
#   Words.earth
#   Word.earth.love
#   God.earth
#   Food.love
#   Science101.earth
#
################################################################################
sub Akashic::GetEarthDomain
{
  my ( $self, $Root, $line ) = @_;

  # Perform standard trim operations (remove \n, multiple spaces, begin/end spaces)
  $line = $self->StandardLineTrim($line);

  # Remove punctuation not used for indexing, returning
  # a space separated list of words without punctuation,
  # suitable for creating a directory tree with the words
  $line = $self->ReplaceLinePunctuation($line, ' ');

  # Compress: Change multiple spaces to single and create an array
  $line =~ s/ [ ]*/ /g;   # Change multiple spaces to a single space
  $line =~ s/ $//g;  # Trim end space
  $line =~ s/^ //g;  # Trim beginning space

  # Change line to lowercase to index words.
  $line =~ tr/[A-Z]/[a-z]/;

  # Next iteration if line is blank (skip the rest of the loop)
  return 0 if ($line eq "");

  # Create the array with the split function based on space between words
  my @words = split(' ', $line);
  my $w="";

  # Process each word in the @words array and add it to library
  foreach my $w (@words)
  {
    if      ($self->FindPath($Root, $w.'.earth')) {
      return $w.".earth\n";
    } elsif ($self->FindPath($Root, $w.'s.earth')) {   # check for plural"s"
      return $w."s.earth\n";
    } elsif ($self->FindPath($Root, $w.'es.earth')) {   # check for plural"es"
      return $w."es.earth\n";
    } elsif ($self->FindPath($Root, $w.'.earth.love')) {   # check for .earth.love subdomain
      return $w.".earth.love\n";
    } elsif ($self->FindPath($Root, $w.'.life')) {
      return $w.".life\n";
    } elsif ($self->FindPath($Root, $w.'.love')) {
      return $w.".love\n";
    } elsif ($self->FindPath($Root, $w.'.land')) {
      return $w.".land\n";
    } elsif ($self->FindPath($Root, $w.'.world')) {
      return $w.".world\n";
    } elsif ($self->FindPath($Root, $w.'.space')) {
      return $w.".space\n";
    } elsif ($self->FindPath($Root, $w.'101.earth')) {
      return $w."101.earth\n";
    } elsif ($self->FindPath($Root, $w.'101.life')) {
      return $w."101.life\n";
    } elsif ($self->FindPath($Root, $w.'101.love')) {
      return $w."101.love\n";
    } elsif ($self->FindPath($Root, $w.'101.land')) {
      return $w."101.land\n";
    } elsif ($self->FindPath($Root, $w.'101.space')) {
      return $w."101.space\n";
    } elsif ($self->FindPath($Root, $w.'101.world')) {
      return $w."101.world\n";
    } elsif ($self->FindPath($Root, $w.'DIG.com')) {   # check for DIG site @com
      return $w."DIG.com\n";
    } elsif ($self->FindPath($Root, $w.'.DIG.earth')) {   # check for DIG.earth site
      return $w.".DIG.earth\n";
    }   # else word not found
  }
  undef @words; # Clear array to free up memory
} #GetEarthDomain


################################################################################
#
# ShowEarthDomains <Root> <text>
#
# - Shows all words in the line that have a corresponding domain name,
#   stored in the PATHS structure, for all of the e:POP earth domains
# - Only look in Root specified
#
#   Checks TLD's in the following order:
#     .EARTH s.EARTH es.EARTH .EARTH.LOVE .LIFE .LOVE .LAND .WORLD .SPACE
#     101.Earth|Life|Love|Land|World|Space
#     DIG.com DIG.earth
#
# - ALL Corresponding domain name(s) will be printed, in Mixed Case if available
# - Great tool for finding KEYWORDS with websites in text data
#
# Ex)  line => "words word god food science"
# Output:
#   words.earth
#   word.earth.love
#   god.earth
#   food.love
#   Science101.earth
#
################################################################################
sub Akashic::ShowEarthDomains
{
  my ( $self, $Root, $line ) = @_;

  # Perform standard trim operations (remove \n, multiple spaces, begin/end spaces)
  $line = $self->StandardLineTrim($line);

  # Remove punctuation not used for indexing, returning
  # a space separated list of words without punctuation,
  # suitable for creating a directory tree with the words
  $line = $self->ReplaceLinePunctuation($line, ' ');

  # Compress: Change multiple spaces to single and create an array
  $line =~ s/ [ ]*/ /g;   # Change multiple spaces to a single space
  $line =~ s/ $//g;  # Trim end space
  $line =~ s/^ //g;  # Trim beginning space

  # Change line to lowercase to index words.
  $line =~ tr/[A-Z]/[a-z]/;

  # Next iteration if line is blank (skip the rest of the loop)
  return 0 if ($line eq "");

  # Create the array with the split function based on space between words
  my @words = split(' ', $line);
  my $w="";

  # Process each word in the @words array and add it to library
  foreach my $w (@words)
  {
    if      ($self->FindPath($Root, $w.'.earth'.'XXX')) {  #TESTING FIX
      $self->Uprint($w.".earth\n");
    }
    if ($self->FindPath($Root, $w.'s.earth')) {   # check for plural"s"
      $self->Uprint($w."s.earth\n");
    }
    if ($self->FindPath($Root, $w.'es.earth')) {   # check for plural"es"
      $self->Uprint($w."es.earth\n");
    }
    if ($self->FindPath($Root, $w.'.earth.love')) {   # check for .earth.love subdomain
      $self->Uprint($w.".earth.love\n");
    }
    #if ($self->FindPath($Root, $w.'.life')) {   #TESTING
    #  $self->Uprint($w.".life\n");
    #}
    #if ($self->FindPath($Root, $w.'.love')) {
    #  $self->Uprint($w.".love\n");
    #}
    #if ($self->FindPath($Root, $w.'.land')) {
    #  $self->Uprint($w.".land\n");
    #}
    #if ($self->FindPath($Root, $w.'.world')) {
    #  $self->Uprint($w.".world\n");
    #}
    #f ($self->FindPath($Root, $w.'.space')) {
    #  $self->Uprint($w.".space\n");
    #}
    if ($self->FindPath($Root, $w.'101.earth')) {
      $self->Uprint($w."101.earth\n");
    }
    if ($self->FindPath($Root, $w.'101.life')) {
      $self->Uprint($w."101.life\n");
    }
    if ($self->FindPath($Root, $w.'101.love')) {
      $self->Uprint($w."101.love\n");
    }
    if ($self->FindPath($Root, $w.'101.land')) {
      $self->Uprint($w."101.land\n");
    }
    if ($self->FindPath($Root, $w.'101.space')) {
      $self->Uprint($w."101.space\n");
    }
    if ($self->FindPath($Root, $w.'101.world')) {
      $self->Uprint($w."101.world\n");
    }
    if ($self->FindPath($Root, $w.'DIG.com')) {   # check for DIG site @com
      $self->Uprint($w."DIG.com\n");
    }
    if ($self->FindPath($Root, $w.'.DIG.earth')) {   # check for DIG.earth site
      $self->Uprint($w.".DIG.earth\n");
    }   # else word not found
  }
  undef @words; # Clear array to free up memory
} #ShowEarthDomains


################################################################################
# END OF Akashic::Earth.pm
################################################################################
1;
