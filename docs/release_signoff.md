# Release Sign-off Guide

This document describes the release validation and sign-off process for Guardian Angel FYP.

## Overview

Our release process ensures that every release meets quality standards through:

1. **Automated Testing** — Unit, integration, and E2E acceptance tests
2. **Automated Gates** — CI enforces test passing before merge
3. **Manual Verification** — Security, metrics, and documentation review
4. **Formal Sign-off** — Explicit approval before release tag creation

## Release Process Flow

```
┌─────────────────┐
│  Development    │
│  (feature work) │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  PR Created     │
│  CI runs tests  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Tests Pass?    │
├─────────┬───────┤
│   NO    │  YES  │
└────┬────┴───┬───┘
     │        │
     │        ▼
     │  ┌─────────────────┐
     │  │  PR Merged to   │
     │  │  main branch    │
     │  └────────┬────────┘
     │           │
     │           ▼
     │  ┌─────────────────┐
     │  │  Acceptance     │
     │  │  Tests Run      │
     │  └────────┬────────┘
     │           │
     │           ▼
     │  ┌─────────────────┐
     │  │  Generate       │
     │  │  Checklist      │
     │  └────────┬────────┘
     │           │
     │           ▼
     │  ┌─────────────────┐
     │  │  Manual Review  │
     │  │  & Verification │
     │  └────────┬────────┘
     │           │
     │           ▼
     │  ┌─────────────────┐
     │  │  Sign-off       │
     │  │  (mark_signoff) │
     │  └────────┬────────┘
     │           │
     │           ▼
     │  ┌─────────────────┐
     │  │  Release Tagged │
     │  │  & Published    │
     │  └─────────────────┘
     │
     └─────► FIX & RETRY
```

## Step-by-Step Instructions

### Step 1: Run Validation Tests

Run the full test suite to validate all components:

```bash
dart run tool/run_all_tests.dart
```

**Expected output:**
- `validation-report.json` created
- All test suites pass (exit code 0)
- No critical errors

**What's tested:**
- Unit tests (models, persistence, sync logic)
- Integration tests (API client, mock server)
- Bootstrap tests (test infrastructure)

### Step 2: Run Acceptance Tests

Run end-to-end acceptance scenarios:

```bash
dart run tool/acceptance_runner.dart
```

**Expected output:**
- `acceptance-report.json` created
- All critical scenarios pass
- No data loss or corruption

**Scenarios validated:**
- ✅ Happy path (offline → online processing)
- ✅ Retry & backoff (429 rate limits)
- ✅ Crash-resume idempotency
- ✅ Conflict resolution (409 handling)
- ✅ Circuit breaker protection
- ✅ Network connectivity transitions
- ✅ Metrics & observability

### Step 3: Generate Release Checklist

Auto-generate the release checklist from test reports:

```bash
dart run scripts/generate_release_checklist.dart
```

**Expected output:**
- `release-checklist.json` created
- Automated checks status populated
- Manual checks listed

### Step 4: Inspect Reports

Review the generated artifacts:

```bash
# View validation report
cat validation-report.json | jq '.'

# View acceptance report
cat acceptance-report.json | jq '.'

# View release checklist
cat release-checklist.json | jq '.'
```

**Key metrics to verify:**
- Test success rate: 100%
- No flaky tests
- Duration acceptable (< 5 minutes total)
- No timeout failures

### Step 5: Manual Verification

Complete the following manual checks:

#### 5.1 Metrics Dashboard Review

- [ ] Check SyncMetrics in production/staging
- [ ] Verify success rate > 95%
- [ ] Confirm average latency < 500ms
- [ ] No circuit breaker trips in last 24h
- [ ] Queue depth trends normal
- [ ] No memory leaks detected

#### 5.2 Security Review

- [ ] Secure storage implementation verified
- [ ] Auth token handling reviewed
- [ ] API error responses don't leak sensitive data
- [ ] Idempotency keys properly generated (UUIDs)
- [ ] No hardcoded secrets in code
- [ ] Dependencies have no known vulnerabilities

#### 5.3 Performance Profile

- [ ] Profile sync engine under load
- [ ] Memory usage within acceptable range
- [ ] No performance regressions vs baseline
- [ ] CPU usage reasonable under load

#### 5.4 Documentation Review

- [ ] README.md up to date
- [ ] API documentation complete
- [ ] Runbook covers operational scenarios
- [ ] Migration guides written (if breaking changes)
- [ ] CHANGELOG.md updated

### Step 6: Sign-off & Release

When all checks pass, run the sign-off script:

```bash
bash scripts/mark_signoff.sh
```

