#!/usr/bin/perl
# Version 1.0.1.0      7-July-2021
#*******************************************************************************
#
#                           Akashic for Perl
# Akashic.pm
#
# Tool Library and Utilities for supporting the Akashic data structures
# for http://earth.love.
#
#-------------------------------------------------------------------------------
# Usage:
#-------------------------------------------------------------------------------
#
# To include these subroutines (functions/procedures) in your code, simply:
#
#     use Akashic;
#
# Utility functions for Akashic
#
#   use AkashicUtils;
#   use AkashicWrite;
#   use AkashicProcess;
#   use AkashicEarth;
#
#   The Akashic package files needs to be in an @INC library path.
#   If running in the current directory you can add:
#
#     use lib qw( ./lib ../lib );
#     use Akashic;
#
#     my $A = Akashic->new();
#
#*******************************************************************************
# History:
#   2021.07.07 earth.love oK Touchup prior to release
#   2021.06.27 earth.love oK Refactored to AkashicWords
#   2021.05.25 earth.love oK Refactored to AkashicWrite and AkashicUtils
#   2021.05.21 earth.love oK Minor fixes
#   2021.05.14 earth.love oK Refactored to Class
#   2021.04.29 earth.love oK Additional arg checking
#   2021.04.23 earth.love oK Support for ROOT Directories under Domain
#   2021.04.16 earth.love oK Refactored from processtext.pl (created 2021.04.04)
#   2021.04.04 earth.love oK Created
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
# INITIALIZATION ROUTINES
#----------------------------------------#
#
# Akashic::new
#   - Create a new Akashic class
#
# InitAkashic()
#   - Initialize the Class variables and Get/Set Environment variables
#
# getInitialized()
#   - Returns _Initialized state 1/0
#
# CheckEnvironment()
#   - Check the environment variables (make sure directories exist)
#   - Returns 1 if environment NOT oK, 0 otherwise
#
# IsNumber <text>
#   - Determines if string is a valid number.
#     NULL is NOT a number
#
# SetVar <variable> <value>
# GetVar <variable>
#   - Set and Get routines for defining Global Variables
#
# GetRoot
#   - Get the _Root value
# GetRootDir
#   - Get the _RootDir value
#
#*******************************************************************************
package Akashic;

use strict;
use warnings;
use utf8;
use feature ':5.16';
use Carp qw(croak);
use Cwd qw(abs_path);
use File::Spec;

# Use the CoreUtils package for Text/Number/Date utility functions
use Akashic::Core;
use Akashic::Words;   # Word Utility Functions

# Get the User Configuration and User Exits subroutines
#
use Akashic::myConfig;

