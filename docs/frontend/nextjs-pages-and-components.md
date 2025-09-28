# Next.js Frontend Pages and Component Inventory

This document enumerates every page and shared component required for the Watch Party frontend. The application will be implemented with the Next.js App Router and TypeScript.

## Directory Overview

```
app/
├─ (marketing)/
│  ├─ page.tsx                # Landing
│  ├─ pricing/page.tsx        # Pricing + plans
│  └─ features/page.tsx       # Feature overview
├─ (auth)/
│  ├─ login/page.tsx          # Email/password & social login
│  ├─ register/page.tsx       # Registration flow
│  ├─ reset-password/page.tsx # Reset request + update
│  └─ verify-email/[token]/page.tsx
├─ (dashboard)/
│  ├─ layout.tsx
│  ├─ page.tsx                # Personalized feed & quick actions
│  ├─ watch-parties/
│  │  ├─ create/page.tsx
│  │  ├─ [partyId]/page.tsx   # Live party room shell
│  │  ├─ [partyId]/settings/page.tsx
│  │  └─ archive/page.tsx     # Past parties
│  ├─ videos/
│  │  ├─ upload/page.tsx
│  │  ├─ library/page.tsx
│  │  └─ [videoId]/page.tsx
│  ├─ events/
│  │  ├─ page.tsx
│  │  ├─ create/page.tsx
│  │  └─ [eventId]/page.tsx
│  ├─ messages/
│  │  ├─ page.tsx             # Conversation list
│  │  └─ [threadId]/page.tsx
│  ├─ notifications/page.tsx
│  ├─ store/page.tsx
│  ├─ analytics/page.tsx
│  ├─ settings/
│  │  ├─ profile/page.tsx
│  │  ├─ account/page.tsx
│  │  ├─ security/page.tsx
│  │  └─ preferences/page.tsx
│  └─ support/
│     ├─ page.tsx             # Help center
│     └─ tickets/[ticketId]/page.tsx
└─ (admin)/
   ├─ layout.tsx
   ├─ page.tsx                # Admin overview
   ├─ users/page.tsx
   ├─ moderation/page.tsx
   ├─ analytics/page.tsx
   ├─ support/page.tsx
   ├─ billing/page.tsx
   └─ system/page.tsx
```

## Shared Component Library

| Component | Location | Description |
|-----------|----------|-------------|
| `TopNav` | `components/navigation/top-nav.tsx` | Authenticated navigation with notifications, search, quick actions.
| `SideNav` | `components/navigation/side-nav.tsx` | Contextual navigation (user dashboard or admin tools).
| `MarketingHeader` | `components/marketing/header.tsx` | Hero header with CTA buttons.
| `Footer` | `components/marketing/footer.tsx` | Global footer, legal links, app download.
| `AuthCard` | `components/auth/auth-card.tsx` | Form card used for login/register/reset.
| `Input`, `Select`, `Textarea` | `components/forms/` | Standardized form inputs integrated with React Hook Form.
| `Button`, `IconButton` | `components/ui/buttons.tsx` | Primary and secondary action buttons.
| `DataTable` | `components/data/table.tsx` | Paginated table supporting cursor pagination from the backend.
| `FilterBar` | `components/data/filter-bar.tsx` | Quick filters and saved views.
| `EmptyState` | `components/ui/empty-state.tsx` | Placeholder state for empty lists.
| `Modal`, `Drawer`, `Popover` | `components/ui/overlays.tsx` | Shared overlay primitives.
| `ToastProvider` | `components/feedback/toast-provider.tsx` | Notification toasts wired to mutation status.
| `Avatar`, `UserBadge` | `components/user/` | User presentation components with status indicator.
| `PartyPlayer` | `components/party/player.tsx` | Video player synced via WebSocket + HLS.
| `PartyChat` | `components/party/chat.tsx` | Realtime chat room with message reactions.
| `PartySidebar` | `components/party/sidebar.tsx` | Participants list, polls, reactions.
| `PollWidget` | `components/party/poll-widget.tsx` | Poll creation & participation UI.
| `ScreenSharePanel` | `components/party/screen-share-panel.tsx` | Host controls for screen sharing.
| `EventCard` | `components/events/event-card.tsx` | List item for events calendar.
| `Calendar` | `components/events/calendar.tsx` | Calendar view for events & watch parties.
| `VideoUploader` | `components/videos/video-uploader.tsx` | Upload widget with progress + transcoding status.
| `VideoDetail` | `components/videos/video-detail.tsx` | Video metadata, analytics summary.
| `MessagingThread` | `components/messaging/thread.tsx` | Conversation view with infinite scroll.
| `NotificationList` | `components/notifications/notification-list.tsx` | Notification center with filters.
| `StoreProductCard` | `components/store/product-card.tsx` | Store items, currency purchase.
| `AnalyticsCharts` | `components/analytics/charts.tsx` | Wrapper around charting library (Recharts or Chart.js).
| `BillingSummary` | `components/billing/summary.tsx` | Subscription status & invoices.
| `SupportTicketForm` | `components/support/ticket-form.tsx` | Form to submit support tickets.
| `AdminStats` | `components/admin/admin-stats.tsx` | KPIs for admin landing page.
| `AdminUserTable` | `components/admin/user-table.tsx` | Manage users with moderation actions.
| `AdminModerationQueue` | `components/admin/moderation-queue.tsx` | Review content reports & actions.
| `SystemHealthWidget` | `components/admin/system-health-widget.tsx` | Surface monitoring metrics.

## Layout & Providers

- `app/layout.tsx`: Global `<html>` shell, theme provider, font imports.
- `app/(auth)/layout.tsx`: Minimal layout for auth forms.
- `app/(dashboard)/layout.tsx`: Authenticated shell with `TopNav` and `SideNav`.
- `app/(admin)/layout.tsx`: Admin shell with additional guard.
- `components/providers/`:
  - `AuthProvider` (hooks into NextAuth or custom JWT refresh flow).
  - `QueryProvider` (TanStack Query hydration for server components).
  - `WebSocketProvider` (party, chat, notifications realtime updates).
  - `ThemeProvider` (light/dark toggle, persisted via cookies).

## Routing Guards

- Middleware in `middleware.ts` to enforce auth and role-based routing.
- Server components fetch user session via cookies and gate server actions.

## Server Actions & Mutations

- Use Next.js server actions for secure mutations where possible (e.g., profile updates) and fallback to API routes when real-time feedback is needed.
- Co-locate mutations inside feature directories, e.g., `app/(dashboard)/watch-parties/actions.ts`.

## Testing & Storybook Coverage

- Storybook stories under `stories/` for each component above.
- Playwright component tests for real-time components (PartyChat, PartyPlayer) using mocked WebSocket server.
- Integration tests for auth, dashboard, and admin flows using Next.js testing utilities.

