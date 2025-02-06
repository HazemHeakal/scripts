#!/bin/bash

# Check if instance ID and file are provided as command-line arguments
if [ $# -lt 2 ]; then
  echo "Usage: $0 <instance-id> <input-file>"
  exit 1
fi

# Define the instance ID and input file from the command-line arguments
INSTANCE_ID="$1"
INPUT_FILE="$2"

# Define the region (update this as necessary)
REGION="us-east-1"  # Make sure to update this with the correct AWS region

# Check if the input file exists
if [ ! -f "$INPUT_FILE" ]; then
  echo "Input file $INPUT_FILE not found!"
  exit 1
fi

# Declare an associative array to store unique Target Group Names
declare -A UNIQUE_TARGET_GROUPS

# Extract Target Group Names from the file under the section '=== Target Groups for Load Balancer'
in_target_group_section=false
while IFS= read -r line; do
  # Check if we are in the Target Group section
  if [[ "$line" =~ "=== Target Groups for Load Balancer" ]]; then
    in_target_group_section=true
    continue
  fi

  # Exit the loop if we reach a new section or the end of the Target Group section
  if [[ "$line" =~ "===" ]] && [ "$in_target_group_section" = true ]; then
    break
  fi

  # Only process lines with 'Name:'
  if [ "$in_target_group_section" = true ] && [[ "$line" =~ "Name:" ]]; then
    TG_NAME=$(echo "$line" | awk -F': ' '{print $2}')
    UNIQUE_TARGET_GROUPS["$TG_NAME"]=1  # Store the unique target group name
  fi
done < "$INPUT_FILE"

# Check if any unique Target Groups were found
if [ ${#UNIQUE_TARGET_GROUPS[@]} -eq 0 ]; then
  echo "No target groups found in the file!"
  exit 1
fi

# Loop through the unique Target Groups and deregister the instance unconditionally
for TG_NAME in "${!UNIQUE_TARGET_GROUPS[@]}"; do
    echo "Fetching ARN for target group $TG_NAME"

    # Get the Target Group ARN using its name
    TG_ARN=$(aws elbv2 describe-target-groups --names "$TG_NAME" --region "$REGION" --query "TargetGroups[0].TargetGroupArn" --output text 2>&1)

    if [[ "$TG_ARN" == "An error occurred"* ]]; then
        echo "Failed to retrieve ARN for target group $TG_NAME"
        continue
    fi

    echo "Deregistering instance $INSTANCE_ID from target group $TG_NAME"

    # Deregister the instance from the target group by ARN
    output=$(aws elbv2 deregister-targets \
        --target-group-arn "$TG_ARN" \
        --targets Id="$INSTANCE_ID" \
        --region "$REGION" 2>&1)

    # Check the result of the deregistration
    if [ $? -eq 0 ]; then
        echo "Successfully deregistered instance $INSTANCE_ID from target group $TG_NAME"
    else
        echo "Failed to deregister instance $INSTANCE_ID from target group $TG_NAME"
        echo "Error: $output"
    fi
done

echo "All unique target groups processed."