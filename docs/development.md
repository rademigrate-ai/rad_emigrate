# Development Guide

## Setup

```bash
flutter pub get
```

## Validation

```bash
flutter analyze
flutter test
flutter build web
```

## Rules

1. Keep features isolated under `lib/features/`.
2. Keep business logic out of widgets; use controllers / notifiers.
3. Use repository contracts in domain; implement in data.
4. Prefer mock repositories until real APIs exist.
5. Add tests when changing auth, session, or routing behaviour.
6. Do not invent RAD services, prices, or guarantees.

## Demo

- Login: any email + any non-empty password
- OTP: `123456`
