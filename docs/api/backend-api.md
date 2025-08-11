# Watch Party Backend API Documentation

## Overview
This document provides a comprehensive list of all defined API endpoints in the Watch Party Backend. All endpoints are prefixed with `/api/` unless otherwise noted.

## Base Endpoints

### API Root
- **GET** `/api/`
  - **Requirements**: None
  - **Returns**: 
    ```json
    {
      "message": "Watch Party API",
      "version": "1.0",
      "endpoints": {
        "authentication": "/api/auth/",
        "users": "/api/users/",
        "videos": "/api/videos/",
        "parties": "/api/parties/",
        "chat": "/api/chat/",
        "billing": "/api/billing/",
        "analytics": "/api/analytics/",
        "notifications": "/api/notifications/",
        "integrations": "/api/integrations/",
        "interactive": "/api/interactive/",
        "moderation": "/api/moderation/",
        "store": "/api/store/",
        "search": "/api/search/",
        "social": "/api/social/",
        "messaging": "/api/messaging/",
        "support": "/api/support/",
        "mobile": "/api/mobile/",
        "admin": "/api/admin/",
        "documentation": "/api/docs/",
        "schema": "/api/schema/"
      }
    }
    ```

### Test Endpoint
- **GET** `/api/test/`
  - **Requirements**: None (AllowAny)
  - **Returns**:
    ```json
    {
      "message": "Server is working!",
      "authenticated": true,
      "user_id": 123,
      "timestamp": "2025-08-10T12:00:00Z"
    }
    ```

### Dashboard Endpoints
- **GET** `/api/dashboard/stats/`
  - **Requirements**: Authentication required
  - **Returns**:
    ```json
    {
      "user": {
        "id": 123,
        "name": "John Doe",
        "email": "john@example.com"
      },
      "stats": {
        "total_parties": 15,
        "recent_parties": 3,
        "total_videos": 8,
        "recent_videos": 1,
        "watch_time_minutes": 0
      },
      "timestamp": "2025-08-10T12:00:00Z"
    }
    ```

- **GET** `/api/dashboard/activities/`
  - **Requirements**: Authentication required
  - **Returns**:
    ```json
    {
      "activities": [
        {
          "id": 456,
          "type": "party_created",
          "timestamp": "2025-08-10T12:00:00Z",
          "data": {},
          "party": {
            "id": 789,
            "title": "Movie Night"
          },
          "video": {
            "id": 101,
            "title": "Sample Movie"
          }
        }
      ],
      "total": 20
    }
    ```

## Authentication Endpoints (`/api/auth/`)

### User Registration & Login
- **POST** `/api/auth/register/`
  - **Requirements**:
    ```json
    {
      "email": "user@example.com",
      "password": "securepassword",
      "confirm_password": "securepassword",
      "first_name": "John",
      "last_name": "Doe",
      "promo_code": "WELCOME2024" // optional
    }
    ```
  - **Returns**:
    ```json
    {
      "success": true,
      "message": "Registration successful. Please verify your email.",
      "user": {
        "id": 123,
        "email": "user@example.com",
        "first_name": "John",
        "last_name": "Doe"
      },
      "access_token": "jwt_access_token",
      "refresh_token": "jwt_refresh_token",
      "verification_sent": true
    }
    ```

- **POST** `/api/auth/login/`
  - **Requirements**:
    ```json
    {
      "email": "user@example.com",
      "password": "securepassword"
    }
    ```
  - **Returns**:
    ```json
    {
      "success": true,
      "access_token": "jwt_access_token",
      "refresh_token": "jwt_refresh_token",
      "user": {
        "id": 123,
        "email": "user@example.com",
        "first_name": "John",
        "last_name": "Doe"
      }
    }
    ```

- **POST** `/api/auth/logout/`
  - **Requirements**: Authentication required
    ```json
    {
      "refresh_token": "jwt_refresh_token"
    }
    ```
  - **Returns**:
    ```json
    {
      "success": true,
      "message": "Successfully logged out."
    }
    ```

- **POST** `/api/auth/refresh/`
  - **Requirements**:
    ```json
    {
      "refresh": "jwt_refresh_token"
    }
    ```
  - **Returns**:
    ```json
    {
      "access": "new_jwt_access_token"
    }
    ```

### Social Authentication
- **GET** `/api/auth/social/<provider>/`
  - **Requirements**: `provider` parameter (google, github)
  - **Returns**: Social auth redirect URL

- **POST** `/api/auth/social/google/`
  - **Requirements**:
    ```json
    {
      "access_token": "google_access_token"
    }
    ```
  - **Returns**: User data and JWT tokens

- **POST** `/api/auth/social/github/`
  - **Requirements**:
    ```json
    {
      "code": "github_auth_code"
    }
    ```
  - **Returns**: User data and JWT tokens

### Password Management
- **POST** `/api/auth/forgot-password/`
  - **Requirements**:
    ```json
    {
      "email": "user@example.com"
    }
    ```
  - **Returns**:
    ```json
    {
      "success": true,
      "message": "Password reset email sent."
    }
    ```

- **POST** `/api/auth/reset-password/`
  - **Requirements**:
    ```json
    {
      "token": "reset_token",
      "new_password": "newpassword",
      "confirm_password": "newpassword"
    }
    ```
  - **Returns**:
    ```json
    {
      "success": true,
      "message": "Password reset successful."
    }
    ```

- **POST** `/api/auth/change-password/`
  - **Requirements**: Authentication required
    ```json
    {
      "current_password": "oldpassword",
      "new_password": "newpassword",
      "confirm_password": "newpassword"
    }
    ```
  - **Returns**:
    ```json
    {
      "success": true,
      "message": "Password changed successfully."
    }
    ```

### Account Verification
- **POST** `/api/auth/verify-email/`
  - **Requirements**:
    ```json
    {
      "token": "verification_token"
    }
    ```
  - **Returns**:
    ```json
    {
      "success": true,
      "message": "Email verified successfully."
    }
    ```

- **POST** `/api/auth/resend-verification/`
  - **Requirements**:
    ```json
    {
      "email": "user@example.com"
    }
    ```
  - **Returns**:
    ```json
    {
      "success": true,
      "message": "Verification email sent."
    }
    ```

### User Profile
- **GET** `/api/auth/profile/`
  - **Requirements**: Authentication required
  - **Returns**: User profile data

- **PUT/PATCH** `/api/auth/profile/`
  - **Requirements**: Authentication required
    ```json
    {
      "first_name": "John",
      "last_name": "Doe",
      "bio": "User bio"
    }
    ```
  - **Returns**: Updated user profile data

### Google Drive Integration
- **GET** `/api/auth/google-drive/auth/`
  - **Requirements**: Authentication required
  - **Returns**: Google Drive authorization URL

- **POST** `/api/auth/google-drive/auth/`
  - **Requirements**: Authentication required
    ```json
    {
      "code": "google_auth_code"
    }
    ```
  - **Returns**: Google Drive integration status

- **DELETE** `/api/auth/google-drive/disconnect/`
  - **Requirements**: Authentication required
  - **Returns**: Disconnection confirmation

- **GET** `/api/auth/google-drive/status/`
  - **Requirements**: Authentication required
  - **Returns**:
    ```json
    {
      "connected": true,
      "email": "user@gmail.com"
    }
    ```

### Two-Factor Authentication
- **POST** `/api/auth/2fa/setup/`
  - **Requirements**: Authentication required
  - **Returns**:
    ```json
    {
      "qr_code": "base64_qr_code",
      "secret": "2fa_secret"
    }
    ```

- **POST** `/api/auth/2fa/verify/`
  - **Requirements**: Authentication required
    ```json
    {
      "token": "123456"
    }
    ```
  - **Returns**:
    ```json
    {
      "success": true,
      "backup_codes": ["code1", "code2"]
    }
    ```

