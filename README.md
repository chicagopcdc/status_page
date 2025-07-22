# Status Page

This app implements a status page for several portal.pedscommons.org and gearbox.pedscommons.org endspoints. The app fetches from each endpoint status from the backend and displays whether an endpoint has no issues, is under maintenance, or has an outage (corresponding to the status strings `success`, `maintenance`, and `fail`).

This app uses vite with the Javascript variant of React.

## Getting Started 

`npm install` when opening the repo for the first time

`npm run dev` to start the development server


## Prerequisites

This Status Page requires the following to run:

- [Node.js v20.17.0](https://nodejs.org/en/download)
- [npm](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm)

## Configuration

Configuration data is located at `config/config.json`. Currently, the file configures which endpoint statuses are fetched (hostnames), what their display names are (urlToTitleDataMap), and the color and message of the banner (bannerConfig). 

#TODO in the github action add the folder name to the react code

### How to add GitHub secrets:
1️⃣ Go to your GitHub repository.
2️⃣ Click on `Settings` > `Secrets and variables` > `Actions`.
3️⃣ Click `New repository secret` for each:
- `AWS_ACCESS_KEY_ID`: Your AWS access key.
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret key.
- `S3_BUCKET_NAME`: The S3 bucket name created by Terraform.
- `AWS_REGION`: The AWS region where the resources are
- `CLOUDFRONT_DISTRIBUTION_ID`: The cloudfront distribution ID to invalidate the cache

The IAM user/role tied to these AWS credentials needs:
- s3:PutObject, s3:DeleteObject, s3:ListBucket on your bucket.
- cloudfront:CreateInvalidation on your distribution.


# React site
The REACT site should be pushed to S3 aumatically with the github action, but if you need to do it manually the process is:
1. `npm run build`
2. `aws s3 sync dist/ s3://d4cg-status-prod-bucket --delete --profile luca_pcdc_prod`
3. `aws cloudfront create-invalidation --distribution-id ENO6Q90NRR8H9 --paths "/*" --profile luca_pcdc_prod`

