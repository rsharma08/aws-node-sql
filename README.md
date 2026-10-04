# Node.js API and SQL Server on AWS

Node.js 24 API running on Lambda, with IAM-authenticated API Gateway routes and a private RDS SQL Server Web database. Terraform creates the infrastructure; GitHub Actions deploys API code changes.

Database passwords stay in Secrets Manager.

## What you need

- Terraform >= 1.10 and < 2.0, Node.js 24, AWS CLI v2 and Git.
- AWS credentials for a provisioning role with the permissions listed in the IAM policy section.
- Your own GitHub repository if you want to test CI/CD.

## Deploy

1. Clone or fork the repository.
2. Copy `infra/environments/dev/terraform.tfvars.example` to `terraform.tfvars`. Set your region, project, repository, environment and exact GitHub OIDC subject.
3. From the repository root, run powershell scripts:

   ``
   .\scripts\package.ps1
   ```

   Requires Node.js 24, npm, zip and unzip. This creates both Lambda
   packages with their handlers, dependencies and TLS certificate bundle.
4. Provision from `infra/environments/dev`:

   ```powershell
   terraform init
   terraform validate
   terraform plan
   terraform apply
   ```


## Initialise the database

From the same Terraform directory:

```powershell
$function = terraform output -raw bootstrap_function_name

aws lambda invoke `
  --function-name $function `
  --cli-read-timeout 150 `
  bootstrap-result.json

Get-Content bootstrap-result.json
```

Check that the invocation has no `FunctionError` and the result reports `status: ok`.

The bootstrap Lambda reads the RDS-managed admin secret, creates `application_db`, creates or updates the restricted `api_user`, and stores its credentials in Secrets Manager. The API uses this application login, not the administrator account.

## Test

Get the endpoint URLs:

```powershell
terraform output -raw health_url
terraform output -raw database_health_url
```

Both routes require IAM authentication. Use SigV4-signed GET requests with a role allowed to perform `execute-api:Invoke` on the output route ARNs. Opening the URLs directly in a browser normally returns 403.

Test scripts are stored in Scripts folder

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
