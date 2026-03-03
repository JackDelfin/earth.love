#!/usr/bin/perl
# Version 6.0.6.0      21-May-2021
#*****************************************************************************************
#*
#*  Package Name    :   Orbit::Utils::Wrap
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
#
# Wrap_Text
#   - Adds CHR(10) (\n) characters to wrap text so that no line is longer
#     than $fn_max_length characters.  Will attempt to wrap text at
#     word boundaries but will break in middle of words if necessary
#
# Count_Word_Wrap_Rows
#   - Given any string without line-breaking characters, count how many
#     Rows should be allotted for display in a TEXTAREA.  We must
#     consider left-breaking and right-breaking characters and groups
#     thereof.  Function is coded to IE v5.5 behavior but could easily
#     be extended to work with other browsers.
#
# Count_Rows
#   - Returns the number of rows in the text area OR 1 if the input text eq ''
#     If fn_max_length is specified, any lines exceeding this length will
#     count as additional rows to count for line wraps.
#     If $fb_word_wrap is TRUE, smart word wrapping will be accounted for
#     when counting line breaks.
#
# Count_Cols
#   - Returns the max number of columns in the text between line breaks,
#     OR NULL if the input text eq ''
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
#* Wrap_Text
#*
#* - Adds CHR(10) (\n) characters to wrap text so that no line is longer
#*   than $fn_max_length characters.  Will attempt to wrap text at
#*   word boundaries but will break in middle of words if necessary
#******************************************************************************************
sub Orbit::Wrap_Text
#                   $fv_in_string                 IN VARCHAR2
#                  ,fn_max_length                IN NUMBER    = 80
#                  ,fv_wordbreak_chars           IN VARCHAR2  = ' '||CHR(9)
#                  ,fv_linebreak_chars           IN VARCHAR2  = CHR(10)||CHR(13)
#                  ) return VARCHAR2;
{
  my ( $self, $fv_in_string, $fn_max_length, $fv_wordbreak_chars, $fv_linebreak_chars ) = @_;
  my $U = $self->{_Utils};
  use Core::Math::Least;

  my $cv_newline           = "\n";     #VARCHAR2(1)     = CHR(10);
  # hack for now with _ instead of chr(15)
  my $cv_match             = "_";   #$U->CHR(15);  #VARCHAR2(1)     = CHR(15);
  my $lv_out_string        = '';       #LONG            = '';
  my $li_begin_posn        = 0;        #INTEGER         = 1;
  my $li_end_posn          = 0;        #INTEGER         = 1;
  my $li_wordbreak_posn    = -1;       #INTEGER;
  my $li_linebreak_posn    = -1;       #INTEGER;
  #-- NULL parameters are replaced with default values
  my $ln_max_length        = $U->NVL($fn_max_length, 80);
  my $lv_wordbreak_chars   = $U->NVL($fv_wordbreak_chars, " \t");  #VARCHAR2(128) = $U->NVL ($fv_wordbreak_chars, ' '||CHR(9));
  my $lv_linebreak_chars   = "\n";     #VARCHAR2(128)   = $U->NVL ($fv_linebreak_chars, CHR(10)||CHR(13));
  ##-- Calculate these values only once per function call
  my $li_length            = '';       #INTEGER         = '';
  my $lv_replace           = '';       #VARCHAR2(128)   = '';
  my $lv_wordbreak_buffer  = $fv_in_string;   #LONG            = $fv_in_string;
  my $lv_linebreak_buffer  = $fv_in_string;   #LONG            = $fv_in_string;
  my $li_count             = 0;        #BINARY_INTEGER  = 0;
  #--
  #-- Optimization: return NULL immediately if input eq ''
  #--
  if ($fv_in_string eq '') {
    return '';
  }
  #--
  #-- Optimization: return input string immediately if it is short enough
  #--
  $li_length = length($fv_in_string);
  if ($li_length <= $ln_max_length) {
    return $fv_in_string;
  }
  #--
  #-- Now calculate wordbreak / linebreak search "buffers"
  #--
  if ($lv_wordbreak_chars ne '') {
    $lv_replace = $U->rpad($cv_match, length($lv_wordbreak_chars), $cv_match);
    $lv_wordbreak_buffer = $U->translate($lv_wordbreak_buffer, $lv_wordbreak_chars, $lv_replace);
  }
  if ($lv_linebreak_chars ne '') {
    $lv_replace = $U->rpad($cv_match, length($lv_linebreak_chars), $cv_match);
    $lv_linebreak_buffer = $U->translate($lv_linebreak_buffer, $lv_linebreak_chars, $lv_replace);
  }
  #--
  #-- Loop through input string, advancing begin-position, until done
  #--
  while (1)
  {
    last if ($li_begin_posn > $li_length-1);
    $li_count = $li_count + 1;
    #--
    #-- Calculate end-position based on max-length and length of string
    $li_end_posn = $U->least($li_begin_posn + $ln_max_length, $li_length);
    #--
    #-- Simplest Case: remaining text is less than max-length
    #-- Last row
    if (($li_end_posn - $li_begin_posn) < $ln_max_length-1) {
      $lv_out_string = $lv_out_string.substr($fv_in_string, $li_begin_posn, $li_end_posn - $li_begin_posn);
      $li_begin_posn = $li_end_posn + 1;
    #--
    } else {
      #--
      #-- Look for linebreaking-char BACKWARDS from just beyond end of current line
      #$li_linebreak_posn = index($lv_linebreak_buffer, $cv_match, $li_end_posn - $li_length);
      # Use for loop to travers backwards from end pos until we find match
      $li_linebreak_posn = -1;
      for (my $i=$li_end_posn; $i>=0; $i--) {
        if (substr($lv_linebreak_buffer, $i, 1) eq $cv_match) {
          $li_linebreak_posn = $i;
          last;
        }
      }
      #--
      #-- Next Case: we found a linebreaking-char within max-length + 1 chars
      if ($li_linebreak_posn >= $li_begin_posn && $li_linebreak_posn <= $li_end_posn) {
        $lv_out_string = $lv_out_string.substr($fv_in_string, $li_begin_posn, $li_linebreak_posn - $li_begin_posn);
        $li_begin_posn = $li_linebreak_posn + 1;
      #--
      } else {
        #--
        #-- Look for wordbreaking-char BACKWARDS from end of current line
        #$li_wordbreak_posn = index($lv_wordbreak_buffer, $cv_match, $li_end_posn - ($li_length-1));
        # Use for loop to travers backwards from end pos until we find match
        $li_wordbreak_posn = -1;
        for (my $i=$li_end_posn; $i>=0; $i--) {
          if (substr($lv_wordbreak_buffer, $i, 1) eq $cv_match) {
            $li_wordbreak_posn = $i;
            last;
          }
        }
        #--
        #-- Next Case: we found a wordbreaking-char within max-length chars
        if ( $li_wordbreak_posn >= $li_begin_posn
          && $li_wordbreak_posn <= $li_end_posn
          ) {
          $lv_out_string = $lv_out_string.substr($fv_in_string, $li_begin_posn, $li_wordbreak_posn - $li_begin_posn);
          $li_begin_posn = $li_wordbreak_posn + 1;
          #-- Add a new linebreak to the output
          $lv_out_string = $lv_out_string.$cv_newline;
        #--
        } else {
          #--
          #-- Final Case: give up and break the line mid-word at max-length chars
          $lv_out_string = $lv_out_string.substr($fv_in_string, $li_begin_posn, $li_end_posn - $li_begin_posn);
          $li_begin_posn = $li_end_posn + 1;
          #--
          #-- Add a new linebreak to the output
          $lv_out_string = $lv_out_string.$cv_newline;
        }
      }
    }
  }
  # Return adjusted string
  return $lv_out_string;
} #Wrap_Text


