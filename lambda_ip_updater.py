import json
import boto3
import urllib.request
import os

def lambda_handler(event, context):
    region = os.environ.get('LAMBDA_REGION', 'ap-south-1')
    ecs = boto3.client('ecs', region_name=region)
    ssm = boto3.client('ssm', region_name=region)
    ec2 = boto3.client('ec2', region_name=region)

    detail = event.get('detail', {})
    cluster_arn = detail.get('clusterArn', '')
    task_arn = detail.get('taskArn', '')
    last_status = detail.get('lastStatus', '')

    if last_status != 'RUNNING':
        return {'statusCode': 200, 'body': 'Task not running'}

    response = ecs.describe_tasks(cluster=cluster_arn, tasks=[task_arn])
    if not response['tasks']:
        return {'statusCode':404,'body':'Task not found'}

    task = response['tasks'][0]
    eni_id = None
    for attachment in task.get('attachments',[]):
        for d in attachment.get('details',[]):
            if d.get('name') == 'networkInterfaceId':
                eni_id = d.get('value')
    if not eni_id:
        return {'statusCode':404,'body':'ENI not found'}

    response = ec2.describe_network_interfaces(NetworkInterfaceIds=[eni_id])
    if not response['NetworkInterfaces']:
        return {'statusCode':404,'body':'NI not found'}
    public_ip = response['NetworkInterfaces'][0].get('Association',{}).get('PublicIp')
    if not public_ip:
        return {'statusCode':404,'body':'Public IP not found'}

    new_api_url = f"http://{public_ip}:8080"
    try:
        current_url = ssm.get_parameter(Name='ecommerce-api-url')['Parameter']['Value']
    except Exception:
        current_url = ''
    if new_api_url == current_url:
        return {'statusCode':200,'body':'No change'}
    ssm.put_parameter(Name='ecommerce-api-url', Value=new_api_url, Type='String', Overwrite=True)

    netlify_token = os.environ.get('NETLIFY_TOKEN')
    netlify_site_id = os.environ.get('NETLIFY_SITE_ID')
    netlify_build_hook = os.environ.get('NETLIFY_BUILD_HOOK')

    if netlify_token and netlify_site_id:
        headers = {'Authorization': f'Bearer {netlify_token}','Content-Type':'application/json'}
        data = json.dumps({'key':'REACT_APP_API_URL','value':new_api_url}).encode('utf-8')
        env_url = f'https://api.netlify.com/api/v1/sites/{netlify_site_id}/env'
        try:
            req = urllib.request.Request(env_url, data=data, headers=headers, method='POST')
            with urllib.request.urlopen(req, timeout=10) as r:
                pass
            if netlify_build_hook:
                build_req = urllib.request.Request(netlify_build_hook, method='POST')
                with urllib.request.urlopen(build_req, timeout=10) as r:
                    pass
        except Exception as e:
            print('Netlify update failed:', e)

    return {'statusCode':200,'body':'Updated'}
