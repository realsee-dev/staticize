#!/bin/bash

# Ensure that AK, SK, and Task ID are provided
if [ $# -lt 3 ]; then
    echo -e "[ERROR]\tPlease provide the app key, app_secret, and resource_code"
    exit 1
fi

app_key=$1
app_secret=$2
resource_code=$3

# Get the access token
response=$(curl -s -X POST "https://app-gateway.realsee.cn/auth/access_token" -H "accept: application/json" -H "content-type: application/x-www-form-urlencoded" -d "app_key=$app_key&app_secret=$app_secret")
access_token=$(echo $response | grep -o '"access_token":.*,' | awk -F: '{print $2}' | sed 's/[",]//g')
if [ -z "$access_token" ]; then
    echo -e "[ERROR]\tFailed to get access token"
    exit 1
fi

# Create the task
response=$(curl -s -X POST "https://app-gateway.realsee.cn/open/v3/shepherd/task/create" -H "content-type: application/json" -H "authorization: $access_token" -d '{"task_type":"staticize","task_input":{"resource_code":"'$resource_code'"}}')

task_id=$(echo $response | sed -n 's|.*"task_id":"\([^"]*\)".*|\1|p')
if [ -z "$task_id" ]; then
    echo -e "[ERROR]\tFailed to create the task"
    echo $response
    exit 1
fi

echo -e "[INFO]\tTask ID: $task_id"
