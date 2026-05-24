# Google OAuth "Testing" Mode — access_denied Gotcha

## The Problem

New Google Cloud OAuth clients default to **Testing** publishing status.
While in Testing mode:
- Only explicitly added **test users** can authorize the app.
- Non-test users get `access_denied` with the message: *"The developer hasn't given you access to this app. It's currently being tested and hasn't been verified by Google."*

## The Fix (before Step 3 — do it early)

**Add the user as a test user BEFORE generating the auth URL:**

1. Go to: https://console.cloud.google.com/auth/audience
2. Select the project with your OAuth client
3. Click **"Test users"** → **"Add users"**
4. Enter the Google account email that will authorize
5. Save

Then generate the auth URL and proceed as normal.

## Verification

- If the user still gets `access_denied` after being added as test user, they may have multiple Google accounts — make sure they're logging in with the exact email added as test user.
- After successful auth, the app can remain in Testing forever for <= 100 test users. No verification needed unless you want to publish publicly.

## Relevant Error Message (full text for searching)

```
access_denied

The developer hasn't given you access to this app. It's currently being tested 
and hasn't been verified by Google. If you think you should have access, 
contact the developer (milvillena99@gmail.com).
```

## Status Check

Publishing status is visible at:
https://console.cloud.google.com/auth/external-credentials
Look for "Publishing status: Testing" or "Publishing status: Production"
