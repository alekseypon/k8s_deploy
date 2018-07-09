#!/bin/bash

sudo apt-get update
sudo apt-get -y install awscli nfs-common
# Get spot instance request tags to tags.json file
AWS_ACCESS_KEY_ID=$1 AWS_SECRET_ACCESS_KEY=$2 aws --region $3 ec2 describe-spot-instance-requests --spot-instance-request-ids $4 --query 'SpotInstanceRequests[0].Tags' > tags.json

# Set instance tags from tags.json file
AWS_ACCESS_KEY_ID=$1 AWS_SECRET_ACCESS_KEY=$2 aws --region $3 ec2 create-tags --resources $5 --tags file://tags.json && rm -rf tags.json

sudo apt-get -y upgrade

sudo su -c '(sleep 5 && reboot)&'
