#!/bin/sh
yum install -y docker
service docker start

sudo docker run -dit -p 5000:5000 -e ACCESS_KEY="<ENTER ACCESS KEY>" -e SECRET_KEY="<ENTER SECRET KEY>" -e REGION="us-east-1" -e STREAM_NAME="<ENTER STREAM NAME>" yageldhn/flask_api_kinesis_producer:latest

