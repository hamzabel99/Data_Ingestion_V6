import boto3
import json
from datetime import datetime
import os

dynamodb = boto3.resource("dynamodb")
WORKFLOW_STATUS_TABLE = os.environ.get("WORKFLOW_STATUS_TABLE")
table = dynamodb.Table(WORKFLOW_STATUS_TABLE)

def lambda_handler(event, context):
    """
    Event attendu depuis Step Function :
    {
      "input_bucket": "...",
      "s3_key": "...",
      "--input_event": {
        "files_to_process": [...]
      }
    }
    """
    
    print(f"📥 Event reçu: {json.dumps(event, indent=2)}")
    
    files_to_process = []
    
    if "--input_event" in event:
        input_event = event["--input_event"]
        
        if isinstance(input_event, str):
            input_event = json.loads(input_event)
        
        if isinstance(input_event, dict):
            files_to_process = input_event.get("files_to_process", [])
        elif isinstance(input_event, list):
            files_to_process = input_event
    
    elif "files_to_process" in event:
        files_to_process = event["files_to_process"]
    
    else:
        raise ValueError("Impossible de trouver les fichiers à traiter dans l'event")
    
    if not files_to_process:
        print("⚠️ Aucun fichier trouvé dans files_to_process")
        return {"updated": 0}

    print(f"📁 {len(files_to_process)} fichiers à marquer comme DONE")
    
    updated_count = 0
    for f in files_to_process:
        s3_key = f["s3_key"]

        try:
            table.update_item(
                Key={"s3_prefix": s3_key},
                UpdateExpression="SET end_time = :et, #st = :st",
                ExpressionAttributeValues={
                    ":et": datetime.utcnow().isoformat(),
                    ":st": "DONE",
                },
                ExpressionAttributeNames={
                    "#st": "workflow_status"  
                },
            )
            updated_count += 1
            print(f" Fichier {s3_key} marqué DONE")
            
        except Exception as e:
            print(f"Erreur lors de la mise à jour de {s3_key}: {e}")
            raise

    print(f"🎉 Workflow terminé - {updated_count} fichiers mis à jour")
    return {
        "updated": updated_count,
        "files_processed": [f["s3_key"] for f in files_to_process]
    }