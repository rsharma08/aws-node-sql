$ErrorActionPreference = 'Stop'
npm.cmd ci --omit=dev
if ($LASTEXITCODE -ne 0) { throw "Dependency installation failed" }

foreach ($file in @("index.js", "db.js", "bootstrap/index.js")) {
    node --check $file
    if ($LASTEXITCODE -ne 0) { throw "Syntax check failed: $file" }
}

if (!(Test-Path certs\global-bundle.pem)) {
    throw "Missing database TLS certificate bundle"
}

New-Item -ItemType Directory -Path dist -Force | Out-Null

Compress-Archive `
    -Path index.js, db.js, package.json, node_modules, certs `
    -DestinationPath dist\api.zip `
    -Force

$stage = Join-Path ([IO.Path]::GetTempPath()) (
    "solirius-bootstrap-" + [Guid]::NewGuid().ToString("N")
)

New-Item -ItemType Directory -Path $stage | Out-Null

try {
    Copy-Item bootstrap\index.js -Destination "$stage\index.js"
    Copy-Item package.json -Destination $stage
    Copy-Item node_modules, certs -Destination $stage -Recurse

    Compress-Archive `
        -Path "$stage\*" `
        -DestinationPath dist\bootstrap.zip `
        -Force
}
finally {
    Remove-Item $stage -Recurse -Force
}

Get-Item dist\api.zip, dist\bootstrap.zip |
    Select-Object Name, Length