- **DELETE** `/api/auth/2fa/disable/`
  - **Requirements**: Authentication required
    ```json
    {
      "password": "userpassword"
    }
    ```
  - **Returns**: Confirmation of 2FA disabling

### Session Management
- **GET** `/api/auth/sessions/`
  - **Requirements**: Authentication required
  - **Returns**: List of active user sessions

- **DELETE** `/api/auth/sessions/<session_id>/`
  - **Requirements**: Authentication required
  - **Returns**: Session revocation confirmation

## Users Endpoints (`/api/users/`)

### Profile Management
- **GET** `/api/users/profile/`
  - **Requirements**: Authentication required
  - **Returns**: Current user profile data

- **PUT/PATCH** `/api/users/profile/update/`
  - **Requirements**: Authentication required
    ```json
    {
      "first_name": "John",
      "last_name": "Doe",
      "bio": "Updated bio",
      "display_name": "JohnD"
    }
    ```
  - **Returns**: Updated user profile

- **POST** `/api/users/avatar/upload/`
  - **Requirements**: Authentication required, multipart form data
    ```
    avatar: file
    ```
  - **Returns**:
    ```json
    {
      "success": true,
      "avatar_url": "https://example.com/avatars/user123.jpg"
    }
    ```

- **GET** `/api/users/achievements/`
  - **Requirements**: Authentication required
  - **Returns**: List of user achievements

- **GET** `/api/users/stats/`
  - **Requirements**: Authentication required
  - **Returns**:
    ```json
    {
      "total_parties": 15,
      "total_watch_time": 1200,
      "videos_uploaded": 5,
      "friends_count": 23
    }
    ```

### Dashboard & Analytics
- **GET** `/api/users/dashboard/stats/`
  - **Requirements**: Authentication required
  - **Returns**: User dashboard statistics

### Session Management
- **GET** `/api/users/sessions/`
  - **Requirements**: Authentication required
  - **Returns**: List of active sessions

- **DELETE** `/api/users/sessions/<session_id>/`
  - **Requirements**: Authentication required
  - **Returns**: Session revocation confirmation

- **DELETE** `/api/users/sessions/revoke-all/`
  - **Requirements**: Authentication required
  - **Returns**: All sessions revocation confirmation

### Security Settings
- **POST** `/api/users/2fa/enable/`
  - **Requirements**: Authentication required
  - **Returns**: 2FA setup instructions

- **DELETE** `/api/users/2fa/disable/`
  - **Requirements**: Authentication required
  - **Returns**: 2FA disable confirmation

- **POST** `/api/users/2fa/setup/`
  - **Requirements**: Authentication required
  - **Returns**: 2FA setup QR code and secret

- **PUT** `/api/users/password/`
  - **Requirements**: Authentication required
    ```json
    {
      "current_password": "oldpassword",
      "new_password": "newpassword"
    }
    ```
  - **Returns**: Password change confirmation

### Onboarding
- **GET/POST** `/api/users/onboarding/`
  - **Requirements**: Authentication required
  - **Returns**: Onboarding status and steps

### Inventory & Items
- **GET** `/api/users/inventory/`
  - **Requirements**: Authentication required
  - **Returns**: User's virtual items and rewards

### Friend System
- **GET** `/api/users/friends/suggestions/`
  - **Requirements**: Authentication required
  - **Returns**: List of suggested friends

- **GET** `/api/users/friends/requests/`
  - **Requirements**: Authentication required
  - **Returns**: Pending friend requests

- **POST** `/api/users/friends/<request_id>/accept/`
  - **Requirements**: Authentication required
  - **Returns**: Friend request acceptance confirmation

- **POST** `/api/users/friends/<request_id>/decline/`
  - **Requirements**: Authentication required
  - **Returns**: Friend request decline confirmation

- **POST** `/api/users/<user_id>/friend-request/`
  - **Requirements**: Authentication required
  - **Returns**: Friend request sent confirmation

- **POST** `/api/users/<user_id>/block/`
  - **Requirements**: Authentication required
  - **Returns**: User blocking confirmation

### Enhanced Social Features
- **GET** `/api/users/friends/`
  - **Requirements**: Authentication required
  - **Returns**: List of user's friends

- **POST** `/api/users/friends/request/`
  - **Requirements**: Authentication required
    ```json
    {
      "username": "target_user"
    }
    ```
  - **Returns**: Friend request sent confirmation

- **POST** `/api/users/friends/<friendship_id>/accept/`
  - **Requirements**: Authentication required
  - **Returns**: Friend request acceptance

- **POST** `/api/users/friends/<friendship_id>/decline/`
  - **Requirements**: Authentication required
  - **Returns**: Friend request decline

- **DELETE** `/api/users/friends/<username>/remove/`
  - **Requirements**: Authentication required
  - **Returns**: Friend removal confirmation

- **GET** `/api/users/search/`
  - **Requirements**: Authentication required
  - **Query Parameters**: `q` (search query)
  - **Returns**: List of matching users

- **GET** `/api/users/activity/`
  - **Requirements**: Authentication required
  - **Returns**: User activity feed

- **POST** `/api/users/block/`
  - **Requirements**: Authentication required
    ```json
    {
      "user_id": "uuid"
    }
    ```
  - **Returns**: User blocking confirmation

- **POST** `/api/users/unblock/`
  - **Requirements**: Authentication required
    ```json
    {
      "user_id": "uuid"
    }
    ```
  - **Returns**: User unblocking confirmation

- **GET** `/api/users/<user_id>/profile/`
  - **Requirements**: Authentication required
  - **Returns**: Public profile of specified user

### Settings & Preferences
- **GET/PUT** `/api/users/settings/`
  - **Requirements**: Authentication required
  - **Returns/Accepts**: User settings configuration

- **GET/PUT** `/api/users/notifications/settings/`
  - **Requirements**: Authentication required
  - **Returns/Accepts**: Notification preferences

- **GET/PUT** `/api/users/privacy/settings/`
  - **Requirements**: Authentication required
  - **Returns/Accepts**: Privacy settings

### Data Management (GDPR)
- **POST** `/api/users/export-data/`
  - **Requirements**: Authentication required
  - **Returns**: Data export initiation confirmation

- **DELETE** `/api/users/delete-account/`
  - **Requirements**: Authentication required
    ```json
    {
      "password": "userpassword",
      "confirmation": "DELETE"
    }
    ```
  - **Returns**: Account deletion confirmation

### User Relationships
- **GET** `/api/users/<user_id>/mutual-friends/`
  - **Requirements**: Authentication required
  - **Returns**: List of mutual friends

- **GET** `/api/users/online-status/`
  - **Requirements**: Authentication required
  - **Returns**: Online status of friends

### Activity & History
- **GET** `/api/users/watch-history/`
  - **Requirements**: Authentication required
  - **Returns**: User's watch history

- **GET** `/api/users/favorites/`
  - **Requirements**: Authentication required
  - **Returns**: User's favorite videos/parties

- **POST** `/api/users/favorites/add/`
  - **Requirements**: Authentication required
    ```json
    {
      "content_type": "video",
      "content_id": "uuid"
    }
    ```
  - **Returns**: Favorite addition confirmation

- **DELETE** `/api/users/favorites/<favorite_id>/remove/`
  - **Requirements**: Authentication required
  - **Returns**: Favorite removal confirmation

### Notifications
- **GET** `/api/users/notifications/`
  - **Requirements**: Authentication required
  - **Returns**: User notifications

- **POST** `/api/users/notifications/<notification_id>/read/`
  - **Requirements**: Authentication required
  - **Returns**: Notification marked as read

- **POST** `/api/users/notifications/mark-all-read/`
  - **Requirements**: Authentication required
  - **Returns**: All notifications marked as read

