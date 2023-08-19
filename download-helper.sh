#!/bin/bash

# Ensure that AK, SK, and Task ID are provided
if [ $# -lt 3 ]; then
    echo "Usage: $0 <app_key> <app_secret> <task_id>"
    exit 1
fi

app_key=$1
app_secret=$2
task_id=$3
force_download=$4

skip_get_url="0"

file_name="download-cache-$task_id.txt"
if [ -f $file_name ]; then
    length=$(cat $file_name | grep http | wc -l)
    if [ $length -gt 0 ]; then
        echo "Skip get url as the cache file exists"
        skip_get_url="1"
    fi
fi

if [[ $force_download -eq 1 ]]; then
    echo "Force download initiated"
    skip_get_url="0"
fi

if [ $skip_get_url == "0" ]; then
    echo "Get the download URLs"

    # Get the access token
    response=$(curl -s -X POST "https://app-gateway.realsee.cn/auth/access_token" -H "accept: application/json" -H "content-type: application/x-www-form-urlencoded" -d "app_key=$app_key&app_secret=$app_secret")
    access_token=$(echo $response | grep -o '"access_token":.*,' | awk -F: '{print $2}' | sed 's/[",]//g')

    # Get the task details
    detail=$(curl -s -X GET "https://app-gateway.realsee.cn/open/v3/shepherd/task/detail?task_id=$task_id" -H "accept: application/json" -H "authorization: $access_token")

    # Extract download URLs
    urls=$(echo $detail | grep -o '"url":"[^"]*' | grep -o '[^"]*$')

    echo $urls"\n" >>$file_name
else
    urls=$(cat $file_name | grep http)
fi

mkdir -p download

# Download files
for url in $urls; do
    # Extract filename from URL
    filename=$(echo $url | grep -o '[^/]*.zip')
    echo "The file name should be "$filename
    if [ -f $filename ]; then
        echo "Skip download as the file exists"
        continue
    fi

    target="./download/$filename"

    if [ -f "$target.tmp" ]; then
        echo "Delete the tmp file first"
        rm "$target.tmp"
    fi

    wget -O "$target.tmp" $url -q --show-progress

    echo "Finished download then rename the file"
    mv "$target.tmp" "$target"
done

echo "Finished all the downloads, start to unzip the files"
