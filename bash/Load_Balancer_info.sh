#!/bin/bash

# Set the AWS region here
REGION="us-east-1"  # Change this to the desired AWS region

# Run these commands before running the script
# sudo apt-get install jq
# chmod +x aws_info_exporter.sh

# Check if Load Balancer name is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <Load Balancer Name>"
    exit 1
fi

LB_NAME=$1

# Output file
OUTPUT_FILE="${LB_NAME}.txt"

# Remove output file if it exists
if [ -f "$OUTPUT_FILE" ]; then
    rm "$OUTPUT_FILE"
fi

# Function to append a section to the output file
append_section() {
    echo -e "$1" >> "$OUTPUT_FILE"
}

# Fetch Load Balancers
append_section "=== Load Balancer Information for '$LB_NAME' ===\n"

load_balancers=$(aws elbv2 describe-load-balancers --region "$REGION" --output json)
lb=$(echo "$load_balancers" | jq --arg name "$LB_NAME" '.LoadBalancers[] | select(.LoadBalancerName == $name)')

if [ -z "$lb" ]; then
    echo "Load Balancer '$LB_NAME' not found."
    exit 1
fi

lb_name=$(echo "$lb" | jq -r '.LoadBalancerName')
lb_arn=$(echo "$lb" | jq -r '.LoadBalancerArn')
lb_dns=$(echo "$lb" | jq -r '.DNSName')
lb_type=$(echo "$lb" | jq -r '.Type')
lb_scheme=$(echo "$lb" | jq -r '.Scheme')
lb_vpc=$(echo "$lb" | jq -r '.VpcId')
lb_state=$(echo "$lb" | jq -r '.State.Code')
azs=$(echo "$lb" | jq -r '.AvailabilityZones[] | "    - \(.ZoneName) (Subnet ID: \(.SubnetId))"')
lb_sgs=$(echo "$lb" | jq -r '.SecurityGroups[]? | "    - \(. // "None")"')

append_section "Name: $lb_name"
append_section "  DNS Name: $lb_dns"
append_section "  Type: $lb_type"
append_section "  Scheme: $lb_scheme"
append_section "  VPC ID: $lb_vpc"
append_section "  State: $lb_state"
append_section "  Availability Zones:"
append_section "$azs"
append_section "  Security Groups:"
append_section "${lb_sgs:-    - None}"
append_section ""

# Fetch Listeners associated with the LB to get certificates
append_section "=== Listeners and Certificates for Load Balancer '$LB_NAME' ===\n"

listeners=$(aws elbv2 describe-listeners --load-balancer-arn "$lb_arn" --region "$REGION" --output json)
listener_arns=$(echo "$listeners" | jq -r '.Listeners[].ListenerArn')

for listener_arn in $listener_arns; do
    listener=$(echo "$listeners" | jq --arg arn "$listener_arn" '.Listeners[] | select(.ListenerArn == $arn)')
    listener_protocol=$(echo "$listener" | jq -r '.Protocol')
    listener_port=$(echo "$listener" | jq -r '.Port')

    append_section "Listener Protocol: $listener_protocol"
    append_section "  Port: $listener_port"

    # Fetch Certificates only if listener is HTTPS
    if [[ "$listener_protocol" == "HTTPS" ]]; then
        certificates=$(echo "$listener" | jq -r '.Certificates[]? | "    - Certificate ARN: \(.CertificateArn)"')
        append_section "  Certificates:"
        append_section "${certificates:-    - None}"
    else
        append_section "  No certificates for this listener (Protocol: $listener_protocol)"
    fi

    # Fetch Listener rules for each listener
    append_section "  Listener Rules:"

    listener_rules=$(aws elbv2 describe-rules --listener-arn "$listener_arn" --region "$REGION" --output json)
    rules=$(echo "$listener_rules" | jq -r '.Rules[]')

    echo "$rules" | jq -c '.' | while read rule; do
        priority=$(echo "$rule" | jq -r '.Priority')
        conditions=$(echo "$rule" | jq -r '.Conditions[] | "\(.Field): \(.Values[] // .HostHeaderConfig.Values[] // .PathPatternConfig.Values[])"')
        actions=$(echo "$rule" | jq -r '.Actions[] | "Type: \(.Type), Target Group ARN: \(.TargetGroupArn // "N/A")"')

        append_section "    - Rule Priority: $priority"
        append_section "      Conditions:"
        append_section "        $conditions"
        append_section "      Actions:"
        append_section "        $actions"
    done
    append_section ""

done

# Fetch Target Groups associated with the LB
append_section "=== Target Groups for Load Balancer '$LB_NAME' ===\n"

target_groups=$(aws elbv2 describe-target-groups --load-balancer-arn "$lb_arn" --region "$REGION" --output json)
tg_names=$(echo "$target_groups" | jq -r '.TargetGroups[].TargetGroupName')

for tg_name in $tg_names; do
    append_section "Target Group Name: $tg_name"
done

# Fetch EC2 Instances and their health status associated with the Load Balancer's target groups
append_section "=== EC2 Instances and Health Status behind Load Balancer '$LB_NAME' ===\n"

# Loop through each target group and get the registered targets (instances) and health status
for tg_arn in $tg_arns; do
    append_section "Target Group ARN: $tg_arn"

    targets=$(aws elbv2 describe-target-health --target-group-arn "$tg_arn" --region "$REGION" --output json)
    target_health_descriptions=$(echo "$targets" | jq -r '.TargetHealthDescriptions[]')

    echo "$target_health_descriptions" | jq -c '.' | while read target; do
        instance_id=$(echo "$target" | jq -r '.Target.Id')
        health_state=$(echo "$target" | jq -r '.TargetHealth.State')

        instance=$(aws ec2 describe-instances --instance-ids "$instance_id" --region "$REGION" --output json)
        instance_type=$(echo "$instance" | jq -r '.Reservations[].Instances[].InstanceType')
        instance_state=$(echo "$instance" | jq -r '.Reservations[].Instances[].State.Name')
        public_ip=$(echo "$instance" | jq -r '.Reservations[].Instances[].PublicIpAddress // "N/A"')
        private_ip=$(echo "$instance" | jq -r '.Reservations[].Instances[].PrivateIpAddress // "N/A"')
        subnet_id=$(echo "$instance" | jq -r '.Reservations[].Instances[].SubnetId')
        vpc_id=$(echo "$instance" | jq -r '.Reservations[].Instances[].VpcId')
        tags=$(echo "$instance" | jq -r '.Reservations[].Instances[].Tags[]? | "    - \(.Key): \(.Value)"')
        sgs=$(echo "$instance" | jq -r '.Reservations[].Instances[].SecurityGroups[]? | "    - \(.GroupId) (\(.GroupName))"')

        append_section "Instance ID: $instance_id"
        append_section "  Instance Type: $instance_type"
        append_section "  State: $instance_state"
        append_section "  Health Status: $health_state"  # Print the health status
        append_section "  Public IP: $public_ip"
        append_section "  Private IP: $private_ip"
        append_section "  Subnet ID: $subnet_id"
        append_section "  VPC ID: $vpc_id"
        append_section "  Security Groups:"
        append_section "${sgs:-    - None}"
        append_section "  Tags:"
        append_section "${tags:-    - None}"
        append_section ""
    done
done

echo "AWS information for Load Balancer '$LB_NAME' has been successfully exported to '$OUTPUT_FILE'."