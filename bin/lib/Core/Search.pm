#!/usr/bin/perl
# Version 6.7.1.0      17-Jun-2021
#*****************************************************************************************
#*
#*  Package Name    :   Core::Search
#*
#*  Description     :   This package contains utility functions and procedures for supporting Orbit for Perl
#*
#*****************************************************************************************
# History:
#   2021.06.17 earth.love oK Refactored package for performance
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
#----------------------------------------#
# SEARCH UTILITIES
#----------------------------------------#
#
# GetDelimiters <text> <delimiter>
#   - Returns the delimiters from a given text string if none was specified
#   - <delimiter> is the primary separator specification
#   - The following characters are valid delimiters: | , : ;
#
# FixSearchString <search>
#   - Standardize the search expression for Regular Expressions RegExp.
#     Changes:  % => .*  ? => .  _ => .  * => .*
#
# FindInList <Item> <List> <SEP> <Wildcard>
#   - Returns 1 if the Item is found in the List of regedit expressions, separated by SEP
#   - Wildcard (1) searches for word in list within the Item
#
#*****************************************************************************************
package CoreUtils;

use strict;
use warnings;
use utf8;
use feature ':5.16';


################################################################################
#
# GetDelimiters <text> <delimiter>
#
# - Returns the delimiter from a given text string if none was specified, using <delim>
# - <delimiter> is the primary separator specification
# - The following characters are valid delimiters: | , : ;
#
################################################################################
sub CoreUtils::GetDelimiters {
  my ( $self, $text, $delim ) = @_;

  return "" if (!defined($text) || $text eq "");

  # Unset default delim if not found in data
  $delim = "" if (!defined($delim) || index($text, $delim) == -1);

  # Check for standard delimiters,
  # but not the delimiter passed in;
  # Must contain at least 2 secondary delimiters to be valid
  $delim .= '|'  if (index($text, '|') != -1 && index($delim,'|')==-1);   # Just need 1 pipe | to make a delimiter
  $delim .= ','  if ($text =~ /.*,.*,.*/   && index($delim,',')==-1);
  $delim .= ':'  if ($text =~ /.*:.*:.*/   && index($delim,':')==-1);
  $delim .= ';'  if ($text =~ /.*;.*;.*/   && index($delim,';')==-1);
  # Only use comma if others not present and one comma
  $delim = ','  if ($delim eq '' && index($text, ',') != -1);

  if (length($delim) == 2) {
    # See which delimiter comes first (it will be the name/value delim)
    my $delim1 = substr($delim,0,1);
    my $delim2 = substr($delim,1,1);
    # Switch the order of delimiters
    if (index($text,$delim1) < index($text,$delim2)) {
      $delim = $delim2.$delim1;
    }
  }

  return $delim;
} #GetDelimiters


################################################################################
#
# FixSearchString <search>
#
# - Standardize the search expression for Regular Expressions RegExp.
#   Changes:
#     % => .*
#     ? => .
#     _ => .
#     * => .*
################################################################################
sub CoreUtils::FixSearchString
{
  my ( $self, $lSearch ) = @_;
  # Standardize the search expression
  return "" if (!defined($lSearch) || $lSearch eq "");

  $lSearch =~ s/%/\.\*/g;
  $lSearch =~ s/\?/\./g;
  $lSearch =~ s/_/\./g;
  # See if Search has * instead of .* for regex
  if (index($lSearch, '*') >= 0
    &&index($lSearch, '.*') == -1) {
    # Switch out * for .*
    $lSearch =~ s/\*/\.\*/g;
  }
  return $lSearch;
} #FixSearchString


################################################################################
#
# FindInList <Item> <List> <SEP> <Wildcard>
#
# - Returns 1 if the Item is found in the List of regedit expressions, separated by SEP
# - Wildcard (1) searches for each word within the Item
# - ! specifies not (ie. !/)
################################################################################
sub CoreUtils::FindInList
{
  my ( $self, $Item, $List, $SEP, $Wild ) = @_;

  $Item = "" if (!defined($Item));
  $List = "" if (!defined($List));
  $Wild = 0 if (!defined($Wild) || $Wild ne '1');

  return 0 if ($Item eq "" || $List eq "");

  # Standardize the search expression
  $List = $self->FixSearchString($List);

  $SEP = $self->GetDelimiters($List, "") if (!defined($SEP) || $SEP eq "");

  # No separator - simple compare for 1 item
  if ($SEP eq "") {
    if (!$Wild && $Item =~ /^$List$/i) {
      return 1;
    # Look for Wildcard and List using ! not
    } elsif ($Wild && $List =~ /^!.*/) {
      $List =~ s/^!//;   # remove !
      # Check for NOT in
      if (!($Item =~ /^.*$List.*$/i)) {
        return 1;
      } else {
        return 0;
      }
    } elsif ($Wild && $Item =~ /^.*$List.*$/i) {
      return 1;
    } else {
      return 0;
    }
  }

  # Check each item in the list for a regedit
  my @LIST = split($SEP, $List);
  my $found = 0;
  foreach my $i (@LIST) {
    $i = $self->trim($i) if ($Wild);   # Trim the argument if wild
    if (!$Wild && $Item =~ /^$i$/) {
      $found = 1;
      last;
    # Look for Wildcard and LIST using ! not
    } elsif ($Wild && $i ne "" && $i =~ /^!.*/) {
      $i =~ s/^!//;   # remove !
      # Check for NOT in
      if ($Item =~ /^.*$i.*$/i) {
        $found = 0;
        last;
      }
    } elsif ($Wild && $i ne "" && $Item =~ /^.*$i.*$/i) {
      $found = 1;
      #last;
    }
  }
  undef @LIST;

  return $found;

} #FindInList


#******************************************************************************************
# Return true to show package was loaded with
# use Core::Search;
#******************************************************************************************
1;

#END Core::Search
