#!/bin/bash

# Prompt for the file containing tags, instance ID or name, and the region
read -p "Enter the file containing tags: " tag_file
read -p "Enter the EC2 instance ID or name: " instance_id_or_name
read -p "Enter the AWS region (e.g., us-east-1): " aws_region

# Check if the tag file exists
if [[ ! -f "$tag_file" ]]; then
    echo "Error: File '$tag_file' not found!"
    exit 1
fi

# Get the instance ID using the instance name
instance_id=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$instance_id_or_name" --query "Reservations[*].Instances[*].InstanceId" --region "$aws_region" --output text)

# Check if the instance ID was found
if [[ -z "$instance_id" ]]; then
    echo "Error: Instance '$instance_id_or_name' not found in region '$aws_region'!"
    exit 1
fi

# Read tags from the file and format them for AWS CLI
tags=()
while IFS= read -r line; do
    tags+=("Key=$(echo "$line" | cut -d '=' -f 1),Value=$(echo "$line" | cut -d '=' -f 2)")
done < "$tag_file"

# Construct the tag specification for the AWS CLI command
tag_spec="ResourceType=instance,Tags=[${tags[*]}]"

# Add tags to the specified instance
aws ec2 create-tags --resources "$instance_id" --tags "${tags[@]}" --region "$aws_region"

if [[ $? -eq 0 ]]; then
    echo "Tags added successfully to instance '$instance_id' in region '$aws_region'."
else
    echo "Failed to add tags to instance '$instance_id' in region '$aws_region'."
fi