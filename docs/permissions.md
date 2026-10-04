# IAM permissions

These policies let an assessor provision the stack, initialise the database,
test the API and clean up afterwards.

An authorised AWS administrator attaches:

- **AssessmentNetwork**, **AssessmentServices** and **AssessmentIdentity**
  to the local Terraform provisioning role.
- **AssessmentVerification** to the role used for bootstrap and API testing.
  This can be the same provisioning role.

Keep each policy separate. These are permissions policies, not role trust
policies. The provisioning role also needs an appropriate trust relationship,
and its caller needs permission to assume it.

## Replace the placeholders

| Placeholder | Value |
|---|---|
| `<ACCOUNT_ID>` | Your AWS account ID |
| `<REGION>` | Your deployment region, such as `eu-west-2` |
| `<STACK_NAME>` | `${project}-${environment}`, such as `solirius-dev` |
| `<API_ID>` | The API ID created by Terraform |

Replace placeholders before adding the policies in AWS. If you change the
project or environment name, update the policy resource prefixes too.

For API testing, use the exact ARNs from these Terraform outputs:

```powershell
terraform output -raw health_invoke_arn
terraform output -raw database_health_invoke_arn
```

## Scope

These are practical assessment templates, not a production permission boundary.

Network mutations cover the selected region. API Gateway management covers
APIs in that region. Secrets creation and tagging allow RDS-generated secret
names. IAM role-policy management can grant powerful permissions within the
stack's role prefix. Use an isolated assessment account and a unique prefix.

Existing organisation policies, permission boundaries and KMS key policies
still apply. These templates use the standard AWS partition and AWS-managed
encryption keys. Custom keys or provider upgrades may need additional permissions.

The complete policy set has not been deployment-tested in a separate assessor
account.

## AssessmentNetwork

Includes network-interface deletion for cleanup after Lambda deletion.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "<REGION>"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateVpc",
        "ec2:DeleteVpc",
        "ec2:ModifyVpcAttribute",
        "ec2:CreateSubnet",
        "ec2:DeleteSubnet",
        "ec2:ModifySubnetAttribute",
        "ec2:CreateRouteTable",
        "ec2:DeleteRouteTable",
        "ec2:AssociateRouteTable",
        "ec2:DisassociateRouteTable",
        "ec2:ReplaceRouteTableAssociation",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:ModifySecurityGroupRules",
        "ec2:CreateVpcEndpoint",
        "ec2:ModifyVpcEndpoint",
        "ec2:DeleteVpcEndpoints",
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "ec2:DeleteNetworkInterface"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "<REGION>"
        }
      }
    }
  ]
}
```

## AssessmentServices

Manages RDS, Lambda, API Gateway, log groups and application-secret metadata.
The provisioning role does not need access to database secret values.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "rds:Describe*"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "<REGION>"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "rds:CreateDBInstance",
        "rds:ModifyDBInstance",
        "rds:DeleteDBInstance",
        "rds:CreateDBSubnetGroup",
        "rds:ModifyDBSubnetGroup",
        "rds:DeleteDBSubnetGroup",
        "rds:CreateDBParameterGroup",
        "rds:ModifyDBParameterGroup",
        "rds:ResetDBParameterGroup",
        "rds:DeleteDBParameterGroup",
        "rds:CreateDBSnapshot",
        "rds:AddTagsToResource",
        "rds:RemoveTagsFromResource",
        "rds:ListTagsForResource"
      ],
      "Resource": [
        "arn:aws:rds:<REGION>:<ACCOUNT_ID>:db:<STACK_NAME>*",
        "arn:aws:rds:<REGION>:<ACCOUNT_ID>:subgrp:<STACK_NAME>*",
        "arn:aws:rds:<REGION>:<ACCOUNT_ID>:pg:<STACK_NAME>*",
        "arn:aws:rds:<REGION>:<ACCOUNT_ID>:snapshot:<STACK_NAME>*",
        "arn:aws:rds:<REGION>:<ACCOUNT_ID>:og:default:sqlserver-web-*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "lambda:CreateFunction",
        "lambda:UpdateFunctionCode",
        "lambda:UpdateFunctionConfiguration",
        "lambda:DeleteFunction",
        "lambda:GetFunction",
        "lambda:GetFunctionConfiguration",
        "lambda:GetFunctionCodeSigningConfig",
        "lambda:GetPolicy",
        "lambda:AddPermission",
        "lambda:RemovePermission",
        "lambda:ListVersionsByFunction",
        "lambda:ListTags",
        "lambda:TagResource",
        "lambda:UntagResource",
        "lambda:GetFunctionConcurrency",
        "lambda:PutFunctionConcurrency",
        "lambda:DeleteFunctionConcurrency",
        "lambda:GetFunctionEventInvokeConfig",
        "lambda:GetRuntimeManagementConfig",
        "lambda:ListAliases"
      ],
      "Resource": "arn:aws:lambda:<REGION>:<ACCOUNT_ID>:function:<STACK_NAME>-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "apigateway:GET",
        "apigateway:POST",
        "apigateway:PUT",
        "apigateway:PATCH",
        "apigateway:DELETE",
        "apigateway:TagResource",
        "apigateway:UntagResource"
      ],
      "Resource": [
        "arn:aws:apigateway:<REGION>::/apis",
        "arn:aws:apigateway:<REGION>::/apis/*",
        "arn:aws:apigateway:<REGION>::/v2/apis",
        "arn:aws:apigateway:<REGION>::/v2/apis/*",
        "arn:aws:apigateway:<REGION>::/tags/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:DescribeLogGroups",
        "logs:DescribeResourcePolicies",
        "logs:PutResourcePolicy"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "<REGION>"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:DeleteLogGroup",
        "logs:PutRetentionPolicy",
        "logs:DeleteRetentionPolicy",
        "logs:ListTagsLogGroup",
        "logs:TagLogGroup",
        "logs:UntagLogGroup",
        "logs:ListTagsForResource",
        "logs:TagResource",
        "logs:UntagResource"
      ],
      "Resource": [
        "arn:aws:logs:<REGION>:<ACCOUNT_ID>:log-group:/aws/lambda/<STACK_NAME>-*",
        "arn:aws:logs:<REGION>:<ACCOUNT_ID>:log-group:/aws/apigateway/<STACK_NAME>-*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:CreateSecret",
        "secretsmanager:TagResource"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "<REGION>"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:ListSecretVersionIds",
        "secretsmanager:UpdateSecret",
        "secretsmanager:DeleteSecret",
        "secretsmanager:RestoreSecret",
        "secretsmanager:TagResource",
        "secretsmanager:UntagResource"
      ],
      "Resource": "arn:aws:secretsmanager:<REGION>:<ACCOUNT_ID>:secret:<STACK_NAME>/database/application-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:DescribeKey"
      ],
      "Resource": "arn:aws:kms:<REGION>:<ACCOUNT_ID>:key/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:CreateGrant"
      ],
      "Resource": "arn:aws:kms:<REGION>:<ACCOUNT_ID>:key/*",
      "Condition": {
        "Bool": {
          "kms:GrantIsForAWSResource": "true"
        },
        "StringEquals": {
          "kms:ViaService": "rds.<REGION>.amazonaws.com"
        }
      }
    }
  ]
}
```

