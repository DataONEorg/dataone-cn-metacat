#!/usr/bin/perl

 #
 #  '$RCSfile$'
 #  Copyright: 2000 Regents of the University of California 
 #
 #   '$Author: daigle $'
 #     '$Date: 2010-04-14 14:31:03 -0400 (Wed, 14 Apr 2010) $'
 # '$Revision: 5311 $' 
 # 
 # This program is free software; you can redistribute it and/or modify
 # it under the terms of the GNU General Public License as published by
 # the Free Software Foundation; either version 2 of the License, or
 # (at your option) any later version.
 #
 # This program is distributed in the hope that it will be useful,
 # but WITHOUT ANY WARRANTY; without even the implied warranty of
 # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 # GNU General Public License for more details.
 #
 # You should have received a copy of the GNU General Public License
 # along with this program; if not, write to the Free Software
 # Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 #

package Metacat;

require 5.005_62;
use strict;
use warnings;

require Exporter;
use AutoLoader qw(AUTOLOAD);

use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use HTTP::Cookies;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Metacat ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);
our $VERSION = '0.01';


# Preloaded methods go here.

#############################################################
# Constructor creates a new class instance and inits all
# of the instance variables to their proper default values,
# which can later be changed using "set_options"
#############################################################
sub new {
  my($type,$metacatUrl) = @_;
  my $cookie_jar = HTTP::Cookies->new;

  my $self = {
    metacatUrl     => $metacatUrl,
    message        => '',
    cookies        => \$cookie_jar
  };

  bless $self, $type; 
  return $self;
}

#############################################################
# subroutine to set options for the class, including the URL 
# for the Metacat database to which we would connect
#############################################################
sub set_options {
  my $self = shift;
  my %newargs = ( @_ );

  my $arg;
  foreach $arg (keys %newargs) {
    $self->{$arg} = $newargs{$arg};
  }
}

#############################################################
# subroutine to send data to metacat and get the response
# return response from metacat
#############################################################
sub sendData {
  my $self = shift;
  my %postData = ( @_ );

  $self->{'message'} = '';
  my $userAgent = new LWP::UserAgent;
  $userAgent->agent("MetacatClient/1.0");

  # determine encoding type
  my $contentType = 'application/x-www-form-urlencoded';
  if ($postData{'enctype'}) {
      $contentType = $postData{'enctype'};
      delete $postData{'enctype'};
  }

  my $request = POST("$self->{'metacatUrl'}",
                     Content_Type => $contentType,
                     Content => \%postData
                );

  # set cookies on UA object
  my $cookie_jar = $self->{'cookies'};
  $$cookie_jar->add_cookie_header($request);
  #print "Content_type:text/html\n\n";
  #print "request: " . $request->as_string();

  my $response = $userAgent->request($request);
  #print "response: " . $response->as_string();
   
  if ($response->is_success) {
    # save the cookies
    $$cookie_jar->extract_cookies($response);
    # save the metacat response message
    $self->{'message'} = $response->content;
  } else {
    #print "SendData content is: ", $response->content, "\n";
    return 0;
  } 
  return $response;
}

#############################################################
# subroutine to log into Metacat and save the cookie if the
# login is valid.  If not valid, return 0. If valid then send 
# following values to indicate user status
# 1 - user
# 2 - moderator
# 3 - administrator
# 4 - moderator and administrator
#############################################################
sub login {
  my $self = shift;
  my $username = shift;
  my $password = shift;

  my $returnval = 0;

  my %postData = ( action => 'login',
                   qformat => 'xml',
                   username => $username,
                   password => $password
                 );
  my $response = $self->sendData(%postData);
  if (($response) && $response->content =~ /<login>/) {
    $returnval = 1;
  }

  if (($response) && $response->content =~ /<isAdministrator>/) {
	if (($response) && $response->content =~ /<isModerator>/) {
    		$returnval = 4;
	} else {
		$returnval = 3;
	}
  } elsif (($response) && $response->content =~ /<isModerator>/){
	$returnval = 2;
  }

  return $returnval;
}

#############################################################
# subroutine to insert an XML document into Metacat
# If success, return 1, else return 0
#############################################################
sub insert {
  my $self = shift;
  my $docid = shift;
  my $xmldocument = shift;
  my $dtd = shift;

  my $returnval = 0;

  my %postData = ( action => 'insert',
                   docid => $docid,
                   doctext => $xmldocument
                 );
  if ($dtd) {
    $postData{'dtdtext'} = $dtd;
  }

  my $response = $self->sendData(%postData);
  if (($response) && $response->content =~ /<success>/) {
    $returnval = 1;
  } elsif (($response)) {
    $returnval = 0;
    #print "Error response from sendData!\n";
    #print $response->content, "\n";
  } else {
    $returnval = 0;
    #print "Invalid response from sendData!\n";
  }

  return $returnval;
}