################################################################################
#
# Akashic::new
#
# Create a new Akashic class
#
################################################################################
sub Akashic::new
{
  my $class = shift;   # class is the name of this package: Akashic
  my $bInit = shift;   # Initialize the environment (1) or not (0)

  $bInit = 1 if (!defined($bInit) || $bInit ne '0');

  # Define the token structure (class variables)
  my $self = {
     _VERSION       => '6.0.0.0   09-May-2021'
    ################################################################################
    # Package Defined Variables
    ################################################################################
    ,_Initialized   => 0               # State of initialization 1/0
     # Useful set of utilities used between Akashic and Orbit for Perl
    ,_Utils         => CoreUtils->new()
     #
     # Advanced Processing for Data Files from the earth.love Directory (for more see: Linguistics.earth)
     # Primary use if you're hosting a local data store in a networked community (see: Community101.earth)
     #
    ,_Domain        => 'EARTH'         # Domain Name ('EARTH')                                                        # $ENV{'ELDOM'}
    ,_DomainDir     => ''  # Domain Directory ('/LOVE/earth.love/')                                  # $ENV{'EARTH_LOVE'}
    ,_Root          => '_ROOT'         # ROOT under Domain (i.e. _ROOT LANGS COMMS LOCS GUILDS SELF JOBS etc)         # $ENV{'ELROOT'}
    ,_RootDir       => '.'             # ROOT Directory ('.')  (i.e. /LOVE/earth.love/COMMS/ for Communities)
    ,_Word          => ''              # WORD under ROOT - a WPP (Word/Phrase/Path)
    ,_WordDir       => '.'             # WORD Directory - set internally for buffering
    ,_Tree          => 'INDEX'         # TREE off of the ROOT (could also be in PATH format: carpenter.classes.earth) # $ENV{'ELTREE'}
    ,_TreeDir       => '.'             # TREE Directory (set internally)
    ,_Branch        => 'LIST'          # BRANCH off of the TREE (could also be in PATH format: tools.nearme.earth)    # $ENV{'ELBRANCH'}
    ,_BranchDir     => '.'             # BRANCH Directory (set internally)
    ,_Page          => '1'             # Page under a TREE BRANCH from the "Tree of Knowledge" for a WPP (Word/Phrase/Path)
    ,_PageDir       => '.'             # Page Directory - set internally
    ,_DataDir       => '.'             # Datafile Directory ('.') - also set Internally
    ,_DataExt       => '.dat'          # Datafile Extension ('.dat') dat not dot
    ,_DataExtAlt    => ',.txt,.oml,.log,.html,' # Alternative Datafile Extensions (separated by ,)
     # Template and Language affecting the viewer
    ,_Template      => ""   # $ENV('ELTEMPLATE')  # OML Template or Template Class for display on various browsers/viewers
    ,_Lang          => ""   # $ENV('ELLANG')      # Language
     #
    ,_WORDS         => "_WORDS"     # $ENV{'ELWORDS'}
    ,_PHRASES       => "_PHRASES"   # $ENV{'ELPHRASES'}
    ,_PATHS         => "_PATHS"     # $ENV{'ELPATHS'}
     #
    ,_TREES         => "_TREES"     # $ENV{'ELTREES'}
    ,_TEMPLATES     => "_TEMPLATES" # $ENV{'ELTEMPLATES'}
    ,_DATES         => "_DATES"     # $ENV{'ELDATES'}
     #
    ,_Data            => {  # Reference like $self->{_Data}->{'_WORD'}
         '_DOMAINS'   => 'DOMAINS.dat'   # Domains that this Domain is linked to
        ,'_DOMAIN'    => 'DOMAIN.dat'    # Current Domain Definition
        ,'_ROOTS'     => 'ROOTS.dat'     # Roots in this Domain
        ,'_ROOT'      => 'ROOT.dat'      # Root Definition
        ,'_OBJECT'    => 'OBJECT.dat'    # Object Definition within root (usually singular)
         #
        ,'_WORD'      => 'WORD.dat'      # Word name (only in the _WORDS directory)
        ,'_PHRASE'    => 'PHRASE.dat'    # Phrase name (_PHRASES directory)
        ,'_PHRASES'   => 'PHRASES.dat'   # Phrases associated with a word or item
        ,'_PATH'      => 'PATH.dat'      # Path name (_PATHS directory)
        ,'_PATHS'     => 'PATHS.dat'     # Paths associated with a word or item
         #
        ,'_NAME'      => 'NAME.dat'      # Mixed case spellings of the item name
        ,'_SHORT'     => 'SHORT.dat'     # Short versions of spelling of the item name
        ,'_ABBREV'    => 'ABBREV.dat'    # Abbreviation versions of spelling of the item name
        ,'_HELP'      => 'HELP.dat'      # Help Text for this item
        ,'_DESC'      => 'DESC.dat'      # Descriptions of the item/object
        ,'_COLOR'     => 'COLOR.dat'     # Color styles to use for this item/object
         #
        ,'_TREES'     => 'TREES.dat'     # Trees that this item is a member of
        ,'_TREE'      => 'TREE.dat'      # A Tree Definition
        ,'_DATES'     => 'DATES.dat'     # Dates associated with this item
        ,'_DATE'      => 'DATE.dat'      # A specific Date Definition
         #
        ,'_CAT'       => 'CAT.dat'       # Catalog name (only in the catalog directory)
        ,'_CATS'      => 'CATS.dat'      # Catalogs that an item (Word,Phrase,Path) is a member of
        ,'_LINKS'     => 'LINKS.dat'     # Links associated with an item
         # Index Navigation
        ,'_INDEX'     => 'INDEX.dat'     # Index of data files and subdirectories
        ,'_DOWN'      => 'DOWN.dat'      # List of all WORDS, PHRASES, PATHS down the directory
        ,'_UP'        => 'UP.dat'        # List of directories above the current one
         #
        ,'_COMM'      => 'COMM.dat'      # Community Name (only in the COMMS directory)
        ,'_COMMS'     => 'COMMS.dat'     # Communities that an item is associated with
        ,'_LOC'       => 'LOC.dat'       # Location Name (only in the LOCS directory)
        ,'_LOCS'      => 'LOCS.dat'      # Locations that an item is associated with
        ,'_DOM'       => 'DOM.dat'       # Web Domain (only in the DOMS directory)
        ,'_DOMS'      => 'DOMS.dat'      # Web Domains that an item is associated with
         #
        ,'_CODES'     => 'CODES.dat'     # Codes associated with an item (i.e. edit key)
        ,'_USER'      => 'USER.dat'      # Codes associated with an item (i.e. edit key)
        ,'_ACCESS'    => 'ACCESS.dat'    # Codes associated with an item (i.e. edit key)
         #
        ,'_TEXT'      => 'TEXT.dat'      # Text data for displaying regarding this item (may contain HTML/OML)
        ,'_DEF'       => 'DEF.dat'       # Definition(s) data file
        ,'_SYMBOL'    => 'SYMBOL.dat'    # Symbol(s) data file
        ,'_LANGS'     => 'LANGS.dat'     # Language data file containing translations of the item
        ,'_CREATED'   => 'CREATED.dat'   # Creation Date; contains Timestamp YYYYMMDD_HH24MISS
        ,'_UPDATED'   => 'UPDATED.dat'   # Last Update Date
        ,'_UPDATECNT' => 'UPDATECNT.dat' # Number of Updates
        }
    ,_CatFile       => ""   # $ENV{'ELCATFILE'}
    ,_Category      => ""   # $ENV{'ELCATEGORY'}
    ,_gCategory     => ""   # Global Category to add to word based on file being processed
    ,_gFileCategory => ""   # Global File Category when processing files
    ,_LinePhrase    => ""   # $ENV{'ELLINEPHRASE'}
    ,_ValidPhrase   => ""   # Used for storing line phrase to index on Words in the line
    ,_PartialDir    => ""   # Partial Directory for INDEX and DOWN when word/phrase not found
     # Optimization
    ,_bSortData     => 1    # Sort data as new items are being added (default 1); Set in batch processing to 0 for optimization
#******************************************************************************************
# COPY START FOR COREUTILS PRINT AND STATS PACKAGES
#******************************************************************************************
     # Statistics Array
    ,_StatsCnt      => 0
    ,_STATS         => { }  # Summary statistics
     # Print Buffer for Uprint
    ,_PrintBuf      => ''
    ,_bBuffer       => 0    # 1 - print to _PrintBuf, 0 - print to STDOUT
     # Optimization Settings
    ,_bShowStats    => 1    # Show Statistics data
    ,_bLogStats     => 1    # Log the statistics (usually for batch jobs, but possibly for OnLine)
    ,_bShowOutput   => 1    # Show Processing Output Messages; This would be set 0 for interactive
#******************************************************************************************
# END COPY
#******************************************************************************************
    ,_WHOTAG        => ':::WHO:::'  # WHO record tag for Archives
     #
    ,_gWordFoundText  => "SILENT"   # $ENV{'ELWORDFOUNDTEXT'}   # SILENT BRIEF EXISTS SHOW
     #
     # Statistics
     #
    ,_gStartTime      => ""
    ,_gEndTime        => ""
    ,_gWordCnt        => 0
    ,_gWordDupeCnt    => 0
    ,_gWordNewCnt     => 0
    ,_gPhraseCnt      => 0
    ,_gPhraseDupeCnt  => 0
    ,_gPhraseNewCnt   => 0
    ,_gPathCnt        => 0
    ,_gPathDupeCnt    => 0
    ,_gPathNewCnt     => 0
     # Cache variables
    ,_gWordCache      => ""
    ,_gWordDirCache   => ""
     # Global file name(s) being processed (set by calling program)
    ,_gFiles          => ""
     ################################################################################
     # END: Packagte Defined Variables
     ################################################################################
  };

  # Bless makes these variables available externally
  bless $self, $class;

  #
  # Do the Initialization in new() for convenience
  #
  $self->InitAkashic() if ($bInit);


  return $self;
} #Akashic::new


