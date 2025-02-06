#!/usr/bin/env python3

import boto3
import json

def get_security_group_info(region, sg_identifier):
    """Fetch security group details, rules, and attached resources"""
    ec2 = boto3.client('ec2', region_name=region)
    
    # Identify SG by ID or Name
    sgs = ec2.describe_security_groups(Filters=[{'Name': 'group-id', 'Values': [sg_identifier]}])['SecurityGroups']
    if not sgs:
        sgs = ec2.describe_security_groups(Filters=[{'Name': 'group-name', 'Values': [sg_identifier]}])['SecurityGroups']
    if not sgs:
        print(f"❌ Security Group '{sg_identifier}' not found in region {region}.")
        return None

    sg = sgs[0]  # Assume one SG found
    sg_id = sg['GroupId']
    sg_name = sg.get('GroupName', 'Unknown')
    vpc_id = sg.get('VpcId', 'Unknown')
    description = sg.get('Description', 'No description')

    # Get EC2 instances using SG
    instances = ec2.describe_instances(Filters=[{"Name": "instance.group-id", "Values": [sg_id]}])['Reservations']
    ec2_instances = [i['Instances'][0]['InstanceId'] for i in instances if i['Instances']]

    # Get RDS instances using SG
    rds_client = boto3.client('rds', region_name=region)
    rds_instances = [
        db['DBInstanceIdentifier']
        for db in rds_client.describe_db_instances()['DBInstances']
        if any(sg['VpcSecurityGroupId'] == sg_id for sg in db['VpcSecurityGroups'])
    ]

    # Get Load Balancers using SG
    elb_client = boto3.client('elbv2', region_name=region)
    elbs = [
        lb['LoadBalancerArn']
        for lb in elb_client.describe_load_balancers()['LoadBalancers']
        if sg_id in lb.get('SecurityGroups', [])
    ]

    # Identify rules that allow 0.0.0.0/0 (Open to the world)
    open_rules = [rule for rule in sg.get('IpPermissions', []) if any(ip['CidrIp'] == '0.0.0.0/0' for ip in rule.get('IpRanges', []))]
    affected_resources = {'EC2': ec2_instances, 'RDS': rds_instances, 'ELB': elbs} if open_rules else {}

    # Format the report
    report = f"""
    AWS Security Group Report
    ==========================
    Region: {region}
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

    Rules Allowing 0.0.0.0/0:
    --------------------------
    {json.dumps(open_rules, indent=4) if open_rules else "None"}

    Resources Associated with Open Rules:
    -------------------------------------
    {json.dumps(affected_resources, indent=4) if affected_resources else "None"}
    """

    filename = f"sg_report_{sg_id}.txt"
    with open(filename, "w") as file:
        file.write(report)

    print(f"\n✅ Security Group report saved: {filename}")

    return sg_id, sg.get('IpPermissions', []), vpc_id, open_rules  # Return values for migration

def create_new_sg(region, old_sg_id, old_sg_rules, vpc_id, open_rules):
    """Create a new security group without 0.0.0.0/0 rules"""
    ec2 = boto3.client('ec2', region_name=region)

    # Create a new security group
    new_sg_name = f"migrated-{old_sg_id}"
    new_sg = ec2.create_security_group(
        GroupName=new_sg_name,
        Description=f"Replacement for {old_sg_id} without 0.0.0.0/0",
        VpcId=vpc_id
    )
    new_sg_id = new_sg['GroupId']
    print(f"✅ Created new Security Group: {new_sg_id}")

    # Remove rules with 0.0.0.0/0
    sanitized_rules = [
        rule for rule in old_sg_rules
        if not any(ip['CidrIp'] == '0.0.0.0/0' for ip in rule.get('IpRanges', []))
    ]

    # Copy only the safe rules to the new SG
    if sanitized_rules:
        ec2.authorize_security_group_ingress(GroupId=new_sg_id, IpPermissions=sanitized_rules)
    print(f"✅ Copied {len(sanitized_rules)} rules to new SG (0.0.0.0/0 rules removed)")

    return new_sg_id

if __name__ == "__main__":
    region = input("Enter AWS Region: ").strip()
    sg_identifier = input("Enter Security Group ID or Name: ").strip()

    sg_id, old_rules, vpc_id, open_rules = get_security_group_info(region, sg_identifier)
    if sg_id:
        create_new_sg(region, sg_id, old_rules, vpc_id, open_rules)