#############################################################
# subroutine to set access for an XML document in Metacat
# If success, return 1, else return 0
#############################################################
sub setaccess {
  my $self = shift;
  my $docid = shift;
  my $principal = shift;
  my $permission = shift;
  my $permType = shift;
  my $permOrder = shift;

  my $returnval = 0;

  my %postData = ( action => 'setaccess',
                   docid => $docid,
		   principal => $principal,
		   permission => $permission,
		   permType => $permType,
		   permOrder => $permOrder
                 );

  my $response = $self->sendData(%postData);
  if (($response) && $response->content =~ /<success>/) {
    $returnval = 1;
  }

  return $returnval;
}



#############################################################
# subroutine to get the message returned from the last executed
# metacat action.  These are generally XML formatted messages.
#############################################################
sub getMessage {
  my $self = shift;

  return $self->{'message'};
}

package main;

use strict;

############################################################################
#
# MAIN program block
#
############################################################################

my $url = 'https://cn-dev.dataone.org/knb/metacat/'; 
my $dn = 'uid=dataone_cn_metacat,o=DATAONE,dc=ecoinformatics,dc=org';
my $password = "";
print "Please enter your password: ";
chomp($password = <>);
my $docid = 'OBJECT_FORMAT_LIST.1.1';
my $principal = 'public';
my $permission = 'read';
my $permType = 'allow';
my $permOrder = 'allowFirst';

my @lines = <DATA>;
my $metadata = join('', @lines);

# Open a metacat connection and login

my $metacat = Metacat->new();

    if ($metacat) {
       $metacat->set_options( metacatUrl => $url );
    } else {
        die("Could not open connection to Metacat url: $url\n");
    }

print "attempting to login\n";
my $response = $metacat->login($dn, $password);
if (!($response)) {
	die("login $response " . $metacat->getMessage() . "\n")
}
print ($metacat->getMessage());


# Do the metacat insertion
$response = $metacat->insert($docid, $metadata);
if (!($response)) {
	die("login $response " . $metacat->getMessage() . "\n")
}

#Check the insertion succeeded, if not possibly try again with new id
print ($metacat->getMessage());


#
# Set access control permissions on the file identified
#

$response = $metacat->setaccess($docid, $principal,$permission, $permType,$permOrder);
if (!($response)) {
	die("login $response " . $metacat->getMessage() . "\n")
}
print ($metacat->getMessage());

__DATA__
<?xml version="1.0" encoding="UTF-8"?>
<!-- 
 * This work was created by participants in the DataONE project, and is
 * jointly copyrighted by participating institutions in DataONE. For
 * more information on DataONE, see our web site at http://dataone.org.
 *
 *   Copyright ${year}
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * 
 * $Id$
 *
 -->
<!-- 
  The object format list is the default list of object formats used
  by Metacat's ObjectFormatService. In the event that the service cannot
  get the authoritative object format list from the DataONE Coordinating
  Node listed in the metacat properties file or from a cached version in
  the metacat database, it will revert to this file.
 -->