#------------------------------------------------------------------------------#
#--                        SUB-ROUTINES START HERE                           --#
#------------------------------------------------------------------------------#

################################################################################
# INITIALIZATION ROUTINES
################################################################################


################################################################################
#
# InitAkashic
#
# - Initialize the Akashic Class and Read/Set Environment variables
#
################################################################################
sub Akashic::InitAkashic
{
  my ( $self ) = @_;
  my $var = "";
  #
  # Initialization
  #
  # EARTH_LOVE
  # elWordFoundText
  # elMyWords
  # --------------------
  #
  ## DOMAIN: EARTH_LOVE   i.e. /LOVE/earth.love/
  $var = $ENV{'ELDOM'};   # Domain name is more for vanity purposes when referring to this Domain
  if (defined($var) && $var ne "") {
    $self->{_Domain}    = $var;
  }

  #
  # Set the Domain directory.  Web requests are always bound to the canonical
  # parent of their server-controlled DOCUMENT_ROOT (<domain>/_WEB).  A global
  # EARTH_LOVE override is intentionally ignored in CGI mode so one inherited
  # process setting cannot collapse separate virtual hosts onto one auth/data
  # store.  EARTH_LOVE remains available to command-line and batch tools.
  #
  my $web_request = (defined($ENV{'GATEWAY_INTERFACE'}) && $ENV{'GATEWAY_INTERFACE'} ne '')
    || (defined($ENV{'REQUEST_METHOD'}) && defined($ENV{'DOCUMENT_ROOT'}));
  if ($web_request) {
    my $document_root = $ENV{'DOCUMENT_ROOT'} // '';
    $document_root =~ s{[\\/]+\z}{};
    croak 'CGI DOCUMENT_ROOT must be an existing <domain>/_WEB directory'
      if ($document_root eq ''
        || !File::Spec->file_name_is_absolute($document_root)
        || $document_root !~ m{(?:\A|[\\/])_WEB\z}
        || !-d $document_root);
    my $domain_candidate = $document_root;
    $domain_candidate =~ s{[\\/]_WEB\z}{};
    my $resolved_domain = abs_path($domain_candidate);
    my $resolved_web = abs_path($document_root);
    croak 'could not resolve the CGI domain directory'
      if (!defined($resolved_domain) || !-d $resolved_domain
        || !defined($resolved_web)
        || $resolved_web ne File::Spec->catdir($resolved_domain, '_WEB'));
    $self->{_DomainDir} = $resolved_domain;
  } else {
    $var = $ENV{'EARTH_LOVE'};
    if (defined($var) && $var ne "" && -d $var) {
      my $resolved_domain = abs_path($var);
      $self->{_DomainDir} = $resolved_domain if (defined($resolved_domain));
    }
  }
  
  # Use current directory if DomainDir is not set
  $self->{_DomainDir} = "." if (!defined($self->{_DomainDir}) || $self->{_DomainDir} eq "");

  # Add trailing / to DomainDir if needed
  #
  $self->{_DomainDir} .= "/" if (substr($self->{_DomainDir}, length($self->{_DomainDir})-1, 1) ne "/");

  #
  ## ROOT: i.e. COMMS LOCS GUILDS etc.
  $var = $ENV{'ELROOT'};
  if (defined($var) && $var ne "") {
  # Standardize Root
    $self->{_Root} = $self->StandardizeRoot($var);
  }
  # Build RootDir
  $self->{_RootDir}   = $self->{_DomainDir}.$self->{_Root}.'/';
  
  #
  ## TREE: i.e. INDEX
  $var = $ENV{'ELTREE'};
  if (defined($var) && $var ne "") {
    $self->{_Tree}    = $var;
  }
  # Build TreeDir
  $self->{_TreeDir}    = $self->{_RootDir}.$self->{_Tree}.'/';

  #
  ## BRANCH:
  $var = $ENV{'ELBRANCH'};
  if (defined($var) && $var ne "") {
    $self->{_Branch}    = $var;
  }
  # Build BranchDir
  $self->{_BranchDir}    = $self->{_TreeDir}.$self->{_Branch}.'/';

  #
  ## PAGE:
  $var = $ENV{'ELPAGE'};
  if (defined($var) && $var ne "") {
    $self->{_Page}    = $var;
  }
  # Build PageDir
  $self->{_PageDir}    = $self->{_BranchDir}.$self->{_Page}.'/';

  #
  ## WORDS
  $var = $ENV{'ELWORDS'};
  if (defined($var) && $var ne "") {
    $self->{_WORDS}    = $var;
  }
  #
  ## PHRASES
  $var = $ENV{'ELPHRASES'};
  if (defined($var) && $var ne "") {
    $self->{_PHRASES}    = $var;
  }
  #
  ## PATHS
  $var = $ENV{'ELPATHS'};
  if (defined($var) && $var ne "") {
    $self->{_PATHS}    = $var;
  }

  #
  ## TREES
  $var = $ENV{'ELTREES'};
  if (defined($var) && $var ne "") {
    $self->{_TREES}    = $var;
  }
  #
  ## TEMPLATES
  $var = $ENV{'ELTEMPLATES'};
  if (defined($var) && $var ne "") {
    $self->{_TEMPLATES}    = $var;
  }
  #
  ## DATES
  $var = $ENV{'ELDATES'};
  if (defined($var) && $var ne "") {
    $self->{_DATES}    = $var;
  }

  #
  # Set Global Variables for:
  # WORDS, PHRASES, PATHS, TREES, TEMPLATES, DATES
  # Note: trailing "/" designates a directory, not a file
  #
  #$self->{_WORDSDIR}     = $self->{_RootDir}.$self->{_WORDS}."/";
  #$self->{_PHRASESDIR}   = $self->{_RootDir}.$self->{_PHRASES}."/";
  #$self->{_PATHSDIR}     = $self->{_RootDir}.$self->{_PATHS}."/";
  #
  #$self->{_TREESDIR}     = $self->{_RootDir}.$self->{_TREES}."/";
  #$self->{_TEMPLATESDIR} = $self->{_RootDir}.$self->{_TEMPLATES}."/";
  #$self->{_DATESDIR}     = $self->{_RootDir}.$self->{_DATES}."/";

  #
  # CatFile
  # Category
  # --------------------
  # The Catalog/Category file (i.e. CATS.dat) contains the categories for the word.
  # This process can be used to store other data for the word in different files.
  #
  ## CATFILE
  $self->{_CatFile} = $ENV{'ELCATFILE'};
  $self->{_CatFile} = $self->{_Data}->{'_CATS'} if (!defined($self->{_CatFile}) || $self->{_CatFile} eq "");
  #
  ## CATEGORY
  $self->{_Category} = $ENV{'ELCATEGORY'};
  $self->{_Category} = "" if (!defined($self->{_Category}));
  $self->{_gCategory} = "";  # Global Category to add to word based on file being processed

  #
  # LinePhrase
  # --------------------
  #   If set to 1, treats each line of the TextFiles as a phrase, storing it as such.
  #   Conditions:
  #     Phrase is no more than 80 characters and contains only VALID word punctuation.
  #     Spaces will be changed to underscore (_) for storage in the Akashic WORDS Library
  $var = $ENV{'ELLINEPHRASE'};
  if (defined($var) && $var ne "") {
    $self->{_LinePhrase}    = $var;
    # Default: 0 - override in user configuration below, not here.
    $self->{_LinePhrase} = "0" if (!defined($self->{_LinePhrase}) || $self->{_LinePhrase} ne "1");
  }
  $self->{_ValidPhrase} = "";   # Used for storing line phrase to index on Words in the line

  # Check for output format as words and phrases are added
  $var = $ENV{'ELWORDFOUNDTEXT'};
  if (defined($var) && $var ne "") {
    $self->{_gWordFoundText}    = $var;
  }

  # Set variables for Utils to default
  $self->SetVar('ShowStats',  $self->{_bShowStats});   # Turn off ShowStats - Don't show statistics for processing
  $self->SetVar('LogStats',   $self->{_bLogStats});    # Turn off LogStats - Don't even log statistics
  $self->SetVar('ShowOutput', $self->{_bShowOutput});  # Turn off ShowOutput - Don't show processing messages

  #
  # Set any user configurations
  #
  $self->UserConfigurations();

  #
  # Check the environment
  #
  if ($self->CheckEnvironment()) {
    $self->Uprint("\nError: InitAkashic: CheckEnvironment Failed.\n");
    $self->{_Initialized} = 0;
  }

  $self->{_Initialized} = 1;

} #InitAkashic


