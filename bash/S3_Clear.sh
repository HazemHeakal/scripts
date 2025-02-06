aws configure
printf "==========================================\n"
printf "PLEASE insert S3 bucket url\nNote: Make sure the bucket is empty first\n\nS3 URL (ex:s3://bucket-name) : "; read s3
aws s3 rm $s3 --recursive
