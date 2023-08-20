#!/bin/bash

# Ensure that AK, SK, and Task ID are provided
if [ $# -lt 3 ]; then
    echo -e "[WARN]\tUsage: $0 <app_key> <app_secret> <task_id>"
    exit 1
fi

app_key=$1
app_secret=$2
task_id=$3
force_download=$4
resign=$5

skip_get_url="0"

file_name="download-cache-$task_id.txt"
if [ -f $file_name ]; then
    length=$(cat $file_name | grep http | wc -l)
    if [ $length -gt 0 ]; then
        echo -e "[INFO]\tSkip get url as the cache file exists"
        skip_get_url="1"
    fi
fi

if [[ $force_download -eq 1 ]]; then
    echo -e "[INFO]\tForce download initiated"
    skip_get_url="0"
fi

if [ $skip_get_url == "0" ]; then
    echo -e "[INFO]\tGet the download URLs"

    # Get the access token
    response=$(curl -s -X POST "https://app-gateway.realsee.cn/auth/access_token" -H "accept: application/json" -H "content-type: application/x-www-form-urlencoded" -d "app_key=$app_key&app_secret=$app_secret")
    access_token=$(echo $response | grep -o '"access_token":.*,' | awk -F: '{print $2}' | sed 's/[",]//g')
    if [ -z "$access_token" ]; then
        echo -e "[ERROR]\tFailed to get access token"
        exit 1
    fi

    # Get the task details
    detail=$(curl -s -X GET "https://app-gateway.realsee.cn/open/v3/shepherd/task/detail?task_id=$task_id" -H "accept: application/json" -H "authorization: $access_token")

    # Extract download URLs
    urls=$(echo $detail | grep -o '"url":"[^"]*' | grep -o '[^"]*$')
    if [ -z "$urls" ]; then
        echo -e "[ERROR]\tFailed to get download URLs"
        exit 1
    fi

    if [[ $resign -eq 1 ]]; then
        # Store paths in an array
        declare -a paths

        pathnames=$(echo $detail | grep -o '"pathname":"[^"]*' | grep -o '[^"]*$')
        for pathname in $pathnames; do
            paths+=("\""$pathname"\"")
        done

        # Join paths with commas for JSON array
        joined_paths=$(
            IFS=','
            echo "[${paths[*]}]"
        )

        curl_sign_response=$(curl -s --location 'https://app-gateway.realsee.cn/staticize/v1/sign' \
            --header "Authorization: $access_token" \
            --header 'Content-Type: application/json' \
            --data "{
        \"storage_type\": \"tencent_cdn\",
        \"ttl\": 3600,
        \"paths\": $joined_paths
    }")

        # Extract presigned_urls to an array
        presigned_urls_string=$(echo $curl_sign_response | grep -o '\["[^]]*\]' | sed 's/\[//g;s/\]//g;s/"//g;s/ //g')
        IFS=','
        read -ra presigned_urls <<<"$presigned_urls_string"

        if [ -z "$presigned_urls" ]; then
            echo -e "[ERROR]\tFailed to get presigned URLs"
            exit 1
        fi

        urls="${presigned_urls[*]}"
    fi

    # Clear the cache file
    echo -e "[INFO]\tRemove the cache file"
    rm -rf $file_name

    if [ -z "$urls" ]; then
        echo -e "[ERROR]\tThe download URLs are empty"
        exit 1
    fi

    for url in $urls; do
        echo $url >>$file_name
    done
else
    urls=$(cat $file_name | grep http)
fi

mkdir -p download

# Download files
for url in $urls; do
    # Extract filename from URL
    filename=$(echo $url | grep -o '[^/]*.zip')
    echo -e "[INFO]\tFile name is "$filename
    if [ -f $filename ]; then
        echo -e "[WARN]\tSkip download as the file exists"
        continue
    fi

    target="./download/$filename"

    if [ -f "$target.tmp" ]; then
        echo -e "[WARN]\tDelete the tmp file first"
        rm "$target.tmp"
    fi

    echo -e "[INFO]\tDownloading "$filename" to "$target".tmp"
    wget -O "$target.tmp" $url -q --show-progress

    echo -e "[INFO]\tDownloaded "$filename" to "$target".tmp"
    mv "$target.tmp" "$target"
done

echo -e "[INFO]\tAll files downloaded, please check the download folder, then unzip the files"
