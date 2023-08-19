#!/bin/bash

# Ensure that AK, SK, and Task ID are provided
if [ $# -ne 3 ]; then
    echo "Usage: $0 <app_key> <app_secret> <task_id>"
    exit 1
fi

app_key=$1
app_secret=$2
task_id=$3

# Get the access token
response=$(curl -s -X POST "https://app-gateway.realsee.cn/auth/access_token" -H "accept: application/json" -H "content-type: application/x-www-form-urlencoded" -d "app_key=$app_key&app_secret=$app_secret")
access_token=$(echo $response | grep -o '"access_token":.*,' | awk -F: '{print $2}' | sed 's/[",]//g')

# Get the task details
detail=$(curl -s -X GET "https://app-gateway.realsee.cn/open/v3/shepherd/task/detail?task_id=$task_id" -H "accept: application/json" -H "authorization: $access_token")

# Extract download URLs
urls=$(echo $detail | grep -o '"url":"[^"]*' | grep -o '[^"]*$')

# Download files
for url in $urls; do
    # Extract filename from URL
    filename=$(echo $url | grep -o '[^/]*.zip')
    echo "The file name should be "$filename
    wget -O "$filename" $url
done