**This script will:**
1. Display the release checklist
2. Verify all automated checks passed
3. Prompt for confirmation (type `SIGNOFF`)
4. Create an annotated Git tag
5. Push the tag to remote

**Tag format:** `release-YYYYMMDD-HHMMSS`

### Step 7: Publish Release

After tag is pushed:

1. Go to GitHub Releases
2. Find the draft release created by CI
3. Edit release notes if needed
4. Publish the release

## CI/CD Integration

### Pull Request Workflow

When a PR is created:

```yaml
1. Code analysis (flutter analyze)
2. Run all tests (dart run tool/run_all_tests.dart)
3. Upload validation report as artifact
4. Comment on PR with test results
```

### Main Branch Workflow

When code is merged to `main`:

```yaml
1. Run acceptance tests (dart run tool/acceptance_runner.dart)
2. Generate release checklist
3. Upload reports as artifacts
4. Comment on commit with acceptance results
5. Create draft release (if tests pass)
```

**Artifacts retained:**
- Validation reports: 30 days
- Acceptance reports: 90 days
- Release checklists: 90 days

## Release Sign-off Template

Copy this template when performing a release:

```markdown
## Release Sign-off

**Date:** YYYY-MM-DD  
**Release Tag:** release-YYYYMMDD-HHMMSS  
**Signed-off by:** [Your Name]

### Automated Checks ✅

- [x] Unit tests passed
- [x] Integration tests passed
- [x] Acceptance tests passed
- [x] All scenarios validated

### Manual Checks ✅

- [x] Metrics dashboard reviewed
- [x] Security review completed
- [x] Performance profiling completed
- [x] Documentation up to date

### Critical Acceptance Criteria ✅

- [x] No data loss
- [x] Idempotency guaranteed
- [x] Conflict resolution automated
- [x] Network resilience validated
- [x] Observable metrics recorded

### Release Notes

[Brief summary of changes]

### Known Issues

[Any known limitations or issues]

### Sign-off

I confirm that all checks have been completed and this release is ready for production.

**Signature:** [Your Name]  
**Date:** YYYY-MM-DD HH:MM UTC
```

## Troubleshooting

### Tests Fail

If tests fail during validation:

1. Review `validation-report.json` for details
2. Fix failing tests
3. Re-run validation
4. Do not proceed to acceptance until all tests pass

### Acceptance Scenarios Fail

If acceptance tests fail:

1. Review `acceptance-report.json` for scenario details
2. Identify root cause
3. Fix issue
4. Re-run acceptance tests
5. Do not proceed to sign-off until all scenarios pass

### Manual Checks Reveal Issues

If manual verification finds problems:

1. Document the issue
2. Create a bug ticket
3. Fix the issue
4. Re-run full validation
5. Re-perform manual checks

### Sign-off Script Fails

Common issues:

- **jq not installed:** `brew install jq` (macOS)
- **No checklist found:** Run `generate_release_checklist.dart` first
- **Not release ready:** Fix failing automated checks
- **Git push fails:** Check permissions and remote configuration

## Roles & Responsibilities

### Developer
- Run validation tests before creating PR
- Fix failing tests
- Address code review feedback

### Tech Lead
- Review release checklist
- Perform security review
- Approve manual checks
- Execute sign-off script

### QA Lead
- Validate acceptance scenarios
- Review metrics dashboard
- Verify performance profile
- Document known issues

### DevOps
- Monitor CI/CD pipeline
- Manage artifact retention
- Configure branch protection
- Handle release deployment

## Compliance & Audit

All releases are tracked with:

- **Git tags:** Immutable release markers
- **Artifacts:** Test reports retained for 90 days
- **Comments:** GitHub commit/PR comments with results
- **Release notes:** Published on GitHub Releases

For audit purposes, retrieve:

```bash
# List all releases
git tag -l "release-*"

# View release details
git show release-YYYYMMDD-HHMMSS

# Download artifacts from CI
# Go to: GitHub Actions > Workflow Run > Artifacts
```

## Emergency Hotfix Process

For critical production issues:

1. Create hotfix branch from release tag
2. Fix issue with minimal changes
3. Run validation tests only (skip full acceptance)
4. Fast-track review and merge
5. Tag as `hotfix-YYYYMMDD-HHMMSS`
6. Deploy immediately

**Note:** Full acceptance tests should be run post-deployment.

## Continuous Improvement

After each release:

- Review process effectiveness
- Update runbook with lessons learned
- Identify automation opportunities
- Improve test coverage

## Questions?

Contact:
- **Tech Lead:** [Name/Email]
- **QA Lead:** [Name/Email]
- **DevOps:** [Name/Email]

---

**Document Version:** 1.0  
**Last Updated:** 2025-11-22  
**Next Review:** 2025-12-22
