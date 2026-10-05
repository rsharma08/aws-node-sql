[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Profile,
    [string]$TerraformDirectory = (Join-Path $PSScriptRoot '../infra/environments/dev')
)
$ErrorActionPreference = 'Stop'
$TerraformDirectory = (Resolve-Path $TerraformDirectory).Path
$function = & terraform "-chdir=$TerraformDirectory" output -raw bootstrap_function_name
if ($LASTEXITCODE -ne 0 -or !$function) { throw 'Cannot read bootstrap function name' }
$region = & terraform "-chdir=$TerraformDirectory" output -raw aws_region
if ($LASTEXITCODE -ne 0 -or !$region) { throw 'Cannot read AWS region' }
$resultFile = [IO.Path]::GetTempFileName()
try {
    $metadata = & aws lambda invoke --profile $Profile --region $region `
        --function-name $function --cli-read-timeout 150 $resultFile
    if ($LASTEXITCODE -ne 0) { throw 'Bootstrap invocation failed' }
    $invocation = ($metadata -join "`n") | ConvertFrom-Json
    if ($invocation.PSObject.Properties['FunctionError']) { throw 'Bootstrap Lambda reported an error; inspect CloudWatch logs' }
    $result = Get-Content $resultFile -Raw | ConvertFrom-Json
    if ($result.status -ne 'ok') { throw 'Unexpected bootstrap result' }
    $result | ConvertTo-Json -Compress
}
finally {
    Remove-Item $resultFile -Force
}
