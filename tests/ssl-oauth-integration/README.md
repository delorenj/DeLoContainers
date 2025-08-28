# SSL/OAuth Integration Testing Suite

A comprehensive testing framework for validating SSL certificate configurations and OAuth authentication flows across your infrastructure.

## Overview

This testing suite provides thorough validation of:

- **SSL Certificate Management**: Certificate chain validation, expiration monitoring, and renewal processes
- **OAuth Authentication Flows**: GitHub and Google OAuth integration testing
- **Cross-Browser Compatibility**: Testing across multiple browser configurations
- **Performance & Security**: Comprehensive security header validation and performance metrics

## Test Components

### 1. SSL Certificate Validator (`ssl-certificate-validator.sh`)

Tests SSL certificate infrastructure:
- Certificate chain validation
- Certificate expiration monitoring
- SSL/TLS handshake verification
- Certificate Transparency (CT) log validation
- OCSP stapling verification
- HTTP to HTTPS redirect testing

**Tested Domains:**
- `traefik.delo.sh`
- `sync.delo.sh`
- `lms.delo.sh`
- `draw.delo.sh`
- `whoami.localhost`

### 2. OAuth Flow Tester (`oauth-flow-tester.sh`)

Validates OAuth authentication implementations:
- OAuth authorization URL generation
- Token endpoint validation
- User info endpoint security
- CORS configuration testing
- Application OAuth endpoint validation
- OAuth state parameter validation

**Supported Providers:**
- GitHub OAuth
- Google OAuth

### 3. Cross-Browser Compatibility Tester (`cross-browser-tester.sh`)

Tests authentication flows across browsers:
- SSL certificate acceptance testing
- TLS version compatibility
- Security headers validation
- Cookie security configuration
- Page loading performance

**Browser Configurations:**
- Chrome (Windows, macOS, Linux)
- Firefox (Windows)
- Safari (macOS)

### 4. Performance & Security Validator (`performance-security-validator.sh`)

Comprehensive security and performance analysis:

**Security Tests:**
- SSL Labs equivalent rating
- Cipher suite strength analysis
- HSTS implementation validation
- Content Security Policy (CSP) analysis
- OAuth security headers verification

**Performance Tests:**
- Page load time measurement
- SSL handshake performance
- Concurrent connection handling

## Quick Start

### Prerequisites

Ensure the following tools are installed:
```bash
# Required tools
sudo apt-get update
sudo apt-get install -y curl openssl jq bc

# Or on macOS
brew install curl openssl jq bc
```

### Running Tests

#### Run All Tests (Recommended)
```bash
cd /home/delorenj/docker/trunk-main/tests/ssl-oauth-integration
./master-test-runner.sh
```

#### Run Individual Test Suites
```bash
# SSL Certificate Validation
./ssl-certificate-validator.sh

# OAuth Flow Testing
./oauth-flow-tester.sh

# Cross-Browser Compatibility
./cross-browser-tester.sh

# Performance & Security Validation
./performance-security-validator.sh
```

## Configuration

### OAuth Configuration

Before running OAuth tests, configure your OAuth providers in `oauth-config.json`:

```json
{
  "providers": {
    "github": {
      "auth_url": "https://github.com/login/oauth/authorize",
      "token_url": "https://github.com/login/oauth/access_token",
      "user_url": "https://api.github.com/user",
      "scopes": ["user:email", "read:user"],
      "client_id": "your_github_client_id",
      "redirect_uri": "https://your-app.delo.sh/auth/github/callback"
    },
    "google": {
      "auth_url": "https://accounts.google.com/o/oauth2/v2/auth",
      "token_url": "https://oauth2.googleapis.com/token",
      "user_url": "https://www.googleapis.com/oauth2/v2/userinfo",
      "scopes": ["openid", "email", "profile"],
      "client_id": "your_google_client_id",
      "redirect_uri": "https://your-app.delo.sh/auth/google/callback"
    }
  },
  "test_endpoints": {
    "app_base_url": "https://your-app.delo.sh",
    "auth_endpoints": {
      "login": "/auth/login",
      "logout": "/auth/logout",
      "callback": "/auth/{provider}/callback",
      "profile": "/auth/profile"
    }
  }
}
```

### Domain Configuration

Update domain configurations in each test script:
- Modify `DOMAIN_BASE` variable in test scripts
- Update `DOMAINS` array with your specific domains
- Configure `TEST_URLS` for your environment

## Test Reports

### Report Locations

All test reports are generated in JSON format:
- **Master Report**: `logs/master-integration-report.json`
- **SSL Validation**: `logs/ssl-validation-report.json`
- **OAuth Testing**: `logs/oauth-test-report.json`
- **Browser Compatibility**: `logs/browser-compatibility-report.json`
- **Performance & Security**: `logs/performance-security-report.json`

### Report Structure

```json
{
  "test_run": {
    "timestamp": "2025-08-28T...",
    "version": "1.0.0",
    "test_suite": "Test Suite Name"
  },
  "results": {
    "domain/test": {
      "status": "PASS|WARN|FAIL",
      "details": {...}
    }
  },
  "summary": {
    "total_tests": 0,
    "passed": 0,
    "failed": 0,
    "warnings": 0
  }
}
```

