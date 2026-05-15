# Deploy Flutter web to Hugging Face Space (Docker)

This mini-guide explains how to deploy the `build/web` output of this Flutter project to a Docker-based Hugging Face Space.

Prerequisites
- Git installed and configured
- PowerShell (Windows) or equivalent terminal
- A Hugging Face account and a write access token (create at https://huggingface.co/settings/tokens)

Quick steps
1. Build the Flutter web bundle (if not already built):
```powershell
cd "C:\Users\Lenovo\Desktop\chess\chess-main"
flutter build web --release --dart-define=API_BASE_URL=https://Anil1515-chess-backend.hf.space/api
```

2. Create a new Docker Space on Hugging Face (choose SDK = Docker) and note the repo URL.

3. Run the included `deploy_to_hf.ps1` script (edit parameters if your Space name differs):
```powershell
# from C:\Users\Lenovo\Desktop\chess
.\chess-main\deploy_to_hf.ps1 -HFUser Anil1515 -HFSpace chess-frontend
```

4. When prompted for credentials during `git push`, enter your Hugging Face username and paste your access token as the password.

5. After pushing, open the Space page and check `Logs` → `Build` and `Container` for build/run output. If the App tab is blank, open the browser DevTools console to see runtime errors.

If you prefer manual steps or upload via the HF web UI, follow the guide in the main conversation or copy the `web/` folder contents and upload them via Files → Upload.

If you need help reading the logs or debugging errors, paste the first 30 lines from Build/Container logs and any App Console output into the chat.
