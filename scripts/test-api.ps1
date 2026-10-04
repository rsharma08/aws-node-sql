$credentials = $null

try {
    $credentials = aws configure export-credentials `
        --profile solirius-terraform `
        --format process | ConvertFrom-Json

    if ($LASTEXITCODE -ne 0 -or !$credentials.AccessKeyId) {
        throw "Could not obtain AWS credentials"
    }

    $region = "eu-west-2"
    $urls = @(
        (terraform output -raw health_url),
        (terraform output -raw database_health_url)
    )

    foreach ($url in $urls) {
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