<d1:objectFormatList count="67" start="0" total="67"
  xmlns:d1="http://ns.dataone.org/service/types/v1" 
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-access-2.0.0beta4//EN</fmtid>
    <formatName>Ecological Metadata Language, Access module, version 2.0.0beta4</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-attribute-2.0.0beta4//EN</fmtid>
    <formatName>Ecological Metadata Language, Attribute module, version 2.0.0beta4</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-constraint-2.0.0beta4//EN</fmtid>
    <formatName>Ecological Metadata Language, Constraint module, version 2.0.0beta4</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-coverage-2.0.0beta4//EN</fmtid>
    <formatName>Ecological Metadata Language, Coverage module, version 2.0.0beta4</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-dataset-2.0.0beta4//EN</fmtid>
    <formatName>Ecological Metadata Language, Dataset module, version 2.0.0beta4</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-distribution-2.0.0beta4//EN</fmtid>
    <formatName>Ecological Metadata Language, Distribution module, version 2.0.0beta4</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-entity-2.0.0beta4//EN</fmtid>
    <formatName>Ecological Metadata Language, Entity module, version 2.0.0beta4</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-literature-2.0.0beta4//EN</fmtid>
    <formatName>Ecological Metadata Language, Literature module, version 2.0.0beta4</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-party-2.0.0beta4//EN</fmtid>
    <formatName>Ecological Metadata Language, Party module, version 2.0.0beta4</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-physical-2.0.0beta4//EN</fmtid>
    <formatName>Ecological Metadata Language, Physical module, version 2.0.0beta4</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-project-2.0.0beta4//EN</fmtid>
    <formatName>Ecological Metadata Language, Project module, version 2.0.0beta4</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-protocol-2.0.0beta4//EN</fmtid>
    <formatName>Ecological Metadata Language, Protocol module, version 2.0.0beta4</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-resource-2.0.0beta4//EN</fmtid>
    <formatName>Ecological Metadata Language, Resource module, version 2.0.0beta4</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-software-2.0.0beta4//EN</fmtid>
    <formatName>Ecological Metadata Language, Software module, version 2.0.0beta4</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-access-2.0.0beta6//EN</fmtid>
    <formatName>Ecological Metadata Language, Access module, version 2.0.0beta6</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-attribute-2.0.0beta6//EN</fmtid>
    <formatName>Ecological Metadata Language, Attribute module, version 2.0.0beta6</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-constraint-2.0.0beta6//EN</fmtid>
    <formatName>Ecological Metadata Language, Constraint module, version 2.0.0beta6</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-coverage-2.0.0beta6//EN</fmtid>
    <formatName>Ecological Metadata Language, Coverage module, version 2.0.0beta6</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-dataset-2.0.0beta6//EN</fmtid>
    <formatName>Ecological Metadata Language, Dataset module, version 2.0.0beta6</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-distribution-2.0.0beta6//EN</fmtid>
    <formatName>Ecological Metadata Language, Distribution module, version 2.0.0beta6</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-entity-2.0.0beta6//EN</fmtid>
    <formatName>Ecological Metadata Language, Entity module, version 2.0.0beta6</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-literature-2.0.0beta6//EN</fmtid>
    <formatName>Ecological Metadata Language, Literature module, version 2.0.0beta6</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-party-2.0.0beta6//EN</fmtid>
    <formatName>Ecological Metadata Language, Party module, version 2.0.0beta6</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-physical-2.0.0beta6//EN</fmtid>
    <formatName>Ecological Metadata Language, Physical module, version 2.0.0beta6</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-project-2.0.0beta6//EN</fmtid>
    <formatName>Ecological Metadata Language, Project module, version 2.0.0beta6</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-protocol-2.0.0beta6//EN</fmtid>
    <formatName>Ecological Metadata Language, Protocol module, version 2.0.0beta6</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-resource-2.0.0beta6//EN</fmtid>
    <formatName>Ecological Metadata Language, Resource module, version 2.0.0beta6</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>-//ecoinformatics.org//eml-software-2.0.0beta6//EN</fmtid>
    <formatName>Ecological Metadata Language, Software module, version 2.0.0beta6</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>eml://ecoinformatics.org/eml-2.0.0</fmtid>
    <formatName>Ecological Metadata Language, version 2.0.0</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>eml://ecoinformatics.org/eml-2.0.1</fmtid>
    <formatName>Ecological Metadata Language, version 2.0.1</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>eml://ecoinformatics.org/eml-2.1.0</fmtid>
    <formatName>Ecological Metadata Language, version 2.1.0</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>eml://ecoinformatics.org/eml-2.1.1</fmtid>
    <formatName>Ecological Metadata Language, version 2.1.1</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>FGDC-STD-001.1-1999</fmtid>
    <formatName>
      Content Standard for Digital Geospatial Metadata, 
      Biological Data Profile, version 001.1-1999
    </formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>FGDC-STD-001.2-1999</fmtid>
    <formatName>
      Content Standard for Digital Geospatial Metadata, 
      Metadata Profile for Shoreline Data, version 001.2-1999
    </formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>FGDC-STD-001-1998</fmtid>
    <formatName>
      Content Standard for Digital Geospatial Metadata, version 001-1998
    </formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>INCITS 453-2009</fmtid>
    <formatName>
      North American Profile of ISO 19115: 2003 Geographic Information - Metadata
    </formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>http://www.unidata.ucar.edu/namespaces/netcdf/ncml-2.2</fmtid>
    <formatName>NetCDF Markup Language, version 2.2</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>CF-1.0</fmtid>
    <formatName>
      NetCDF Climate and Forecast Metadata Convention, version 1.0
    </formatName>
    <formatType>DATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>CF-1.1</fmtid>
    <formatName>
      NetCDF Climate and Forecast Metadata Convention, version 1.1
    </formatName>
    <formatType>DATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>CF-1.2</fmtid>
    <formatName>
      NetCDF Climate and Forecast Metadata Convention, version 1.2
    </formatName>
    <formatType>DATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>CF-1.3</fmtid>
    <formatName>
      NetCDF Climate and Forecast Metadata Convention, version 1.3
    </formatName>
    <formatType>DATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>CF-1.4</fmtid>
    <formatName>
      NetCDF Climate and Forecast Metadata Convention, version 1.4
    </formatName>
    <formatType>DATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>http://www.cuahsi.org/waterML/1.0/</fmtid>
    <formatName>
      Water Markup Language, version 1.0
    </formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>http://www.cuahsi.org/waterML/1.1/</fmtid>
    <formatName>
      Water Markup Language, version 1.0
    </formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>http://www.loc.gov/METS/</fmtid>
    <formatName>
      Metadata Encoding and Transmission Standard, version 1
    </formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>netCDF-3</fmtid>
    <formatName>Network Common Data Format, version 3</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>netCDF-4</fmtid>
    <formatName>Network Common Data Format, version 4</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>text/plain</fmtid>
    <formatName>Plain Text</formatName>
    <formatType>DATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>text/csv</fmtid>
    <formatName>Comma Separated Values Text</formatName>
    <formatType>DATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>image/bmp</fmtid>
    <formatName>Bitmap Image File</formatName>
    <formatType>DATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>image/gif</fmtid>
    <formatName>Graphics Interchange Format</formatName>
    <formatType>DATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>image/jp2</fmtid>
    <formatName>JPEG 2000</formatName>
    <formatType>DATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>image/jpeg</fmtid>
    <formatName>JPEG</formatName>
    <formatType>DATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>image/png</fmtid>
    <formatName>Portable Network Graphics</formatName>
    <formatType>DATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>image/svg+xml</fmtid>
    <formatName>Scalable Vector Graphics</formatName>
    <formatType>DATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>image/tiff</fmtid>
    <formatName>Tagged Image File Format</formatName>
    <formatType>DATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>http://rs.tdwg.org/dwc/xsd/simpledarwincore/</fmtid>
    <formatName>Simple Darwin Core</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>http://digir.net/schema/conceptual/darwin/2003/1.0/darwin2.xsd</fmtid>
    <formatName>Darwin Core, version 2.0</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>application/octet-stream</fmtid>
    <formatName>Octet Stream</formatName>
    <formatType>DATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>http://www.w3.org/2005/Atom</fmtid>
    <formatName>ATOM-1.0</formatName>
    <formatType>RESOURCE</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>text/n3</fmtid>
    <formatName>N3</formatName>
    <formatType>RESOURCE</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>text/turtle</fmtid>
    <formatName>TURTLE</formatName>
    <formatType>RESOURCE</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>http://www.w3.org/TR/rdf-testcases/#ntriples</fmtid>
    <formatName>N-TRIPLE</formatName>
    <formatType>RESOURCE</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>http://www.w3.org/TR/rdf-syntax-grammar</fmtid>
    <formatName>RDF/XML</formatName>
    <formatType>RESOURCE</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>http://www.w3.org/TR/rdfa-syntax</fmtid>
    <formatName>RDFa</formatName>
    <formatType>RESOURCE</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>http://www.openarchives.org/ore/terms</fmtid>
    <formatName>Object Reuse and Exchange Vocabulary</formatName>
    <formatType>RESOURCE</formatType>
  </objectFormat>
  <objectFormat>
   <fmtid>application/pdf</fmtid>
   <formatName>Portable Document Format</formatName>
   <formatType>DATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>http://dublincore.org/schemas/xmls/qdc/2008/02/11/simpledc.xsd</fmtid>
    <formatName>Simple DC container XML Schema Created 2008-02-11</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
  <objectFormat>
    <fmtid>http://dublincore.org/schemas/xmls/qdc/2008/02/11/qualifieddc.xsd</fmtid>
    <formatName>Qualified DC container XML Schema Created 2008-02-11</formatName>
    <formatType>METADATA</formatType>
  </objectFormat>
</d1:objectFormatList>
