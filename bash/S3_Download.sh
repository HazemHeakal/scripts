read s3
bash -c "mkdir /home/student/desktop/Marawan/$s3"
bash -c "aws s3 sync s3://$s3 /home/student/desktop/Marawan/$s3"
echo "Done"
