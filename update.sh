#!/bin/bash
#Authors: Jackson Sadowski and Luke Matarazzo
#Purpose: Grab files via FTP, update them the way the user defines, and reupload them

if [ $# -lt 1 ]; then
  echo "Usage: ./update.sh [CONFIGFILE]"
  exit 1
fi

if [ $1 = "--help" ]; then
  echo "Printing help information"
  echo "CONFIGFILE - Text file containing each file on the remote FTP server that needs to be updated. Each file should be on a separate line."
fi



#setting the config file to a variable
file=$1

#getting a line 
line=`cat $file | head -1`

#checking for a line
if[ "$line" = "" ]; then
   echo "No more files"


