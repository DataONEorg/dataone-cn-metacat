#!/bin/bash
# This work was created by participants in the DataONE project, and is
# jointly copyrighted by participating institutions in DataONE. For 
# more information on DataONE, see our web site at http://dataone.org.
#
#   Copyright 2013
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

# dependency: sudo apt-get install xmlstarlet

# Insert or update the object format list on the local CN
# If this is a new installation of a CN environment, the object format list
# will not be present, and will be inserted.  Otherwise it will be updated
# based on the previous revision number already registered on the localhost CN.
#
#     '$Id$'
# '$Author$'
#   '$Date$'
# 
usage() {
    echo "./insert-or-update-object-format-list.sh /path/to/file";
    exit 1;
}


# Check that we have the path to the format list as an argument
if [ $# == 1  ]; then
    echo "Using object format list: ${1}";
else
    if [ $# == 0 ]; then 
        echo "Not enough arguments. Please provide a path to the object format list:";
        usage;
    else
        echo "Too many arguments. Please provide one path to the object format list:";
        usage;
    fi
fi

# Also check that we have xmlstarlet
xmlstarletLocation=$(which xmlstarlet);
if [[ ! "$xmlstarletLocation" =~ "xmlstarlet" ]]; then
    echo "xmlstarlet does not look to be installed. Use 'sudo apt-get install xmlstarlet' to install it.";
    exit 1;
fi

baseURL="https://localhost/metacat/metacat";
action="login";
username="uid=dataone_cn_metacat,o=DATAONE,dc=ecoinformatics,dc=org";
docid="OBJECT_FORMAT_LIST.1";
newDocid="";
curlCmd="curl -s -o - -k ";
objectFormatListFile=${1};

# Prompt for the password
echo "Enter the password for $username:";
stty_orig=$(stty -g);
stty -echo;
read password;
stty $stty_orig;

# log in
response=$($curlCmd -d "action=$action" \
    -d "password=$password" -d "username=$username" $baseURL);

# get the session id
sessionId=$(echo "$response" | xmlstarlet sel -t -m "//login" -v "sessionId");

if [[ $sessionId != "" ]]; then
    echo "Successfully logged in.";
else
    echo "Failed to log in."
    exit 1;
fi


# Does the formats list exist?
action="getrevisionanddoctype";
response=$($curlCmd -d "action=$action" \
    -d docid=$docid -d "sessionid=$sessionId" $baseURL);

rev=$(echo $response | cut -d";" -f1);
if [[ $rev =~ "error" ]]; then
    rev="0";
fi
currentDocid=$docid"."$rev

echo "Latest version is $currentDocid"

newRevision=$(expr $rev + 1);
newDocid=$docid"."$newRevision;
echo "New version is $newDocid";

# Get the new object format list XML document
doctext=$(cat $objectFormatListFile);
if [[ $doctext == "" ]];then
    echo "$objectFormatListFile is empty or not present. Exiting."
    exit 1;
fi

# Is this an insert or an update?
if [[ $rev == "0" ]]; then
    action="insert";
else
    action="update";
fi
echo "Using action: $action";

# update the object format list
response=$($curlCmd \
-d "action=$action" \
--data-urlencode "docid=$newDocid" \
--data-urlencode "doctext=$doctext" \
--data-urlencode "sessionid=$sessionId" $baseURL);
echo $response;

# set public/read access to the document
action="setaccess";
response=$($curlCmd \
-d "action=$action" \
--data-urlencode "docid=$newDocid" \
--data-urlencode "principal=public" \
-d "permission=read" \
-d "permType=allow" \
-d "permOrder=allowFirst" \
--data-urlencode "sessionid=$sessionId" $baseURL);
echo $response;