### Reports
- **POST** `/api/users/report/`
  - **Requirements**: Authentication required
    ```json
    {
      "reported_user_id": "uuid",
      "reason": "spam",
      "description": "Report details"
    }
    ```
  - **Returns**: Report submission confirmation

## Videos Endpoints (`/api/videos/`)

### Video CRUD (ViewSet endpoints)
- **GET** `/api/videos/`
  - **Requirements**: Authentication optional
  - **Query Parameters**: `page`, `page_size`, `search`, `category`, `uploaded_by`
  - **Returns**: Paginated list of videos

- **POST** `/api/videos/`
  - **Requirements**: Authentication required
    ```json
    {
      "title": "Video Title",
      "description": "Video description",
      "video_file": "file_upload",
      "thumbnail": "thumbnail_upload",
      "category": "movies",
      "is_public": true,
      "tags": ["tag1", "tag2"]
    }
    ```
  - **Returns**: Created video object

- **GET** `/api/videos/<video_id>/`
  - **Requirements**: Authentication optional (depends on video privacy)
  - **Returns**: Video details with metadata

- **PUT/PATCH** `/api/videos/<video_id>/`
  - **Requirements**: Authentication required (owner only)
    ```json
    {
      "title": "Updated Title",
      "description": "Updated description",
      "is_public": false
    }
    ```
  - **Returns**: Updated video object

- **DELETE** `/api/videos/<video_id>/`
  - **Requirements**: Authentication required (owner only)
  - **Returns**: Deletion confirmation

### Upload Endpoints
- **POST** `/api/videos/upload/`
  - **Requirements**: Authentication required, multipart form data
    ```
    video_file: file
    title: string
    description: string
    thumbnail: file (optional)
    ```
  - **Returns**:
    ```json
    {
      "upload_id": "uuid",
      "video_id": "uuid",
      "status": "uploading"
    }
    ```

- **POST** `/api/videos/upload/s3/`
  - **Requirements**: Authentication required
    ```json
    {
      "filename": "video.mp4",
      "file_size": 1024000,
      "content_type": "video/mp4"
    }
    ```
  - **Returns**:
    ```json
    {
      "upload_url": "https://s3.amazonaws.com/presigned-url",
      "upload_id": "uuid"
    }
    ```

- **POST** `/api/videos/upload/<upload_id>/complete/`
  - **Requirements**: Authentication required
    ```json
    {
      "title": "Video Title",
      "description": "Description"
    }
    ```
  - **Returns**: Video creation confirmation

- **GET** `/api/videos/upload/<upload_id>/status/`
  - **Requirements**: Authentication required
  - **Returns**:
    ```json
    {
      "status": "processing",
      "progress": 75,
      "estimated_completion": "2025-08-10T13:00:00Z"
    }
    ```

### Video Processing & Streaming
- **GET** `/api/videos/<video_id>/stream/`
  - **Requirements**: Authentication required
  - **Returns**:
    ```json
    {
      "streaming_url": "https://cdn.example.com/videos/video.m3u8",
      "quality_variants": ["720p", "1080p"],
      "duration": 3600
    }
    ```

- **GET** `/api/videos/<video_id>/thumbnail/`
  - **Requirements**: Authentication optional
  - **Returns**: Thumbnail image URL or redirect

- **GET** `/api/videos/<video_id>/analytics/`
  - **Requirements**: Authentication required (owner only)
  - **Returns**:
    ```json
    {
      "total_views": 1500,
      "unique_viewers": 1200,
      "watch_time": 45000,
      "engagement_rate": 0.85
    }
    ```

### Enhanced Video Management
- **GET** `/api/videos/<video_id>/processing-status/`
  - **Requirements**: Authentication required
  - **Returns**:
    ```json
    {
      "status": "completed",
      "processing_steps": {
        "transcoding": "completed",
        "thumbnail_generation": "completed",
        "quality_variants": "completed"
      }
    }
    ```

- **GET** `/api/videos/<video_id>/quality-variants/`
  - **Requirements**: Authentication optional
  - **Returns**:
    ```json
    {
      "variants": [
        {
          "quality": "720p",
          "url": "https://cdn.example.com/720p.m3u8",
          "bitrate": 2500
        },
        {
          "quality": "1080p",
          "url": "https://cdn.example.com/1080p.m3u8",
          "bitrate": 5000
        }
      ]
    }
    ```

- **POST** `/api/videos/<video_id>/regenerate-thumbnail/`
  - **Requirements**: Authentication required (owner only)
    ```json
    {
      "timestamp": 30.5
    }
    ```
  - **Returns**: Thumbnail regeneration confirmation

- **POST** `/api/videos/<video_id>/share/`
  - **Requirements**: Authentication required
    ```json
    {
      "platform": "twitter",
      "message": "Check out this video!"
    }
    ```
  - **Returns**: Share link and details

### Advanced Analytics
- **GET** `/api/videos/<video_id>/analytics/detailed/`
  - **Requirements**: Authentication required (owner only)
  - **Returns**: Detailed video analytics

- **GET** `/api/videos/<video_id>/analytics/heatmap/`
  - **Requirements**: Authentication required (owner only)
  - **Returns**: Engagement heatmap data

- **GET** `/api/videos/<video_id>/analytics/retention/`
  - **Requirements**: Authentication required (owner only)
  - **Returns**: Viewer retention curve data

- **GET** `/api/videos/<video_id>/analytics/journey/`
  - **Requirements**: Authentication required (owner only)
  - **Returns**: Viewer journey analytics

- **GET** `/api/videos/<video_id>/analytics/comparative/`
  - **Requirements**: Authentication required (owner only)
  - **Returns**: Comparative analytics data

### Channel Analytics
- **GET** `/api/videos/analytics/channel/`
  - **Requirements**: Authentication required
  - **Returns**: User's channel analytics

- **GET** `/api/videos/analytics/trending/`
  - **Requirements**: Authentication optional
  - **Returns**: Trending videos analytics

### Video Validation
- **POST** `/api/videos/validate-url/`
  - **Requirements**: Authentication required
    ```json
    {
      "url": "https://example.com/video.mp4"
    }
    ```
  - **Returns**:
    ```json
    {
      "valid": true,
      "content_type": "video/mp4",
      "file_size": 1024000,
      "duration": 3600
    }
    ```

### Search
- **GET** `/api/videos/search/`
  - **Requirements**: Authentication optional
  - **Query Parameters**: `q`, `category`, `duration_min`, `duration_max`, `sort_by`
  - **Returns**: Search results with videos

- **GET** `/api/videos/search/advanced/`
  - **Requirements**: Authentication optional
  - **Query Parameters**: Advanced search filters
  - **Returns**: Advanced search results

### Google Drive Integration
- **GET** `/api/videos/gdrive/`
  - **Requirements**: Authentication required, Google Drive connected
  - **Returns**: List of Google Drive movies

- **POST** `/api/videos/gdrive/upload/`
  - **Requirements**: Authentication required, Google Drive connected
    ```json
    {
      "file_id": "google_drive_file_id",
      "title": "Movie Title"
    }
    ```
  - **Returns**: Upload initiation confirmation

- **DELETE** `/api/videos/gdrive/<video_id>/delete/`
  - **Requirements**: Authentication required (owner only)
  - **Returns**: Deletion confirmation

- **GET** `/api/videos/gdrive/<video_id>/stream/`
  - **Requirements**: Authentication required
  - **Returns**: Google Drive streaming URL

### Video Proxy
- **GET** `/api/videos/<video_id>/proxy/`
  - **Requirements**: Authentication required
  - **Returns**: Proxied video stream

## Parties Endpoints (`/api/parties/`)

### Special Party Endpoints
- **GET** `/api/parties/recent/`
  - **Requirements**: Authentication required
  - **Returns**: User's recent parties

- **GET** `/api/parties/public/`
  - **Requirements**: Authentication optional
  - **Query Parameters**: `page`, `search`, `category`
  - **Returns**: Public parties list

