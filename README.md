# status_page
This app uses vite with the Javascript variant of React.

`npm install` when opening the repo for the first time

`npm run dev` to start the development server



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
2. `aws s3 sync dist/ s3://d4cg-status-prod-bucket --delete --profile luca_pcdc_prod`
3. `aws cloudfront create-invalidation --distribution-id ENO6Q90NRR8H9 --paths "/*" --profile luca_pcdc_prod`
