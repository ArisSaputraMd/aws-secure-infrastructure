import boto3
import json
import os
from datetime import datetime, timedelta, timezone

wafv2 = boto3.client('wafv2')

# Environment variables — set these in Terraform, not hardcoded in code.
WEB_ACL_ARN = os.environ['WEB_ACL_ARN']
IP_SET_ID = os.environ['IP_SET_ID']
IP_SET_NAME = os.environ['IP_SET_NAME']

# Lambda handler
def lambda_handler(event, context):
    print("Lambda triggered:", json.dumps(event))
    
    sampled_requests = get_blocked_ips(WEB_ACL_ARN)  # <- no rule_name argument anymore
    worst_ip = find_worst_offender(sampled_requests)
    
    if worst_ip is None:
        print("No blocked requests found in sample window. Nothing to do.")
        return {"statusCode": 200, "body": "no action taken"}
    
    block_ip(IP_SET_ID, IP_SET_NAME, "REGIONAL", worst_ip)
    return {"statusCode": 200, "body": f"blocked {worst_ip}"}

#fetch sampled requests from WAF
def get_blocked_ips(web_acl_arn):
    end_time = datetime.now(timezone.utc)
    start_time = end_time - timedelta(minutes=5)
    
    response = wafv2.get_sampled_requests(
        WebAclArn=web_acl_arn,
        RuleMetricName='ALL',
        Scope='REGIONAL',
        TimeWindow={'StartTime': start_time, 'EndTime': end_time},
        MaxItems=100
    )
    return response['SampledRequests']

# count which IP shows up most
def find_worst_offender(sampled_requests):
    ip_counts = {}
    for request in sampled_requests:
        ip = request['Request']['ClientIP']
        ip_counts[ip] = ip_counts.get(ip, 0) + 1
    
    if not ip_counts:
        return None
    
    worst_ip = max(ip_counts, key=ip_counts.get)
    print(f"IP counts: {ip_counts}")
    return worst_ip


#update the WAF IP Set

def block_ip(ip_set_id, ip_set_name, scope, new_ip):
    current = wafv2.get_ip_set(Name=ip_set_name, Scope=scope, Id=ip_set_id)
    current_addresses = current['IPSet']['Addresses']
    lock_token = current['LockToken']
    
    new_entry = f"{new_ip}/32"
    if new_entry in current_addresses:
        print(f"{new_ip} already blocked.")
        return
    
    wafv2.update_ip_set(
        Name=ip_set_name,
        Scope=scope,
        Id=ip_set_id,
        Addresses=current_addresses + [new_entry],
        LockToken=lock_token
    )
    print(f"Blocked IP: {new_ip}")

