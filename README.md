# Node.js API and SQL Server on AWS

This repository provisions a Node.js 24 Lambda API, IAM-authenticated API Gateway HTTP routes, private RDS SQL Server Web, Secrets Manager, and a GitHub OIDC deployment role. Terraform provisions infrastructure; GitHub Actions deploys later API code changes. A separate, manually invoked bootstrap Lambda initializes the application database and credentials.

## Prerequisites and scope

- Terraform >= 1.10 and < 2.0; Node.js 24; npm; AWS CLI v2; Git.
- The identity must manage this stack's VPC resources, RDS, Lambda, HTTP API, CloudWatch Logs, Secrets Manager, IAM roles/inline policies, and GitHub OIDC provider. It needs scoped `iam:PassRole` for the Lambda roles, RDS service-linked-role creation if absent, and KMS permissions for AWS-managed encryption. `PowerUserAccess` alone does not provide the required IAM management access.
- Terraform provider read operations also need `ec2:DescribePrefixLists`, `lambda:GetFunctionCodeSigningConfig`; API creation/tagging needs both HTTP API operations and tagging permissions (`apigateway:TagResource`, `UntagResource`, and applicable `/tags/*` GET/POST/DELETE operations).
- For verification, grant `lambda:InvokeFunction` on bootstrap and `execute-api:Invoke` on the two route ARNs output by Terraform. The GitHub deployment role cannot provision infrastructure or run bootstrap.



