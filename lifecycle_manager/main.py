import json
import urllib.request
import boto3
import os

sqs = boto3.client('sqs')
autoscaling = boto3.client('autoscaling')
ssm = boto3.client('ssm')
api_key = ssm.get_parameter(Name=os.environ.get("SPACELIFT_API_KEY_SECRET_NAME"), WithDecryption=True)['Parameter']['Value']

domain = os.environ.get("SPACELIFT_API_KEY_ENDPOINT", None)
api_key_id = os.environ.get("SPACELIFT_API_KEY_ID", None)
worker_pool_id = os.environ.get("SPACELIFT_WORKER_POOL_ID", None)
queue_url = os.environ.get("QUEUE_URL", None)

def query_api(query: str, variables: dict = None, token: str = None) -> dict:
    headers = {
        "Content-Type": "application/json",
    }

    if token is not None:
        headers["Authorization"] = f"Bearer {token}"

    data = {
        "query": query,
    }

    if variables is not None:
        data["variables"] = variables

    req = urllib.request.Request(f"{domain}/graphql", json.dumps(data).encode('utf-8'), headers)
    with urllib.request.urlopen(req) as response:
        resp = json.loads(response.read().decode('utf-8'))

    if "errors" in resp:
        print(f"Error: {resp['errors']}")
        return resp
    else:
        return resp

def get_token():
    token_mutation = """
        mutation GetSpaceliftToken($id: ID!, $secret: String!) {
            apiKeyUser(id: $id, secret: $secret) {
                jwt
            }
        }
    """

    token_variables = {
        "id": api_key_id,
        "secret": api_key
    }

    token_response = query_api(token_mutation, token_variables)
    return token_response["data"]["apiKeyUser"]["jwt"]

def get_workerpool(token):
    workerpool_query = """
        query GetWorkerpool($id: ID!) {
            workerPool(id: $id) {
                workers {
                    id
                    metadata
                }
            }
        }
    """
    workerpool_variables = {
        "id": worker_pool_id
    }
    workerpool_response = query_api(workerpool_query, workerpool_variables, token)
    workers = workerpool_response["data"]["workerPool"]["workers"]

    # Convert the workers list to a map of instance_id => worker_id for faster lookup
    instance_id_to_worker = {}
    for worker in workers:
        instance_id = json.loads(worker["metadata"])["instance_id"]
        if instance_id:
            instance_id_to_worker[instance_id] = worker["id"]

    return instance_id_to_worker

def drain_worker(worker, token):
    print(f"Draining worker {worker}")
    drain_mutation = """
        mutation DrainWorker($workerPool: ID!, $id: ID!, $drain: Boolean!) {
            workerDrainSet(workerPool: $workerPool, id: $id, drain: $drain) {
                busy
            }
        }
    """
    drain_variables = {
        "id": worker,
        "workerPool": worker_pool_id,
        "drain": True
    }
    drain_response = query_api(drain_mutation, drain_variables, token)
    if "errors" in drain_response:
        print(f"Drain Error: {drain_response['errors']}")
        return False

    if drain_response["data"]["workerDrainSet"]["busy"]:
        print(f"Worker {worker} is still busy after draining.")
        return False
    else:
        print("Drain Success!")
        return True

def complete_hook(lifecycle_hook_name, autoscaling_group_name, lifecycle_action_token, instance_id):
    status = autoscaling.complete_lifecycle_action(
        LifecycleHookName=lifecycle_hook_name,
        AutoScalingGroupName=autoscaling_group_name,
        LifecycleActionToken=lifecycle_action_token,
        LifecycleActionResult="CONTINUE",
        InstanceId=instance_id
    )
    if "ResponseMetadata" in status and "HTTPStatusCode" in status["ResponseMetadata"]:
        if status["ResponseMetadata"]["HTTPStatusCode"] == 200:
            print(f"Lifecycle hook completed successfully for instance {instance_id}.")
            return True
        else:
            print(f"Failed to complete lifecycle hook for instance {instance_id}.")

    return False


def put_message_back_on_queue(event):
    delay_seconds = 2
    retry = 1
    if "retry" in event:
        delay_seconds = event["retry"]["delay_seconds"] * 2
        retry = event["retry"]["retry"] + 1

    if delay_seconds >= 15 * 60:
        delay_seconds = 15 * 60

    event["retry"] = {
        "delay_seconds": delay_seconds,
        "retry": retry
    }

    if event["retry"]["retry"] >= 30:
        # We should hit this after about 45 minutes of retrying
        # This is a safety net to prevent infinite retries
        print("Max retries reached. Not retrying. Dropping Message")
        return

    print(f"Retrying event in {delay_seconds} seconds.")
    sqs.send_message(
        QueueUrl=queue_url,
        MessageBody=json.dumps(event),
        DelaySeconds=delay_seconds
    )

def main(event, context):
    print(event)

    token = get_token()
    workers = get_workerpool(token)

    for record in event["Records"]:
        body = json.loads(record["body"])

        if "Event" in body and body["Event"] == "autoscaling:TEST_NOTIFICATION":
            print("Received test notification. Skipping")
            continue

        instance_id = body["EC2InstanceId"] if "EC2InstanceId" in body else None
        lifecycle_hook_name = body["LifecycleHookName"] if "LifecycleHookName" in body else None
        autoscaling_group_name = body["AutoScalingGroupName"] if "AutoScalingGroupName" in body else None
        lifecycle_action_token = body["LifecycleActionToken"] if "LifecycleActionToken" in body else None

        if instance_id is None or lifecycle_hook_name is None or autoscaling_group_name is None or lifecycle_action_token is None:
            print("Missing required fields in the event. Skipping")
            continue

        worker = workers.get(instance_id)

        if worker:
            success = drain_worker(worker, token)
            if not success:
                put_message_back_on_queue(body)
            else:
                success = complete_hook(lifecycle_hook_name, autoscaling_group_name, lifecycle_action_token, instance_id)
                if not success:
                    put_message_back_on_queue(body)
        else:
            print(f"No worker found for instance ID {instance_id}.")