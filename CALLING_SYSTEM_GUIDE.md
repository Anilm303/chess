# Flutter Video/Audio Calling - Complete Fix & Testing Guide

## Changes Made

### 1. **New `call_service.dart`** - Complete Rewrite
- ✅ Proper socket event handlers for all call states
- ✅ Complete WebRTC peer connection lifecycle
- ✅ Proper renderer initialization and cleanup
- ✅ Audio/video media constraints with emulator fallback
- ✅ Call duration timer with elapsed time
- ✅ Debug logging for all events
- ✅ Proper state transitions: idle → ringing → connecting → connected → ended
- ✅ ICE candidate handling
- ✅ SDP offer/answer exchange
- ✅ Multi-participant support prepared

**Key Features:**
- `_log()` method for detailed debugging
- Proper async/await flow
- Renderer pooling and disposal
- Stream cleanup on call end
- Call duration tracking

### 2. **New `incoming_call_screen.dart`** - Proper UI
- ✅ Dark mode design
- ✅ Pulsing avatar animation  
- ✅ Clear accept/decline buttons with animations
- ✅ Caller name and call type display
- ✅ Profile image support with fallback
- ✅ Landscape/portrait responsive layout

### 3. **New `call_screen.dart`** - Modern Dark UI
- ✅ Dark gray background (#1E1E1E)
- ✅ Local preview in top-right corner
- ✅ Remote video full screen or grid
- ✅ Header with caller name and call status
- ✅ Call duration timer
- ✅ Control buttons: Mute, Camera, Flip, Speaker, End
- ✅ Status-based button styling (red for end, gray for active)
- ✅ No white screen issue - proper layout management
- ✅ Proper padding and safe areas

### 4. **Updated `main.dart`** - CallKit Integration
- ✅ Proper event subscription with cleanup
- ✅ Stream subscription disposal in dispose()
- ✅ Error handling for all CallKit events
- ✅ Navigation to CallScreen on accept
- ✅ Proper async/await handling
- ✅ Debug logging for all events

---

## Network Configuration

### Backend IP Setup (192.168.1.12)
Edit `lib/services/api_service.dart` (already configured):
```dart
static const String _defaultPhysicalDeviceBaseUrl =
    'http://192.168.1.12:7860/api';
```

This ensures both emulator and physical device can reach your backend.

---

## Testing Checklist

### ✅ Setup Phase
- [ ] Start backend server on `192.168.1.12:7860`
- [ ] Run Android Emulator
- [ ] Connect physical device on same Wi-Fi (192.168.1.x)
- [ ] Launch app on emulator and physical device
- [ ] Both devices show "Socket connected" in logs

### ✅ Test 1: Emulator → Real Device (Audio Call)
1. On **Emulator**: Login as User A
2. On **Real Device**: Login as User B  
3. On **Emulator**: Go to contacts, tap User B, select "Audio Call"
4. On **Real Device**: 
   - [ ] See incoming call notification/screen
   - [ ] Caller avatar displays
   - [ ] Caller name shows
   - [ ] Accept button works
5. On **Both devices**:
   - [ ] Call connects (status changes to "Connected")
   - [ ] Duration timer starts
   - [ ] Audio is clear (test by speaking)
   - [ ] Mute button works (toggle on/off)
   - [ ] Speaker button works
6. **End call** and verify both close call screen

### ✅ Test 2: Emulator → Real Device (Video Call)
1. Repeat Test 1 but select "Video Call"
2. On **Both devices**:
   - [ ] Local camera preview shows (top-right small window)
   - [ ] Remote video displays (main window)
   - [ ] Camera is enabled initially
   - [ ] Camera toggle button works (on/off)
   - [ ] Flip camera button works
   - [ ] Audio works in video call

### ✅ Test 3: Real Device → Emulator (Audio Call)
1. On **Real Device**: Initiate audio call to Emulator user
2. On **Emulator**: 
   - [ ] See incoming call screen
   - [ ] Accept and connect
   - [ ] Audio test as in Test 1

### ✅ Test 4: Real Device → Emulator (Video Call)
1. Repeat Test 3 with video call
2. Verify video on both ends

### ✅ Test 5: Reject Call
1. One device calls another
2. Recipient taps **Decline**
3. Both devices show "Call declined"
4. Caller's call screen closes

### ✅ Test 6: Call Duration
1. During connected call:
   - [ ] Timer shows MM:SS format
   - [ ] Timer increments every second
   - [ ] Timer accurate

### ✅ Test 7: Network Resilience  
1. During call, go to Settings → WiFi, turn WiFi off for 2 seconds
2. Turn WiFi back on
3. Call should reconnect or gracefully end

### ✅ Test 8: Camera Fallback (Emulator)
1. Run on emulator (which has no real camera)
2. Should fallback to software camera or handle gracefully
3. Should not crash

---

## Debug Logging

### To see detailed logs:
```bash
# Terminal 1: Watch emulator logs
adb logcat | grep "CallService"

# Terminal 2: Watch physical device logs
adb -s <DEVICE_ID> logcat | grep "CallService"
```

### Key Log Messages:
- `✅ Socket connected` - WebSocket established
- `🎬 Preparing local media` - Permission check
- `📹 Media stream obtained` - Camera/mic acquired
- `🔗 Creating peer connection` - P2P setup
- `📤 Sending offer` - SDP offer sent
- `📥 Received answer` - SDP answer received
- `✅ Answer processed` - Ready to transmit
- `🧊 ICE candidate` - Network candidate added

---

## Common Issues & Fixes

### 🔴 "White Screen During Call"
**Cause:** Renderer not initialized or no remote stream
**Fix:** Already handled in new code with placeholder UI

### 🔴 "No Audio / Muted Audio"
**Cause:** autoGainControl disabled, speaker off
**Fix:** Enabled autoGainControl=true, speaker auto-on

### 🔴 "No Camera on Emulator"
**Cause:** Emulator lacks real camera
**Fix:** New constraints support emulator camera fallback

### 🔴 "Incoming Call Not Appearing"
**Cause:** Socket not connected, CallKit not initialized
**Fix:** Proper socket connection in main.dart, CallKit event handling

### 🔴 "Call Ends Immediately"
**Cause:** Media preparation failed, peer connection error
**Fix:** Proper error logging, state management

### 🔴 "Blank Avatar / Profile Picture"
**Cause:** Base64 decoding failed
**Fix:** Try-catch with fallback to initial letter

### 🔴 "Permission Denied"
**Cause:** Permissions not granted
**Fix:** App requests permission, logs if denied

---

## Files Modified

```
lib/services/call_service.dart ...................... ✅ REWRITTEN
lib/screens/call_screen.dart ........................ ✅ REWRITTEN  
lib/screens/incoming_call_screen.dart .............. ✅ REWRITTEN
lib/main.dart ....................................... ✅ UPDATED
```

### Backup Files (old versions):
```
lib/services/call_service_old.dart
lib/screens/call_screen_old.dart
lib/screens/incoming_call_screen_old.dart
```

---

## Performance Considerations

1. **Renderer Lifecycle:** Renderers are properly disposed after calls
2. **Media Streams:** Tracks are stopped and streams disposed
3. **Peer Connections:** Properly closed after call ends
4. **Memory:** No memory leaks from unclosed connections
5. **CPU:** Efficient constraint-based video encoding

---

## Next Steps for Production

1. **STUN/TURN Servers:** Add production TURN servers in peer connection
2. **Call History:** Save calls to database
3. **Call Recording:** Implement media recording
4. **Notifications:** Improve push notifications
5. **Group Calls:** Expand multi-participant support
6. **UI Polish:** Add call transfer, conference features

---

## Support & Troubleshooting

If you encounter issues:

1. Check logs with grep "CallService"
2. Verify backend is running on 192.168.1.12:7860
3. Check both devices are on same WiFi
4. Try clearing app cache and reinstalling
5. Check that permissions are granted in app settings
6. Restart emulator/device if socket won't connect

---

**Version:** 1.0 - Complete Rewrite  
**Date:** May 11, 2026  
**Status:** Ready for Testing
