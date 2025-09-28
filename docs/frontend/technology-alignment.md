# Technology Alignment: Using Backend Capabilities from Next.js

This reference explains how the Next.js frontend should leverage backend technologies exposed by the Watch Party platform.

## Django REST Framework (DRF)

- All REST endpoints conform to DRF viewsets/serializers (see [`config/urls.py`](../../config/urls.py)).
- Expect consistent envelope: success responses provide resource payloads, validation errors return serializer error maps.
- Use TypeScript types generated from the backend OpenAPI schema (`/api/schema/` via drf-spectacular). Generate types with `openapi-typescript` and store in `@types/generated`.

## SimpleJWT Authentication

- Access tokens: short-lived, stored in memory and forwarded via `Authorization: Bearer` header.
- Refresh tokens: long-lived, stored securely in `httpOnly` cookies. Next.js Route Handlers call `/api/auth/refresh/` to rotate tokens.
- Handle token rotation in a server action to avoid exposing refresh tokens to the client bundle.

## Django Channels WebSockets

- Channels routes defined in [`apps/chat/routing.py`](../../apps/chat/routing.py), [`apps/interactive/routing.py`](../../apps/interactive/routing.py), and [`apps/parties/routing.py`](../../apps/parties/routing.py).
- Use the native `WebSocket` API or compatible libraries (e.g., `ws`, `@tanstack/query`) to connect, passing JWT via query string or custom header `Sec-WebSocket-Protocol: Bearer,<token>`.
- Implement exponential backoff reconnection and presence tracking aligned with `PartyConsumer` events.

## Celery & Async Tasks

- Video processing, analytics aggregation, and notification dispatch run asynchronously via Celery workers (`start-celery-worker.sh`).
- Frontend should poll or subscribe to status endpoints such as `/api/videos/{id}/processing/` and `/api/analytics/jobs/{id}/` to reflect Celery job progress.
- Display user feedback (spinners/toasts) until `status` transitions to `completed` or `failed`.

## Redis & Caching

- Realtime features rely on Redis through `channels_redis`. Frontend must be resilient to transient disconnects.
- Cached endpoints may expose `ETag`/`Last-Modified`. Use `If-None-Match` headers when available to minimize bandwidth.

## Stripe Billing

- Billing endpoints (e.g., `/api/billing/checkout/`) integrate with Stripe per [`apps/billing`](../../apps/billing/).
- Frontend initiates Stripe Checkout via the publishable key in `NEXT_PUBLIC_STRIPE_KEY` and uses session IDs returned from the backend.
- Handle webhooks indirectly: backend notifies frontend via notifications WebSocket when payment status changes.

## Firebase & Push Notifications

- The backend manages Firebase Admin for push notifications (`apps/notifications`).
- Frontend web app should register service workers using Firebase Web SDK and send registration tokens to `/api/notifications/push-subscriptions/`.
- Display fallback browser notifications for unsupported clients.

## Analytics Pipeline

- Analytics events captured through `/api/analytics/events/` and real-time party analytics endpoints.
- Debounce client-side analytics dispatch to avoid spamming Celery tasks; batch events where supported (`POST` array payloads).
- Align event names with `AnalyticsEvent` model defined in [`apps/analytics/models.py`](../../apps/analytics/models.py).

## Search Infrastructure

- Search endpoints under `/api/search/` likely backed by Elastic/OpenSearch (check `apps/search`).
- Provide instant-search UI with debounced requests and highlight results based on `SearchResult` schema.
- For advanced filters, inspect serializer filters in `apps/search/api.py` to mirror facets on the frontend.

## Third-Party Integrations

- Google/Firebase: Use tokens or configuration served from `/api/integrations/google/config/` to initialize client SDKs lazily.
- Social Auth: For social logins, the backend exposes OAuth redirect URLs. Implement Next.js route handler proxies to start flows without exposing backend secrets.
- Streaming Providers: Some parties use external streaming via `/api/integrations/providers/`. Render provider-specific components when `integration.type` indicates Twitch, YouTube, etc.

## Monitoring & Sentry

- Backend emits Sentry events; align frontend error reporting by initializing `@sentry/nextjs` with matching DSN.
- Include breadcrumbs correlating to API requests to aid cross-service debugging.

## Environment Management

- Store runtime config in `.env.local`; mirror backend required variables (`NEXT_PUBLIC_API_BASE_URL`, `NEXT_PUBLIC_WS_BASE_URL`, `NEXT_PUBLIC_STRIPE_KEY`, `FIREBASE_CONFIG_*`).
- During Vercel deploy, configure environment groups that match backend staging/production clusters.

## Local Development

1. Start backend via `./start-django.sh` or `docker-compose`.
2. Run websocket server (`./start-daphne.sh`) if testing realtime flows.
3. Launch frontend `pnpm dev` with proxies for `/api` and `/ws` to backend ports (use Next.js rewrites in `next.config.js`).
4. Seed demo data using backend fixtures (`python manage.py loaddata demo`).

