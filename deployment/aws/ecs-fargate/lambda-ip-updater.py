import json
import boto3
import requests
import os

def lambda_handler(event, context):
    """
    AWS Lambda function triggered by ECS task state changes
    Automatically updates Vercel when ECS task gets new IP
    """
    
    # Initialize AWS clients
    ecs = boto3.client('ecs')
    ssm = boto3.client('ssm')
    ec2 = boto3.client('ec2')
    
    try:
        # Parse ECS event
        detail = event.get('detail', {})
        cluster_arn = detail.get('clusterArn', '')
        task_arn = detail.get('taskArn', '')
        last_status = detail.get('lastStatus', '')
        
        # Only process RUNNING tasks
        if last_status != 'RUNNING':
            return {'statusCode': 200, 'body': 'Task not running, skipping'}
        
        # Get task details
        response = ecs.describe_tasks(
            cluster=cluster_arn,
            tasks=[task_arn]
        )
        
        if not response['tasks']:
            return {'statusCode': 404, 'body': 'Task not found'}
        
        task = response['tasks'][0]
        
        # Extract network interface ID
        eni_id = None
        for attachment in task.get('attachments', []):
            for detail in attachment.get('details', []):
                if detail['name'] == 'networkInterfaceId':
                    eni_id = detail['value']
                    break
        
        if not eni_id:
            return {'statusCode': 404, 'body': 'Network interface not found'}
        
        # Get public IP
        response = ec2.describe_network_interfaces(
            NetworkInterfaceIds=[eni_id]
        )
        
        if not response['NetworkInterfaces']:
            return {'statusCode': 404, 'body': 'Network interface details not found'}
        
        public_ip = response['NetworkInterfaces'][0].get('Association', {}).get('PublicIp')
        
        if not public_ip:
            return {'statusCode': 404, 'body': 'Public IP not found'}
        
        new_api_url = f"http://{public_ip}:8080"
        
        # Check if IP changed
        try:
            current_url = ssm.get_parameter(Name='ecommerce-api-url')['Parameter']['Value']
        except:
            current_url = ""
        
        if new_api_url == current_url:
            return {'statusCode': 200, 'body': 'IP unchanged'}
        
        # Update parameter store
        ssm.put_parameter(
            Name='ecommerce-api-url',
            Value=new_api_url,
            Type='String',
            Overwrite=True
        )
        
        # Trigger Vercel deployment webhook (if configured)
        vercel_webhook = os.environ.get('VERCEL_WEBHOOK_URL')
        if vercel_webhook:
            requests.post(vercel_webhook, json={'api_url': new_api_url})
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'IP updated successfully',
                'old_url': current_url,
                'new_url': new_api_url,
                'public_ip': public_ip
            })
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }