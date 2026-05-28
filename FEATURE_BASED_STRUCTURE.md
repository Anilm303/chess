# Feature-Based Folder Structure

The app already uses a feature-slice pattern for `face_liveness`. This document extends that idea to the rest of the Flutter codebase so UI, state, data, and shared helpers stay grouped by product area.

## Recommended Layout

```text
lib/
  core/
    config/
    constants/
    routes/
    theme/
    utils/
    widgets/
  features/
    auth/
      data/
        models/
        repositories/
        services/
      domain/
        entities/
        repositories/
        use_cases/
      presentation/
        screens/
        widgets/
        controllers/
    chat/
      data/
      domain/
      presentation/
    calls/
      data/
      domain/
      presentation/
    friends/
      data/
      domain/
      presentation/
    ludo/
      data/
      domain/
      presentation/
    chess/
      data/
      domain/
      presentation/
    notes/
      data/
      domain/
      presentation/
    stories/
      data/
      domain/
      presentation/
    notifications/
      data/
      domain/
      presentation/
    profile/
      data/
      domain/
      presentation/
    settings/
      data/
      domain/
      presentation/
    face_liveness/
      data/
      domain/
      presentation/
      ml/
  shared/
    models/
    services/
    widgets/
```

## Current File Mapping

- `lib/screens/login_screen.dart`, `lib/screens/register_screen.dart`, `lib/screens/forgot_password_screen.dart`, `lib/screens/reset_password_screen.dart` -> `lib/features/auth/presentation/screens/`
- `lib/services/auth_service.dart` -> `lib/features/auth/data/services/` or `lib/features/auth/presentation/controllers/` depending on ownership
- `lib/screens/chat_screen.dart`, `lib/screens/messaging_screen.dart`, `lib/services/message_service.dart` -> `lib/features/chat/`
- `lib/screens/call_screen.dart`, `lib/screens/incoming_call_screen.dart`, `lib/services/call_service.dart` -> `lib/features/calls/`
- `lib/screens/ludo_*`, `lib/services/ludo_*`, `lib/models/ludo_models.dart` -> `lib/features/ludo/`
- `lib/screens/chess_board_screen.dart`, `lib/services/ai_player.dart`, `lib/chess_logic.dart` -> `lib/features/chess/`
- `lib/screens/notes_*`, `lib/screens/add_note_screen.dart`, `lib/services/note_service.dart` -> `lib/features/notes/`
- `lib/screens/stories_*`, `lib/screens/add_story_screen.dart`, `lib/services/story_service.dart` -> `lib/features/stories/`
- `lib/screens/notifications_screen.dart`, `lib/widgets/notification_*`, `lib/services/notification_service.dart` -> `lib/features/notifications/`
- `lib/screens/profile_screen.dart`, `lib/screens/settings_screen.dart`, `lib/services/theme_service.dart` -> `lib/features/profile/` and `lib/features/settings/`
- `lib/models/*.dart` that are app-wide can move to `lib/shared/models/`
- `lib/widgets/*.dart` that are reused across multiple features can move to `lib/shared/widgets/`

## Migration Rule

Move one feature at a time:

1. Move the feature's screens, services, models, and widgets together.
2. Update imports for that feature only.
3. Keep `main.dart` thin and use a single app router or feature entry screen.
4. Leave shared utilities in `core/` or `shared/` so features do not depend on each other directly.

## Practical Starting Order

1. `auth`
2. `chat`
3. `calls`
4. `notes`
5. `stories`
6. `notifications`
7. `ludo`
8. `chess`

## Existing Example

The `face_liveness` feature is already close to the target pattern, so it can be used as the template for the rest of the app.