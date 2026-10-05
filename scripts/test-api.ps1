[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Profile,
    [string]$TerraformDirectory = (Join-Path $PSScriptRoot '../infra/environments/dev')
)
$ErrorActionPreference = 'Stop'
$TerraformDirectory = (Resolve-Path $TerraformDirectory).Path
function Get-Output([string]$Name) {
    $value = & terraform "-chdir=$TerraformDirectory" output -raw $Name
    if ($LASTEXITCODE -ne 0 -or !$value) { throw "Cannot read Terraform output: $Name" }
    return ($value -join "`n").Trim()
}
$credentials = $null

try {
    $credentials = aws configure export-credentials `
        --profile $Profile `
        --format process | ConvertFrom-Json

    if ($LASTEXITCODE -ne 0 -or !$credentials.AccessKeyId) {
        throw "Could not obtain AWS credentials"
    }

    $urls = @(
        (Get-Output 'health_url'),
        (Get-Output 'database_health_url')
    )

    foreach ($url in $urls) {
        $uri = [Uri]$url
        if ($uri.Scheme -ne 'https' -or $uri.Host -notmatch '^[a-z0-9]+\.execute-api\.([a-z0-9-]+)\.amazonaws\.com$') {
            throw 'Unexpected API Gateway endpoint'
        }
        $region = $Matches[1]
        Write-Host "`nTesting $url"

        curl.exe --silent --show-error --fail-with-body `
            --connect-timeout 10 `
            --max-time 30 `
            --aws-sigv4 "aws:amz:${region}:execute-api" `
            --user "$($credentials.AccessKeyId):$($credentials.SecretAccessKey)" `
            --header "x-amz-security-token: $($credentials.SessionToken)" `
            --write-out "`nHTTP %{http_code}`n" `
            "$url"

        if ($LASTEXITCODE -ne 0) {
            throw "Health test failed for $url"
        }
    }
}
finally {
    $credentials = $null
}