## Understanding Test Results

### Status Codes

- **PASS**: Test completed successfully with no issues
- **WARN**: Test completed but with warnings (needs attention)
- **FAIL**: Test failed (requires immediate attention)

### Exit Codes

- **0**: All tests passed
- **1**: One or more tests failed
- **2**: Tests completed with warnings

## Common Issues and Solutions

### SSL Certificate Issues

**Problem**: Certificate chain validation fails
**Solution**: 
```bash
# Check certificate chain manually
openssl s_client -connect domain.com:443 -servername domain.com
```

**Problem**: Certificate expiring soon
**Solution**: 
- Review Traefik ACME configuration
- Check Let's Encrypt rate limits
- Verify DNS propagation

### OAuth Configuration Issues

**Problem**: OAuth endpoints not responding
**Solutions**:
- Verify OAuth application credentials
- Check callback URL configuration
- Validate OAuth provider settings

### Performance Issues

**Problem**: Slow page load times
**Solutions**:
- Enable HTTP/2 in Traefik
- Implement caching headers
- Optimize SSL cipher selection

**Problem**: Poor SSL handshake performance
**Solutions**:
- Enable OCSP stapling
- Configure SSL session resumption
- Use ECDSA certificates

## Advanced Configuration

### Custom Test Domains

To test additional domains, modify the test scripts:

```bash
# In ssl-certificate-validator.sh
DOMAINS=(
    "new-service.delo.sh"
    "api.delo.sh"
    "admin.delo.sh"
)
```

### Custom OAuth Providers

Add additional OAuth providers in `oauth-config.json`:

```json
"providers": {
  "custom_provider": {
    "auth_url": "https://provider.com/oauth/authorize",
    "token_url": "https://provider.com/oauth/token",
    "user_url": "https://provider.com/api/user",
    "scopes": ["read", "profile"],
    "client_id": "your_client_id",
    "redirect_uri": "https://your-app.delo.sh/auth/custom/callback"
  }
}
```

### Performance Thresholds

Modify performance thresholds in test scripts:

```bash
# Page load time thresholds (seconds)
EXCELLENT_TIME=1.0
GOOD_TIME=2.0
ACCEPTABLE_TIME=3.0
POOR_TIME=5.0
```

## Continuous Integration

### GitHub Actions Integration

```yaml
name: SSL/OAuth Integration Tests
on:
  schedule:
    - cron: '0 6 * * *'  # Daily at 6 AM
  workflow_dispatch:

jobs:
  integration-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install Dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y curl openssl jq bc
      - name: Run Integration Tests
        run: |
          cd tests/ssl-oauth-integration
          ./master-test-runner.sh
      - name: Upload Test Reports
        uses: actions/upload-artifact@v3
        with:
          name: integration-test-reports
          path: tests/ssl-oauth-integration/logs/
```

### Monitoring Integration

Set up monitoring alerts based on test results:

```bash
# Example Prometheus alerting rule
- alert: SSLCertificateExpiringSoon
  expr: ssl_cert_days_until_expiry < 30
  for: 0m
  labels:
    severity: warning
  annotations:
    summary: "SSL certificate expiring soon"
    description: "SSL certificate for {{ $labels.domain }} expires in {{ $value }} days"
```

## Security Considerations

### Test Environment

- Run tests from trusted environments only
- Secure OAuth credentials and client secrets
- Use separate OAuth applications for testing
- Monitor test logs for sensitive information

### Production Testing

- Schedule tests during low-traffic periods
- Implement rate limiting for test requests
- Use read-only operations where possible
- Monitor impact on production services

## Troubleshooting

### Debug Mode

Enable debug output in test scripts:
```bash
export DEBUG=1
./master-test-runner.sh
```

### Verbose Logging

Increase logging verbosity:
```bash
export VERBOSE=1
./ssl-certificate-validator.sh
```

### Manual Testing

Test individual components manually:
```bash
# Test SSL certificate
openssl s_client -connect domain.com:443 -servername domain.com

# Test OAuth endpoint
curl -I https://github.com/login/oauth/authorize

# Test security headers
curl -I https://your-app.delo.sh
```

## Contributing

To extend or modify the test suite:

1. **Add New Tests**: Create new test functions following the existing pattern
2. **Update Configurations**: Modify domain and endpoint configurations
3. **Enhance Reporting**: Improve JSON report structure and content
4. **Documentation**: Update this README with new features

### Test Function Template

```bash
test_new_feature() {
    local domain=$1
    local result=""
    
    log_info "Testing new feature for ${domain}"
    
    # Test implementation here
    
    if [[ condition ]]; then
        log_success "New feature working for ${domain}"
        result="PASS"
    else
        log_error "New feature failed for ${domain}"
        result="FAIL"
    fi
    
    echo "${result}"
}
```

## Support

For issues with the testing suite:
1. Check test logs in the `logs/` directory
2. Verify prerequisites are installed
3. Review domain and OAuth configurations
4. Check network connectivity to test endpoints

## License

This testing suite is part of the SSL/OAuth integration validation framework and follows the same licensing as the parent project.

---

**Note**: Always test in a safe environment before running against production services. These tests are designed to be non-invasive but may generate logs and monitoring alerts on target systems.