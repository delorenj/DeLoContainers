# Firebase Configuration for PotPie

## Overview
Firebase provides authentication and data storage services for PotPie's production environment. This document outlines the setup process and features enabled by Firebase integration.

## Setup Instructions

### 1. Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" 
3. Name your project (e.g., "PotPie-DeLoNet")
4. Configure Google Analytics (optional)
5. Click "Create project"

### 2. Configure Authentication
1. In Firebase console, navigate to Authentication → Sign-in method
2. Enable desired providers:
   - Email/Password (recommended baseline)
   - Google
   - GitHub
   - Others as needed

### 3. Generate Service Account Credentials
1. Go to Project Settings → Service accounts
2. Click "Generate new private key"
3. Save the JSON file as `firebase_service_account.json`
4. Place this file in the PotPie root directory

### 4. Update Environment Variables
Update your `.env` file:
```
isDevelopmentMode=disabled
ENV=production
```

### 5. GitHub Authentication (Optional)
If using GitHub auth:
1. Go to GitHub → Settings → Developer settings → OAuth Apps
2. Create a new OAuth app
3. Set Authorization callback URL to: `https://[YOUR-FIREBASE-PROJECT-ID].firebaseapp.com/__/auth/handler`
4. Copy Client ID and Secret to Firebase Authentication → GitHub provider

## Features Enabled by Firebase

### Authentication
- Secure user login and registration
- JWT-based API access
- Role-based authorization
- Session management

### User Management
- User profiles and preferences storage
- User activity tracking
- Access control lists

### Data Persistence
- Conversation history storage
- AI agent configuration persistence
- User-specific settings

## Firebase Security Rules
Important security considerations:
- Firebase authentication restricts API access to authorized users
- Database operations are limited to owner-only for user data
- Admin privileges are required for system-wide operations

## Troubleshooting

### Common Issues
1. **Authentication Failed**: Verify the service account JSON is properly formatted and in the root directory
2. **Permission Denied**: Check Firebase Security Rules
3. **JWT Errors**: Ensure environment variables are correctly set

### Testing Authentication
```bash
# Test if Firebase auth is working
curl -X GET http://localhost:8001/api/auth/status -H "Authorization: Bearer YOUR_TOKEN"
```

## Advanced Configuration
For enterprise setups, consider:
- Custom email templates
- Multi-factor authentication
- IP-based access restrictions
- Audit logging
