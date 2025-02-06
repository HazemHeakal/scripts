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
REGION="eu-west-1"  # You can update this with the correct AWS region

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

# Loop through the unique Target Groups and check if the instance is already in the target group
for TG_NAME in "${!UNIQUE_TARGET_GROUPS[@]}"; do
    echo "Looking up ARN for target group $TG_NAME"

    # Get the Target Group ARN by Name
    TG_ARN=$(aws elbv2 describe-target-groups --names "$TG_NAME" --region "$REGION" --query "TargetGroups[0].TargetGroupArn" --output text 2>&1)

    # Check if the ARN was successfully retrieved
    if [[ "$TG_ARN" == "An error occurred"* ]]; then
        echo "Failed to find ARN for target group $TG_NAME. Error: $TG_ARN"
        continue
    fi

    if [[ -z "$TG_ARN" ]]; then
        echo "Target group $TG_NAME returned an empty ARN. Skipping."
        continue
    fi

    echo "Successfully retrieved ARN: $TG_ARN"

    echo "Checking if instance $INSTANCE_ID is already in target group $TG_ARN"

    # Check if the instance is already registered in the target group
    INSTANCE_EXISTS=$(aws elbv2 describe-target-health --target-group-arn "$TG_ARN" --region "$REGION" --query "TargetHealthDescriptions[?Target.Id=='$INSTANCE_ID'].Target.Id" --output text 2>&1)

    if [[ "$INSTANCE_EXISTS" == "$INSTANCE_ID" ]]; then
        echo "Instance $INSTANCE_ID is already registered in target group $TG_NAME ($TG_ARN). Skipping."
        continue
    fi

    echo "Adding instance $INSTANCE_ID to target group $TG_ARN"
    
    # Register the instance with the target group
    output=$(aws elbv2 register-targets \
        --target-group-arn "$TG_ARN" \
        --targets Id="$INSTANCE_ID" \
        --region "$REGION" 2>&1)

    # Check the result of the registration
    if [ $? -eq 0 ]; then
        echo "Successfully added instance $INSTANCE_ID to target group $TG_ARN"
    else
        echo "Failed to add instance $INSTANCE_ID to target group $TG_ARN"
        echo "Error: $output"
    fi
done

echo "All unique target groups processed."