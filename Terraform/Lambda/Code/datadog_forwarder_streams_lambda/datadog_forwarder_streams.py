import json
import boto3
import os
import time
from datetime import datetime
from datadog import initialize, api

def get_datadog_credentials():

    try:
        ssm = boto3.client('ssm')
        api_key = ssm.get_parameter(Name='/datadog/api_key', WithDecryption=True)['Parameter']['Value']
        app_key = ssm.get_parameter(Name='/datadog/app_key', WithDecryption=True)['Parameter']['Value']
        return api_key, app_key
    except Exception as e:
        print(f"Utilisation des variables d'environnement: {e}")
        return os.environ['DATADOG_API_KEY'], os.environ['DATADOG_APP_KEY']


api_key, app_key = get_datadog_credentials()
initialize(api_key=api_key, app_key=app_key)

def lambda_handler(event, context):
    
    current_time = int(time.time())
    metrics_to_send = []
    
    print(f"Traitement de {len(event['Records'])} records DynamoDB")
    
    for record in event['Records']:
        try:
            if record['eventName'] != 'MODIFY':
                continue
            
            
            old_image = record.get('dynamodb', {}).get('OldImage', {})
            new_image = record.get('dynamodb', {}).get('NewImage', {})
            
            if not old_image or not new_image:
                continue
            
            old_status = old_image.get('workflow_status', {}).get('S', '')
            new_status = new_image.get('workflow_status', {}).get('S', '')
            
            if old_status == 'processing' and new_status == 'DONE':
                print(f"🎉 Workflow terminé détecté: {new_image.get('s3_prefix', {}).get('S', 'unknown')}")
                
                s3_bucket = new_image.get('s3_bucket', {}).get('S', 'unknown')
                s3_prefix = new_image.get('s3_prefix', {}).get('S', 'unknown')
                upload_time = new_image.get('upload_time', {}).get('S', '')
                start_time = new_image.get('start_time', {}).get('S', '')
                end_time = new_image.get('end_time', {}).get('S', '')
                
               
                processing_duration = None
                total_duration = None
                
                try:
                    if start_time and end_time:
                        start_dt = datetime.fromisoformat(start_time)
                        end_dt = datetime.fromisoformat(end_time)
                        processing_duration = (end_dt - start_dt).total_seconds()
                        
                    if upload_time and end_time:
                        upload_dt = datetime.fromisoformat(upload_time)
                        end_dt = datetime.fromisoformat(end_time)
                        total_duration = (end_dt - upload_dt).total_seconds()
                        
                except Exception as e:
                    print(f"Erreur calcul durée: {e}")
                
                folder_prefix = s3_prefix.split('/')[0] if '/' in s3_prefix else 'root'
                file_extension = s3_prefix.split('.')[-1] if '.' in s3_prefix else 'unknown'
                
             
                common_tags = [
                    f'bucket:{s3_bucket}',
                    f'folder:{folder_prefix}',
                    f'file_type:{file_extension}',
                    'status:completed',
                    'source:dynamodb_stream'
                ]
                
                
                metrics_to_send.append({
                    'metric': 'workflow.completion.count',
                    'points': [(current_time, 1)],
                    'tags': common_tags,
                    'type': 'count'
                })
                
                
                if processing_duration is not None:
                    metrics_to_send.append({
                        'metric': 'workflow.processing.duration_seconds',
                        'points': [(current_time, processing_duration)],
                        'tags': common_tags
                    })
                    
                    print(f" Durée de traitement: {processing_duration:.2f}s")
                
                
                if total_duration is not None:
                    metrics_to_send.append({
                        'metric': 'workflow.total.duration_seconds',
                        'points': [(current_time, total_duration)],
                        'tags': common_tags
                    })
                    
                    print(f" Durée totale: {total_duration:.2f}s")
                
             
                completion_hour = datetime.now().strftime('%H')
                metrics_to_send.append({
                    'metric': 'workflow.completion.by_hour',
                    'points': [(current_time, 1)],
                    'tags': common_tags + [f'hour:{completion_hour}'],
                    'type': 'count'
                })
        

                size_bytes = record.get('dynamodb', {}).get('SizeBytes', 0)
                if size_bytes > 0:
                    metrics_to_send.append({
                        'metric': 'workflow.file.size_bytes',
                        'points': [(current_time, size_bytes)],
                        'tags': common_tags
                    })
                
                print(f"Préparé {len(metrics_to_send)} métriques pour {s3_prefix}")
                
        except Exception as e:
            print(f" Erreur traitement record: {e}")
            continue
    
    print(f"Metrics to send : {metrics_to_send}")

    if metrics_to_send:
        try:
            api.Metric.send(metrics_to_send)
            print(f"Envoyé {len(metrics_to_send)} métriques à Datadog avec succès")
            
            for metric in metrics_to_send:
                print(f"   {metric['metric']}: {metric['points'][0][1]} (tags: {metric.get('tags', [])})")
                
        except Exception as e:
            print(f" Erreur envoi Datadog: {e}")
          
    else:
        print(" Aucun changement processing → DONE détecté dans ce batch")
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': f'Traité {len(event["Records"])} records',
            'metrics_sent': len(metrics_to_send)
        })
    }

def extract_workflow_metadata(new_image):
    
    metadata = {}
    
    s3_prefix = new_image.get('s3_prefix', {}).get('S', '')
    if s3_prefix:
        metadata['filename'] = s3_prefix.split('/')[-1]
        metadata['folder_path'] = '/'.join(s3_prefix.split('/')[:-1]) if '/' in s3_prefix else ''
        metadata['file_extension'] = s3_prefix.split('.')[-1] if '.' in s3_prefix else 'unknown'
    
    timestamps = {}
    for time_field in ['upload_time', 'start_time', 'end_time']:
        time_value = new_image.get(time_field, {}).get('S', '')
        if time_value:
            try:
                timestamps[time_field] = datetime.fromisoformat(time_value)
            except:
                pass
    
    metadata['timestamps'] = timestamps
    
    return metadata