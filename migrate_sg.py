import boto3
import time

def migrate_security_group(region, old_sg_id, new_sg_name):
    """Create new SG, copy rules, update resources, delete old SG"""
    ec2 = boto3.client('ec2', region_name=region)
    
    # Get old SG details
    sg_info = ec2.describe_security_groups(GroupIds=[old_sg_id])['SecurityGroups'][0]
    vpc_id = sg_info['VpcId']
    
    # Create new security group
    new_sg = ec2.create_security_group(
        GroupName=new_sg_name,
        Description=f"Replacement for {old_sg_id}",
        VpcId=vpc_id
    )
    new_sg_id = new_sg['GroupId']

    # Copy rules from old SG
    if 'IpPermissions' in sg_info:
        ec2.authorize_security_group_ingress(GroupId=new_sg_id, IpPermissions=sg_info['IpPermissions'])
    if 'IpPermissionsEgress' in sg_info:
        ec2.authorize_security_group_egress(GroupId=new_sg_id, IpPermissions=sg_info['IpPermissionsEgress'])

    print(f"✅ New Security Group Created: {new_sg_id}")

    # Find resources using old SG
    ec2_instances = ec2.describe_instances(Filters=[{"Name": "instance.group-id", "Values": [old_sg_id]}])['Reservations']
    instances = [i['Instances'][0]['InstanceId'] for i in ec2_instances if i['Instances']]

    rds_client = boto3.client('rds', region_name=region)
    rds_instances = [
        db['DBInstanceIdentifier']
        for db in rds_client.describe_db_instances()['DBInstances']
        if any(sg['VpcSecurityGroupId'] == old_sg_id for sg in db['VpcSecurityGroups'])
    ]

    elb_client = boto3.client('elbv2', region_name=region)
    elbs = [
        lb['LoadBalancerArn']
        for lb in elb_client.describe_load_balancers()['LoadBalancers']
        if old_sg_id in lb.get('SecurityGroups', [])
    ]

    # Update resources
    for instance_id in instances:
        ec2.modify_instance_attribute(InstanceId=instance_id, Groups=[new_sg_id])

    for rds_id in rds_instances:
        rds_client.modify_db_instance(DBInstanceIdentifier=rds_id, VpcSecurityGroupIds=[new_sg_id])

    for lb_arn in elbs:
        elb_client.modify_load_balancer_attributes(
            LoadBalancerArn=lb_arn,
            Attributes=[{'Key': 'security-groups', 'Value': new_sg_id}]
        )

    print(f"✅ Updated {len(instances)} EC2 instances, {len(rds_instances)} RDS instances, and {len(elbs)} Load Balancers.")

    # Delete old SG if not in use
    in_use = ec2.describe_network_interfaces(Filters=[{"Name": "group-id", "Values": [old_sg_id]}])['NetworkInterfaces']
    if not in_use:
        ec2.delete_security_group(GroupId=old_sg_id)
        print(f"🗑 Deleted old Security Group: {old_sg_id}")
    else:
        print(f"⚠️ Old SG {old_sg_id} is still in use and was NOT deleted.")

if __name__ == "__main__":
    region = input("Enter AWS Region: ").strip()
    old_sg_id = input("Enter Old Security Group ID or Name: ").strip()
    new_sg_name = input("Enter New Security Group Name: ").strip()
    migrate_security_group(region, old_sg_id, new_sg_name)