################################################################################
#
# getInitialized()
#
# - Returns _Initialized state 1/0
#
################################################################################
sub Akashic::getInitialized
{
  my ($self) = @_;
  return $self->{_Initialized};
} #getInitialized

################################################################################
#
# CheckEnvironment()
#
# - Check the environment variables (make sure directories exist)
# - Returns 1 if environment NOT oK, 0 otherwise
#
################################################################################
sub Akashic::CheckEnvironment
{
  my ( $self ) = @_;
  my $bError=0;

  #
  # Add a trailing / to the Akashic ROOT if needed
  #
  $self->{_DomainDir} = $self->{_DomainDir}."/" if (substr($self->{_DomainDir}, length($self->{_DomainDir})-1, 1) ne "/");

  # Add a trailing / to the ROOT directory if needed
  $self->{_RootDir} = $self->{_RootDir}."/" if (substr($self->{_RootDir}, length($self->{_RootDir})-1, 1) ne "/" && $self->{_RootDir} ne "");

  #
  # Set Class Variables for Root subdirectories (WPPTTD):
  # Note: trailing "/" designates a directory, not a file
  #
  # Check for WORDS, PHRASES, PATHS directories
  my $dir = $self->{_RootDir}.$self->{_WORDS}."/";
  if (!-d $dir) {
    $self->Uprint("\nError: WORDSDIR [$dir] directory NOT FOUND");
    $bError=1;
  }
  $dir = $self->{_RootDir}.$self->{_PHRASES}."/";
  if (!-d $dir) {
    $self->Uprint("\nError: PHRASESDIR [$dir] directory NOT FOUND");
    $bError=1;
  }
  $dir = $self->{_RootDir}.$self->{_PATHS}."/";
  if (!-d $dir) {
    $self->Uprint("\nError: PATHSDIR [$dir] directory NOT FOUND");
    $bError=1;
  }
  $dir = $self->{_RootDir}.$self->{_TREES}."/";
  if (!-d $dir) {
    $self->Uprint("\nError: TREESDIR [$dir] directory NOT FOUND");
    $bError=1;
  }
  $dir = $self->{_RootDir}.$self->{_TEMPLATES}."/";
  if (!-d $dir) {
    $self->Uprint("\nError: TEMPLATESDIR [$dir] directory NOT FOUND");
    $bError=1;
  }
  $dir = $self->{_RootDir}.$self->{_DATES}."/";
  if (!-d $dir) {
    $self->Uprint("\nError: DATESDIR [$dir] directory NOT FOUND");
    $bError=1;
  }

  # Check for error above
  if ($bError) {
    $self->Uprint("\n\n");
    return 1;
  }

  return 0;   # Everything checks oK
} #CheckEnvironment


