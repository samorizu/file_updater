#!/bin/bash
#Authors: Jackson Sadowski and Luke Matarazzo
#Purpose: Grab files via SFTP or FTP, update them the way the user defines, and reupload them

if [ $1 = "--help" ]; then
	echo "Printing help information"
	echo "CONFIGFILE - File with the text to be found, a tilde (~) on a line by itself and then the changes (temporary)."
	#echo "CONFIGFILE - Text file containing each file on the remote FTP server that needs to be updated. Each file should be on a separate line."
	echo "[DIRECTORY_OF_FILES] - Directory in which the files to be updated are (temporary)."
	echo "-f - Specifies the use of FTP rather than SFTP. SFTP is the default protocol for this program."
	echo "-s - Specifies the use of FTPS rather than SFTP. SFTP is the default protocol for this program."
	exit 0
fi

if [ $# -lt 2 ]; then
  echo "Usage: ./update.sh [options] [CONFIGFILE] [DIRECTORY_OF_FILES] [options]"
  exit 1
fi

for param in $@; do
	if [ ${param:0:1} == "-" ]; then
		ftp_option=${param:1:1}
		break
	fi
done

if [ "$ftp_option" == "f" ]; then
	protocol=ftp
elif [ "$ftp_option" == "s" ]; then
	protocol=ftps
else
	protocol=sftp
fi

if test ! -d $2; then
	mkdir $2
fi

cd $2

read -p "FTP host (example ftp.server.com): " host
read -p "FTP user: " user
read -s -p "FTP password: " pass

#Uses the ftp command with the -inv switches. -i turns off interactive prompting. -n Restrains FTP from attempting the auto-login feature. -v enables verbose and progress.
$protocol -inv $host <<EOF
user $user $pass
cd testing
mget *.asp
bye
EOF
#exit 0

cd ..
path=`pwd`
files=`ls $2`
num_files=0

for file in $files; do
	cp $2/$file $2/$file.bak
	$path/manipulator.pl $1 < $2/$file > $2/$file.new
	result=`cat $2/$file.new`
	#echo "result: '$result'"
	if [ "$result" != "" ]; then
		num_files=$num_files+1
		rm $2/$file
		mv $2/$file.new $2/$file
	else
		#echo "in the else"
		rm $2/$file.new
		mv $2/$file.bak $2/$file
	fi
done

cd $2
$protocol -inv $host <<EOF
user $user $pass
cd testing
mput *.asp
bye
EOF
cd ..

echo "All eligible files were uploaded successfully."
read -p "Would you like to revert all or some files (A/S/N): " choice
choice=`echo $choice | tr '[:lower:]' '[:upper:]'`
if [ "$choice" = "A" -o "$choice" = "ALL" ]; then
	for file in $files; do
		if test -e $2/$file.bak; then
			mv $2/$file.bak $2/$file
		fi
	done
elif [ "$choice" = "S" -o "$choice" = "SOME" ]; then
	for file in $files; do
		if test -e $2/$file.bak; then
			read -p "Would you like to revert $file (Y/N): " choice
			choice=`echo $choice | tr '[:lower:]' '[:upper:]'`
			if [ "$choice" = "Y" -o "$choice" = "YES" ]; then
				mv $2/$file.bak $2/$file
			fi
		fi
	done
fi