- **GET** `/api/parties/trending/`
  - **Requirements**: Authentication optional
  - **Returns**: Trending parties

- **GET** `/api/parties/recommendations/`
  - **Requirements**: Authentication required
  - **Returns**: Recommended parties for user

- **POST** `/api/parties/join-by-code/`
  - **Requirements**: Authentication required
    ```json
    {
      "code": "ABC123"
    }
    ```
  - **Returns**: Party join confirmation

- **POST** `/api/parties/join-by-invite/`
  - **Requirements**: Authentication required
    ```json
    {
      "invite_code": "invitation_code"
    }
    ```
  - **Returns**: Party join confirmation

- **GET** `/api/parties/search/`
  - **Requirements**: Authentication optional
  - **Query Parameters**: `q`, `is_public`, `category`
  - **Returns**: Party search results

- **POST** `/api/parties/report/`
  - **Requirements**: Authentication required
    ```json
    {
      "party_id": "uuid",
      "reason": "inappropriate_content",
      "description": "Report details"
    }
    ```
  - **Returns**: Report submission confirmation

### Party-Specific Enhanced Endpoints
- **POST** `/api/parties/<party_id>/generate-invite/`
  - **Requirements**: Authentication required (host/moderator)
  - **Returns**:
    ```json
    {
      "invite_code": "ABC123XYZ",
      "invite_url": "https://app.example.com/join/ABC123XYZ",
      "expires_at": "2025-08-11T12:00:00Z"
    }
    ```

- **GET** `/api/parties/<party_id>/analytics/`
  - **Requirements**: Authentication required (host/moderator)
  - **Returns**: Party analytics data

- **POST** `/api/parties/<party_id>/update-analytics/`
  - **Requirements**: Authentication required (host/moderator)
  - **Returns**: Analytics update confirmation

### Party CRUD (ViewSet endpoints)
- **GET** `/api/parties/`
  - **Requirements**: Authentication required
  - **Query Parameters**: `page`, `search`, `is_public`, `host`
  - **Returns**: Paginated list of parties

- **POST** `/api/parties/`
  - **Requirements**: Authentication required
    ```json
    {
      "title": "Movie Night",
      "description": "Friday movie night with friends",
      "video_id": "uuid",
      "is_public": true,
      "max_participants": 10,
      "scheduled_for": "2025-08-10T20:00:00Z"
    }
    ```
  - **Returns**: Created party object

- **GET** `/api/parties/<party_id>/`
  - **Requirements**: Authentication required (participant or public)
  - **Returns**: Party details with participants

- **PUT/PATCH** `/api/parties/<party_id>/`
  - **Requirements**: Authentication required (host only)
    ```json
    {
      "title": "Updated Title",
      "description": "Updated description",
      "is_public": false
    }
    ```
  - **Returns**: Updated party object

- **DELETE** `/api/parties/<party_id>/`
  - **Requirements**: Authentication required (host only)
  - **Returns**: Deletion confirmation

### Party Actions
- **POST** `/api/parties/<party_id>/join/`
  - **Requirements**: Authentication required
  - **Returns**: Join confirmation and party details

- **POST** `/api/parties/<party_id>/leave/`
  - **Requirements**: Authentication required
  - **Returns**: Leave confirmation

- **POST** `/api/parties/<party_id>/start/`
  - **Requirements**: Authentication required (host only)
  - **Returns**: Party start confirmation

- **POST** `/api/parties/<party_id>/control/`
  - **Requirements**: Authentication required (host/moderator)
    ```json
    {
      "action": "play",
      "timestamp": 120.5
    }
    ```
  - **Returns**: Control action confirmation

### Party Chat
- **GET** `/api/parties/<party_id>/chat/`
  - **Requirements**: Authentication required (participant)
  - **Query Parameters**: `page`, `before_timestamp`
  - **Returns**: Chat message history

- **POST** `/api/parties/<party_id>/chat/`
  - **Requirements**: Authentication required (participant)
    ```json
    {
      "message": "Great movie!",
      "message_type": "text"
    }
    ```
  - **Returns**: Sent message details

### Party Reactions
- **POST** `/api/parties/<party_id>/react/`
  - **Requirements**: Authentication required (participant)
    ```json
    {
      "emoji": "😂",
      "timestamp": 180.3
    }
    ```
  - **Returns**: Reaction confirmation

### Party Participants
- **GET** `/api/parties/<party_id>/participants/`
  - **Requirements**: Authentication required (participant)
  - **Returns**: List of party participants

### Party Invitations
- **POST** `/api/parties/<party_id>/invite/`
  - **Requirements**: Authentication required (host/participant)
    ```json
    {
      "user_ids": ["uuid1", "uuid2"],
      "message": "Join us for movie night!"
    }
    ```
  - **Returns**: Invitation sent confirmation

### Invitation Management (ViewSet)
- **GET** `/api/parties/invitations/`
  - **Requirements**: Authentication required
  - **Returns**: User's party invitations

- **GET** `/api/parties/invitations/<invitation_id>/`
  - **Requirements**: Authentication required
  - **Returns**: Invitation details

- **POST** `/api/parties/invitations/<invitation_id>/accept/`
  - **Requirements**: Authentication required
  - **Returns**: Invitation acceptance confirmation

- **POST** `/api/parties/invitations/<invitation_id>/decline/`
  - **Requirements**: Authentication required
  - **Returns**: Invitation decline confirmation

## Chat Endpoints (`/api/chat/`)

### Chat History & Messaging
- **GET** `/api/chat/<party_id>/messages/`
  - **Requirements**: Authentication required (party participant)
  - **Query Parameters**: `page`, `before`, `after`, `limit`
  - **Returns**:
    ```json
    {
      "messages": [
        {
          "id": "uuid",
          "user": {
            "id": "uuid",
            "username": "johndoe",
            "display_name": "John Doe"
          },
          "message": "Great movie!",
          "message_type": "text",
          "timestamp": "2025-08-10T20:30:00Z",
          "edited": false
        }
      ],
      "pagination": {
        "next": null,
        "previous": "url",
        "total": 50
      }
    }
    ```

- **POST** `/api/chat/<party_id>/messages/send/`
  - **Requirements**: Authentication required (party participant)
    ```json
    {
      "message": "This is awesome!",
      "message_type": "text",
      "reply_to": "message_id" // optional
    }
    ```
  - **Returns**:
    ```json
    {
      "id": "uuid",
      "message": "This is awesome!",
      "timestamp": "2025-08-10T20:31:00Z",
      "status": "sent"
    }
    ```

### Chat Room Management
- **POST** `/api/chat/<room_id>/join/`
  - **Requirements**: Authentication required
  - **Returns**: Room join confirmation

- **POST** `/api/chat/<room_id>/leave/`
  - **Requirements**: Authentication required
  - **Returns**: Room leave confirmation

- **GET** `/api/chat/<room_id>/active-users/`
  - **Requirements**: Authentication required (room participant)
  - **Returns**:
    ```json
    {
      "active_users": [
        {
          "id": "uuid",
          "username": "johndoe",
          "display_name": "John Doe",
          "last_seen": "2025-08-10T20:32:00Z"
        }
      ],
      "total_active": 5
    }
    ```

- **GET/PUT** `/api/chat/<room_id>/settings/`
  - **Requirements**: Authentication required (host/moderator)
  - **Returns/Accepts**:
    ```json
    {
      "slow_mode": false,
      "slow_mode_interval": 5,
      "allow_emojis": true,
      "allow_links": true,
      "max_message_length": 500
    }
    ```

### Chat Moderation
- **POST** `/api/chat/<room_id>/moderate/`
  - **Requirements**: Authentication required (moderator)
    ```json
    {
      "action": "delete_message",
      "target_id": "message_id",
      "reason": "spam"
    }
    ```
  - **Returns**: Moderation action confirmation

