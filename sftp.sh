#!/bin/bash

#export SSHPASS=$pass

sftp -oBatchMode=no -b - $user@$host <<!
   put test.asp
   bye
!
