# 🩸 BloodLink

BloodLink is an iOS app that connects people who urgently need blood with nearby donors. A requester posts a blood request, matching donors see it live, and they respond with a single tap: **Available** or **Not Available**.

> Academic prototype built for a college project. Push notifications are simulated with an in-app banner.

## Features

- **Role-based accounts:** sign up as a Donor or Requester, each with their own dashboard. Admin accounts can't be created from the sign-up screen; an admin is a user whose `role` is set to `admin` in Firestore (the demo data includes one)
- **Donor profile:** name, phone, blood group, city, and an availability toggle
- **Blood requests:** create, edit, and delete requests with patient details, units needed, hospital, city, urgency (Normal / Urgent / Critical), contact number, and notes
- **Smart matching:** donors only see open requests that match their blood group, filtered by city and availability
- **Donor responses:** donors mark themselves Available or Not Available, and requesters see who responded
- **Real-time updates:** Firestore snapshot listeners keep every dashboard in sync without refreshing
- **In-app notification banner:** a lightweight stand-in for push notifications
- **Admin dashboard:** view every request in the system and update or close its status
- **Firestore security rules:** users can only change their own data, and admin actions are restricted to admins

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| Auth | Firebase Authentication (Email/Password) |
| Database | Cloud Firestore |
| Version control | Git + GitHub |

## Screenshots

<!-- Add screenshots here, e.g. ![Login](screenshots/login.png) -->

| Login | Donor Dashboard | Requester Dashboard | Admin Dashboard |
|---|---|---|---|
| _add_ | _add_ | _add_ | _add_ |

## Getting Started

### Requirements

- macOS with **Xcode 15.4** (or later)
- A Firebase project (the free Spark plan is enough)

### 1. Clone the repo

```bash
git clone https://github.com/tiwarisudhanshu165/BloodLink.git
cd BloodLink
```

### 2. Firebase setup

1. Create a project in the [Firebase console](https://console.firebase.google.com).
2. Enable **Authentication → Sign-in method → Email/Password**.
3. Create a **Firestore Database**.
4. Register an iOS app in the project. The bundle identifier must match your Xcode target **exactly**.
5. Download `GoogleService-Info.plist` and add it to the Xcode target.
6. Publish the security rules from the [Firestore Security Rules](#firestore-security-rules) section.

### 3. Firebase SDK version

The Firebase iOS SDK is pinned to **exactly `10.29.0`**. Newer versions (v12+) need Xcode 16 and fail on Xcode 15.4.

In Xcode, go to **Project → Package Dependencies**, and set the `firebase-ios-sdk` rule to **Exact Version 10.29.0**.

### 4. Run

Open `BloodLink.xcodeproj`, choose a simulator, and press **Run**.

## Demo Data

Debug builds include a seeder (`DemoSeeder.swift`) that creates demo accounts, blood requests, and donor responses. Tap the **Seed Demo Data** button on the login screen once, then wait for `🎉 Seeding complete` in the Xcode console. It is safe to run again.

All demo accounts share the password **`Demo@1234`**.

| Role | Email | Details |
|---|---|---|
| Admin | `admin@bloodlink.demo` | Sees all requests |
| Requester | `rohan.requester@bloodlink.demo` | 2 open requests (O+, A+) in Noida |
| Requester | `priya.requester@bloodlink.demo` | 1 open (B+), 1 fulfilled (O-) |
| Requester | `amit.requester@bloodlink.demo` | 1 open (AB+), 1 closed (A+) |
| Donor | `aarav.donor@bloodlink.demo` | O+, Noida, available |
| Donor | `neha.donor@bloodlink.demo` | A+, Noida, available |
| Donor | `karan.donor@bloodlink.demo` | B+, Greater Noida, available |
| Donor | `simran.donor@bloodlink.demo` | O-, Delhi, available |
| Donor | `vikram.donor@bloodlink.demo` | AB+, Ghaziabad, available |
| Donor | `isha.donor@bloodlink.demo` | A+, Greater Noida, available |
| Donor | `manish.donor@bloodlink.demo` | B-, Noida, **not available** |
| Donor | `pooja.donor@bloodlink.demo` | O+, Delhi, available |

## Data Model

| Collection | Purpose |
|---|---|
| `users/{uid}` | Account info and role |
| `donors/{uid}` | Donor profile: name, phone, blood group, city, availability |
| `requests/{requestId}` | A blood request and its status (`open`, `fulfilled`, `closed`) |
| `requests/{requestId}/responses/{donorUid}` | A donor's Available / Not Available response |

## Firestore Security Rules

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() {
      return request.auth != null;
    }

    function isOwner(uid) {
      return isSignedIn() && request.auth.uid == uid;
    }

    function isAdmin() {
      return isSignedIn() &&
        exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    match /users/{uid} {
      allow read: if isOwner(uid) || isAdmin();
      allow create: if isOwner(uid);
      allow update: if isAdmin() ||
        (isOwner(uid) && request.resource.data.role == resource.data.role);
      allow delete: if isAdmin();
    }

    match /donors/{uid} {
      allow read, write: if isOwner(uid);
    }

    match /requests/{requestId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && request.resource.data.requesterId == request.auth.uid;
      allow update: if isAdmin() ||
        (isSignedIn() && resource.data.requesterId == request.auth.uid);
      allow delete: if isAdmin() ||
        (isSignedIn() && resource.data.requesterId == request.auth.uid);

      match /responses/{donorId} {
        allow create, update: if isOwner(donorId);
        allow read: if isAdmin() ||
          isOwner(donorId) ||
          (isSignedIn() &&
            get(/databases/$(database)/documents/requests/$(requestId)).data.requesterId == request.auth.uid);
        allow delete: if isAdmin() ||
          (isSignedIn() &&
            get(/databases/$(database)/documents/requests/$(requestId)).data.requesterId == request.auth.uid);
      }
    }
  }
}
```

## Limitations and Future Scope

- Real push notifications (APNs) need a paid Apple Developer account and a physical device, so an in-app banner is used instead
- Matching currently uses exact blood group, city, and availability; compatible-group matching (e.g. O- donors for any group) could be added
- Distance-based matching with location services
- Donor donation history and a cooldown period between donations

## Team

- Sudhanshu Tiwari
- Samarth Soni
