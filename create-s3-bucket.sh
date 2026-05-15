#!/bin/bash

BUCKET_NAME="seyi-my-project-bucket-2026"
REGION="eu-west-1"

echo "Creating bucket..."

aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region $REGION \
  --create-bucket-configuration LocationConstraint=$REGION

echo "Enabling versioning..."

aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

echo "Done."