#******************************************************************************************
# IsNumber <text>
#   - Determines if string is a valid number.
#     NULL is NOT a number
#******************************************************************************************/
sub Akashic::IsNumber
{
  my ( $self, $String ) = @_;
  # Null is not a number
  return 0 if (!defined($String) || $String eq "");
  return ($String =~ /^[-]*[0-9]*[\.]*[0-9]*$/)?1:0;
} #IsNumber


################################################################################
#
# SetVar <global_variable> <value>
#
# - Sets the value of certain global variables
#
#SetVar('Domain', '');
#SetVar('DomainDir', '');
#SetVar('Root', '');
#SetVar('Tree', '');
#SetVar('Branch', '');
#SetVar('Page', '');
#
#SetVar('WORDS', '');
#SetVar('PHRASES', '');
#SetVar('PATHS', '');
#SetVar('TREES')
#SetVar('TEMPLATES')
#SetVar('DATES')
#
#SetVar('Template', '');
#SetVar('Lang', '');
#SetVar('CatFile', '');
#SetVar('Category', '');
#SetVar('gCategory', '');
#SetVar('gFileCategory', '');
#SetVar('LinePhrase', '');
#SetVar('ValidPhrase', '');
#SetVar('gWordCache', '');
#SetVar('gWordDirCache', '');
#SetVar('gFiles', '');
#SetVar('gWordFoundText', '');
#
#SetVar('SortData',   '0');   # Turn off SortData - Don't sort index data as new items added
#SetVar('ShowStats',  '0');   # Turn off ShowStats - Don't show statistics for processing
#SetVar('LogStats',   '0');   # Turn off LogStats - Don't even log statistics
#SetVar('ShowOutput', '0');   # Turn off ShowOutput - Don't show processing messages
#
################################################################################
sub Akashic::SetVar
{
  my ( $self, $lVar, $lValue  ) = @_;
  $lValue = "" if (!defined($lValue));
  #
  # Root
  #
  if ($lVar eq 'Root') {
    # Return if the stored Root is the same as incoming value
    return 0 if ($self->{_RootDir} ne '.'
               && ($self->{_Root} eq $lValue
                 || ($lValue eq ''
                     && $self->{_Root} eq '_ROOT'
                     )
                  )
                );
    # A blank root is the _ROOT Root
    $lValue = '_ROOT' if  ($lValue eq "");
    # Root is uppercase by convention
    $lValue =~ tr/[a-z]/[A-Z]/;
    # Set the new Root Name
    $self->{_Root} = $lValue;
    $self->{_Root} = '_ROOT' if ($self->{_Root} eq "");   # default
    # Change . to / in Root name (i.e. LANGS.ENG -> LANGS/ENG)
    # Either format works, but . shows better on the url than encoded /
    $self->{_Root} =~ s/\./\//g if ($self->{_Root} =~ /.*\..*/);
    # Set the ELROOT environment variable so other scripts can reference
    $ENV{'ELROOT'} = $self->{_Root};

    # Reset RootDir
    $self->{_RootDir} = $self->{_DomainDir}.$self->{_Root}.'/';

    # Reset the TreeDir
    $self->{_TreeDir} = $self->{_RootDir}.$self->{_Tree}."/";   #TESTING
    # Reset the BranchDir
    $self->{_BranchDir} = $self->{_TreeDir}.$self->{_Branch}."/";
    # Reset the PageDir
    $self->{_PageDir} = $self->{_BranchDir}.$self->{_Page}."/";

    # Reset cached word data when DOMAIN or ROOT changes
    $self->{_gWordCache}="";
    $self->{_gWordDirCache}="";
  #
  # Domain Name (vanity more or less)
  #
  } elsif ($lVar eq 'Domain') {
    $self->{_Domain} = $lValue;
  #
  # DomainDir
  #
  } elsif ($lVar eq 'DomainDir') {
    $self->{_DomainDir} = $lValue if ($lValue ne "");

    # Add a trailing / to the DomainDir if needed
    $self->{_DomainDir} = $self->{_DomainDir}."/" if ($self->{_DomainDir} ne "" && substr($self->{_DomainDir}, length($self->{_DomainDir})-1, 1) ne "/");

    # Leave if the domain dir is the same on file
    return 0 if ($self->{_DomainDir} eq $lValue);

    # Set the EARTH_LOVE environment variable so other scripts can reference
    $ENV{'EARTH_LOVE'} = $self->{_DomainDir};

    # Reset RootDir
    $self->{_RootDir} = $self->{_DomainDir}.$self->{_Root}.'/';

    # Reset the TreeDir
    $self->{_TreeDir} = $self->{_RootDir}.$self->{_Tree}."/";   #TESTING
    # Reset the BranchDir
    $self->{_BranchDir} = $self->{_TreeDir}.$self->{_Branch}."/";
    # Reset the PageDir
    $self->{_PageDir} = $self->{_BranchDir}.$self->{_Page}."/";

    # Reset cached word data when Domain or ROOT changes
    $self->{_gWordCache}="";
    $self->{_gWordDirCache}="";
  #
  # Tree
  #
  } elsif ($lVar eq 'Tree') {
    # Leave if tree is the same
    return 0 if ($self->{_Tree} eq $lValue);
    $self->{_Tree} = $lValue;
    $self->{_Tree} = 'INDEX' if ($self->{_Tree} eq "");   # default
    # Set the ELTREE environment variable so other scripts can reference
    $ENV{'ELTREE'} = $self->{_Tree};
    # Reset the TreeDir
    $self->{_TreeDir} = $self->{_RootDir}.$self->{_Tree}."/";
    # Reset the BranchDir
    $self->{_BranchDir} = $self->{_TreeDir}.$self->{_Branch}."/";
    # Reset the PageDir
    $self->{_PageDir} = $self->{_BranchDir}.$self->{_Page}."/";
  #
  # Branch
  #
  } elsif ($lVar eq 'Branch') {
    # Leave if branch is the same
    return 0 if ($self->{_Branch} eq $lValue);
    $self->{_Branch} = $lValue;
    $self->{_Branch} = 'LIST' if ($self->{_Branch} eq "");   # default
    # Set the ELBRANCH environment variable so other scripts can reference
    $ENV{'ELBRANCH'} = $self->{_Branch};
    # Reset the BranchDir
    $self->{_BranchDir} = $self->{_TreeDir}.$self->{_Branch}."/";   #TESTING
    # Reset the PageDir
    $self->{_PageDir} = $self->{_BranchDir}.$self->{_Page}."/";
  #
  # Page
  #
  } elsif ($lVar eq 'Page') {
    # Leave if page is the same
    return 0 if ($self->{_Page} eq $lValue);
    $self->{_Page} = $lValue;
    $self->{_Page} = '1' if ($self->{_Page} eq "");   # default
    # Set the ELPAGE environment variable so other scripts can reference
    $ENV{'ELPAGE'} = $self->{_Page};
    # Reset the PageDir
    $self->{_PageDir} = $self->{_BranchDir}.$self->{_Page}."/";   #TESTING
  #
  #
  #
  } elsif ($lVar eq 'WORDS') {
    $self->{_WORDS} = $lValue;
  } elsif ($lVar eq 'PHRASES') {
    $self->{_PHRASES} = $lValue;
  } elsif ($lVar eq 'PATHS') {
    $self->{_PATHS} = $lValue;
  } elsif ($lVar eq 'TREES') {
    $self->{_TREES} = $lValue;
  } elsif ($lVar eq 'TEMPLATES') {
    $self->{_TEMPLATES} = $lValue;
  } elsif ($lVar eq 'DATES') {
    $self->{_DATES} = $lValue;

  } elsif ($lVar eq 'Template') {
    $self->{_Template} = $lValue;
  } elsif ($lVar eq 'Lang') {
    $lValue =~ tr/[a-z]/[A-Z]/;   # Uppercase Language by convention since it's a subROOT
    $self->{_Lang} = $lValue;

  # Category / Phrase / Cache
  } elsif ($lVar eq 'CatFile') {
    $self->{_CatFile} = $lValue;
  } elsif ($lVar eq 'Category') {
    $self->{_Category} = $lValue;
  } elsif ($lVar eq 'gCategory') {
    $self->{_gCategory} = $lValue;
  } elsif ($lVar eq 'gFileCategory') {
    $self->{_gFileCategory} = $lValue;
  } elsif ($lVar eq 'LinePhrase') {
    $self->{_LinePhrase} = $lValue;
  } elsif ($lVar eq 'ValidPhrase') {
    $self->{_ValidPhrase} = $lValue;
  } elsif ($lVar eq 'gWordCache') {
    $self->{_gWordCache} = $lValue;
  } elsif ($lVar eq 'gWordDirCache') {
    $self->{_gWordDirCache} = $lValue;

  } elsif      ($lVar eq 'gFiles') {
    $self->{_gFiles} = $lValue;
  } elsif ($lVar eq 'gWordFoundText') {
    $self->{_gWordFoundText} = $lValue;

  # Stats and Optimization
  } elsif ($lVar eq 'SortData') {
    $lValue = '1' if ($lValue ne '0');
    $self->{_bSortData} = $lValue;
  } elsif ($lVar eq 'ShowStats') {
    $lValue = '1' if ($lValue ne '0');
    $self->{_bShowStats} = $lValue;
    # Set Utils class for Stats processing
    #$ U->{_bShowStats} = $lValue;
  } elsif ($lVar eq 'LogStats') {
    $lValue = '1' if ($lValue ne '0');
    # Set Utils class for Stats processing
    $self->SetLogStats($lValue);
  } elsif ($lVar eq 'ShowOutput') {
    $lValue = '1' if ($lValue ne '0');
    # Set Utils class for Uprint
    $self->SetShowOutput($lValue);

  } else {
    $self->Uprint("SetVar: Variable not found [$lVar][$lValue]\n");
    return 1;
  }
} #SetVar


