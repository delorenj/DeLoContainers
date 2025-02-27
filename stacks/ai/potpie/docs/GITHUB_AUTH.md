# GitHub Authentication for PotPie

## Overview
GitHub authentication allows users to log in to PotPie using their GitHub accounts. This is particularly useful for developer-focused applications. This guide explains how to configure GitHub authentication for your PotPie instance.

## Prerequisites
- A Firebase project set up for PotPie
- A GitHub account with access to create OAuth applications

## Setup Instructions

### 1. Create GitHub OAuth Application

1. Log in to GitHub
2. Go to Settings → Developer settings → OAuth Apps
3. Click "New OAuth App"
4. Fill in the following details:
   - **Application name**: PotPie AI (or your preferred name)
   - **Homepage URL**: https://your-domain.com or http://localhost:8001 for local testing
   - **Application description**: (Optional) A brief description
   - **Authorization callback URL**: https://[YOUR-FIREBASE-PROJECT-ID].firebaseapp.com/__/auth/handler
5. Click "Register application"
6. Note your Client ID
7. Generate a new Client Secret and note it

### 2. Configure Firebase

1. Go to your Firebase Console
2. Navigate to Authentication → Sign-in method
3. Enable GitHub provider
4. Enter the Client ID and Client Secret from GitHub
5. Save the changes

### 3. Update PotPie Settings

Ensure your `.env` file has the following settings:
```
isDevelopmentMode=disabled
ENV=production
```

## Testing GitHub Authentication

1. Start your PotPie application
2. Navigate to the login page
3. Select "Sign in with GitHub"
4. You should be redirected to GitHub for authorization
5. After authorizing, you should be redirected back to your PotPie application

## Troubleshooting

### Common Issues

1. **Callback URL Mismatch**: Ensure the callback URL in GitHub exactly matches the one provided by Firebase
2. **Network Errors**: Check if firewall settings are blocking connections
3. **Scope Permissions**: If certain GitHub data is not accessible, verify the scope permissions in your OAuth app

### Debug Steps

1. Check Firebase Authentication logs in the console
2. Review the Network tab in browser developer tools
3. Verify the GitHub OAuth application settings

## Security Considerations

- GitHub OAuth tokens should be treated as sensitive data
- Consider implementing additional security measures for production environments
- Regular rotation of Client Secrets is recommended

## Advanced Configuration

### Custom Scopes
By default, basic GitHub profile information is requested. If you need access to additional GitHub data, you can configure custom scopes in Firebase.

### Enterprise GitHub
For GitHub Enterprise installations, additional configuration is required. Consult the Firebase documentation for GitHub Enterprise authentication setup.
