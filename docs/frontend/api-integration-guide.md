# Frontend ↔ Backend Integration Guide

This guide explains how the Next.js frontend communicates with the Watch Party backend. It covers REST conventions, authentication, pagination, realtime channels, and client utilities.

## Base Configuration

- **API Base URL**: `${process.env.NEXT_PUBLIC_API_BASE_URL}/api`
- **WebSocket Base URL**: `${process.env.NEXT_PUBLIC_WS_BASE_URL}/ws`
- **Authentication**: JSON Web Tokens (JWT) issued by `/api/auth/login/` and refreshed via `/api/auth/refresh/`.
- **Content Type**: `application/json` (multipart for uploads).
- **Pagination**: Cursor-based with `page`, `page_size`, and optional `cursor` parameters as described in [`docs/api/backend-endpoints.json`](../api/backend-endpoints.json).

Create a central API client in `lib/api-client.ts`:

```ts
export const apiClient = {
  async get<T>(path: string, options?: RequestInit) {
    const res = await fetch(`${process.env.NEXT_PUBLIC_API_BASE_URL}/api${path}`, {
      ...options,
      method: 'GET',
      headers: await withAuthHeaders(options?.headers),
      next: { revalidate: 0 },
    });
    return parseResponse<T>(res);
  },
  async post<T>(path: string, body?: unknown, options?: RequestInit) {
    const res = await fetch(`${process.env.NEXT_PUBLIC_API_BASE_URL}/api${path}`, {
      ...options,
      method: 'POST',
      headers: await withAuthHeaders({ 'Content-Type': 'application/json', ...options?.headers }),
      body: body ? JSON.stringify(body) : undefined,
    });
    return parseResponse<T>(res);
  },
  // implement patch/delete similarly
};
```

`withAuthHeaders` reads the JWT access token from cookies or NextAuth session. Refresh tokens are stored in `httpOnly` cookies and exchanged using Next.js Route Handlers (`app/api/auth/refresh/route.ts`).

## Authentication Flows

1. **Login** (`POST /api/auth/login/`)
   - Body: `{ "email": string, "password": string }`
   - Response: `{ access: string, refresh: string, user: {...} }`
   - Frontend stores `access` in memory (e.g., Zustand store) and `refresh` in `httpOnly` cookie via a server action.
2. **Register** (`POST /api/auth/register/`)
   - Provide profile fields defined in `apps/users/serializers.py` (username, email, password, profile data).
3. **Two-Factor** (`POST /api/auth/verify-2fa/`) when required by `apps/authentication` policies.
4. **Session Refresh** (`POST /api/auth/refresh/`) automatically invoked by the `AuthProvider` when TanStack Query receives a `401`.

## Core Feature Endpoints

| Feature | Endpoint | Notes |
|---------|----------|-------|
| Watch Parties | `GET /api/parties/` | List parties the user hosts or attends; use query params `status`, `cursor`.
| Create Party | `POST /api/parties/` | Submit payload matching `WatchPartyCreateSerializer` including `title`, `scheduled_for`, `video` reference, `settings`.
| Party Detail | `GET /api/parties/{partyId}/` | Includes participants, chat summary, polls.
| Party Invitations | `POST /api/parties/{partyId}/invite/` | Send invites; expect `emails` array.
| Party Analytics | `GET /api/analytics/parties/{partyId}/` | Power the dashboard analytics page.
| Realtime Sync | WebSocket `ws/party/{partyId}/` | Join with JWT in query string `?token=` or `Authorization` header via protocols.
| Conversations | `GET /api/messaging/conversations/` | Cursor pagination; use `MessagingThread` component.
| Party Chat Messages | `GET /api/chat/{partyId}/messages/` & `POST /api/chat/{partyId}/messages/send/` for sending.
| Videos | `GET /api/videos/` | Upload uses multipart `POST /api/videos/upload/`; track progress with `VideoProcessingJob` status polling (`/api/videos/{id}/processing/`).
| Events | `GET /api/events/` | Filter with `?from`, `?to`, `?type` for calendar.
| Notifications | `GET /api/notifications/` | Use `PATCH /api/notifications/{id}/read/` to mark as read.
| Store | `GET /api/store/items/` | Purchases via `POST /api/store/purchase/`.
| Billing | `GET /api/billing/subscription/` | Manage plan, `POST /api/billing/upgrade/`.
| Support | `POST /api/support/tickets/` | Attachments via multipart; follow-up updates `POST /api/support/tickets/{id}/messages/`.
| Admin Users | `GET /api/admin/users/` | Provide `role`, `status`, `search` filters.
| Moderation | `GET /api/moderation/reports/` & `POST /api/moderation/admin/reports/{id}/resolve/`.

Refer to serializers and viewsets under `apps/*/api` for payload shape.

## Data Fetching Strategy

- **Server Components**: Use `cache: 'no-store'` for personalized data; leverage React Suspense for parallel fetches in `app/(dashboard)/page.tsx`.
- **TanStack Query**: Wrap client components with `QueryProvider`. Define keys per resource (e.g., `['parties', { status, cursor }]`).
- **Optimistic Updates**: For actions like message send or notification mark-as-read, update query cache immediately and roll back if mutation fails.
- **Error Handling**: Normalize API errors using backend standard `{ "detail": string }` or serializer error maps.

## File Uploads

- Use `next-safe-middleware` to allow video uploads only from authorized roles.
- For large uploads, request pre-signed URL via `/api/videos/upload-url/` before uploading directly to storage.
- Track processing status by polling `/api/videos/{id}/` until `processing_state === 'ready'` or subscribing to `ws/party/{partyId}/` events that emit `video_ready`.

## Realtime Channels

- **Party Sync**: `ws://.../ws/party/{partyId}/` for playback position, reactions.
- **Chat**: `ws://.../ws/chat/{partyId}/` for in-party messages.
- **Notifications**: `ws://.../ws/notifications/` for toast updates.
- **Interactive Widgets**: Polls, screen share, and voice chat routes defined in [`apps/interactive/routing.py`](../../apps/interactive/routing.py).

The frontend should create a `WebSocketProvider` that handles connection lifecycle, authentication (JWT as query param), reconnection with exponential backoff, and dispatches events to Zustand stores.

## Rate Limiting & Retries

- The backend enforces throttling on endpoints like `/api/auth/login/` and `/api/parties/{id}/invite/`. Catch `429` responses and show retry countdowns.
- Use `Retry-After` header for scheduling retries. TanStack Query's retry logic should respect this header.

## Testing Requests

- Use MSW (Mock Service Worker) to simulate backend endpoints during Storybook and Playwright runs.
- Provide fixtures aligned with backend serializers (see `tests/` directory for JSON examples).

