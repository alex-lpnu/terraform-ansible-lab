#!/bin/bash

terraform apply -auto-approve

rm -rf jupyter_ssh.pem
terraform output -raw jupyter_ssh_private_key > jupyter_ssh.pem
chmod 400 jupyter_ssh.pem

ansible-playbook -i inventory.txt app.yml