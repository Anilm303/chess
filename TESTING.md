Manual Test Plan — Messaging & Stories UI

Prerequisites
- Flutter SDK installed
- Device/emulator available
- Backend running and reachable (default: http://127.0.0.1:7860)
- Ensure you are logged in in the app (or use a test account)

Quick start
```bash
cd chess_app
flutter pub get
flutter run
```

Tests
1. App launches
- App should open to the Messaging screen with top AppBar and bottom navigation (Chats, Stories, Notifications, Menu).

2. Navigation
- Tap bottom nav: switch between Chats, Stories grid, Notifications, Menu.
- AppBar title should update accordingly.

3. Stories strip (Chats tab)
- On Chats tab, confirm a horizontal stories strip appears above the user strip.
- Tap the leading `+` (Add) avatar: AddStoryScreen opens.
- Pick an image or video and `Share Story`.
- On success, AddStoryScreen should close and a SnackBar confirms upload.
- The stories strip should refresh (may need pull-to-refresh) and new story should appear.

4. Stories grid (Stories tab)
- Open Stories tab: grid of story cards is shown.
- Tap any story card: StoryViewer opens, swiping shows story items.
- Closing viewer should update the strip badge (viewed stories no longer show unviewed accent).

5. Profile & Chat navigation
- Tap a user in the horizontal user strip: opens `ChatScreen` with that user.
- Tap profile icon in AppBar: opens `ProfileScreen`.

6. Notifications & Menu
- Open Notifications tab: list appears; `Mark all` should call the service.
- Open Menu tab: Profile and Create Story items navigate correctly.

7. Error conditions
- Attempt to upload an unsupported file or disconnect backend: app should show a SnackBar with the error.

Notes
- If using an Android emulator, backend at `http://10.0.2.2:7860` may be required; ensure `ApiService.baseUrl` points to correct host.
- Large videos may take longer; uploads use a 120s timeout for multipart requests.

If you find issues during testing, paste the exact console logs or screenshots and I'll fix them step-by-step.
