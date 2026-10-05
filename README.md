# Node.js API and SQL Server on AWS

Node.js 24 API running on Lambda, with IAM-authenticated API Gateway routes and a private RDS SQL Server Web database. Terraform creates the infrastructure; GitHub Actions deploys API code changes.

Database passwords stay in Secrets Manager.

## What you need

- Terraform >= 1.10 and < 2.0, Node.js 24, AWS CLI v2 and Git.
- AWS credentials for a provisioning role with the required permissions.
- Your own GitHub repository if you want to test CI/CD.

## AWS permissions

See [IAM permissions](docs/permissions.md) for provisioning,
cleanup, bootstrap and authenticated API-testing policies.


## Deployment Steps

1. Clone or fork the repository.

2. From the repository root, copy the configuration:

   ```powershell
   Copy-Item infra/environments/dev/terraform.tfvars.example `
     infra/environments/dev/terraform.tfvars
   ```

   Set your region, project, repository, environment and exact GitHub
   OIDC subject. Never commit this file.

3. Create both Lambda packages:

   ```powershell
   .\scripts\package.ps1
   ```

   Requires Windows PowerShell, Node.js 24 and npm.

4. Provision the infrastructure:

   ```powershell
   Set-Location infra/environments/dev

   terraform init
   terraform validate
   terraform plan "-out=deployment.tfplan"
   terraform show deployment.tfplan
   terraform apply deployment.tfplan
   ```

   Review the plan before applying. Applying the saved plan starts
   provisioning immediately.

## Initialise the database

After Terraform apply succeeds, run from the same directory:

```powershell
$function = terraform output -raw bootstrap_function_name

aws lambda invoke `
  --function-name $function `
  --cli-read-timeout 150 `
  bootstrap-result.json

Get-Content bootstrap-result.json
```

Check that the invocation has no `FunctionError` and the result reports
`status: ok`.

Bootstrap reads the RDS-managed admin secret, creates `application_db`
and the restricted `api_user`, and stores application credentials in
Secrets Manager. The API uses this application login rather than the
administrator account.


## Test

Get the endpoint URLs:

```
terraform output -raw health_url
terraform output -raw database_health_url
```

Both routes require IAM authentication. Use SigV4-signed GET requests with a role allowed to perform `execute-api:Invoke` on the output route ARNs. Opening the URLs directly in a browser normally returns 403.

Test scripts are stored in Scripts folder
Test Locally:  
```
node --check app/index.js

node -e "require('./app/index').handler({rawPath:'/health',requestContext:{http:{method:'GET'}}}).then(r=>console.log(r.body)).catch(e=>{console.error(e);process.exit(1)})"
```
Expected responses:

- `/health`: HTTP 200, `{"status":"ok"}`
- `/health/db`: HTTP 200, `{"status":"ok","database":"ok"}`

## GitHub deployment

Create a GitHub environment named `dev`, restricted to `main`.

Repository variables:

- `AWS_DEPLOY_ENABLED=true`
- `DEPLOY_ENVIRONMENT=dev`

Environment variables:

- `AWS_REGION`: your deployment region
- `AWS_DEPLOY_ROLE_ARN`: Terraform's `github_deploy_role_arn`
- `API_FUNCTION_NAME`: Terraform's `api_function_name`

Run **API CI/CD** on `main`. If OIDC authentication fails, copy the exact `sub` from **Check OIDC identity** into `github_oidc_subject`, apply Terraform and retry. Subject formats can include repository IDs.

The pipeline updates the existing API Lambda; it does not provision infrastructure.


## Cleanup

Set `AWS_DEPLOY_ENABLED=false`. Change RDS `deletion_protection` to `false`, apply that change, then review and run `terraform destroy`.