- **POST** `/api/chat/<room_id>/ban/`
  - **Requirements**: Authentication required (moderator)
    ```json
    {
      "user_id": "uuid",
      "duration": 3600,
      "reason": "inappropriate_behavior"
    }
    ```
  - **Returns**: Ban confirmation

- **POST** `/api/chat/<room_id>/unban/`
  - **Requirements**: Authentication required (moderator)
    ```json
    {
      "user_id": "uuid"
    }
    ```
  - **Returns**: Unban confirmation

- **GET** `/api/chat/<room_id>/moderation-log/`
  - **Requirements**: Authentication required (moderator)
  - **Returns**: Chat moderation history

### Chat Statistics
- **GET** `/api/chat/<room_id>/stats/`
  - **Requirements**: Authentication required (host/moderator)
  - **Returns**:
    ```json
    {
      "total_messages": 150,
      "active_participants": 8,
      "message_rate": 2.5,
      "popular_emojis": ["😂", "👍", "❤️"]
    }
    ```

## Billing Endpoints (`/api/billing/`)

### Subscription Management
- **GET** `/api/billing/plans/`
  - **Requirements**: Authentication optional
  - **Returns**:
    ```json
    {
      "plans": [
        {
          "id": "basic",
          "name": "Basic Plan",
          "price": 9.99,
          "currency": "USD",
          "interval": "month",
          "features": ["Feature 1", "Feature 2"]
        }
      ]
    }
    ```

- **POST** `/api/billing/subscribe/`
  - **Requirements**: Authentication required
    ```json
    {
      "plan_id": "premium",
      "payment_method_id": "pm_123456",
      "promo_code": "SAVE20" // optional
    }
    ```
  - **Returns**: Subscription creation confirmation

- **GET** `/api/billing/subscription/`
  - **Requirements**: Authentication required
  - **Returns**:
    ```json
    {
      "id": "sub_123",
      "plan": "premium",
      "status": "active",
      "current_period_end": "2025-09-10T00:00:00Z",
      "cancel_at_period_end": false
    }
    ```

- **POST** `/api/billing/subscription/cancel/`
  - **Requirements**: Authentication required
    ```json
    {
      "cancel_at_period_end": true,
      "reason": "switching_plans" // optional
    }
    ```
  - **Returns**: Cancellation confirmation

- **POST** `/api/billing/subscription/resume/`
  - **Requirements**: Authentication required
  - **Returns**: Resume confirmation

### Payment Methods
- **GET** `/api/billing/payment-methods/`
  - **Requirements**: Authentication required
  - **Returns**: List of user's payment methods

- **GET** `/api/billing/payment-methods/<payment_method_id>/`
  - **Requirements**: Authentication required
  - **Returns**: Payment method details

- **POST** `/api/billing/payment-methods/<payment_method_id>/set-default/`
  - **Requirements**: Authentication required
  - **Returns**: Default payment method update confirmation

### Billing History
- **GET** `/api/billing/history/`
  - **Requirements**: Authentication required
  - **Query Parameters**: `page`, `year`, `month`
  - **Returns**: Billing history with invoices

- **GET** `/api/billing/invoices/<invoice_id>/`
  - **Requirements**: Authentication required
  - **Returns**: Invoice details

- **GET** `/api/billing/invoices/<invoice_id>/download/`
  - **Requirements**: Authentication required
  - **Returns**: Invoice PDF download

### Billing Address
- **GET/PUT** `/api/billing/address/`
  - **Requirements**: Authentication required
  - **Returns/Accepts**:
    ```json
    {
      "line1": "123 Main St",
      "line2": "Apt 4B",
      "city": "New York",
      "state": "NY",
      "postal_code": "10001",
      "country": "US"
    }
    ```

### Promotional Codes
- **POST** `/api/billing/promo-code/validate/`
  - **Requirements**: Authentication required
    ```json
    {
      "promo_code": "SAVE20"
    }
    ```
  - **Returns**:
    ```json
    {
      "valid": true,
      "discount_percent": 20,
      "expires_at": "2025-12-31T23:59:59Z"
    }
    ```

### Webhooks
- **POST** `/api/billing/webhooks/stripe/`
  - **Requirements**: Stripe webhook signature
  - **Returns**: Webhook processing confirmation

## Analytics Endpoints (`/api/analytics/`)

### Standard Analytics
- **GET** `/api/analytics/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: General analytics overview

- **GET** `/api/analytics/user-stats/`
  - **Requirements**: Authentication required
  - **Returns**: User-specific statistics

- **GET** `/api/analytics/party-stats/<party_id>/`
  - **Requirements**: Authentication required (party host/moderator)
  - **Returns**: Party-specific analytics

- **GET** `/api/analytics/admin/analytics/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: Admin analytics dashboard

- **POST** `/api/analytics/export/`
  - **Requirements**: Authentication required (admin)
    ```json
    {
      "date_range": {
        "start": "2025-08-01",
        "end": "2025-08-31"
      },
      "format": "csv"
    }
    ```
  - **Returns**: Export initiation confirmation

### Dashboard Analytics
- **GET** `/api/analytics/dashboard/`
  - **Requirements**: Authentication required
  - **Returns**: Dashboard statistics

- **GET** `/api/analytics/user/`
  - **Requirements**: Authentication required
  - **Returns**: User analytics

- **GET** `/api/analytics/video/<video_id>/`
  - **Requirements**: Authentication required (video owner)
  - **Returns**: Video analytics

- **GET** `/api/analytics/party/<party_id>/`
  - **Requirements**: Authentication required (party host/moderator)
  - **Returns**: Party analytics

- **GET** `/api/analytics/system/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: System analytics

- **GET** `/api/analytics/system/performance/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: System performance metrics

- **GET** `/api/analytics/revenue/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: Revenue analytics

- **GET** `/api/analytics/retention/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: User retention analytics

- **GET** `/api/analytics/content/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: Content analytics

- **POST** `/api/analytics/events/`
  - **Requirements**: Authentication required
    ```json
    {
      "event_type": "video_view",
      "event_data": {
        "video_id": "uuid",
        "watch_duration": 120
      }
    }
    ```
  - **Returns**: Event tracking confirmation

### Advanced Analytics
- **GET** `/api/analytics/dashboard/realtime/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: Real-time dashboard data

- **POST** `/api/analytics/advanced/query/`
  - **Requirements**: Authentication required (admin)
    ```json
    {
      "query": "custom_analytics_query",
      "parameters": {}
    }
    ```
  - **Returns**: Custom query results

- **GET/POST** `/api/analytics/ab-testing/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: A/B testing results

- **GET** `/api/analytics/predictive/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: Predictive analytics data

### Latest Advanced Analytics
- **GET** `/api/analytics/platform-overview/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: Platform overview analytics

- **GET** `/api/analytics/user-behavior/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: User behavior analytics

- **GET** `/api/analytics/content-performance/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: Content performance analytics

- **GET** `/api/analytics/revenue-advanced/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: Advanced revenue analytics

- **GET** `/api/analytics/personal/`
  - **Requirements**: Authentication required
  - **Returns**: Personal user analytics

