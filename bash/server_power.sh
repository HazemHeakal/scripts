#!/bin/bash

INSTANCE_ID=""
LOAD_BALANCER_NAME=""

# Step 1: Start the instance
echo "Starting the Windows server..."
aws ec2 start-instances --instance-ids $INSTANCE_ID
aws ec2 wait instance-running --instance-ids $INSTANCE_ID
echo "Windows server is now running."

# Step 2: Perform health checks (optional)
echo "Checking server readiness..."
SSM_COMMAND_ID=$(aws ssm send-command \
    --document-name "AWS-RunPowerShellScript" \
    --targets "Key=instanceIds,Values=$INSTANCE_ID" \
    --parameters '{"commands":["Get-Service -Name W3SVC"]}' \
    --query "Command.CommandId" --output text)

# Wait for health check completion (optional)
aws ssm wait command-executed --command-id "$SSM_COMMAND_ID" --instance-id "$INSTANCE_ID"
echo "Health check completed."

# Step 3: Add to the load balancer
echo "Adding server to the load balancer..."
aws elb register-instances-with-load-balancer \
    --load-balancer-name $LOAD_BALANCER_NAME \
    --instances $INSTANCE_ID
echo "Server registered to the load balancer."

# Step 4: Stop the instance
echo "Stopping the Windows server..."
aws ec2 stop-instances --instance-ids $INSTANCE_ID
aws ec2 wait instance-stopped --instance-ids $INSTANCE_ID
echo "Windows server is now stopped but still registered with the load balancer."