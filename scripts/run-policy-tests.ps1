
$ErrorActionPreference = "Stop"

# Run from the project root
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$EvidenceRoot = Join-Path $ProjectRoot "evidence"
$SummaryPath = Join-Path $EvidenceRoot "policy-test-summary.csv"

Set-Location $ProjectRoot
New-Item -ItemType Directory -Force -Path $EvidenceRoot | Out-Null

if (-not (Get-Command checkov -ErrorAction SilentlyContinue)) {
    throw "Checkov was not found. Activate your virtual environment first: .\.venv\Scripts\Activate.ps1"
}

# Each policy specifies its fixture paths and Checkov rules.
$Policies = @(
    @{
        Id = "ENC-001"; Name = "S3 encryption"
        Rule = "CKV_AWS_145"
        Compliant = "tests\fixtures\s3-encryption.tf"
        NonCompliant = "tests\fixtures\s3-encryption-noncompliant.tf"
    },
    @{
        Id = "ENC-002"; Name = "EBS encryption"
        Rule = "CKV_AWS_3"
        Compliant = "tests\fixtures\ebs-encryption-compliant"
        NonCompliant = "tests\fixtures\ebs-encryption-noncompliant"
    },
    @{
        Id = "ENC-003"; Name = "RDS encryption"
        Rule = "CKV_AWS_16"
        Compliant = "tests\fixtures\rds-encryption-compliant"
        NonCompliant = "tests\fixtures\rds-encryption-noncompliant"
    },
    @{
        Id = "NET-001"; Name = "SSH ingress restriction"
        Rule = "CKV_AWS_24"
        Compliant = "tests\fixtures\ssh-ingress-compliant"
        NonCompliant = "tests\fixtures\ssh-ingress-noncompliant"
    },
    @{
        Id = "NET-002"; Name = "RDP ingress restriction"
        Rule = "CKV_AWS_25"
        Compliant = "tests\fixtures\rdp-ingress-compliant"
        NonCompliant = "tests\fixtures\rdp-ingress-noncompliant"
    },
    @{
        Id = "NET-003"; Name = "RDS public access"
        Rule = "CKV_AWS_17"
        Compliant = "tests\fixtures\rds-public-access-compliant"
        NonCompliant = "tests\fixtures\rds-public-access-noncompliant"
    },
    @{
        Id = "IAM-001"; Name = "Wildcard permissions"
        Rule = "CKV_AWS_355"
        Compliant = "tests\fixtures\iam-wildcard-compliant"
        NonCompliant = "tests\fixtures\iam-wildcard-noncompliant"
    },
    @{
        Id = "IAM-002"; Name = "Least privilege"
        Rule = "CKV_AWS_63,CKV_AWS_355"
        Compliant = "tests\fixtures\iam-least-privilege-compliant"
        NonCompliant = "tests\fixtures\iam-least-privilege-noncompliant"
    },
    @{
        Id = "IAM-003"; Name = "IAM password complexity"
        Rule = "CKV_AWS_14,CKV_AWS_15"
        Compliant = "tests\fixtures\iam-credentials-compliant"
        NonCompliant = "tests\fixtures\iam-credentials-noncompliant"
    }
)

$Results = [System.Collections.Generic.List[object]]::new()

