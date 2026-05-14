# 🎲 Ludo Game - Quick Start Guide

## ⚡ Fast Setup (5 minutes)

### 1️⃣ Start Python Backend

```bash
# Navigate to backend
cd chess_backend

# Install dependencies
pip install -r requirements.txt

# Start server
python main.py
```

✅ Server runs on `http://localhost:8000`
- API Docs: `http://localhost:8000/docs`
- WebSocket: `ws://localhost:8000/ws/{room_id}/{player_id}`

### 2️⃣ Start Flutter Frontend

```bash
# Navigate to frontend
cd chess-main

# Get dependencies
flutter pub get

# Run app
flutter run
```

✅ App launches on your device/emulator

---

## 🎮 Playing the Game

### Offline Mode
1. Open Ludo game from main menu
2. Tap **"Play Offline"**
3. Select 2 or 4 players
4. Roll dice and move tokens
5. First to get all tokens home wins! 🏆

### VS Computer Mode
1. Tap **"VS Computer"**
2. Select difficulty (Easy/Medium/Hard)
3. Play against AI opponent

### Online Multiplayer (Coming Soon)
1. Tap **"Play Online"**
2. Create or join a room
3. Wait for players to join
4. Start game
5. Real-time multiplayer gameplay

---

## 🎯 Core Features

| Feature | Status | Location |
|---------|--------|----------|
| Offline Game | ✅ | `lib/screens/ludo_game_screen.dart` |
| AI Opponent | ✅ | `lib/services/ai_player.dart` |
| Game Logic | ✅ | `lib/services/ludo_game_logic.dart` |
| Board Rendering | ✅ | `lib/widgets/ludo_painters.dart` |
| Multiplayer Backend | ✅ | `app/game_engine.py` |
| WebSocket | ✅ | `app/websocket_handler.py` |
| Sound System | 🔄 | `lib/services/sound_service.dart` |

---

## 📁 File Structure Overview

### Must-Know Files

**Frontend:**
```
📦 Models
├── lib/models/ludo_models.dart           ← Game data structures

📦 Game Logic
├── lib/services/ludo_game_logic.dart     ← Core rules
├── lib/services/ai_player.dart           ← AI opponent
├── lib/providers/game_provider.dart      ← State management

📦 UI
├── lib/screens/ludo_home_screen.dart     ← Main menu
├── lib/screens/ludo_game_screen.dart     ← Game screen
├── lib/widgets/ludo_painters.dart        ← Board rendering
```

**Backend:**
```
📦 Game
├── app/game_engine.py                    ← Game rules
├── app/room_manager.py                   ← Room management
├── app/websocket_handler.py              ← Real-time sync

📦 API
├── app/api_routes.py                     ← REST endpoints

📦 Main
├── main.py                                ← FastAPI app
└── requirements.txt                       ← Dependencies
```

---

## 🧪 Testing the API

### Create a Room
```bash
curl -X POST http://localhost:8000/api/rooms \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Room",
    "creatorId": "player1",
    "maxPlayers": 4
  }'
```

### List Rooms
```bash
curl http://localhost:8000/api/rooms
```

### Health Check
```bash
curl http://localhost:8000/health
```

---

## 🎨 Game Rules (Implemented)

✅ **Token Movement**
- Tokens open only on rolling 6
- Clockwise board movement
- Exact dice needed to reach home

✅ **Killing Tokens**
- Same position = capture opponent token
- Safe zones protect tokens (can't be killed)
- Killed tokens return to start

✅ **Winning**
- Move all 4 tokens to home
- First player home wins

✅ **Special Rules**
- 6 = extra turn
- 3 consecutive 6s = turn cancelled
- Safe positions: 0, 9, 14, 22, 27, 35, 40, 48

---

## 🤖 AI Difficulty Levels

### Easy 🟢
Random move selection from available tokens

### Medium 🟡
Balanced strategy:
1. Kill opponent tokens
2. Protect own tokens
3. Open new tokens
4. Progress toward home

### Hard 🔴
Aggressive strategy:
1. Eliminate opponent tokens (high priority)
2. Reach home path quickly
3. Strategic blocking
4. Predictive positioning

---

## 🔧 Configuration

### Backend Setup
Edit `.env` file:
```env
DATABASE_URL=sqlite:///./ludo_game.db
SERVER_HOST=0.0.0.0
SERVER_PORT=8000
DEBUG=True
```

### Frontend Setup
Edit `lib/constants.dart`:
```dart
const String API_URL = "http://localhost:8000";
const String WS_URL = "ws://localhost:8000/ws";
```

---

## 🐛 Troubleshooting

### Frontend Won't Connect
```
❌ Problem: "Connection refused"
✅ Solution: 
  - Ensure backend is running
  - Check URL in constants
  - Device can reach localhost
```

### Game Logic Issues
```
❌ Problem: "Token moved to wrong position"
✅ Solution:
  - Check ludo_game_logic.dart calculation
  - Verify BoardConfig settings
  - Test with debug prints
```

### WebSocket Errors
```
❌ Problem: "WebSocket connection failed"
✅ Solution:
  - Check websocket_handler.py
  - Verify room_id and player_id
  - Check network connectivity
```

---

## 📊 Project Stats

- **Lines of Code**: ~2500+
- **Flutter Files**: 10+
- **Python Files**: 5+
- **Game Rules**: 10+
- **Board Positions**: 52 main + 6 home
- **Difficulty Levels**: 3 (Easy, Medium, Hard)

---

## 🚀 Next Steps

### To Add Sounds
1. Add audio files to `assets/sounds/`
2. Update `sound_service.dart`
3. Call `playSound()` in game events

### To Add Leaderboard
1. Add database models
2. Create leaderboard API endpoint
3. Add leaderboard UI screen

### To Deploy
1. Backend: Docker + Heroku/AWS
2. Frontend: Google Play Store / App Store

---

## 📚 Documentation

For detailed information, see:
- `LUDO_GAME_IMPLEMENTATION.md` - Complete technical guide
- `lib/services/ludo_game_logic.dart` - Game logic comments
- `app/game_engine.py` - Backend logic documentation

---

## 💬 Support

**Issues?** Check these files:
1. Game logic errors → `ludo_game_logic.dart`
2. UI problems → `ludo_painters.dart`
3. Multiplayer issues → `websocket_handler.py`
4. API errors → `app/api_routes.py`

---

**Happy Gaming! 🎲✨**

Last Updated: May 14, 2026