## AssessmentIdentity

Manages the stack's IAM roles and inline policies. PassRole is restricted to
the API and bootstrap execution roles and the Lambda service.

If the account already has a GitHub OIDC provider, set `oidc_provider_arn`
to reuse it. Do not let this stack destroy a provider shared by other projects.
For a reused provider, remove its mutation permissions below if unnecessary.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:GetRole",
        "iam:UpdateRole",
        "iam:UpdateAssumeRolePolicy",
        "iam:DeleteRole",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:ListRoleTags",
        "iam:PutRolePolicy",
        "iam:GetRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies",
        "iam:ListInstanceProfilesForRole"
      ],
      "Resource": "arn:aws:iam::<ACCOUNT_ID>:role/<STACK_NAME>-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": [
        "arn:aws:iam::<ACCOUNT_ID>:role/<STACK_NAME>-lambda",
        "arn:aws:iam::<ACCOUNT_ID>:role/<STACK_NAME>-bootstrap"
      ],
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": "lambda.amazonaws.com"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateOpenIDConnectProvider",
        "iam:GetOpenIDConnectProvider",
        "iam:DeleteOpenIDConnectProvider",
        "iam:UpdateOpenIDConnectProviderThumbprint",
        "iam:AddClientIDToOpenIDConnectProvider",
        "iam:RemoveClientIDFromOpenIDConnectProvider",
        "iam:TagOpenIDConnectProvider",
        "iam:UntagOpenIDConnectProvider",
        "iam:ListOpenIDConnectProviderTags"
      ],
      "Resource": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:ListOpenIDConnectProviders"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateServiceLinkedRole"
      ],
      "Resource": "arn:aws:iam::<ACCOUNT_ID>:role/aws-service-role/rds.amazonaws.com/AWSServiceRoleForRDS",
      "Condition": {
        "StringEquals": {
          "iam:AWSServiceName": "rds.amazonaws.com"
        }
      }
    }
  ]
}
```

## AssessmentVerification

Allows manual database bootstrap and invocation of the two health routes.
Replace `<API_ID>` after provisioning.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "lambda:InvokeFunction"
      ],
      "Resource": "arn:aws:lambda:<REGION>:<ACCOUNT_ID>:function:<STACK_NAME>-bootstrap"
    },
    {
      "Effect": "Allow",
      "Action": [
        "execute-api:Invoke"
      ],
      "Resource": [
        "arn:aws:execute-api:<REGION>:<ACCOUNT_ID>:<API_ID>/$default/GET/health",
        "arn:aws:execute-api:<REGION>:<ACCOUNT_ID>:<API_ID>/$default/GET/health/db"
      ]
    }
  ]
}
```

## API testing

Both health routes require AWS IAM authentication. Being signed into AWS is
not enough: the testing role needs the invocation permissions above, and each
request must be SigV4-signed for service `execute-api` in the deployed region.

Opening an endpoint directly in a browser normally returns HTTP 403.

From Git Bash at the repository root:

```bash
bash scripts/test-api.sh YOUR_AWS_PROFILE
```

After a rebuild, update the testing policy with the new API ID.

## GitHub deployment role

Terraform creates this role separately. Do not attach the provisioning
policies above to it.

Its code-deployment policy allows only these actions on the API Lambda ARN:

- `lambda:UpdateFunctionCode`
- `lambda:GetFunction`
- `lambda:GetFunctionConfiguration`

`GetFunction` is needed by the workflow's update waiter.

The role's OIDC trust must match your repository's exact token subject.
Set `github_oidc_subject` using the `sub` printed by the workflow's
Check OIDC identity step. Repository IDs may be included in that subject.

## Cleanup

Keep provisioning permissions until Terraform destroy finishes.

- Disable RDS deletion protection and apply that change before destroying.
- Review the destroy plan, particularly deletion of any OIDC provider.
- ENI cleanup requires `ec2:DeleteNetworkInterface`.
- A final database snapshot remains and incurs storage charges.
- Snapshot deletion is intentionally excluded. Grant
  `rds:DeleteDBSnapshot` separately if you choose to delete retained snapshots.
- The application secret has a recovery window, which can block immediate
  recreation using the same name.
- Keep Terraform state until cleanup is confirmed.