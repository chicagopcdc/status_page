# status_page

#TODO in the github action add the folder name to the react code

### How to add GitHub secrets:
1️⃣ Go to your GitHub repository.
2️⃣ Click on `Settings` > `Secrets and variables` > `Actions`.
3️⃣ Click `New repository secret` for each:
- `AWS_ACCESS_KEY_ID`: Your AWS access key.
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret key.
- `S3_BUCKET_NAME`: The S3 bucket name created by Terraform.


# React site
The REACT site should be pushed to S3 aumatically with the github action, but if you need to do it manually the process is:
1. `npm run build`
2. `aws s3 sync build/ s3://your-bucket-name --delete`
3. `aws cloudfront create-invalidation --distribution-id YOUR_DISTRIBUTION_ID --paths "/*"`