
$ErrorActionPreference = "Stop"

# Allow Checkov's non-zero exit codes for expected policy violations.
# The script evaluates the JSON results and decides whether each test passed.
$PSNativeCommandUseErrorActionPreference = $false

# Resolve paths relative to this script so it works on Windows and Linux.
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$EvidenceRoot = Join-Path $ProjectRoot "evidence"
$SummaryPath = Join-Path $EvidenceRoot "policy-test-summary.csv"

Set-Location $ProjectRoot
New-Item -ItemType Directory -Force -Path $EvidenceRoot | Out-Null

if (-not (Get-Command checkov -ErrorAction SilentlyContinue)) {
    throw "Checkov is not installed or is not available on PATH."
}

# Policy definitions.
# Compliant fixtures must pass every selected rule.
# Non-compliant fixtures must trigger every selected rule.
$Policies = @(
    @{
        Id = "ENC-001"
        Name = "S3 encryption"
        Rule = "CKV_AWS_145"
        Compliant = "tests/fixtures/s3-encryption.tf"
        NonCompliant = "tests/fixtures/s3-encryption-noncompliant.tf"
    },
    @{
        Id = "ENC-002"
        Name = "EBS encryption"
        Rule = "CKV_AWS_3"
        Compliant = "tests/fixtures/ebs-encryption-compliant"
        NonCompliant = "tests/fixtures/ebs-encryption-noncompliant"
    },
    @{
        Id = "ENC-003"
        Name = "RDS encryption"
        Rule = "CKV_AWS_16"
        Compliant = "tests/fixtures/rds-encryption-compliant"
        NonCompliant = "tests/fixtures/rds-encryption-noncompliant"
    },
    @{
        Id = "NET-001"
        Name = "SSH ingress restriction"
        Rule = "CKV_AWS_24"
        Compliant = "tests/fixtures/ssh-ingress-compliant"
        NonCompliant = "tests/fixtures/ssh-ingress-noncompliant"
    },
    @{
        Id = "NET-002"
        Name = "RDP ingress restriction"
        Rule = "CKV_AWS_25"
        Compliant = "tests/fixtures/rdp-ingress-compliant"
        NonCompliant = "tests/fixtures/rdp-ingress-noncompliant"
    },
    @{
        Id = "NET-003"
        Name = "RDS public access"
        Rule = "CKV_AWS_17"
        Compliant = "tests/fixtures/rds-public-access-compliant"
        NonCompliant = "tests/fixtures/rds-public-access-noncompliant"
    },
    @{
        Id = "IAM-001"
        Name = "Wildcard permissions"
        Rule = "CKV_AWS_355"
        Compliant = "tests/fixtures/iam-wildcard-compliant"
        NonCompliant = "tests/fixtures/iam-wildcard-noncompliant"
    },
    @{
        Id = "IAM-002"
        Name = "Least privilege"
        Rule = "CKV_AWS_63,CKV_AWS_355"
        Compliant = "tests/fixtures/iam-least-privilege-compliant"
        NonCompliant = "tests/fixtures/iam-least-privilege-noncompliant"
    },
    @{
        Id = "IAM-003"
        Name = "IAM password complexity"
        Rule = "CKV_AWS_14,CKV_AWS_15"
        Compliant = "tests/fixtures/iam-credentials-compliant"
        NonCompliant = "tests/fixtures/iam-credentials-noncompliant"
    }
)

$Results = [System.Collections.Generic.List[object]]::new()

