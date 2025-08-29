import boto3
from boto3.dynamodb.conditions import Key
import os
import json
from datetime import datetime

# Tables DynamoDB
WORKFLOW_STATUS_TABLE = os.environ.get("WORKFLOW_STATUS_TABLE")
WORKFLOW_METADATA_TABLE = os.environ.get("WORKFLOW_METADATA_TABLE")

dynamodb = boto3.resource('dynamodb')
sfn_client = boto3.client('stepfunctions')

queue_table = dynamodb.Table(WORKFLOW_STATUS_TABLE)
metadata_table = dynamodb.Table(WORKFLOW_METADATA_TABLE)

def get_parent_prefix(s3_key):
   
    parts = s3_key.split('/')
    if len(parts) <= 1:
        return s3_key  
    return '/'.join(parts[:-1])


def lambda_handler(event, context):
    response = queue_table.scan(
        FilterExpression=Key('workflow_status').eq('TODO')
    )
    items = response.get('Items', [])

    if not items:
        print("No pending files found.")
        return {"processed": 0}

    prefix_map = {}
    for item in items:
        parent_prefix = get_parent_prefix(item['s3_prefix'])
        prefix_map.setdefault(parent_prefix, []).append(item)

    processed_count = 0

    for prefix, files in prefix_map.items():
        metadata = metadata_table.get_item(Key={'s3_prefix': prefix}).get('Item')
        if not metadata:
            print(f"No metadata found for prefix {prefix}, skipping.")
            continue

        batch_size = metadata.get('batch_size', 1)
        step_function_arn = metadata.get('step_function_arn')

        if len(files) >= batch_size:
            s3_keys = [{"s3_key": f['s3_prefix'], "input_bucket": f['s3_bucket']} for f in files]

            input_payload = {"files_to_process": s3_keys}
            response = sfn_client.start_execution(
                stateMachineArn=step_function_arn,
                input=json.dumps(input_payload)
            )
            print(f"Started Step Function {step_function_arn} for prefix {prefix}, executionArn: {response['executionArn']}")

            with queue_table.batch_writer() as batch:
                for f in files:
                    batch.put_item(
                        Item={
                            "s3_prefix": f["s3_prefix"],
                            "s3_bucket": f["s3_bucket"],
                            "workflow_status": "processing",
                            "upload_time": f["upload_time"],
                            "start_time": datetime.utcnow().isoformat()
                        }
                    )

            processed_count += len(files)
        else:
            print(f"Not enough files for prefix {prefix}. Needed {batch_size}, found {len(files)}.")

    return {"processed": processed_count}
