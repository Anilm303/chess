# Quick Start Testing Guide

## 🚀 Launch Instructions

### Step 1: Start Backend
```bash
cd c:\Users\Lenovo\Desktop\chess\chess_backend
python run.py
# Should show: "Running on http://0.0.0.0:7860"
```

### Step 2: Start Android Emulator
```bash
# In Android Studio or:
emulator -avd Pixel_4_API_30
```

### Step 3: Get Device Serial
```bash
adb devices
# Note the device ID (emulator-5554 or real device serial)
```

### Step 4: Run Flutter App on Both

**On Emulator:**
```bash
cd c:\Users\Lenovo\Desktop\chess\chess-main
flutter run -d emulator-5554
```

**On Real Device (in new terminal):**
```bash
cd c:\Users\Lenovo\Desktop\chess\chess-main
adb devices  # Get real device ID (e.g., ABC123)
flutter run -d ABC123
```

### Step 5: Watch Logs (in another terminal)
```bash
# Emulator logs
adb logcat | findstr "CallService"

# Real device logs
adb -s ABC123 logcat | findstr "CallService"
```

---

## 📞 Test Scenario 1: Emulator Calls Real Device (Audio)

### Setup:
- **Emulator User:** user_a / password
- **Real Device User:** user_b / password
- **Backend:** http://192.168.1.12:7860

### Steps:
1. **Emulator:** Login as user_a
2. **Real Device:** Login as user_b
3. **Emulator:** Navigate to Contacts/Chat
4. **Emulator:** Find and tap user_b
5. **Emulator:** Select "📞 Audio Call" button
6. **Emulator:** Should show "Calling..." with timer

### Expected on Real Device:
```
✓ Incoming call notification/screen
✓ Caller avatar visible (user_a's profile pic)
✓ Caller name: "user_a"
✓ Call type: "Voice Call"
✓ Two buttons: Decline | Accept
```

### Real Device User Actions:
1. Tap "Accept" button
2. **Should transition to:** Call screen with:
   ```
   ✓ Caller name at top
   ✓ Status: "Connecting..." → "Connected"
   ✓ Duration timer: "00:00" and counting
   ✓ Mute button (microphone icon)
   ✓ Speaker button
   ✓ End call button (red)
   ```

### Verification:
- [ ] Audio is clear (both speak, both hear)
- [ ] Mute button works (speaker stops hearing you)
- [ ] Speaker button works (can toggle)
- [ ] End button ends call and returns both to main screen

---

## 📱 Test Scenario 2: Emulator Calls Real Device (Video)

### Setup: Same as Scenario 1

### Steps:
1. **Emulator:** Find user_b in contacts
2. **Emulator:** Select "📹 Video Call" button
3. **Real Device:** Accept when prompt appears

### Expected Video Elements:
```
✓ Local preview (small, top-right corner)
  - Shows own camera feed
  
✓ Remote video (center/fullscreen)
  - Shows other person's camera feed
  
✓ Video Controls:
  - 📹 Camera button (toggle on/off)
  - 🔄 Flip camera (front/back)
  - 🔇 Mute (audio)
  - 🔊 Speaker
  - 🔴 End call
```

### Verification:
- [ ] Local camera shows your face
- [ ] Remote shows other person's face
- [ ] Camera toggle works (video on/off)
- [ ] Flip camera switches to back camera
- [ ] Audio still works in video mode
- [ ] Timer counts correctly

---

## 📞 Test Scenario 3: Real Device Calls Emulator

### Setup: Reverse roles
- **Real Device User:** user_a
- **Emulator User:** user_b

### Steps:
1. **Real Device:** Login as user_a
2. **Emulator:** Login as user_b
3. **Real Device:** Initiate audio or video call to user_b
4. **Emulator:** Accept call

### Expected:
- Same behavior as Scenario 1 & 2 but roles reversed
- Audio and video should work in both directions

---

## 🔍 Log Monitoring

### Watch for these key logs:

**Connection Established:**
```
✅ Socket connected (id=...)
```