- **GET** `/api/analytics/real-time/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: Real-time analytics feed

## Notifications Endpoints (`/api/notifications/`)

### Notification Management
- **GET** `/api/notifications/`
  - **Requirements**: Authentication required
  - **Query Parameters**: `page`, `read`, `type`
  - **Returns**:
    ```json
    {
      "notifications": [
        {
          "id": "uuid",
          "type": "friend_request",
          "title": "New Friend Request",
          "message": "John Doe sent you a friend request",
          "read": false,
          "created_at": "2025-08-10T20:00:00Z",
          "data": {
            "sender_id": "uuid"
          }
        }
      ],
      "unread_count": 5
    }
    ```

- **GET** `/api/notifications/<notification_id>/`
  - **Requirements**: Authentication required
  - **Returns**: Notification details

- **POST** `/api/notifications/<notification_id>/mark-read/`
  - **Requirements**: Authentication required
  - **Returns**: Mark as read confirmation

- **POST** `/api/notifications/mark-all-read/`
  - **Requirements**: Authentication required
  - **Returns**: Mark all as read confirmation

- **DELETE** `/api/notifications/clear-all/`
  - **Requirements**: Authentication required
  - **Returns**: Clear all confirmation

### Notification Preferences
- **GET** `/api/notifications/preferences/`
  - **Requirements**: Authentication required
  - **Returns**:
    ```json
    {
      "email_notifications": true,
      "push_notifications": true,
      "friend_requests": true,
      "party_invitations": true,
      "video_comments": false,
      "marketing": false
    }
    ```

- **POST** `/api/notifications/preferences/update/`
  - **Requirements**: Authentication required
    ```json
    {
      "email_notifications": true,
      "push_notifications": true,
      "friend_requests": true,
      "party_invitations": true
    }
    ```
  - **Returns**: Preferences update confirmation

### Mobile Push Notifications
- **POST** `/api/notifications/push/token/update/`
  - **Requirements**: Authentication required
    ```json
    {
      "device_token": "fcm_token",
      "device_type": "ios",
      "app_version": "1.0.0"
    }
    ```
  - **Returns**: Token update confirmation

- **DELETE** `/api/notifications/push/token/remove/`
  - **Requirements**: Authentication required
    ```json
    {
      "device_token": "fcm_token"
    }
    ```
  - **Returns**: Token removal confirmation

- **POST** `/api/notifications/push/test/`
  - **Requirements**: Authentication required
  - **Returns**: Test notification sent confirmation

- **POST** `/api/notifications/push/broadcast/`
  - **Requirements**: Authentication required (admin)
    ```json
    {
      "title": "Announcement",
      "message": "New features available!",
      "target_users": ["all"] // or specific user IDs
    }
    ```
  - **Returns**: Broadcast confirmation

### Templates & Channels (Admin)
- **GET** `/api/notifications/templates/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: List of notification templates

- **GET** `/api/notifications/templates/<template_id>/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: Template details

- **GET** `/api/notifications/channels/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: List of notification channels

### Statistics
- **GET** `/api/notifications/stats/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: Notification statistics

- **GET** `/api/notifications/delivery-stats/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: Delivery statistics

### Bulk Operations
- **POST** `/api/notifications/bulk/send/`
  - **Requirements**: Authentication required (admin)
    ```json
    {
      "template_id": "uuid",
      "target_users": ["uuid1", "uuid2"],
      "data": {}
    }
    ```
  - **Returns**: Bulk send confirmation

- **POST** `/api/notifications/cleanup/`
  - **Requirements**: Authentication required (admin)
    ```json
    {
      "older_than_days": 30
    }
    ```
  - **Returns**: Cleanup confirmation

## Integrations Endpoints (`/api/integrations/`)

### Health Check
- **GET** `/api/integrations/health/`
  - **Requirements**: None
  - **Returns**:
    ```json
    {
      "status": "healthy",
      "services": {
        "google_drive": "available",
        "aws_s3": "available",
        "social_oauth": "available"
      }
    }
    ```

### Google Drive Integration
- **GET** `/api/integrations/google-drive/auth-url/`
  - **Requirements**: Authentication required
  - **Returns**:
    ```json
    {
      "auth_url": "https://accounts.google.com/oauth/authorize?..."
    }
    ```

- **POST** `/api/integrations/google-drive/oauth-callback/`
  - **Requirements**: Authentication required
    ```json
    {
      "code": "google_oauth_code"
    }
    ```
  - **Returns**: OAuth completion confirmation

- **GET** `/api/integrations/google-drive/files/`
  - **Requirements**: Authentication required, Google Drive connected
  - **Query Parameters**: `folder_id`, `mime_type`, `page`
  - **Returns**: List of Google Drive files

- **GET** `/api/integrations/google-drive/files/<file_id>/streaming-url/`
  - **Requirements**: Authentication required, Google Drive connected
  - **Returns**:
    ```json
    {
      "streaming_url": "https://drive.google.com/file/d/xyz/view",
      "expires_at": "2025-08-10T21:00:00Z"
    }
    ```

### AWS S3 Integration
- **POST** `/api/integrations/s3/presigned-upload/`
  - **Requirements**: Authentication required
    ```json
    {
      "filename": "video.mp4",
      "content_type": "video/mp4",
      "file_size": 1024000
    }
    ```
  - **Returns**:
    ```json
    {
      "upload_url": "https://s3.amazonaws.com/presigned-url",
      "file_key": "uploads/video_123.mp4"
    }
    ```

- **POST** `/api/integrations/s3/upload/`
  - **Requirements**: Authentication required, multipart form data
    ```
    file: video_file
    ```
  - **Returns**: Upload confirmation

- **GET** `/api/integrations/s3/files/<file_key>/streaming-url/`
  - **Requirements**: Authentication required
  - **Returns**: S3 streaming URL

### Social OAuth
- **GET** `/api/integrations/social/<provider>/auth-url/`
  - **Requirements**: Authentication optional
  - **Parameters**: `provider` (google, github, facebook, twitter)
  - **Returns**: Social OAuth URL

- **POST** `/api/integrations/social/<provider>/callback/`
  - **Requirements**: Authentication optional
    ```json
    {
      "code": "oauth_code",
      "state": "oauth_state"
    }
    ```
  - **Returns**: OAuth callback processing

### Integration Management
- **GET** `/api/integrations/status/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: Status of all integrations

- **GET** `/api/integrations/management/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: Integration management interface

- **POST** `/api/integrations/test/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: Integration test results

- **GET** `/api/integrations/types/`
  - **Requirements**: Authentication optional
  - **Returns**: Available integration types

- **GET** `/api/integrations/connections/`
  - **Requirements**: Authentication required
  - **Returns**: User's connected services

- **DELETE** `/api/integrations/connections/<connection_id>/disconnect/`
  - **Requirements**: Authentication required
  - **Returns**: Service disconnection confirmation

## Search Endpoints (`/api/search/`)

### Global Search
- **GET** `/api/search/`
  - **Requirements**: Authentication optional
  - **Query Parameters**: 
    - `q` (search query)
    - `type` (videos, parties, users, all)
    - `page`
    - `page_size`
  - **Returns**:
    ```json
    {
      "query": "search term",
      "results": {
        "videos": [
          {
            "id": "uuid",
            "title": "Video Title",
            "description": "Description",
            "thumbnail": "url",
            "duration": 3600
          }
        ],
        "parties": [
          {
            "id": "uuid",
            "title": "Party Title",
            "host": "username",
            "participants_count": 5
          }
        ],
        "users": [
          {
            "id": "uuid",
            "username": "johndoe",
            "display_name": "John Doe",
            "avatar": "url"
          }
        ]
      },
      "total_results": 45
    }
    ```

### Discover Content
- **GET** `/api/search/discover/`
  - **Requirements**: Authentication optional
  - **Query Parameters**: `category`, `trending`, `recommended`
  - **Returns**:
    ```json
    {
      "featured_videos": [],
      "trending_parties": [],
      "recommended_content": [],
      "popular_categories": []
    }
    ```

## Social Endpoints (`/api/social/`)

### Social Groups
- **GET** `/api/social/groups/`
  - **Requirements**: Authentication required
  - **Returns**: List of user's social groups

- **GET** `/api/social/groups/<group_id>/`
  - **Requirements**: Authentication required
  - **Returns**: Group details

- **POST** `/api/social/groups/<group_id>/join/`
  - **Requirements**: Authentication required
  - **Returns**: Group join confirmation

- **POST** `/api/social/groups/<group_id>/leave/`
  - **Requirements**: Authentication required
  - **Returns**: Group leave confirmation

## Mobile Endpoints (`/api/mobile/`)

### Mobile App Configuration
- **GET** `/api/mobile/config/`
  - **Requirements**: Authentication required
  - **Returns**:
    ```json
    {
      "app_version": "1.0.0",
      "min_supported_version": "1.0.0",
      "features": {
        "offline_sync": true,
        "push_notifications": true,
        "video_streaming": true
      },
      "api_endpoints": {},
      "settings": {}
    }
    ```

### Mobile Home Screen
- **GET** `/api/mobile/home/`
  - **Requirements**: Authentication required
  - **Returns**:
    ```json
    {
      "featured_content": [],
      "recent_parties": [],
      "friend_activity": [],
      "recommendations": []
    }
    ```

### Offline Sync
- **GET/POST** `/api/mobile/sync/`
  - **Requirements**: Authentication required
  - **Returns**: Offline synchronization data

### Push Notifications
- **POST** `/api/mobile/push-token/`
  - **Requirements**: Authentication required
    ```json
    {
      "device_token": "fcm_token",
      "device_type": "ios"
    }
    ```
  - **Returns**: Token registration confirmation

### App Information
- **GET** `/api/mobile/app-info/`
  - **Requirements**: Authentication optional
  - **Returns**: Mobile app information and metadata

## Moderation Endpoints (`/api/moderation/`)

### Content Reporting
- **GET** `/api/moderation/reports/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: List of content reports

