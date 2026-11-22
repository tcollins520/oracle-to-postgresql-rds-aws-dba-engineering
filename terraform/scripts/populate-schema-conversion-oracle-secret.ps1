<#
.DESCRIPTION
Populate the separate Oracle metadata-account secret used by the optional DMS Schema Conversion project.
This account is distinct from DMS_USER because schema assessment requires a different metadata permission profile.
The script stores the gateway private IP and reverse-tunnel port in the secret connection payload.
.NOTES
Run only after the optional Schema Conversion infrastructure and the dedicated Oracle metadata account are ready.
#>
[CmdletBinding()]
param(
    [string]$Region = "us-east-1",
    [string]$Username = "DMS_SCHEMA_CONVERSION_USER",
    [string]$DatabaseName = "MIGPDB",
    [int]$Port = 11521
)

$ErrorActionPreference = "Stop"
$secretArn = (& terraform output -raw oracle_schema_conversion_secret_arn).Trim()
$gatewayIp = (& terraform output -raw tunnel_gateway_private_ip).Trim()
if (-not $secretArn -or -not $gatewayIp) {
    throw "Could not read Terraform outputs. Run this script from environments/dev after apply."
}

$securePassword = Read-Host "Enter the separate Oracle Schema Conversion account password (hidden input)" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
$tempFile = Join-Path $env:TEMP ("oracle-schema-conversion-secret-{0}.json" -f $PID)
try {
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    $secretObject = @{
        engine   = "oracle"
        username = $Username
        password = $plainPassword
        host     = $gatewayIp
        port     = $Port
        dbname   = $DatabaseName
    }
    $json = $secretObject | ConvertTo-Json -Compress
    [System.IO.File]::WriteAllText($tempFile, $json, [System.Text.UTF8Encoding]::new($false))
    & icacls $tempFile /inheritance:r /grant:r "$($env:USERNAME):(F)" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Could not secure the temporary secret file ACL." }
    & aws secretsmanager put-secret-value --region $Region --secret-id $secretArn --secret-string "file://$tempFile"
    if ($LASTEXITCODE -ne 0) { throw "AWS Secrets Manager update failed." }
    Write-Host "Oracle Schema Conversion secret populated. Password was not passed to Terraform." -ForegroundColor Green
}
finally {
    if ($bstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
    $plainPassword = $null
    $json = $null
    $secretObject = $null
}
