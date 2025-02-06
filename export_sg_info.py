#!/usr/bin/env python3

import boto3
import json
import threading

def export_security_group(region, sg):
    """Export details of a single security group into a unique file."""
    sg_id = sg['GroupId']
    sg_name = sg.get('GroupName', 'Unknown')
    vpc_id = sg.get('VpcId', 'Unknown')
    description = sg.get('Description', 'No description')

    ec2 = boto3.client('ec2', region_name=region)
    rds_client = boto3.client('rds', region_name=region)
    elb_client = boto3.client('elbv2', region_name=region)

    # Get EC2 instances using this SG
    instances = ec2.describe_instances(Filters=[{"Name": "instance.group-id", "Values": [sg_id]}])['Reservations']
    ec2_instances = [i['Instances'][0]['InstanceId'] for i in instances if i['Instances']]

    # Get RDS instances using this SG
    rds_instances = [
        db['DBInstanceIdentifier']
        for db in rds_client.describe_db_instances()['DBInstances']
        if any(sg['VpcSecurityGroupId'] == sg_id for sg in db['VpcSecurityGroups'])
    ]

    # Get Load Balancers using this SG
    elbs = [
        lb['LoadBalancerArn']
        for lb in elb_client.describe_load_balancers()['LoadBalancers']
        if sg_id in lb.get('SecurityGroups', [])
    ]

    # Format the report
    report_content = f"""
    AWS Security Group Report - {region}
    ===================================
    Security Group ID: {sg_id}
    Name: {sg_name}
    VPC: {vpc_id}
    Description: {description}

    Rules:
    ------
    {json.dumps(sg.get('IpPermissions', []), indent=4)}

    Attached Resources:
    -------------------
    EC2 Instances: {', '.join(ec2_instances) if ec2_instances else 'None'}
    RDS Instances: {', '.join(rds_instances) if rds_instances else 'None'}
    Load Balancers: {', '.join(elbs) if elbs else 'None'}
    ===================================
    """

    # Save report in a unique file
    filename = f"sg_report_{sg_id}.txt"
    with open(filename, "w") as file:
        file.write(report_content)

    print(f"✅ Exported Security Group: {sg_id} -> {filename}")

def get_all_security_groups(region):
    """Fetch all security groups and create reports concurrently"""
    ec2 = boto3.client('ec2', region_name=region)
    
    # Get all security groups in the region
    security_groups = ec2.describe_security_groups()['SecurityGroups']

    if not security_groups:
        print(f"No security groups found in region {region}.")
        return

    print(f"🔎 Found {len(security_groups)} security groups in {region}. Exporting...")

    # Use threading for concurrent exports
    threads = []
    for sg in security_groups:
        thread = threading.Thread(target=export_security_group, args=(region, sg))
        thread.start()
        threads.append(thread)

    # Don't wait for all to finish (exports independently)
    print(f"🚀 Exporting security groups concurrently...")

if __name__ == "__main__":
    region = input("Enter AWS Region: ").strip()
    get_all_security_groups(region)