# ReadRSS

Flutter RSS reader with auto refresh, notification badge, sync link, and in-app article overlay.

## Run App

```bash
flutter pub get
flutter run -d chrome
```

Web app mặc định dùng gateway:

`https://readrss-gateway.onrender.com`

## RSS Gateway (shelf + CORS)

For feeds blocked by browser CORS, run local gateway:

```bash
dart run tool/rss_gateway.dart --port 8787
```

Nếu muốn override sang gateway khác (ví dụ local), dùng:

```bash
flutter run -d chrome --dart-define=RSS_GATEWAY_URL=http://localhost:8787
```

Gateway endpoints:

- `GET /health`
- `GET /api/rss?url=<encoded_rss_url>`

## Deploy Gateway on Render

This repo already includes Render Blueprint config: [render.yaml](render.yaml).

1. Push code to GitHub.
2. In Render: `New +` -> `Blueprint` -> select this repo.
3. Deploy service `readrss-gateway` (free plan).
4. After deploy, copy gateway URL, for example:
   `https://readrss-gateway.onrender.com`

Build Flutter Web with gateway URL:

```bash
flutter build web --release --dart-define=RSS_GATEWAY_URL=https://readrss-gateway.onrender.com
```

## Build

```bash
flutter build web --release
flutter build apk --release
```