foreach ($Policy in $Policies) {
    $RuleIds = @(
        $Policy.Rule -split "," |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ }
    )

    $Cases = @(
        @{
            Type = "Compliant"
            Path = $Policy.Compliant
            ExpectFailure = $false
        },
        @{
            Type = "NonCompliant"
            Path = $Policy.NonCompliant
            ExpectFailure = $true
        }
    )

    foreach ($Case in $Cases) {
        $FixturePath = Join-Path $ProjectRoot $Case.Path
        $ReportDir = Join-Path $EvidenceRoot (
            "$($Policy.Id)-$($Case.Type.ToLowerInvariant())"
        )
        $ReportPath = Join-Path $ReportDir "results.json"
        $OutputDir = Join-Path $ReportDir "checkov-output"
        $ErrorPath = Join-Path $ReportDir "checkov-error.txt"

        # Remove old output for this case so stale reports cannot be reused.
        if (Test-Path -LiteralPath $ReportDir) {
            Remove-Item -LiteralPath $ReportDir -Recurse -Force
        }

        New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

        $Expected = if ($Case.ExpectFailure) { "Fail" } else { "Pass" }

        if (-not (Test-Path -LiteralPath $FixturePath)) {
            $Results.Add([pscustomobject]@{
                PolicyID = $Policy.Id
                Policy = $Policy.Name
                Test = $Case.Type
                Expected = $Expected
                Actual = "Missing fixture"
                Result = "ERROR"
                PassedChecks = 0
                FailedChecks = 0
                ParsingErrors = 0
                ResourceCount = 0
                ExitCode = $null
                Report = $ReportPath
            })

            Write-Host "ERROR - Missing fixture: $FixturePath" -ForegroundColor Red
            continue
        }

        Write-Host "`n[$($Policy.Id)] $($Policy.Name) - $($Case.Type)" -ForegroundColor Cyan

        # Checkov requires -f for a file and -d for a directory.
        if (Test-Path -LiteralPath $FixturePath -PathType Leaf) {
            $ScanTargetArgs = @("-f", $FixturePath)
        }
        elseif (Test-Path -LiteralPath $FixturePath -PathType Container) {
            $ScanTargetArgs = @("-d", $FixturePath)
        }
        else {
            $Results.Add([pscustomobject]@{
                PolicyID = $Policy.Id
                Policy = $Policy.Name
                Test = $Case.Type
                Expected = $Expected
                Actual = "Unsupported fixture path"
                Result = "ERROR"
                PassedChecks = 0
                FailedChecks = 0
                ParsingErrors = 0
                ResourceCount = 0
                ExitCode = $null
                Report = $ReportPath
            })

            Write-Host "ERROR - Unsupported fixture path: $FixturePath" -ForegroundColor Red
            continue
        }

        $CheckArgs = $ScanTargetArgs + @(
            "--framework", "terraform",
            "--check", $Policy.Rule,
            "--output", "json",
            "--output-file-path", $OutputDir
        )

        $ExitCode = $null

        try {
            # Non-compliant fixtures may legitimately produce exit code 1.
            & checkov @CheckArgs
            $ExitCode = $LASTEXITCODE

            # Checkov 3.x normally writes results_json.json in the output folder.
            $JsonFile = Join-Path $OutputDir "results_json.json"

            if (-not (Test-Path -LiteralPath $JsonFile)) {
                $JsonFile = Join-Path $OutputDir "results.json"
            }

            if (-not (Test-Path -LiteralPath $JsonFile)) {
                throw "Checkov did not create a JSON report in $OutputDir"
            }

            $Report = Get-Content -LiteralPath $JsonFile -Raw |
                ConvertFrom-Json -ErrorAction Stop

            # Store a consistent report path for the workflow artifact step.
            $Report | ConvertTo-Json -Depth 100 |
                Set-Content -LiteralPath $ReportPath -Encoding utf8

            $PassedChecks = @(
                $Report.results.passed_checks |
                    Where-Object { $null -ne $_ }
            )
            $FailedChecks = @(
                $Report.results.failed_checks |
                    Where-Object { $null -ne $_ }
            )

            $PassedCount = $PassedChecks.Count
            $FailedCount = $FailedChecks.Count

            if ($null -ne $Report.summary.parsing_errors) {
                $ParsingErrors = [int]$Report.summary.parsing_errors
            }
            else {
                $ParsingErrors = @($Report.results.parsing_errors).Count
            }

            $ResourceCount = [int]$Report.summary.resource_count

            $RelevantPassed = @(
                $PassedChecks |
                    Where-Object { $_.check_id -in $RuleIds }
            )
            $RelevantFailed = @(
                $FailedChecks |
                    Where-Object { $_.check_id -in $RuleIds }
            )

            $PassedRuleIds = @(
                $RelevantPassed |
                    Select-Object -ExpandProperty check_id -Unique
            )
            $FailedRuleIds = @(
                $RelevantFailed |
                    Select-Object -ExpandProperty check_id -Unique
            )

            if ($ParsingErrors -gt 0) {
                $Actual = "Terraform parsing errors detected"
                $TestResult = "ERROR"
            }
            elseif ($ResourceCount -le 0) {
                $Actual = "No resources were scanned"
                $TestResult = "NOT VERIFIED"
            }
            elseif (-not $Case.ExpectFailure) {
                $MissingRules = @(
                    $RuleIds | Where-Object { $_ -notin $PassedRuleIds }
                )

                if ($RelevantFailed.Count -gt 0) {
                    $Actual = "Compliant fixture triggered a selected rule failure"
                    $TestResult = "FAIL"
                }
                elseif ($MissingRules.Count -gt 0) {
                    $Actual = "Not all selected rules passed: $($MissingRules -join ', ')"
                    $TestResult = "NOT VERIFIED"
                }
                else {
                    $Actual = "All selected rules passed"
                    $TestResult = "PASS"
                }
            }
            else {
                $MissingRules = @(
                    $RuleIds | Where-Object { $_ -notin $FailedRuleIds }
                )

                if ($RelevantFailed.Count -eq 0) {
                    $Actual = "Non-compliant fixture was not detected"
                    $TestResult = "FAIL"
                }
                elseif ($MissingRules.Count -gt 0) {
                    $Actual = "Not all expected failures were detected: $($MissingRules -join ', ')"
                    $TestResult = "NOT VERIFIED"
                }
                else {
                    $Actual = "All expected policy failures detected"
                    $TestResult = "PASS"
                }
            }

            $Results.Add([pscustomobject]@{
                PolicyID = $Policy.Id
                Policy = $Policy.Name
                Test = $Case.Type
                Expected = $Expected
                Actual = $Actual
                Result = $TestResult
                PassedChecks = $PassedCount
                FailedChecks = $FailedCount
                ParsingErrors = $ParsingErrors
                ResourceCount = $ResourceCount
                ExitCode = $ExitCode
                Report = $ReportPath
            })

            $Color = if ($TestResult -eq "PASS") {
                "Green"
            }
            elseif ($TestResult -eq "FAIL" -or $TestResult -eq "ERROR") {
                "Red"
            }
            else {
                "Yellow"
            }

            Write-Host "$TestResult - $Actual" -ForegroundColor $Color
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            Set-Content -LiteralPath $ErrorPath -Value $ErrorMessage -Encoding utf8

            $Results.Add([pscustomobject]@{
                PolicyID = $Policy.Id
                Policy = $Policy.Name
                Test = $Case.Type
                Expected = $Expected
                Actual = $ErrorMessage
                Result = "ERROR"
                PassedChecks = 0
                FailedChecks = 0
                ParsingErrors = 0
                ResourceCount = 0
                ExitCode = $ExitCode
                Report = $ReportPath
            })

            Write-Host "ERROR - $ErrorMessage" -ForegroundColor Red
        }
    }
}

