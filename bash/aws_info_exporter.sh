#!/bin/bash

#Run those commands before running the script
#sudo apt-get install jq
#chmod +x aws_info_exporter.sh

# Output file
OUTPUT_FILE="load_balancer_info.txt"

# Remove output file if it exists
if [ -f "$OUTPUT_FILE" ]; then
    rm "$OUTPUT_FILE"
fi

# Function to append a section to the output file
append_section() {
    echo -e "$1" >> "$OUTPUT_FILE"
}

# Fetch Load Balancers
append_section "=== Load Balancers ===\n"

load_balancers=$(aws elbv2 describe-load-balancers --output json)
lb_arns=$(echo "$load_balancers" | jq -r '.LoadBalancers[].LoadBalancerArn')

for lb_arn in $lb_arns; do
    lb=$(echo "$load_balancers" | jq --arg arn "$lb_arn" '.LoadBalancers[] | select(.LoadBalancerArn == $arn)')
    lb_name=$(echo "$lb" | jq -r '.LoadBalancerName')
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
done

# Fetch Target Groups
append_section "=== Target Groups ===\n"

target_groups=$(aws elbv2 describe-target-groups --output json)
tg_arns=$(echo "$target_groups" | jq -r '.TargetGroups[].TargetGroupArn')

for tg_arn in $tg_arns; do
    tg=$(echo "$target_groups" | jq --arg arn "$tg_arn" '.TargetGroups[] | select(.TargetGroupArn == $arn)')
    tg_name=$(echo "$tg" | jq -r '.TargetGroupName')
    tg_protocol=$(echo "$tg" | jq -r '.Protocol')
    tg_port=$(echo "$tg" | jq -r '.Port')
    tg_vpc=$(echo "$tg" | jq -r '.VpcId')
    tg_type=$(echo "$tg" | jq -r '.TargetType')
    hc_protocol=$(echo "$tg" | jq -r '.HealthCheckProtocol')
    hc_path=$(echo "$tg" | jq -r '.HealthCheckPath // "N/A"')

    append_section "Name: $tg_name"
    append_section "  Protocol: $tg_protocol"
    append_section "  Port: $tg_port"
    append_section "  VPC ID: $tg_vpc"
    append_section "  Target Type: $tg_type"
    append_section "  Health Check Protocol: $hc_protocol"
    append_section "  Health Check Path: $hc_path"
    append_section ""
done

# Fetch EC2 Instances
append_section "=== EC2 Instances ===\n"

instances=$(aws ec2 describe-instances --output json)
instance_ids=$(echo "$instances" | jq -r '.Reservations[].Instances[].InstanceId')

for instance_id in $instance_ids; do
    instance=$(echo "$instances" | jq --arg id "$instance_id" '.Reservations[].Instances[] | select(.InstanceId == $id)')
    instance_type=$(echo "$instance" | jq -r '.InstanceType')
    instance_state=$(echo "$instance" | jq -r '.State.Name')
    public_ip=$(echo "$instance" | jq -r '.PublicIpAddress // "N/A"')
    private_ip=$(echo "$instance" | jq -r '.PrivateIpAddress // "N/A"')
    subnet_id=$(echo "$instance" | jq -r '.SubnetId')
    vpc_id=$(echo "$instance" | jq -r '.VpcId')
    tags=$(echo "$instance" | jq -r '.Tags[]? | "    - \(.Key): \(.Value)"')
    sgs=$(echo "$instance" | jq -r '.SecurityGroups[]? | "    - \(.GroupId) (\(.GroupName))"')

    append_section "Instance ID: $instance_id"
    append_section "  Instance Type: $instance_type"
    append_section "  State: $instance_state"
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

echo "AWS information has been successfully exported to '$OUTPUT_FILE'."