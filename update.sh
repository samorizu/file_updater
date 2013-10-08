#!/bin/bash
#Authors: Jackson Sadowski and Luke Matarazzo
#Purpose: Grab files via SFTP or FTP, update them the way the user defines, and reupload them

if [ $1 = "--help" ]; then
  echo "Printing help information"
  echo "CONFIGFILE - Text file containing each file on the remote FTP server that needs to be updated. Each file should be on a separate line."
  echo "-f - Specifies the use of FTP rather than SFTP. SFTP is the default protocol for this program."
  exit 0
fi

if [ $# -lt 2 ]; then
  echo "Usage: ./update.sh [CONFIGFILE] [DIRECTORY_OF_FILES]"
  exit 1
fi

files=`ls $2`

for file in $files; do
	#echo "$2/$file";
	#cp $2/$file $2/$file.bak
	./manipulator.pl $1 < $2/$file > $file
done

#setting the config file to a variable
#file=$1

#getting a line 
#line=`cat $file | head -1`

#checking for a line
#if[ "$line" = "" ]; then
#   echo "No more files"