################################################################################
#
# GetVar <global_variable> <value>
#
# - Sets the value of certain global variables
#
#GetVar('Domain')
#GetVar('DomainDir')
#GetVar('Root')
#GetVar('RootDir')
#GetVar('Tree')
#GetVar('TreeDir')
#GetVar('Branch')
#GetVar('BranchDir')
#GetVar('Page')
#GetVar('PageDir')
#
#GetVar('WORDS')
#GetVar('PHRASES')
#GetVar('PATHS')
#GetVar('TREES')
#GetVar('TEMPLATES')
#GetVar('DATES')
#
#GetVar('Template')
#GetVar('CatFile')
#GetVar('Category')
#GetVar('gCategory')
#GetVar('gFileCategory')
#GetVar('LinePhrase')
#GetVar('ValidPhrase')
#GetVar('gWordCache')
#GetVar('gWordDirCache')
#GetVar('gFiles')
#GetVar('gWordFoundText')
#
#GetVar('SortData');
#GetVar('ShowStats');
#GetVar('LogStats');
#GetVar('ShowOutput');
#
################################################################################
sub Akashic::GetVar
{
  my ( $self, $lVar  ) = @_;

  if ($lVar eq 'Domain') {
    return $self->{_Domain};
  } elsif ($lVar eq 'DomainDir') {
    return $self->{_DomainDir};
  } elsif ($lVar eq 'Root') {
    return $self->{_Root};
  } elsif ($lVar eq 'RootDir') {
    return $self->{_RootDir};
  } elsif ($lVar eq 'Tree') {
    return $self->{_Tree};
  } elsif ($lVar eq 'TreeDir') {
    return $self->{_TreeDir};
  } elsif ($lVar eq 'Branch') {
    return $self->{_Branch};
  } elsif ($lVar eq 'BranchDir') {
    return $self->{_BranchDir};
  } elsif ($lVar eq 'Page') {
    return $self->{_Page};
  } elsif ($lVar eq 'PageDir') {
    return $self->{_PageDir};

  } elsif ($lVar eq 'WORDS') {
    return $self->{_WORDS};
  } elsif ($lVar eq 'PHRASES') {
    return $self->{_PHRASES};
  } elsif ($lVar eq 'PATHS') {
    return $self->{_PATHS};
  } elsif ($lVar eq 'TREES') {
    return $self->{_TREES};
  } elsif ($lVar eq 'TEMPLATES') {
    return $self->{_TEMPLATES};
  } elsif ($lVar eq 'DATES') {
    return $self->{_DATES};

  } elsif ($lVar eq 'Template') {
    return $self->{_Template};
  } elsif ($lVar eq 'CatFile') {
    return $self->{_CatFile};
  } elsif ($lVar eq 'Category') {
    return $self->{_Category};
  } elsif ($lVar eq 'gCategory') {
    return $self->{_gCategory};
  } elsif ($lVar eq 'gFileCategory') {
    return $self->{_gFileCategory};
  } elsif ($lVar eq 'LinePhrase') {
    return $self->{_LinePhrase};
  } elsif ($lVar eq 'ValidPhrase') {
    return $self->{_ValidPhrase};
  } elsif ($lVar eq 'gWordCache') {
    return $self->{_gWordCache};
  } elsif ($lVar eq 'gWordDirCache') {
    return $self->{_gWordDirCache};

  } elsif ($lVar eq 'gFiles') {
    return $self->{_gFiles};
  } elsif ($lVar eq 'gWordFoundText') {
    return $self->{_gWordFoundText};

  # Stats and Optimization
  } elsif ($lVar eq 'SortData') {
    return $self->{_bSortData};
  } elsif ($lVar eq 'ShowStats') {
    return $self->{_bShowStats};
  } elsif ($lVar eq 'LogStats') {
    return $self->{_bLogStats};
  } elsif ($lVar eq 'ShowOutput') {
    return $self->{_bShowOutput};

  } else {
    $self->Uprint("GetVar: Variable not found [$lVar]\n");
    return "";
  }
} #GetVar


#******************************************************************************************/
# GetRoot
#   - Get the _Root value
#******************************************************************************************/
sub Akashic::GetRoot {
  my ($self) = @_;
  return $self->{_Root};
} #GetRoot


#******************************************************************************************/
# GetRootDir
#   - Get the _RootDir value
#******************************************************************************************/
sub Akashic::GetRootDir {
  my ($self) = @_;
  return $self->{_RootDir};
} #GetRootDir


################################################################################
# END OF Akashic.pm
################################################################################
1;
