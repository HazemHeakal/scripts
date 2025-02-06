#!/bin/bash

# Replace with your AWS region
REGION="us-east-1"

# Get the Hosted Zone ID from user input
read -p "Enter the Hosted Zone ID: " HOSTED_ZONE_ID

# Get all record sets in the hosted zone
RECORD_SETS=$(aws route53 list-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --region "$REGION")

# Loop through each record set and print the DNS name
for ROW in $(echo "${RECORD_SETS}" | jq -r '.ResourceRecordSets[] | @base64'); do
  _jq() {
    echo "${ROW}" | base64 --decode | jq -r "${1}"
  }
  DNS_NAME=$(_jq '.Name')
  echo "$DNS_NAME"
done
