# Frontend User & Admin Experience Scenarios

This document outlines end-to-end scenarios the Next.js frontend must support for both end users and administrators. Each scenario references relevant pages from the [structure guide](./nextjs-pages-and-components.md) and backend touchpoints from the [integration guide](./api-integration-guide.md).

## Personas

- **Host**: Runs watch parties, uploads videos, manages invitations.
- **Participant**: Joins parties, chats, reacts, purchases items.
- **Content Creator**: Focused on video uploads, analytics, monetization.
- **Administrator**: Oversees platform health, moderation, billing, support.

## User Scenarios

### 1. First-Time Visitor → Registered Host
1. Visit marketing landing (`/(marketing)`).
2. Explore pricing, click **Get Started**.
3. Register via `/(auth)/register` (POST `/api/auth/register/`).
4. Verify email using link hitting `/(auth)/verify-email/[token]`.
5. Log in `/(auth)/login` (POST `/api/auth/login/`).
6. Redirect to dashboard home `/(dashboard)`; load stats via `GET /api/dashboard/stats/`.
7. Complete profile in `/(dashboard)/settings/profile` (PATCH `/api/users/me/`).

### 2. Create and Host a Watch Party
1. From dashboard home, click **Create Party**.
2. `/(dashboard)/watch-parties/create` displays form prefilled with video library data (`GET /api/videos/?status=ready`).
3. Submit form (`POST /api/parties/`).
4. On success, redirect to party settings `/(dashboard)/watch-parties/[partyId]/settings` to configure moderation toggles (`PATCH /api/parties/{id}/settings/`).
5. Send invitations using party sidebar (modal uses `POST /api/parties/{id}/invite/`).
6. At scheduled time, navigate to live room `/(dashboard)/watch-parties/[partyId]`.
7. `PartyPlayer` connects to `ws/party/{partyId}/` for playback sync; `PartyChat` joins `ws/chat/{partyId}/`.
8. Host can trigger polls (`POST /api/interactive/parties/{partyId}/polls/create/`) and screen share (WebRTC handshake via interactive WebSocket endpoints).

### 3. Participant Joins from Invitation
1. Receives invitation email linking to `/(auth)/login?next=/join/party/{partyId}`.
2. After login, join page fetches party metadata (`GET /api/parties/{id}/`) and ensures access.
3. Participant enters lobby `ws/party/{id}/lobby/` for readiness, then transitions into party.
4. Interacts via chat, reactions, polls, and purchases merch from store sidebar (`POST /api/store/purchase/`).

### 4. Creator Uploads Video & Reviews Analytics
1. Navigate to `/(dashboard)/videos/upload`.
2. Upload file; request pre-signed URL (`POST /api/videos/upload-url/`) and direct-upload.
3. Poll `GET /api/videos/{id}/` until `processing_state` is `ready`.
4. Video appears in library `/(dashboard)/videos/library`.
5. View analytics in `/(dashboard)/analytics` using `GET /api/analytics/videos/{id}/` and aggregated metrics from `/api/analytics/overview/`.

### 5. Support Ticket Submission
1. From dashboard `Need Help?` link to `/(dashboard)/support`.
2. Submit new ticket (`POST /api/support/tickets/`).
3. Receive updates via notifications (WebSocket `ws/notifications/`) and view conversation in `/(dashboard)/support/tickets/[ticketId]`.

## Admin Scenarios

### A. Platform Overview & Moderation
1. Admin signs in (`/(auth)/login` → `role === admin`).
2. Redirect to admin home `/(admin)`.
3. Dashboard loads KPIs using `GET /api/admin/overview/` & `/api/analytics/platform/`.
4. Navigate to moderation queue `/(admin)/moderation`; fetch reports via `GET /api/moderation/reports/`.
5. Review flagged content using embedded video/player components.
6. Take action with `POST /api/moderation/admin/reports/{id}/resolve/` or escalate to suspension (`POST /api/moderation/users/{userId}/suspend/`).
7. Changes broadcast to affected users through notifications WebSocket.

### B. User Management & Support
1. Admin opens `/(admin)/users`; `AdminUserTable` calls `GET /api/admin/users/?search=`.
2. View detailed profile in modal `GET /api/admin/users/{id}/`.
3. Adjust roles or reset MFA via `PATCH /api/admin/users/{id}/`.
4. Switch to support tab `/(admin)/support`; join active ticket threads (`GET /api/support/tickets/?status=open`).
5. Respond directly using admin reply endpoint `POST /api/support/tickets/{id}/messages/`.

### C. Billing Oversight
1. Go to `/(admin)/billing`.
2. Fetch subscription summary (`GET /api/billing/admin/summary/`) and invoice history (`GET /api/billing/invoices/`).
3. Trigger refunds or manual adjustments via `POST /api/billing/invoices/{id}/refund/`.

### D. System Health Monitoring
1. Navigate to `/(admin)/system`.
2. Display logs from `/api/admin/system/logs/` and performance metrics from `/api/analytics/system/`.
3. Provide quick links to backend health endpoints: `/api/health/`, `/api/test/`, `/api/docs/`.

## Cross-Cutting Concerns

- **Access Control**: `middleware.ts` checks `session.role` to route between `(dashboard)` and `(admin)` segments.
- **Global Notifications**: Toasts triggered by WebSocket `notification` events; fallback polling `/api/notifications/unread-count/`.
- **Offline Support**: Cache marketing pages statically; degrade party experience with recorded video playback if realtime fails.
- **Internationalization**: Use `next-intl` with namespaces per page to match backend localization keys.

