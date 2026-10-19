import os

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError
from dotenv import load_dotenv


load_dotenv(dotenv_path='app/.env.local', override=True)

s3_client = boto3.client(
    's3',
    region_name='us-east-2',
    endpoint_url="https://s3.us-east-2.amazonaws.com",
    config=Config(signature_version='s3v4')
)
bucket_name = os.getenv('S3_BUCKET')

def _create_presigned_url(bucket_name, object_name, operation, expiration=3600):
    try:
        response = s3_client.generate_presigned_url(
            operation,
            Params={'Bucket': bucket_name, 'Key': object_name},
            ExpiresIn=expiration # Time in seconds before it expires
        )
    except ClientError as e:
        print(f"Error generating URL: {e}")
        return None

    return response


def create_presigned_upload_url(object_name):
    return _create_presigned_url(bucket_name, object_name, 'put_object')


def create_presigned_download_url(object_name):
    return _create_presigned_url(bucket_name, object_name, 'get_object')


def get_object(object_path):
    return s3_client.get_object(Bucket=bucket_name, Key=object_path)


def put_object(object_path, body, content_type):
    return s3_client.put_object(
        Bucket=bucket_name, Key=object_path, Body=body, ContentType=content_type
    )


def get_clip_object_name(id):
    return f'{id}-clip'


def get_computer_picture_object_name(id):
    return f'{id}-computer-picture-from-phone'


def get_screenshot_object_name(id):
    return f'{id}-screenshot'