#******************************************************************************************
#* Count_Word_Wrap_Rows
#*
#* - Given any string without line-breaking characters, count how many
#*   Rows should be allotted for display in a TEXTAREA.  We must
#*   consider left-breaking and right-breaking characters and groups
#*   thereof.  Function is coded to IE v5.5 behavior but could easily
#*   be extended to work with other browsers.
#******************************************************************************************
sub Orbit::Count_Word_Wrap_Rows
{
  my ( $self, $fv_text, $fn_max_length, $fn_max_loops ) = @_;

  my $ln_test_posn    = $fn_max_length;  #  BINARY_INTEGER = $fn_max_length;
  my $lv_test_char    = '';              #  VARCHAR2(1)  = NULL;
  my $lb_leftb_seen   = 0;               #  BOOLEAN  = 0;
  my $lb_rightb_seen  = 0;               #    BOOLEAN  = 0;
  my $lb_nonb_seen    = 0;               #    BOOLEAN  = 0;
  #-- Default left- and right-breaking character sets for IE v5.5 (Netscape
  #--   only breaks on tab and space; Opera adds '$<\' (left) and '>' (right)
  my $cv_leftb_chars  = '\t([{';         #    CONSTANT  VARCHAR2(16)  = CHR(9)||'([{';
  my $cv_rightb_chars = ' !%)-?]}';      #    CONSTANT  VARCHAR2(16)  = ' !%)-?]}';
  my $li_count        = 0;               #    BINARY_INTEGER = 0;

  #-- Quick return for NULL string
  if ($fv_text eq '') {
    return 1;
  }
  #-- Quick return if max length is NULL
  if ($fn_max_length eq '') {
    return 1;
  }
  #-- Quick return for string already short enough
  if (length($fv_text) <= $fn_max_length) {
    return 1;
  }
  #-- Check for infinite recursion
  if ($fn_max_loops >= 100) {
    return 1;
  }
  #-- Loop through first max-length characters to look for word breaks
  while (1)
  {
    last if ($ln_test_posn <= 0);
    $li_count = $li_count + 1;
    #-- Grab the next character as we move backwards through the string
    $lv_test_char = substr($fv_text, $ln_test_posn, 1);
    #-- Is current character a left-breaking character?
    if (index($cv_leftb_chars, $lv_test_char) >= 0) {
      #-- remember that we've seen a leftbreaking char
      $lb_leftb_seen = 1;
    #-- This character isn't left-breaking, but was the last one?
    } elsif ($lb_leftb_seen) {
      #-- break after the current character
      return 1 + $self->Count_Word_Wrap_Rows (substr($fv_text, $ln_test_posn + 1), $fn_max_length, $fn_max_loops + 1);
    #-- Is current character a right-breaking character?
    } elsif (index($cv_rightb_chars, $lv_test_char) >= 0) {
      #-- don't break here unless we've seen non-right-breaking characters already
      if ($lb_leftb_seen || $lb_nonb_seen) {
        #-- break after the current character
        return 1 + $self->Count_Word_Wrap_Rows (substr($fv_text, $ln_test_posn + 1), $fn_max_length, $fn_max_loops + 1);
      } else {
        #-- remember that we've seen a right-breaking char
        $lb_rightb_seen = 1;
      }
    #-- remember that we've seen a non-breaking char
    } else {
      $lb_nonb_seen = 1;
    }
    #-- Decrement loop counter
    $ln_test_posn = $ln_test_posn - 1;
  }
  #-- No wordbreaking position qualified in the first max-length characters
  return 1 + $self->Count_Word_Wrap_Rows (substr($fv_text, $fn_max_length + 1), $fn_max_length, $fn_max_loops + 1);
} #Count_Word_Wrap_Rows


