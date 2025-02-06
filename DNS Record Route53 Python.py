import boto3

# Get the desired region and domain name from user input
region = input("Enter the region name: ")
domain_name = input("Enter the domain name: ")

# Create a Route 53 client
route53 = boto3.client('route53', region_name=region)

# Get the Hosted Zone ID for the domain
hosted_zones = route53.list_hosted_zones_by_name(
    DNSName=domain_name
)['HostedZones']
if hosted_zones:
    hosted_zone_id = hosted_zones[0]['Id'].split('/')[-1]
else:
    print(f"No Hosted Zone found for domain {domain_name}")
    exit()

# Get all record sets in the hosted zone
record_sets = route53.list_resource_record_sets(
    HostedZoneId=hosted_zone_id
)['ResourceRecordSets']

# Loop through each record set and print the DNS name
for record_set in record_sets:
    dns_name = record_set['Name']
    print(dns_name)
