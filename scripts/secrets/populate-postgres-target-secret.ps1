<#
.DESCRIPTION
Populate the Terraform-created Secrets Manager secret for the PostgreSQL DMS target endpoint.
This secret uses the dedicated dms_target login, not the RDS master account.
The script reads the RDS endpoint and database name from Terraform outputs and prompts for the password securely.
.NOTES
Create the dms_target role first, then run this script from environments/dev after Terraform outputs exist.
#>
[CmdletBinding()]
param(
    [string]$Region = "us-east-1",
    [string]$Username = "dms_target",
    [int]$Port = 5432
)

$ErrorActionPreference = "Stop"

$secretArn = (& terraform output -raw postgres_dms_target_secret_arn).Trim()
$postgresHost = (& terraform output -raw postgres_endpoint_address).Trim()
$databaseName = (& terraform output -raw postgres_database_name).Trim()
if (-not $secretArn -or -not $postgresHost -or -not $databaseName) {
    throw "Could not read Terraform outputs. Run from environments/dev after apply."
}

$securePassword = Read-Host "Enter the dms_target password (input is hidden)" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
$tempFile = Join-Path $env:TEMP ("postgres-dms-target-secret-{0}.json" -f $PID)

try {
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    $secretObject = @{
        engine   = "postgres"
        username = $Username
        password = $plainPassword
        host     = $postgresHost
        port     = $Port
        dbname   = $databaseName
    }
    $json = $secretObject | ConvertTo-Json -Compress
    [System.IO.File]::WriteAllText($tempFile, $json, [System.Text.UTF8Encoding]::new($false))

    & icacls $tempFile /inheritance:r /grant:r "$($env:USERNAME):(F)" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Could not secure the temporary secret file ACL." }

    & aws secretsmanager put-secret-value --region $Region --secret-id $secretArn --secret-string "file://$tempFile"
    if ($LASTEXITCODE -ne 0) { throw "AWS Secrets Manager update failed." }

    Write-Host "PostgreSQL DMS target secret populated. The password was not passed to Terraform." -ForegroundColor Green
}
finally {
    if ($bstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
    $plainPassword = $null
    $json = $null
    $secretObject = $null
}