#******************************************************************************************
#* Count_Rows
#*
#* - Returns the number of rows in the text area OR 1 if the input text eq ''
#*   If fn_max_length is specified, any lines exceeding this length will
#*   count as additional rows to count for line wraps.
#*   If $fb_word_wrap is TRUE, smart word wrapping will be accounted for
#*   when counting line breaks.
#******************************************************************************************
sub Orbit::Count_Rows
{
  my ( $self, $fv_text, $fn_max_length, $fb_word_wrap ) = @_;
  my $U = $self->{_Utils};
  use Core::Math::Round;

  my $ln_rows         = 0;   #BINARY_INTEGER = 0;
  my $ln_cr_end       = 0;   #BINARY_INTEGER = 0;
  my $ln_cr_start     = 0;   #BINARY_INTEGER = 0;
  my $ln_wrap_count   = 0;   #BINARY_INTEGER = 0;
  my $ln_length       = 0;   #BINARY_INTEGER;
  my $lb_exit         = 0;   #BOOLEAN = 0;

  #-- Quick return for most common case
  return 1 if (!defined($fv_text) || $fv_text eq "");

  #-- Set a default length
  $fn_max_length = '' if (!defined($fn_max_length) || $fn_max_length == 0);
  #-- Loop to count number of lines that extend beyond the max length
  while (!$lb_exit)
  {
    #break if ($lb_exit);
    $ln_cr_end = index($fv_text, chr(10), $ln_cr_start+1);
    #-- Check for last line in text (without carriage return)
    if ($ln_cr_end == -1) {
      $lb_exit = 1;
      $ln_cr_end = length($fv_text) + 1;
    }
    #-- Increment the number of lines
    $ln_rows = $ln_rows + 1;
    #-- Check the length of the line
    $ln_length = $ln_cr_end - $ln_cr_start - 1;
    if ($ln_length > $U->NVL($fn_max_length, $ln_length)) {
      #-- Are we wrapping at word boundaries?
      if ($fb_word_wrap) {
        #-- Call recursive word-wrap row-counter on extralong line
        $ln_rows = $ln_rows;  # - 1 + $self->Count_Word_Wrap_Rows (substr($fv_text, $ln_cr_start, $ln_length), $fn_max_length);
      } else {
        #-- Add any multiple of
        $ln_rows = $ln_rows + $U->trunc($ln_length / $fn_max_length);
      }
    }
    #-- Reset the start position
    $ln_cr_start = $ln_cr_end;
  }
  return $U->NVL($ln_rows, 1);
} #Count_Rows