**Media Preparation:**
```
🎬 Preparing local media... videoCall=true
🔐 Permissions: {Permission.microphone: granted, Permission.camera: granted}
📞 Getting user media...
✅ Media stream obtained
🎙️ Audio: 1, 📹 Video: 1
```

**Peer Connection:**
```
🔗 Creating peer connection for [username]
✅ Peer created for [username]
```

**SDP Exchange:**
```
📤 Sending offer to [username]
📥 Offer from [username]
📝 Creating answer...
✅ Answer sent
```

**Connection Live:**
```
CallStatus.connected
⏱️ Call timer started
Connected
```

---

## ❌ Troubleshooting

### Issue: "Incoming call screen not appearing"
**Solution:**
```bash
# Check socket connection
adb logcat | findstr "Socket"

# Restart backend
python run.py

# Ensure Firebase/CallKit is properly initialized
# Check AndroidManifest.xml has:
# - CAMERA permission
# - RECORD_AUDIO permission
# - MODIFY_AUDIO_SETTINGS permission
```

### Issue: "White screen during call"
**Solution:**
- Already fixed in new code
- If still appears, check:
```bash
adb logcat | findstr "Renderer\|RTCVideoView"
```

### Issue: "No audio or audio unclear"
**Solution:**
- Ensure Speaker is ON (yellow button in UI)
- Check device volume is not muted
- Verify microphone permissions granted
- Check autoGainControl is enabled (it is in code)

### Issue: "No video"
**Solution:**
- Ensure Camera permission granted
- Check local preview shows (small window top-right)
- Verify emulator has camera enabled
- Check RTCVideoRenderer initialized

### Issue: "Backend connection fails"
**Solution:**
```bash
# Check backend is running
netstat -an | findstr 7860

# Check IP is correct (192.168.1.12)
ipconfig

# Ensure device is on same WiFi network
# Ping test:
adb shell ping 192.168.1.12
```

---

## 📊 Success Criteria

### Full Test Passed When:
- [ ] Both devices can initiate and receive calls
- [ ] Audio is clear and bidirectional
- [ ] Video shows on both ends when requested
- [ ] All buttons work (Mute, Camera, Speaker, End)
- [ ] Call duration timer displays and counts correctly
- [ ] Caller information (avatar, name) displays correctly
- [ ] Proper state transitions (Ringing → Connecting → Connected)
- [ ] Calls can be ended cleanly
- [ ] No crashes or errors in logs

---

## 📝 Notes

- **Backend IP:** 192.168.1.12 (your machine)
- **Backend Port:** 7860
- **Emulator:** Usually on 192.168.1.x (auto)
- **Real Device:** Must be on same WiFi (192.168.1.x)
- **Logs:** Always check `grep "CallService"` when debugging

---

## Quick Reference

```
╔════════════════════════════════════════╗
║      CALL FLOW DIAGRAM                 ║
╠════════════════════════════════════════╣
║                                        ║
║  Device A          Socket            Device B
║     │───────────→ Backend ←────────────│
║     │  call_user              incoming_call
║     │                                  │
║     │  [Shows "Calling..."]       [Shows Accept]
║     │                                  │
║     │            accept_call           │
║     │←──────────────────────────────────│
║     │                                  │
║  🔗 WebRTC P2P Connection Established  🔗
║     │═══════════════════════════════════│
║     │  SDP Offer/Answer                 │
║     │  ICE Candidates                   │
║     │  Audio/Video Streams              │
║     │                                  │
║  📞 CALL CONNECTED 📞                  │
║     │ [Call Screen with Video/Audio]  │
║     │                                  │
║     │            end_call              │
║     │─────────────────────────────────→│
║     │                                  │
║  Cleanup & Disconnect                  │
║     │                                  │
╚════════════════════════════════════════╝
```

---

## Ready? Let's test! 🚀

Run backend, emulator, and follow the test scenarios above.
Check logs with: `adb logcat | findstr "CallService"`

Good luck! 🎉
