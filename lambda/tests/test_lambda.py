import json
from unittest.mock import MagicMock, patch


def make_context():
    ctx = MagicMock()
    ctx.aws_request_id = "test-request-id"
    return ctx


@patch('lambda_function.table')
def test_returns_200(mock_table):
    mock_table.update_item.return_value = {'Attributes': {'count': 42}}

    from lambda_function import lambda_handler
    result = lambda_handler({}, make_context())

    assert result['statusCode'] == 200


@patch('lambda_function.table')
def test_returns_count(mock_table):
    mock_table.update_item.return_value = {'Attributes': {'count': 42}}

    from lambda_function import lambda_handler
    result = lambda_handler({}, make_context())

    body = json.loads(result['body'])
    assert body['count'] == 42


@patch('lambda_function.table')
def test_cors_header(mock_table):
    mock_table.update_item.return_value = {'Attributes': {'count': 1}}

    from lambda_function import lambda_handler
    result = lambda_handler({}, make_context())

    assert result['headers']['Access-Control-Allow-Origin'] == 'https://jannatp.com'


@patch('lambda_function.table')
def test_uses_atomic_increment(mock_table):
    mock_table.update_item.return_value = {'Attributes': {'count': 1}}

    from lambda_function import lambda_handler
    lambda_handler({}, make_context())

    call_kwargs = mock_table.update_item.call_args.kwargs
    assert 'ADD' in call_kwargs['UpdateExpression']
    assert call_kwargs['ReturnValues'] == 'UPDATED_NEW'


@patch('lambda_function.table')
def test_returns_500_on_dynamodb_error(mock_table):
    mock_table.update_item.side_effect = Exception("DynamoDB unavailable")

    from lambda_function import lambda_handler
    result = lambda_handler({}, make_context())

    assert result['statusCode'] == 500
    body = json.loads(result['body'])
    assert 'error' in body