foreach ($Policy in $Policies) {
    foreach ($Case in @(
        @{ Type = "Compliant"; Path = $Policy.Compliant; ExpectFailure = $false },
        @{ Type = "NonCompliant"; Path = $Policy.NonCompliant; ExpectFailure = $true }
    )) {
        $FixturePath = Join-Path $ProjectRoot $Case.Path
        $ReportDir = Join-Path $EvidenceRoot (
            "$($Policy.Id)-$($Case.Type.ToLower())"
        )
        $ReportPath = Join-Path $ReportDir "results.json"

        New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

        if (-not (Test-Path $FixturePath)) {
            $Results.Add([pscustomobject]@{
                PolicyID = $Policy.Id
                Policy = $Policy.Name
                Test = $Case.Type
                Expected = if ($Case.ExpectFailure) { "Fail" } else { "Pass" }
                Actual = "Missing fixture"
                Result = "ERROR"
                Report = $ReportPath
            })
            Write-Warning "Missing fixture: $FixturePath"
            continue
        }

        Write-Host "`n[$($Policy.Id)] $($Policy.Name) - $($Case.Type)" -ForegroundColor Cyan

        # Checkov can return a non-zero exit code for expected failed checks.
        # Capture it without stopping the entire test run.
        $CheckArgs = @(
            "-d", $FixturePath,
            "--framework", "terraform",
            "--check", $Policy.Rule,
            "-o", "json"
        )

       
        $OutputDir = Join-Path $ReportDir "checkov-output"
        New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

        $CheckArgs = @(
            "-d", $FixturePath,
            "--framework", "terraform",
            "--check", $Policy.Rule,
            "--output", "json",
            "--output-file-path", $OutputDir
        )

        & checkov @CheckArgs
        $ExitCode = $LASTEXITCODE

        # Checkov may name the JSON file results_json.json.
        $JsonFile = Join-Path $OutputDir "results_json.json"

        if (-not (Test-Path $JsonFile)) {
            $JsonFile = Join-Path $OutputDir "results.json"
        }

        try {
            if (-not (Test-Path $JsonFile)) {
                throw "Checkov did not create a JSON report in $OutputDir"
            }

            $Report = Get-Content -Path $JsonFile -Raw |
                ConvertFrom-Json -ErrorAction Stop

            $Report | ConvertTo-Json -Depth 100 |
                Set-Content -Path $ReportPath -Encoding utf8


            $PassedCount = @($Report.results.passed_checks).Count
            $FailedCount = @($Report.results.failed_checks).Count
            $ParsingErrors = @($Report.results.parsing_errors).Count

            # Confirm the selected policy rule was actually evaluated.
            $RelevantPassed = @(
                $Report.results.passed_checks |
                    Where-Object { $_.check_id -in $Policy.Rule.Split(",") }
            ).Count
            $RelevantFailed = @(
                $Report.results.failed_checks |
                    Where-Object { $_.check_id -in $Policy.Rule.Split(",") }
            ).Count

            if ($ParsingErrors -gt 0) {
                $Actual = "Parsing error"
                $TestResult = "ERROR"
            }
            elseif ($Case.ExpectFailure -and $RelevantFailed -gt 0) {
                $Actual = "Expected failure detected"
                $TestResult = "PASS"
            }
            elseif (-not $Case.ExpectFailure -and
                    $RelevantFailed -eq 0 -and
                    $RelevantPassed -gt 0) {
                $Actual = "Expected pass detected"
                $TestResult = "PASS"
            }
            elseif ($RelevantPassed -eq 0 -and $RelevantFailed -eq 0) {
                $Actual = "Rule not evaluated"
                $TestResult = "NOT VERIFIED"
            }
            else {
                $Actual = "Unexpected Checkov result"
                $TestResult = "FAIL"
            }

            $Results.Add([pscustomobject]@{
                PolicyID = $Policy.Id
                Policy = $Policy.Name
                Test = $Case.Type
                Expected = if ($Case.ExpectFailure) { "Fail" } else { "Pass" }
                Actual = $Actual
                Result = $TestResult
                PassedChecks = $PassedCount
                FailedChecks = $FailedCount
                ParsingErrors = $ParsingErrors
                ExitCode = $ExitCode
                Report = $ReportPath
            })

            Write-Host "$TestResult - $Actual" -ForegroundColor $(
                if ($TestResult -eq "PASS") { "Green" }
                elseif ($TestResult -eq "FAIL") { "Red" }
                else { "Yellow" }
            )
        }
        catch {
            $OutputText | Set-Content -Path (
                Join-Path $ReportDir "checkov-output.txt"
            ) -Encoding utf8

            $Results.Add([pscustomobject]@{
                PolicyID = $Policy.Id
                Policy = $Policy.Name
                Test = $Case.Type
                Expected = if ($Case.ExpectFailure) { "Fail" } else { "Pass" }
                Actual = "Could not parse Checkov JSON"
                Result = "ERROR"
                Report = $ReportPath
            })

            Write-Warning "Could not parse Checkov JSON for $($Policy.Id). See $ReportDir"
        }
    }
}

$Results |
    Export-Csv -Path $SummaryPath -NoTypeInformation -Encoding utf8

Write-Host "`n===== POLICY TEST SUMMARY =====" -ForegroundColor Cyan
$Results |
    Format-Table PolicyID, Policy, Test, Expected, Actual, Result -AutoSize

$Verified = @($Results | Where-Object { $_.Result -eq "PASS" }).Count
$NotVerified = @($Results | Where-Object { $_.Result -eq "NOT VERIFIED" }).Count
$Errors = @($Results | Where-Object { $_.Result -eq "ERROR" }).Count
$Failures = @($Results | Where-Object { $_.Result -eq "FAIL" }).Count

Write-Host "`nVerified test cases: $Verified / $($Results.Count)"
Write-Host "Not verified: $NotVerified | Errors: $Errors | Failed tests: $Failures"
Write-Host "CSV summary: $SummaryPath"
Write-Host "JSON reports: $EvidenceRoot"

if ($NotVerified -gt 0 -or $Errors -gt 0 -or $Failures -gt 0) {
    Write-Warning "Review NOT VERIFIED, ERROR, and FAIL entries before claiming full policy coverage."
}