- **POST** `/api/moderation/reports/`
  - **Requirements**: Authentication required
    ```json
    {
      "content_type": "video",
      "content_id": "uuid",
      "reason": "inappropriate_content",
      "description": "Report details"
    }
    ```
  - **Returns**: Report submission confirmation

- **GET** `/api/moderation/reports/<report_id>/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: Report details

### Admin Moderation Interface
- **GET** `/api/moderation/admin/queue/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: Moderation queue

- **GET** `/api/moderation/admin/stats/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: Moderation statistics

- **GET** `/api/moderation/admin/dashboard/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: Moderation dashboard data

### Report Actions
- **POST** `/api/moderation/admin/reports/<report_id>/assign/`
  - **Requirements**: Authentication required (admin)
    ```json
    {
      "moderator_id": "uuid"
    }
    ```
  - **Returns**: Report assignment confirmation

- **POST** `/api/moderation/admin/reports/<report_id>/resolve/`
  - **Requirements**: Authentication required (admin)
    ```json
    {
      "action": "approve",
      "reason": "Valid content"
    }
    ```
  - **Returns**: Report resolution confirmation

- **POST** `/api/moderation/admin/reports/<report_id>/dismiss/`
  - **Requirements**: Authentication required (admin)
    ```json
    {
      "reason": "Invalid report"
    }
    ```
  - **Returns**: Report dismissal confirmation

- **GET** `/api/moderation/admin/reports/<report_id>/actions/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: Report action history

### Bulk Operations
- **POST** `/api/moderation/admin/reports/bulk-action/`
  - **Requirements**: Authentication required (admin)
    ```json
    {
      "report_ids": ["uuid1", "uuid2"],
      "action": "resolve",
      "reason": "Bulk resolution"
    }
    ```
  - **Returns**: Bulk action confirmation

### Utility Endpoints
- **GET** `/api/moderation/report-types/`
  - **Requirements**: Authentication optional
  - **Returns**: Available report types

- **GET** `/api/moderation/content-types/`
  - **Requirements**: Authentication optional
  - **Returns**: Available content types for reporting

## Interactive Endpoints (`/api/interactive/`)

### Live Reactions
- **GET** `/api/interactive/parties/<party_id>/reactions/`
  - **Requirements**: Authentication required (party participant)
  - **Returns**: Live reactions for party

- **POST** `/api/interactive/parties/<party_id>/reactions/create/`
  - **Requirements**: Authentication required (party participant)
    ```json
    {
      "emoji": "😂",
      "timestamp": 120.5
    }
    ```
  - **Returns**: Reaction creation confirmation

### Voice Chat
- **GET** `/api/interactive/parties/<party_id>/voice-chat/`
  - **Requirements**: Authentication required (party participant)
  - **Returns**: Voice chat room information

- **POST** `/api/interactive/parties/<party_id>/voice-chat/manage/`
  - **Requirements**: Authentication required (host/moderator)
    ```json
    {
      "action": "mute_user",
      "user_id": "uuid"
    }
    ```
  - **Returns**: Voice chat management confirmation

### Screen Sharing
- **GET** `/api/interactive/parties/<party_id>/screen-shares/`
  - **Requirements**: Authentication required (party participant)
  - **Returns**: Active screen shares

- **POST** `/api/interactive/parties/<party_id>/screen-shares/start/`
  - **Requirements**: Authentication required (party participant)
  - **Returns**: Screen share initiation

- **POST** `/api/interactive/parties/<party_id>/screen-shares/<share_id>/stop/`
  - **Requirements**: Authentication required (owner/host)
  - **Returns**: Screen share termination

### Polls & Games
- **GET** `/api/interactive/parties/<party_id>/polls/`
  - **Requirements**: Authentication required (party participant)
  - **Returns**: Active polls

- **POST** `/api/interactive/parties/<party_id>/polls/create/`
  - **Requirements**: Authentication required (host/moderator)
    ```json
    {
      "question": "What should we watch next?",
      "options": ["Movie A", "Movie B", "Movie C"],
      "duration": 300
    }
    ```
  - **Returns**: Poll creation confirmation

- **POST** `/api/interactive/parties/<party_id>/polls/<poll_id>/vote/`
  - **Requirements**: Authentication required (party participant)
    ```json
    {
      "option_id": "uuid"
    }
    ```
  - **Returns**: Vote confirmation

## Store Endpoints (`/api/store/`)

### Store Items
- **GET** `/api/store/items/`
  - **Requirements**: Authentication required
  - **Query Parameters**: `category`, `featured`, `page`
  - **Returns**:
    ```json
    {
      "items": [
        {
          "id": "uuid",
          "name": "Premium Theme",
          "description": "Exclusive theme",
          "price": 9.99,
          "currency": "USD",
          "category": "themes",
          "featured": true
        }
      ]
    }
    ```

- **POST** `/api/store/purchase/`
  - **Requirements**: Authentication required
    ```json
    {
      "item_id": "uuid",
      "payment_method": "credits"
    }
    ```
  - **Returns**: Purchase confirmation

### User Inventory
- **GET** `/api/store/inventory/`
  - **Requirements**: Authentication required
  - **Returns**: User's purchased items and virtual inventory

### Achievements & Rewards
- **GET** `/api/store/achievements/`
  - **Requirements**: Authentication required
  - **Returns**: Available achievements

- **GET** `/api/store/rewards/`
  - **Requirements**: Authentication required
  - **Returns**: Available rewards

- **POST** `/api/store/rewards/<reward_id>/claim/`
  - **Requirements**: Authentication required
  - **Returns**: Reward claim confirmation

### User Stats
- **GET** `/api/store/stats/`
  - **Requirements**: Authentication required
  - **Returns**: User statistics for achievements and rewards

## Support Endpoints (`/api/support/`)

### FAQ System
- **GET** `/api/support/faq/categories/`
  - **Requirements**: Authentication optional
  - **Returns**: FAQ categories

- **GET** `/api/support/faq/`
  - **Requirements**: Authentication optional
  - **Query Parameters**: `category`, `search`
  - **Returns**: FAQ list

- **POST** `/api/support/faq/<faq_id>/vote/`
  - **Requirements**: Authentication required
    ```json
    {
      "helpful": true
    }
    ```
  - **Returns**: FAQ vote confirmation

- **GET** `/api/support/faq/<faq_id>/view/`
  - **Requirements**: Authentication optional
  - **Returns**: FAQ content and details

### Support Tickets
- **GET** `/api/support/tickets/`
  - **Requirements**: Authentication required
  - **Returns**: User's support tickets

- **POST** `/api/support/tickets/`
  - **Requirements**: Authentication required
    ```json
    {
      "subject": "Issue with video upload",
      "description": "Detailed description",
      "category": "technical",
      "priority": "medium"
    }
    ```
  - **Returns**: Ticket creation confirmation

- **GET** `/api/support/tickets/<ticket_id>/`
  - **Requirements**: Authentication required
  - **Returns**: Ticket details and messages

- **POST** `/api/support/tickets/<ticket_id>/messages/`
  - **Requirements**: Authentication required
    ```json
    {
      "message": "Additional information"
    }
    ```
  - **Returns**: Message addition confirmation

### Feedback System
- **GET** `/api/support/feedback/`
  - **Requirements**: Authentication required
  - **Returns**: User feedback submissions

- **POST** `/api/support/feedback/`
  - **Requirements**: Authentication required
    ```json
    {
      "type": "feature_request",
      "title": "Add dark mode",
      "description": "Would love a dark mode option",
      "rating": 5
    }
    ```
  - **Returns**: Feedback submission confirmation

- **POST** `/api/support/feedback/<feedback_id>/vote/`
  - **Requirements**: Authentication required
    ```json
    {
      "vote": "upvote"
    }
    ```
  - **Returns**: Feedback vote confirmation

### Help Search
- **GET** `/api/support/search/`
  - **Requirements**: Authentication optional
  - **Query Parameters**: `q` (search query)
  - **Returns**: Help content search results

## Messaging Endpoints (`/api/messaging/`)

### Direct Messaging
- **GET** `/api/messaging/conversations/`
  - **Requirements**: Authentication required
  - **Returns**: User's message conversations

- **POST** `/api/messaging/conversations/`
  - **Requirements**: Authentication required
    ```json
    {
      "participant_ids": ["uuid1", "uuid2"],
      "initial_message": "Hello!"
    }
    ```
  - **Returns**: Conversation creation confirmation

- **GET** `/api/messaging/conversations/<conversation_id>/messages/`
  - **Requirements**: Authentication required
  - **Query Parameters**: `page`, `before`, `after`
  - **Returns**: Conversation messages

- **POST** `/api/messaging/conversations/<conversation_id>/messages/`
  - **Requirements**: Authentication required
    ```json
    {
      "message": "Hello there!",
      "message_type": "text"
    }
    ```
  - **Returns**: Message send confirmation

## Admin Panel Endpoints (`/api/admin/`)

### User Management
- **GET** `/api/admin/users/`
  - **Requirements**: Authentication required (admin)
  - **Query Parameters**: `search`, `status`, `page`
  - **Returns**: User management interface

- **GET** `/api/admin/users/<user_id>/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: User details for admin

