# Manual Steps
1. After `terraform apply`, go to AWS ACM console.
2. get the created certificate DNS validation TXT record rfom the output and add to the DNS provider
4. Wait until ACM cert status shows `ISSUED`.
5. switch `manual_step` to true
6. RE run the apply
7. Add a CNAME in GoDaddy:
    - Name: `app`
    - Value: your CloudFront domain (e.g., `d1234abcd.cloudfront.net`)


