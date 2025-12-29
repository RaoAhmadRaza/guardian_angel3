# Firebase Setup Guide

This document explains how to complete the Firebase setup for Guardian Angel.

## Prerequisites

1. **Firebase Account**: Create a project at [Firebase Console](https://console.firebase.google.com/)
2. **FlutterFire CLI**: Install the CLI tool

```bash
dart pub global activate flutterfire_cli
```

## Quick Setup (Recommended)

Run the FlutterFire CLI to automatically configure Firebase:

```bash
cd /path/to/guardian_angel2-main
flutterfire configure
```

This will:
1. Create or select a Firebase project
2. Register your app for Android, iOS, and Web
3. Download platform-specific configuration files
4. Generate `lib/firebase/firebase_options.dart` with real credentials

**After running `flutterfire configure`:**
- Replace the placeholder `lib/firebase/firebase_options.dart` with the generated one
- Or let FlutterFire overwrite it automatically

---

## Manual Setup (Alternative)

If you prefer manual configuration:

### 1. Android Configuration

1. Go to Firebase Console → Project Settings → Your apps → Android
2. Register your app with package name: `com.example.guardian_angel_fyp`
3. Download `google-services.json`
4. Place it in `android/app/google-services.json`

**android/build.gradle** (project-level):
```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

**android/app/build.gradle** (app-level):
```gradle
apply plugin: 'com.google.gms.google-services'
```

### 2. iOS Configuration

1. Go to Firebase Console → Project Settings → Your apps → iOS
2. Register your app with bundle ID: `com.example.guardianAngel`
3. Download `GoogleService-Info.plist`
4. Place it in `ios/Runner/GoogleService-Info.plist`
5. Add it to the Xcode project

### 3. Web Configuration

1. Go to Firebase Console → Project Settings → Your apps → Web
2. Register your app
3. Copy the Firebase config object
4. Update `web/index.html`:

```html
<script src="https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.7.0/firebase-auth-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.7.0/firebase-firestore-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.7.0/firebase-storage-compat.js"></script>
<script>
  const firebaseConfig = {
    apiKey: "YOUR_API_KEY",
    authDomain: "YOUR_AUTH_DOMAIN",
    projectId: "YOUR_PROJECT_ID",
    storageBucket: "YOUR_STORAGE_BUCKET",
    messagingSenderId: "YOUR_SENDER_ID",
    appId: "YOUR_APP_ID"
  };
  firebase.initializeApp(firebaseConfig);
</script>
```

---

## Firebase Services Setup

### Authentication

1. Go to Firebase Console → Authentication → Sign-in method
2. Enable the providers you need:
   - **Google**: Enable and configure OAuth consent screen
   - **Apple**: Enable and configure Sign in with Apple
   - **Phone**: Enable and add test phone numbers

### Firestore Database

1. Go to Firebase Console → Firestore Database
2. Create database (start in test mode for development)
3. Set up security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Subcollections under user document
      match /{subcollection}/{document} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
    
    // Deny all other access by default
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

### Firebase Storage

1. Go to Firebase Console → Storage
2. Get started (start in test mode for development)
3. Set up security rules:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Users can only access their own files
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Deny all other access by default
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

---

## Project Structure

```
lib/
  firebase/
    firebase.dart              # Barrel file for all exports
    firebase_initializer.dart  # Initialization logic
    firebase_options.dart      # Platform-specific config (generated)
    auth/
      auth_service.dart        # Authentication abstraction
      auth_providers.dart      # Provider definitions
    firestore/
      firestore_service.dart   # Firestore abstraction
    storage/
      storage_service.dart     # Storage abstraction
```

---

## Usage Examples

### Authentication

```dart
import 'package:guardian_angel_fyp/firebase/firebase.dart';

// Get auth service
final authService = AuthService.instance;

// Check if user is logged in
if (authService.isAuthenticated) {
  print('User ID: ${authService.currentUserId}');
}

// Listen to auth state changes
authService.authStateChanges.listen((user) {
  if (user != null) {
    print('User signed in');
  } else {
    print('User signed out');
  }
});

// Sign out
await authService.signOut();
```

### Firestore

```dart
import 'package:guardian_angel_fyp/firebase/firebase.dart';

// Get firestore service
final firestoreService = FirestoreService.instance;

// Access a collection
final usersRef = firestoreService.collection('users');

// Access current user's document
final userDoc = firestoreService.currentUserDocument('users');

// Write data
await userDoc.set({
  'name': 'John Doe',
  'createdAt': firestoreService.serverTimestamp,
});

// Read data
final snapshot = await userDoc.get();
final data = snapshot.data();
```

### Storage

```dart
import 'package:guardian_angel_fyp/firebase/firebase.dart';

// Get storage service
final storageService = StorageService.instance;

// Get a reference for profile image
final profileRef = storageService.profileImageRef('avatar.jpg');

// Get download URL (after upload)
final url = await profileRef.getDownloadURL();
```

---

## Troubleshooting

### "Firebase not initialized" error

Make sure:
1. You've run `flutterfire configure`
2. Platform config files are in place (google-services.json, GoogleService-Info.plist)
3. The app bootstrap runs before accessing Firebase services

### "No Firebase App" error

Check that `FirebaseInitializer.initialize()` completes successfully in the bootstrap phase.

### iOS build fails

Ensure:
1. `GoogleService-Info.plist` is added to the Xcode project (not just the folder)
2. iOS deployment target is compatible (iOS 12.0+)

### Android build fails

Ensure:
1. `google-services.json` is in `android/app/`
2. Google Services plugin is applied in gradle files
3. minSdkVersion is 21 or higher

---

## Next Steps

After completing Firebase setup:

1. **Implement Auth Providers**: Add Google, Apple, Phone sign-in in `auth/` folder
2. **Add Data Models**: Create Firestore document models
3. **Add Upload Logic**: Implement file upload in storage service
4. **Set Up Security Rules**: Tighten Firestore and Storage rules for production
