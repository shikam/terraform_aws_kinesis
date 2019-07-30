#!/usr/bin/python
from flask import Flask, request, jsonify
import json
import os
import boto3

# Connect to kinesis data stream. The credentials are from environment variables provided in the dockerfile.
client = boto3.client('kinesis', aws_access_key_id=os.environ['ACCESS_KEY'], aws_secret_access_key=os.environ['SECRET_KEY'], region_name=os.environ['REGION'])
# Start flask app
app = Flask(__name__)

# Get POST restful calls, to <url>:<ip>/producer address.
@app.route('/producer', methods = ['POST'])
def postJsonHandler():
    # Get the data that posted, as json, to the variable
    content = request.json
    print(content)
    # Put the data to the data stream
    response = client.put_record(
        StreamName=os.environ['STREAM_NAME'],
        Data=json.dumps(content),
        PartitionKey='directeam'
    )
    print "another one"
    # Return the data posted to the user (so he could see, if it worked)
    return jsonify(content)
# App can run on every host
app.run(host='0.0.0.0')
