✅ **What this does:**
- Hosts React app on S3 with CloudFront (HTTPS via ACM)
- Backend with Lambda + API Gateway (HTTP API)
- Uses ACM, you will manually validate DNS in GoDaddy (no Route 53)

✅ **Manual Steps:**
1. After `terraform apply`, go to AWS ACM console.
2. Find the created certificate and copy the DNS validation TXT record.
3. Add the TXT record in GoDaddy DNS for your domain (e.g., `_acme-challenge.app`).
4. Wait until ACM cert status shows `ISSUED`.
5. Add a CNAME in GoDaddy:
    - Name: `app`
    - Value: your CloudFront domain (e.g., `d1234abcd.cloudfront.net`)