# Always save the summary, even if some test cases failed.
$Results |
    Export-Csv -Path $SummaryPath -NoTypeInformation -Encoding utf8

Write-Host "`n===== POLICY TEST SUMMARY =====" -ForegroundColor Cyan
$Results |
    Format-Table PolicyID, Policy, Test, Expected, Actual, Result -AutoSize

$ExpectedCases = $Policies.Count * 2
$Verified = @($Results | Where-Object { $_.Result -eq "PASS" }).Count
$NotVerified = @($Results | Where-Object { $_.Result -eq "NOT VERIFIED" }).Count
$Errors = @($Results | Where-Object { $_.Result -eq "ERROR" }).Count
$Failures = @($Results | Where-Object { $_.Result -eq "FAIL" }).Count

Write-Host "`nVerified test cases: $Verified / $ExpectedCases"
Write-Host "Not verified: $NotVerified | Errors: $Errors | Failed tests: $Failures"
Write-Host "CSV summary: $SummaryPath"
Write-Host "JSON reports: $EvidenceRoot"

# Fail the CI job unless every test case was actually verified.
if (
    $Results.Count -ne $ExpectedCases -or
    $Verified -ne $ExpectedCases -or
    $NotVerified -gt 0 -or
    $Errors -gt 0 -or
    $Failures -gt 0
) {
    Write-Error "Policy validation did not pass completely. Review the summary and evidence."
    exit 1
}

Write-Host "`nAll $ExpectedCases policy test cases passed verification." -ForegroundColor Green
exit 0
