import json
import boto3
import urllib.request
import urllib.parse
import os

def lambda_handler(event, context):
    # Initialize AWS clients with explicit region
    region = os.environ.get('LAMBDA_REGION', 'ap-south-1')
    ecs = boto3.client('ecs', region_name=region)
    ssm = boto3.client('ssm', region_name=region)
    ec2 = boto3.client('ec2', region_name=region)
    
    # Get environment variables
    cluster_name = os.environ.get('CLUSTER_NAME', 'ecommerce-fargate-cluster')
    service_name = os.environ.get('SERVICE_NAME', 'ecommerce-fargate-service')
    app_name = os.environ.get('APP_NAME', 'ecommerce-fargate')
    
    print(f"Processing event: {json.dumps(event)}")
    
    try:
        detail = event.get('detail', {})
        cluster_arn = detail.get('clusterArn', '')
        task_arn = detail.get('taskArn', '')
        last_status = detail.get('lastStatus', '')
        
        print(f"Task status: {last_status}, Cluster: {cluster_arn}, Task: {task_arn}")
        
        if last_status != 'RUNNING':
            return {'statusCode': 200, 'body': 'Task not running'}
        
        response = ecs.describe_tasks(cluster=cluster_arn, tasks=[task_arn])
        if not response['tasks']:
            return {'statusCode': 404, 'body': 'Task not found'}
        
        task = response['tasks'][0]
        eni_id = None
        for attachment in task.get('attachments', []):
            for detail in attachment.get('details', []):
                if detail['name'] == 'networkInterfaceId':
                    eni_id = detail['value']
                    break
        
        if not eni_id:
            return {'statusCode': 404, 'body': 'Network interface not found'}
        
        response = ec2.describe_network_interfaces(NetworkInterfaceIds=[eni_id])
        if not response['NetworkInterfaces']:
            return {'statusCode': 404, 'body': 'Network interface details not found'}
        
        public_ip = response['NetworkInterfaces'][0].get('Association', {}).get('PublicIp')
        if not public_ip:
            return {'statusCode': 404, 'body': 'Public IP not found'}
        
        new_api_url = f"http://{public_ip}:8080"
        
        try:
            current_url = ssm.get_parameter(Name='ecommerce-api-url')['Parameter']['Value']
        except:
            current_url = ""
        
        if new_api_url == current_url:
            return {'statusCode': 200, 'body': 'IP unchanged'}
        
        ssm.put_parameter(Name='ecommerce-api-url', Value=new_api_url, Type='String', Overwrite=True)
        print(f"Updated SSM parameter: ecommerce-api-url = {new_api_url}")
        
        # Update Vercel environment variable
        vercel_token = os.environ.get('VERCEL_TOKEN')
        vercel_project_id = os.environ.get('VERCEL_PROJECT_ID')
        
        if vercel_token and vercel_project_id and vercel_token != 'PLACEHOLDER':
            try:
                vercel_headers = {
                    'Authorization': f'Bearer {vercel_token}',
                    'Content-Type': 'application/json'
                }
                
                vercel_data = {
                    'key': 'BACKEND_API_URL',
                    'value': new_api_url,
                    'type': 'encrypted',
                    'target': ['production']
                }
                
                # Use urllib instead of requests
                url = f'https://api.vercel.com/v9/projects/{vercel_project_id}/env'
                data = json.dumps(vercel_data).encode('utf-8')
                
                req = urllib.request.Request(url, data=data, headers=vercel_headers, method='POST')
                
                try:
                    with urllib.request.urlopen(req, timeout=10) as response:
                        if response.status in [200, 201]:
                            print(f"Updated Vercel environment variable: BACKEND_API_URL = {new_api_url}")
                        else:
                            print(f"Failed to update Vercel env var: {response.status}")
                except urllib.error.HTTPError as http_err:
                    print(f"HTTP error updating Vercel: {http_err.code}")
                except urllib.error.URLError as url_err:
                    print(f"URL error updating Vercel: {url_err.reason}")
                    
            except Exception as vercel_error:
                print(f"Vercel update error: {str(vercel_error)}")
        else:
            print("Vercel credentials not configured, skipping Vercel update")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'IP updated successfully',
                'old_url': current_url,
                'new_url': new_api_url,
                'public_ip': public_ip,
                'cluster': cluster_name,
                'service': service_name
            })
        }
        
    except Exception as e:
        return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}