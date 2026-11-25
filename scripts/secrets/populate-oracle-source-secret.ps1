<#
.DESCRIPTION
Populate the Terraform-created Secrets Manager secret for the Oracle DMS Full Load + CDC source endpoint.
The secret host is the gateway private IP; DMS reaches Oracle through the reverse SSH tunnel.
Passwords are requested as secure input and are never passed as Terraform variables or written to Terraform state.
.NOTES
Run from environments/dev after Terraform outputs exist and the Oracle reverse tunnel gateway has been deployed.
The Oracle account is DMS_USER, a least-privilege migration account in the MIGPDB PDB.
#>
[CmdletBinding()]
param(
    [string]$Region = "us-east-1",
    [string]$Username = "DMS_USER",
    [int]$Port = 11521
)

$ErrorActionPreference = "Stop"

$secretArn = (& terraform output -raw oracle_source_secret_arn).Trim()
$gatewayIp = (& terraform output -raw tunnel_gateway_private_ip).Trim()
if (-not $secretArn -or -not $gatewayIp) {
    throw "Could not read Terraform outputs. Run this script from environments/dev after apply."
}

$securePassword = Read-Host "Enter the DMS_USER password (input is hidden)" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
$tempFile = Join-Path $env:TEMP ("oracle-dms-source-secret-{0}.json" -f $PID)

try {
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    $secretObject = @{
        engine   = "oracle"
        username = $Username
        password = $plainPassword
        host     = $gatewayIp
        port     = $Port
        dbname   = "migpdb"
    }
    $json = $secretObject | ConvertTo-Json -Compress
    [System.IO.File]::WriteAllText($tempFile, $json, [System.Text.UTF8Encoding]::new($false))

    # Restrict the temporary file to the current Windows account before passing it to AWS CLI.
    & icacls $tempFile /inheritance:r /grant:r "$($env:USERNAME):(F)" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Could not secure the temporary secret file ACL." }

    & aws secretsmanager put-secret-value --region $Region --secret-id $secretArn --secret-string "file://$tempFile"
    if ($LASTEXITCODE -ne 0) { throw "AWS Secrets Manager update failed." }

    Write-Host "Oracle source endpoint secret populated. The password was not passed to Terraform." -ForegroundColor Green
}
finally {
    if ($bstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
    $plainPassword = $null
    $json = $null
    $secretObject = $null
}
