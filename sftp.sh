#!/bin/bash

export SSHPASS=$pass
sshpass -e sftp -oBatchMode=no -b - $user@$host << !
   put fuckingfile.txt
   bye
!