- **POST** `/api/admin/users/<user_id>/ban/`
  - **Requirements**: Authentication required (admin)
    ```json
    {
      "reason": "Terms violation",
      "duration": 86400
    }
    ```
  - **Returns**: User ban confirmation

- **POST** `/api/admin/users/<user_id>/unban/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: User unban confirmation

### Party Management
- **GET** `/api/admin/parties/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: Party management interface

- **DELETE** `/api/admin/parties/<party_id>/delete/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: Party deletion confirmation

### Video Management
- **GET** `/api/admin/videos/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: Video management interface

- **DELETE** `/api/admin/videos/<video_id>/delete/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: Video deletion confirmation

### Content Moderation
- **GET** `/api/admin/reports/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: Content reports dashboard

- **POST** `/api/admin/reports/<report_id>/resolve/`
  - **Requirements**: Authentication required (admin)
    ```json
    {
      "action": "approve",
      "reason": "Content approved"
    }
    ```
  - **Returns**: Report resolution confirmation

### System Management
- **GET** `/api/admin/logs/`
  - **Requirements**: Authentication required (admin)
  - **Query Parameters**: `level`, `date_from`, `date_to`
  - **Returns**: System logs

- **GET** `/api/admin/system-health/`
  - **Requirements**: Authentication required (admin)
  - **Returns**:
    ```json
    {
      "status": "healthy",
      "services": {
        "database": "healthy",
        "redis": "healthy",
        "celery": "healthy",
        "storage": "healthy"
      },
      "metrics": {
        "cpu_usage": 45.2,
        "memory_usage": 68.5,
        "disk_usage": 32.1
      }
    }
    ```

- **POST** `/api/admin/maintenance/`
  - **Requirements**: Authentication required (admin)
    ```json
    {
      "action": "enable",
      "message": "Scheduled maintenance"
    }
    ```
  - **Returns**: Maintenance mode confirmation

### Communication
- **POST** `/api/admin/broadcast/`
  - **Requirements**: Authentication required (admin)
    ```json
    {
      "message": "System maintenance scheduled",
      "type": "announcement",
      "target_users": "all"
    }
    ```
  - **Returns**: Broadcast message confirmation

- **POST** `/api/admin/notifications/send/`
  - **Requirements**: Authentication required (admin)
    ```json
    {
      "title": "Important Update",
      "message": "New features available",
      "recipients": ["uuid1", "uuid2"]
    }
    ```
  - **Returns**: Notification send confirmation

### Settings Management
- **GET** `/api/admin/settings/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: System settings

- **POST** `/api/admin/settings/update/`
  - **Requirements**: Authentication required (admin)
    ```json
    {
      "setting_key": "max_upload_size",
      "setting_value": "100MB"
    }
    ```
  - **Returns**: Settings update confirmation

### Health & Monitoring
- **GET** `/api/admin/health/check/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: Basic health check

- **GET** `/api/admin/health/status/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: Detailed system status

- **GET** `/api/admin/health/metrics/`
  - **Requirements**: Authentication required (admin)
  - **Returns**: System performance metrics

## API Documentation Endpoints

### Schema & Documentation
- **GET** `/api/schema/`
  - **Requirements**: None
  - **Returns**: OpenAPI schema definition

- **GET** `/api/docs/`
  - **Requirements**: None
  - **Returns**: Swagger UI documentation interface

- **GET** `/api/redoc/`
  - **Requirements**: None
  - **Returns**: ReDoc documentation interface

## Error Responses

All endpoints may return error responses in the following format:

```json
{
  "success": false,
  "error": "error_code",
  "message": "Human readable error message",
  "details": {
    "field_name": ["Field specific error messages"]
  },
  "timestamp": "2025-08-10T12:00:00Z"
}
```

Common HTTP status codes:
- `200` - Success
- `201` - Created
- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `429` - Too Many Requests
- `500` - Internal Server Error

## Authentication

Most endpoints require authentication using JWT tokens:

```
Authorization: Bearer <access_token>
```

Tokens are obtained through the login endpoint and should be refreshed using the refresh endpoint when expired.

## Rate Limiting

API endpoints have rate limiting applied:
- Authentication endpoints: Limited per IP
- General API endpoints: Limited per user
- File upload endpoints: Separate limits for upload operations

Rate limit information is returned in response headers:
- `X-RateLimit-Limit`: Request limit
- `X-RateLimit-Remaining`: Remaining requests
- `X-RateLimit-Reset`: Reset time

## Pagination

List endpoints use cursor-based pagination:

```json
{
  "results": [...],
  "pagination": {
    "next": "cursor_token",
    "previous": "cursor_token",
    "total": 100,
    "page_size": 20
  }
}
```

Query parameters:
- `page`: Page number
- `page_size`: Items per page (max 100)
- `cursor`: Pagination cursor

## WebSocket Endpoints

Real-time features use WebSocket connections:
- `/ws/party/<party_id>/` - Party synchronization
- `/ws/chat/<room_id>/` - Real-time chat
- `/ws/notifications/` - Live notifications

WebSocket authentication uses token-based authentication in the connection headers.
