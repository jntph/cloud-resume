import json
import logging
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('cloud-resume-counter')


def lambda_handler(event, context):
    logger.info(json.dumps({
        "message": "visitor counter invoked",
        "requestId": context.aws_request_id,
    }))

    try:
        response = table.update_item(
            Key={'id': 'visitors'},
            UpdateExpression='ADD #count :inc',
            ExpressionAttributeNames={'#count': 'count'},
            ExpressionAttributeValues={':inc': 1},
            ReturnValues='UPDATED_NEW'
        )

        count = int(response['Attributes']['count'])

        logger.info(json.dumps({
            "message": "counter updated",
            "requestId": context.aws_request_id,
            "count": count,
        }))

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': 'https://jannatp.com'
            },
            'body': json.dumps({'count': count})
        }

    except Exception as e:
        logger.error(json.dumps({
            "message": "failed to update counter",
            "requestId": context.aws_request_id,
            "error": str(e),
        }))
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': 'https://jannatp.com'
            },
            'body': json.dumps({'error': 'internal server error'})
        }
