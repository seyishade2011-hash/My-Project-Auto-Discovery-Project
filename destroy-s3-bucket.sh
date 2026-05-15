#!/bin/bash

BUCKET_NAME="seyi-my-project-bucket-2026"

aws s3 rm s3://$BUCKET_NAME --recursive

aws s3api delete-bucket \
  --bucket $BUCKET_NAME

echo "Bucket deleted."