#******************************************************************************************
#* Count_Cols
#*
#* - Returns the max number of columns in the text between line breaks,
#*   OR NULL if the input text eq ''
#******************************************************************************************
sub Orbit::Count_Cols
{
  my ( $self, $fv_text ) = @_;

  my $ln_rows           = 0;   #BINARY_INTEGER = 0;
  my $ln_cr_end         = 0;   #BINARY_INTEGER = 0;
  my $ln_cr_start       = 0;   #BINARY_INTEGER = 0;
  my $ln_wrap_count     = 0;   #BINARY_INTEGER = 0;
  my $ln_max_length     = 0;  #BINARY_INTEGER = '';
  my $ln_length         = 0;   #BINARY_INTEGER;
  my $lb_exit           = 0;   #BOOLEAN = 0;

  #-- Quick return for most common case
  if ($fv_text eq '') {
    return '';
  }
  #-- Loop to count max number of columns between line breaks
  while (!$lb_exit)
  {
    $ln_cr_end = index($fv_text, "\n", $ln_cr_start+1);
    #-- Check for last line in text (without carriage return)
    if ($ln_cr_end == -1) {
      $lb_exit = 1;
      $ln_cr_end = length($fv_text);
    }
    #-- Check the length of the line
    #$ln_length = $ln_cr_end - $ln_cr_start - 1;
    $ln_length = $ln_cr_end - $ln_cr_start;
    if ($ln_length > $ln_max_length) {
      #-- Reset the max length
      $ln_max_length = $ln_length;
    }
    #-- Reset the start position
    $ln_cr_start = $ln_cr_end;
  }
  return $ln_max_length;
} #Count_Cols


#========================================================================================
# END UTILITY FUNCTIONS IMPLEMENTATION
#========================================================================================


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::Utils::Wrap;
#******************************************************************************************
1;


#END Orbit::Utils::Wrap Package
