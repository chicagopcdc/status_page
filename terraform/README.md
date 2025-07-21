# Manual Steps
1. build the lambda function
2. terraform init
3. After `terraform apply`, go to AWS ACM console.
4. get the created certificate DNS validation TXT record rfom the output and add to the DNS provider
5. Wait until ACM cert status shows `ISSUED`.
6. switch `manual_step` to true
7. RE run the apply
8. Add a CNAME in GoDaddy:
    - Name: `your subdomain`
    - Value: your CloudFront domain (e.g., `d1234abcd.cloudfront.net`)


