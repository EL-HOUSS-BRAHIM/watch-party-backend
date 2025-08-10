# Watch Party Frontend - API Requests Analysis

Based on my analysis of the codebase, here is a comprehensive list of all API requests made in this Watch Party application:

## Authentication API Requests

### 1. Register User
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/auth/register/`
- **Request Payload**:
  ```typescript
  {
    email: string
    password: string
    confirm_password: string
    first_name: string
    last_name: string
    promo_code?: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    access_token: string
    refresh_token: string
    user: User
    verification_sent?: boolean
  }
  ```

### 2. Login User
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/auth/login/`
- **Request Payload**:
  ```typescript
  {
    email: string
    password: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    access_token: string
    refresh_token: string
    user: User
  }
  ```

### 3. Logout User
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/auth/logout/`
- **Request Payload**:
  ```typescript
  {
    refresh_token: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 4. Refresh Token
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/auth/refresh/`
- **Request Payload**:
  ```typescript
  {
    refresh: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    access: string
  }
  ```

### 5. Forgot Password
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/auth/forgot-password/`
- **Request Payload**:
  ```typescript
  {
    email: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 6. Reset Password
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/auth/reset-password/`
- **Request Payload**:
  ```typescript
  {
    token: string
    new_password: string
    confirm_password: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 7. Change Password
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/auth/change-password/`
- **Request Payload**:
  ```typescript
  {
    current_password: string
    new_password: string
    confirm_password: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 8. Verify Email
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/auth/verify-email/`
- **Request Payload**:
  ```typescript
  {
    token: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 9. Get User Profile
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/auth/profile/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  User
  ```

### 10. Setup Two-Factor Authentication
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/auth/2fa/setup/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    success: boolean
    qr_code: string
    secret: string
    backup_codes: string[]
  }
  ```

### 11. Verify 2FA Code
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/auth/2fa/verify/`
- **Request Payload**:
  ```typescript
  {
    code: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    access_token: string
    refresh_token: string
    user: User
  }
  ```

### 12. Disable 2FA
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/auth/2fa/disable/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 13. Get User Sessions
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/auth/sessions/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  Array<{
    id: string
    device: string
    location: string
    last_activity: string
    is_current: boolean
  }>
  ```

### 14. Delete Session
- **HTTP Method**: DELETE
- **Mock Endpoint Path**: `/api/auth/sessions/{sessionId}/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 15. Get Google Drive Auth URL
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/auth/google-drive/auth/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    auth_url: string
  }
  ```

### 16. Disconnect Google Drive
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/auth/google-drive/disconnect/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 17. Get Google Drive Status
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/auth/google-drive/status/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    is_connected: boolean
    email: string | null
    permissions: string[]
  }
  ```

## Users API Requests

### 18. Get Dashboard Stats
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/users/dashboard/stats/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    total_parties: number
    parties_hosted: number
    parties_joined: number
    total_videos: number
    watch_time_hours: number
    friends_count: number
    recent_activity: {
      parties_this_week: number
      videos_uploaded_this_week: number
      watch_time_this_week: number
    }
  }
  ```

### 19. Get User Profile
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/users/profile/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  User & { profile: UserProfile }
  ```

### 20. Update User Profile
- **HTTP Method**: PUT
- **Mock Endpoint Path**: `/api/users/profile/update/`
- **Request Payload**:
  ```typescript
  Partial<UserProfile>
  ```
- **Expected Response**:
  ```typescript
  User & { profile: UserProfile }
  ```

### 21. Upload Avatar
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/users/avatar/upload/`
- **Request Payload**: FormData with file
- **Expected Response**:
  ```typescript
  {
    success: boolean
    avatar_url: string
  }
  ```

### 22. Get User Achievements
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/users/achievements/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  Achievement[]
  ```

### 23. Get User Stats
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/users/stats/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  UserStats
  ```

### 24. Complete Onboarding
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/users/onboarding/`
- **Request Payload**:
  ```typescript
  {
    interests: string[]
    preferred_genres: string[]
    notifications_enabled: boolean
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 25. Change Password (Users)
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/users/password/`
- **Request Payload**:
  ```typescript
  {
    current_password: string
    new_password: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 26. Get User Inventory
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/users/inventory/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  any[]
  ```

### 27. Get User Sessions
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/users/sessions/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  UserSession[]
  ```

### 28. Delete User Session
- **HTTP Method**: DELETE
- **Mock Endpoint Path**: `/api/users/sessions/{sessionId}/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 29. Revoke All Sessions
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/users/sessions/revoke-all/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 30. Enable 2FA (Users)
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/users/2fa/enable/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    success: boolean
    qr_code: string
    secret: string
    backup_codes: string[]
  }
  ```

### 31. Get Friends List
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/users/friends/`
- **Request Payload**: Query parameters: `page?: number, limit?: number`
- **Expected Response**:
  ```typescript
  PaginatedResponse<Friend>
  ```

### 32. Send Friend Request
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/users/friends/request/`
- **Request Payload**:
  ```typescript
  FriendRequest
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 33. Get Friend Suggestions
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/users/friends/suggestions/`
- **Request Payload**: Query parameters: `limit?: number`
- **Expected Response**:
  ```typescript
  Friend[]
  ```

### 34. Get Friend Requests
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/users/friends/requests/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  FriendRequest[]
  ```

### 35. Accept Friend Request
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/users/friends/{requestId}/accept/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 36. Search Users
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/users/search/`
- **Request Payload**: Query parameters: `q: string, limit?: number`
- **Expected Response**:
  ```typescript
  PaginatedResponse<Friend>
  ```

### 37. Get User Notifications
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/users/notifications/`
- **Request Payload**: Query parameters: `page?: number, unread?: boolean, type?: string`
- **Expected Response**:
  ```typescript
  PaginatedResponse<Notification> & { unread_count: number }
  ```

## Videos API Requests

### 38. Get Videos List
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/videos/`
- **Request Payload**: Query parameters: `page?: number, search?: string, visibility?: string, uploader?: string, ordering?: string`
- **Expected Response**:
  ```typescript
  PaginatedResponse<Video>
  ```

### 39. Create Video
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/videos/`
- **Request Payload**:
  ```typescript
  {
    title: string
    description: string
    visibility: 'public' | 'private' | 'unlisted'
    allow_download?: boolean
    require_premium?: boolean
  }
  ```
- **Expected Response**:
  ```typescript
  Video
  ```

### 40. Get Video Details
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/videos/{id}/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  Video
  ```

### 41. Update Video
- **HTTP Method**: PATCH
- **Mock Endpoint Path**: `/api/videos/{id}/`
- **Request Payload**:
  ```typescript
  Partial<Video>
  ```
- **Expected Response**:
  ```typescript
  Video
  ```

### 42. Delete Video
- **HTTP Method**: DELETE
- **Mock Endpoint Path**: `/api/videos/{id}/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 43. Upload Video
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/videos/upload/`
- **Request Payload**: FormData with file and metadata
- **Expected Response**:
  ```typescript
  VideoUpload
  ```

### 44. Get Upload Status
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/videos/upload/{uploadId}/status/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  VideoUploadStatus
  ```

### 45. Get Video Stream
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/videos/{id}/stream/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  VideoStreamInfo
  ```

### 46. Like Video
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/videos/{id}/like/`
- **Request Payload**:
  ```typescript
  {
    is_like: boolean
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    is_liked: boolean
    like_count: number
  }
  ```

### 47. Search Videos
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/videos/search/`
- **Request Payload**: Query parameters: `q: string, category?: string, duration_min?: number, duration_max?: number, quality?: string, ordering?: string`
- **Expected Response**:
  ```typescript
  PaginatedResponse<Video> & {
    facets: {
      categories: Array<{ name: string; count: number }>
      qualities: Array<{ name: string; count: number }>
    }
  }
  ```

### 48. Get Video Comments
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/videos/{id}/comments/`
- **Request Payload**: Query parameters: `page?: number, limit?: number`
- **Expected Response**:
  ```typescript
  PaginatedResponse<VideoComment>
  ```

### 49. Download Video
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/videos/{id}/download/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  File download response
  ```

### 50. Upload S3 Video
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/videos/upload/s3/`
- **Request Payload**:
  ```typescript
  {
    file_name: string
    file_size: number
    content_type: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    upload_url: string
    upload_id: string
    fields: Record<string, string>
  }
  ```

### 51. Complete Upload
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/videos/upload/{uploadId}/complete/`
- **Request Payload**:
  ```typescript
  {
    etag: string
    parts?: Array<{ ETag: string; PartNumber: number }>
  }
  ```
- **Expected Response**:
  ```typescript
  VideoUpload
  ```

### 52. Get Video Thumbnail
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/videos/{videoId}/thumbnail/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    thumbnail_url: string
  }
  ```

### 53. Get Video Analytics
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/videos/{videoId}/analytics/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  VideoAnalytics
  ```

## Parties API Requests

### 54. Get Parties List
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/parties/`
- **Request Payload**: Query parameters: `status?: string, visibility?: string, search?: string, page?: number`
- **Expected Response**:
  ```typescript
  PaginatedResponse<WatchParty>
  ```

### 55. Create Party
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/parties/`
- **Request Payload**:
  ```typescript
  {
    title: string
    description: string
    video: string
    visibility: 'public' | 'private'
    max_participants?: number
    scheduled_start?: string
    require_approval?: boolean
    allow_chat?: boolean
    allow_reactions?: boolean
  }
  ```
- **Expected Response**:
  ```typescript
  WatchParty
  ```

### 56. Get Party Details
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/parties/{id}/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  WatchParty
  ```

### 57. Update Party
- **HTTP Method**: PATCH
- **Mock Endpoint Path**: `/api/parties/{id}/`
- **Request Payload**:
  ```typescript
  Partial<WatchParty>
  ```
- **Expected Response**:
  ```typescript
  WatchParty
  ```

### 58. Delete Party
- **HTTP Method**: DELETE
- **Mock Endpoint Path**: `/api/parties/{id}/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 59. Join Party
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/parties/{partyId}/join/`
- **Request Payload**:
  ```typescript
  {
    message?: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message: string
    participant: {
      user: {
        id: string
        name: string
        avatar: string
      }
      role: string
      status: string
      joined_at: string
    }
  }
  ```

### 60. Leave Party
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/parties/{partyId}/leave/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

## Chat API Requests

### 61. Get Chat Messages
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/chat/{partyId}/messages/`
- **Request Payload**: Query parameters: `page?: number, limit?: number`
- **Expected Response**:
  ```typescript
  PaginatedResponse<ChatMessage>
  ```

### 62. Send Chat Message
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/chat/{partyId}/send/`
- **Request Payload**:
  ```typescript
  {
    message: string
    message_type: 'text' | 'emoji'
  }
  ```
- **Expected Response**:
  ```typescript
  ChatMessage
  ```

### 63. Get Chat Settings
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/chat/{roomId}/settings/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  ChatSettings
  ```

### 64. Update Chat Settings
- **HTTP Method**: PUT
- **Mock Endpoint Path**: `/api/chat/{roomId}/settings/`
- **Request Payload**:
  ```typescript
  Partial<ChatSettings>
  ```
- **Expected Response**:
  ```typescript
  ChatSettings
  ```

### 65. Join Chat Room
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/chat/{roomId}/join/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 66. Leave Chat Room
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/chat/{roomId}/leave/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 67. Get Active Chat Users
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/chat/{roomId}/active-users/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  ChatUser[]
  ```

### 68. Moderate Chat Room
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/chat/{roomId}/moderate/`
- **Request Payload**:
  ```typescript
  {
    action: 'slow_mode' | 'subscriber_only' | 'emote_only' | 'clear_chat'
    duration?: number
    reason?: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

## Analytics API Requests

### 69. Get Analytics Dashboard
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/analytics/dashboard/`
- **Request Payload**: Query parameters: `time_range?: string`
- **Expected Response**:
  ```typescript
  AnalyticsDashboard
  ```

### 70. Get User Analytics
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/analytics/user/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  UserAnalytics
  ```

### 71. Get Video Analytics
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/analytics/video/{videoId}/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    video: {
      id: string
      title: string
      views: number
      completion_rate: number
    }
    engagement: {
      likes: number
      comments: number
      shares: number
      average_rating: number
    }
    view_chart: Array<{
      date: string
      views: number
    }>
  }
  ```

### 72. Get Basic Analytics
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/analytics/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  BasicAnalytics
  ```

### 73. Export Analytics
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/analytics/export/`
- **Request Payload**:
  ```typescript
  {
    format: 'csv' | 'excel' | 'pdf'
    date_range: {
      start: string
      end: string
    }
    metrics: string[]
  }
  ```
- **Expected Response**:
  ```typescript
  {
    download_url: string
    expires_at: string
  }
  ```

## Store API Requests

### 74. Get Store Items
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/store/items/`
- **Request Payload**: Query parameters: `category?: string, page?: number, limit?: number`
- **Expected Response**:
  ```typescript
  PaginatedResponse<StoreItem>
  ```

### 75. Purchase Item
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/store/purchase/`
- **Request Payload**:
  ```typescript
  {
    item_id: string
    quantity?: number
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    purchase_id: string
    total_cost: number
    message?: string
  }
  ```

### 76. Get User Inventory
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/store/inventory/`
- **Request Payload**: Query parameters: `page?: number, category?: string`
- **Expected Response**:
  ```typescript
  PaginatedResponse<UserInventory>
  ```

## Search API Requests

### 77. Global Search
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/search/`
- **Request Payload**: Query parameters: `q: string, type?: string, page?: number, limit?: number`
- **Expected Response**:
  ```typescript
  {
    success: boolean
    results: {
      videos: SearchResult[]
      parties: SearchResult[]
      users: SearchResult[]
    }
    total_count: number
    search_time: number
  }
  ```

### 78. Discover Content
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/search/discover/`
- **Request Payload**: Query parameters: `category?: string, trending?: boolean, recommended?: boolean, limit?: number`
- **Expected Response**:
  ```typescript
  {
    success: boolean
    content: DiscoverContent
    recommendations: {
      videos: any[]
      parties: any[]
      users: any[]
    }
  }
  ```

## Interactive Features API Requests

### 79. Get Reactions
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/interactive/parties/{partyId}/reactions/`
- **Request Payload**: Query parameters: `page?: number, limit?: number`
- **Expected Response**:
  ```typescript
  PaginatedResponse<Reaction>
  ```

### 80. Create Reaction
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/interactive/parties/{partyId}/reactions/create/`
- **Request Payload**:
  ```typescript
  {
    type: string
    emoji?: string
    timestamp?: number
  }
  ```
- **Expected Response**:
  ```typescript
  Reaction
  ```

### 81. Create Poll
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/interactive/parties/{partyId}/polls/create/`
- **Request Payload**:
  ```typescript
  {
    question: string
    options: string[]
    duration?: number
  }
  ```
- **Expected Response**:
  ```typescript
  Poll
  ```

### 82. Get Voice Chat
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/interactive/parties/{partyId}/voice-chat/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  VoiceChat
  ```

### 83. Manage Voice Chat
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/interactive/parties/{partyId}/voice-chat/manage/`
- **Request Payload**:
  ```typescript
  {
    action: 'start' | 'stop' | 'mute' | 'unmute'
    user_id?: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

## Admin API Requests

### 84. Get Admin Dashboard
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/admin/dashboard/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  AdminDashboard
  ```

### 85. Get Admin Users
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/admin/users/`
- **Request Payload**: Query parameters: various filters
- **Expected Response**:
  ```typescript
  PaginatedResponse<User>
  ```

### 86. Export Users
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/admin/users/export/`
- **Request Payload**:
  ```typescript
  {
    format?: 'csv' | 'excel'
    filters?: Record<string, any>
  }
  ```
- **Expected Response**:
  ```typescript
  {
    download_url: string
    expires_at: string
  }
  ```

### 87. Get User Actions
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/admin/users/{userId}/actions/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  any[]
  ```

### 88. Get Admin Parties
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/admin/parties/`
- **Request Payload**: Query parameters: `search?: string, status?: string, page?: number`
- **Expected Response**:
  ```typescript
  PaginatedResponse<any>
  ```

### 89. Update User Status (Admin)
- **HTTP Method**: PUT
- **Mock Endpoint Path**: `/api/admin/users/{userId}/status/`
- **Request Payload**:
  ```typescript
  {
    status: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 90. Update User Role (Admin)
- **HTTP Method**: PUT
- **Mock Endpoint Path**: `/api/admin/users/{userId}/role/`
- **Request Payload**:
  ```typescript
  {
    role: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 91. Get System Logs
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/admin/system-logs/`
- **Request Payload**: Query parameters: `level?: string, component?: string, search?: string, date_from?: string, date_to?: string, page?: number`
- **Expected Response**:
  ```typescript
  PaginatedResponse<any>
  ```

### 92. Delete Admin Party
- **HTTP Method**: DELETE
- **Mock Endpoint Path**: `/api/admin/parties/{partyId}/delete/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 93. Get Admin Videos
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/admin/videos/`
- **Request Payload**: Query parameters: various filters
- **Expected Response**:
  ```typescript
  PaginatedResponse<Video>
  ```

### 94. Delete Admin Video
- **HTTP Method**: DELETE
- **Mock Endpoint Path**: `/api/admin/videos/{videoId}/delete/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 95. Get Admin Reports
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/admin/reports/`
- **Request Payload**: Query parameters: `page?: number, status?: string, type?: string`
- **Expected Response**:
  ```typescript
  PaginatedResponse<any>
  ```

### 96. Resolve Report
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/admin/reports/{reportId}/resolve/`
- **Request Payload**:
  ```typescript
  {
    action: string
    reason?: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 97. Get Admin Logs
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/admin/logs/`
- **Request Payload**: Query parameters: `level?: string, page?: number, date_from?: string, date_to?: string`
- **Expected Response**:
  ```typescript
  PaginatedResponse<any>
  ```

### 98. Get System Health
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/admin/system-health/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    status: string
    uptime: number
    memory_usage: number
    cpu_usage: number
    disk_usage: number
    active_users: number
    active_parties: number
  }
  ```

### 99. System Maintenance
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/admin/maintenance/`
- **Request Payload**:
  ```typescript
  {
    action: 'start' | 'stop' | 'status'
    message?: string
    duration?: number
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    maintenance_mode: boolean
    message?: string
  }
  ```

### 100. Broadcast Message
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/admin/broadcast/`
- **Request Payload**:
  ```typescript
  {
    message: string
    type: 'info' | 'warning' | 'error' | 'success'
    target_users?: string[]
    channels?: string[]
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message_id: string
    sent_count: number
  }
  ```

### 101. Send Admin Notification
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/admin/notifications/send/`
- **Request Payload**:
  ```typescript
  {
    title: string
    message: string
    type: string
    target_users: string[]
    send_push?: boolean
    send_email?: boolean
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    notification_id: string
    sent_count: number
  }
  ```

### 102. Get Admin Settings
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/admin/settings/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  Record<string, any>
  ```

### 103. Update Admin Settings
- **HTTP Method**: PUT
- **Mock Endpoint Path**: `/api/admin/settings/update/`
- **Request Payload**:
  ```typescript
  Record<string, any>
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 104. Health Check
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/admin/health/check/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    status: 'healthy' | 'unhealthy'
    checks: Record<string, boolean>
    timestamp: string
  }
  ```

### 105. Health Status
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/admin/health/status/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    overall_status: string
    services: Record<string, any>
  }
  ```

### 106. Health Metrics
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/admin/health/metrics/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    metrics: Record<string, number>
    timestamp: string
  }
  ```

## Billing API Requests

### 107. Get Billing Plans
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/billing/plans/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  Array<{
    id: string
    name: string
    price: number
    features: string[]
    billing_period: 'monthly' | 'yearly'
  }>
  ```

### 108. Get Subscription
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/billing/subscription/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    id: string
    plan: any
    status: string
    current_period_start: string
    current_period_end: string
    auto_renew: boolean
  }
  ```

### 109. Subscribe to Plan
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/billing/subscribe/`
- **Request Payload**:
  ```typescript
  {
    plan_id: string
    payment_method_id: string
    promo_code?: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    subscription_id: string
    client_secret?: string
  }
  ```

### 110. Get Payment Methods
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/billing/payment-methods/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  Array<{
    id: string
    type: string
    last4: string
    brand: string
    is_default: boolean
  }>
  ```

### 111. Get Billing History
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/billing/history/`
- **Request Payload**: Query parameters: `page?: number, limit?: number`
- **Expected Response**:
  ```typescript
  PaginatedResponse<{
    id: string
    amount: number
    status: string
    date: string
    description: string
  }>
  ```

### 112. Cancel Subscription
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/billing/subscription/cancel/`
- **Request Payload**:
  ```typescript
  {
    reason?: string
    immediate?: boolean
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    cancellation_date: string
    message?: string
  }
  ```

### 113. Resume Subscription
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/billing/subscription/resume/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 114. Set Default Payment Method
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/billing/payment-methods/{methodId}/set-default/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 115. Get Invoice
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/billing/invoices/{invoiceId}/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    id: string
    amount: number
    status: string
    date: string
    pdf_url: string
  }
  ```

### 116. Download Invoice
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/billing/invoices/{invoiceId}/download/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  File download response
  ```

### 117. Get Billing Address
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/billing/address/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    line1: string
    line2?: string
    city: string
    state: string
    postal_code: string
    country: string
  }
  ```

### 118. Update Billing Address
- **HTTP Method**: PUT
- **Mock Endpoint Path**: `/api/billing/address/`
- **Request Payload**:
  ```typescript
  {
    line1: string
    line2?: string
    city: string
    state: string
    postal_code: string
    country: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 119. Validate Promo Code
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/billing/promo-code/validate/`
- **Request Payload**:
  ```typescript
  {
    code: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    valid: boolean
    discount_amount?: number
    discount_percentage?: number
    message?: string
  }
  ```

## Moderation API Requests

### 120. Get Moderation Reports
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/moderation/reports/`
- **Request Payload**: Query parameters: `page?: number, status?: string, type?: string, reported_by?: string`
- **Expected Response**:
  ```typescript
  PaginatedResponse<{
    id: string
    content_type: string
    content_id: string
    reporter: any
    reason: string
    status: string
    created_at: string
    resolved_at?: string
    moderator?: any
  }>
  ```

### 121. Create Report
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/moderation/reports/`
- **Request Payload**:
  ```typescript
  {
    content_type: string
    content_id: string
    reason: string
    description?: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    report_id: string
    message?: string
  }
  ```

### 122. Get Report Types
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/moderation/report-types/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  Array<{
    id: string
    name: string
    description: string
    severity: string
  }>
  ```

### 123. Get Content Types
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/moderation/content-types/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  Array<{
    id: string
    name: string
    description: string
  }>
  ```

## Events API Requests

### 124. Get Events List
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/events/`
- **Request Payload**: Query parameters: `page?: number, category?: string, date_from?: string, date_to?: string`
- **Expected Response**:
  ```typescript
  PaginatedResponse<{
    id: string
    title: string
    description: string
    start_time: string
    end_time: string
    location?: string
    max_attendees?: number
    current_attendees: number
    status: string
  }>
  ```

### 125. Create Event
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/events/`
- **Request Payload**:
  ```typescript
  {
    title: string
    description: string
    start_time: string
    end_time: string
    location?: string
    max_attendees?: number
    require_approval?: boolean
    is_public?: boolean
  }
  ```
- **Expected Response**:
  ```typescript
  {
    id: string
    title: string
    description: string
    start_time: string
    end_time: string
    status: string
  }
  ```

### 126. Get Event Details
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/events/{id}/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    id: string
    title: string
    description: string
    start_time: string
    end_time: string
    location?: string
    max_attendees?: number
    current_attendees: number
    status: string
    organizer: any
    attendees: any[]
  }
  ```

### 127. Update Event
- **HTTP Method**: PUT
- **Mock Endpoint Path**: `/api/events/{id}/`
- **Request Payload**:
  ```typescript
  Partial<{
    title: string
    description: string
    start_time: string
    end_time: string
    location: string
    max_attendees: number
  }>
  ```
- **Expected Response**:
  ```typescript
  {
    id: string
    title: string
    description: string
    start_time: string
    end_time: string
    status: string
  }
  ```

### 128. Delete Event
- **HTTP Method**: DELETE
- **Mock Endpoint Path**: `/api/events/{id}/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 129. Join Event
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/events/{id}/join/`
- **Request Payload**:
  ```typescript
  {
    message?: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 130. Leave Event
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/events/{id}/leave/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 131. Cancel Event
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/events/{id}/cancel/`
- **Request Payload**:
  ```typescript
  {
    reason?: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 132. RSVP to Event
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/events/{id}/rsvp/`
- **Request Payload**:
  ```typescript
  {
    status: 'attending' | 'not_attending' | 'maybe'
    message?: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    rsvp_status: string
    message?: string
  }
  ```

### 133. Get Event Attendees
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/events/{id}/attendees/`
- **Request Payload**: Query parameters: `page?: number, status?: string`
- **Expected Response**:
  ```typescript
  PaginatedResponse<{
    user: any
    rsvp_status: string
    joined_at: string
  }>
  ```

### 134. Get Event Invitations
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/events/{id}/invitations/`
- **Request Payload**: Query parameters: `page?: number`
- **Expected Response**:
  ```typescript
  PaginatedResponse<{
    id: string
    invitee: any
    status: string
    sent_at: string
    responded_at?: string
  }>
  ```

### 135. Send Event Invitation
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/events/{id}/invite/`
- **Request Payload**:
  ```typescript
  {
    user_ids: string[]
    message?: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    invitations_sent: number
    message?: string
  }
  ```

### 136. Get Upcoming Events
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/events/upcoming/`
- **Request Payload**: Query parameters: `limit?: number, category?: string`
- **Expected Response**:
  ```typescript
  Array<{
    id: string
    title: string
    start_time: string
    location?: string
    attendees_count: number
  }>
  ```

### 137. Get My Events
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/events/my/`
- **Request Payload**: Query parameters: `page?: number, status?: string`
- **Expected Response**:
  ```typescript
  PaginatedResponse<{
    id: string
    title: string
    start_time: string
    end_time: string
    my_role: string
    status: string
  }>
  ```

### 138. Get Hosted Events
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/events/hosted/`
- **Request Payload**: Query parameters: `page?: number, status?: string`
- **Expected Response**:
  ```typescript
  PaginatedResponse<{
    id: string
    title: string
    start_time: string
    attendees_count: number
    status: string
  }>
  ```

### 139. Search Events
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/events/search/`
- **Request Payload**: Query parameters: `q: string, category?: string, location?: string, date_from?: string, date_to?: string`
- **Expected Response**:
  ```typescript
  PaginatedResponse<{
    id: string
    title: string
    description: string
    start_time: string
    location?: string
    attendees_count: number
  }>
  ```

### 140. Get Featured Events
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/events/featured/`
- **Request Payload**: Query parameters: `limit?: number`
- **Expected Response**:
  ```typescript
  Array<{
    id: string
    title: string
    description: string
    start_time: string
    featured_image?: string
    attendees_count: number
  }>
  ```

### 141. Get Event Analytics
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/events/{id}/analytics/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    total_views: number
    rsvps: {
      attending: number
      not_attending: number
      maybe: number
    }
    attendance_rate: number
    engagement_metrics: Record<string, number>
  }
  ```

### 142. Get Events Statistics
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/events/statistics/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    total_events: number
    events_this_month: number
    total_attendees: number
    popular_categories: Array<{
      category: string
      count: number
    }>
  }
  ```

## Social Groups API Requests

### 143. Get Groups List
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/social/groups/`
- **Request Payload**: Query parameters: `page?: number, category?: string, search?: string`
- **Expected Response**:
  ```typescript
  PaginatedResponse<{
    id: string
    name: string
    description: string
    member_count: number
    is_private: boolean
    category: string
  }>
  ```

### 144. Get Group Details
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/social/groups/{groupId}/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    id: string
    name: string
    description: string
    member_count: number
    is_private: boolean
    category: string
    created_at: string
    admin: any
    moderators: any[]
    my_role?: string
  }
  ```

## Integrations API Requests

### 145. Get Google Drive Auth URL
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/integrations/google-drive/auth-url/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    auth_url: string
  }
  ```

### 146. Get Google Drive Files
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/integrations/google-drive/files/`
- **Request Payload**: Query parameters: `page?: number, search?: string, mime_type?: string`
- **Expected Response**:
  ```typescript
  PaginatedResponse<{
    id: string
    name: string
    mime_type: string
    size: number
    modified_time: string
  }>
  ```

### 147. Get S3 Presigned Upload URL
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/integrations/s3/presigned-upload/`
- **Request Payload**:
  ```typescript
  {
    file_name: string
    file_type: string
    file_size: number
  }
  ```
- **Expected Response**:
  ```typescript
  {
    upload_url: string
    fields: Record<string, string>
  }
  ```

### 148. Get Integration Auth URL
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/integrations/{provider}/auth-url/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    auth_url: string
  }
  ```

### 149. Integration Callback
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/integrations/{provider}/callback/`
- **Request Payload**:
  ```typescript
  {
    code: string
    state?: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 150. Integration Health Check
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/integrations/health/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    status: string
    services: Record<string, boolean>
  }
  ```

### 151. Get Google Drive Streaming URL
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/integrations/files/{fileId}/streaming-url/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    streaming_url: string
    expires_at: string
  }
  ```

## Interactive Features Extended API Requests

### 152. Get Screen Shares
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/interactive/parties/{partyId}/screen-shares/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  Array<{
    id: string
    user: any
    status: string
    started_at: string
    viewers_count: number
  }>
  ```

### 153. Update Screen Share
- **HTTP Method**: PUT
- **Mock Endpoint Path**: `/api/interactive/screen-shares/{shareId}/update/`
- **Request Payload**:
  ```typescript
  {
    status?: string
    quality?: string
    allow_annotations?: boolean
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    screen_share: any
  }
  ```

### 154. Create Screen Share Annotation
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/interactive/screen-shares/{shareId}/annotations/`
- **Request Payload**:
  ```typescript
  {
    type: string
    x: number
    y: number
    text?: string
    color?: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    annotation_id: string
  }
  ```

### 155. Publish Poll
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/interactive/polls/{pollId}/publish/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 156. Respond to Poll
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/interactive/polls/{pollId}/respond/`
- **Request Payload**:
  ```typescript
  {
    option_id: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 157. Get Interactive Analytics
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/interactive/parties/{partyId}/analytics/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    reactions_count: number
    polls_count: number
    voice_chat_duration: number
    screen_shares_count: number
    engagement_score: number
  }
  ```

## Support API Requests

### 158. Get Support Tickets
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/support/tickets/`
- **Request Payload**: Query parameters: `page?: number, status?: string, priority?: string`
- **Expected Response**:
  ```typescript
  PaginatedResponse<{
    id: string
    subject: string
    status: string
    priority: string
    created_at: string
    updated_at: string
    unread_messages: number
  }>
  ```

### 159. Create Support Ticket
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/support/tickets/`
- **Request Payload**:
  ```typescript
  {
    subject: string
    description: string
    priority: 'low' | 'medium' | 'high' | 'urgent'
    category: string
    attachments?: string[]
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    ticket_id: string
    message?: string
  }
  ```

### 160. Get Support Ticket Details
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/support/tickets/{ticketId}/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    id: string
    subject: string
    description: string
    status: string
    priority: string
    category: string
    created_at: string
    messages: Array<{
      id: string
      content: string
      author: any
      created_at: string
      attachments: string[]
    }>
  }
  ```

### 161. Reply to Support Ticket
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/support/tickets/{ticketId}/reply/`
- **Request Payload**:
  ```typescript
  {
    content: string
    attachments?: string[]
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message_id: string
  }
  ```

### 162. Close Support Ticket
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/support/tickets/{ticketId}/close/`
- **Request Payload**:
  ```typescript
  {
    reason?: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 163. Get FAQ
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/support/faq/`
- **Request Payload**: Query parameters: `category?: string, search?: string`
- **Expected Response**:
  ```typescript
  Array<{
    id: string
    question: string
    answer: string
    category: string
    helpful_count: number
  }>
  ```

### 164. Submit Feedback
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/support/feedback/`
- **Request Payload**:
  ```typescript
  {
    type: 'bug' | 'feature' | 'improvement' | 'other'
    title: string
    description: string
    rating?: number
    page_url?: string
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    feedback_id: string
    message?: string
  }
  ```

### 165. Vote on Feedback
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/support/feedback/{feedbackId}/vote/`
- **Request Payload**:
  ```typescript
  {
    vote: 'up' | 'down'
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    vote_count: number
  }
  ```

### 166. Search Support
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/support/search/`
- **Request Payload**: Query parameters: `q: string, type?: string`
- **Expected Response**:
  ```typescript
  {
    tickets: any[]
    faq: any[]
    knowledge_base: any[]
  }
  ```

## Mobile API Requests

### 167. Get Mobile Config
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/mobile/config/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    min_version: string
    features_enabled: Record<string, boolean>
    api_endpoints: Record<string, string>
  }
  ```

### 168. Get Mobile Home
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/mobile/home/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    recent_parties: any[]
    trending_videos: any[]
    friend_activity: any[]
    notifications_count: number
  }
  ```

### 169. Mobile Sync
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/mobile/sync/`
- **Request Payload**:
  ```typescript
  {
    last_sync?: string
    device_info: {
      platform: string
      version: string
      device_id: string
    }
  }
  ```
- **Expected Response**:
  ```typescript
  {
    sync_token: string
    updated_data: Record<string, any>
  }
  ```

### 170. Update Push Token
- **HTTP Method**: POST
- **Mock Endpoint Path**: `/api/mobile/push-token/`
- **Request Payload**:
  ```typescript
  {
    token: string
    platform: 'ios' | 'android'
  }
  ```
- **Expected Response**:
  ```typescript
  {
    success: boolean
    message?: string
  }
  ```

### 171. Get Mobile App Info
- **HTTP Method**: GET
- **Mock Endpoint Path**: `/api/mobile/app-info/`
- **Request Payload**: None
- **Expected Response**:
  ```typescript
  {
    current_version: string
    update_available: boolean
    update_required: boolean
    download_url?: string
    changelog?: string
  }
  ```

## WebSocket Requests

### WebSocket Connection
- **WebSocket URL**: `ws://localhost:8000/ws?token={access_token}`
- **Connection**: Authenticated WebSocket connection using JWT token
- **Reconnection**: Automatic reconnection with exponential backoff (max 5 attempts)

### WebSocket Message Format
All WebSocket messages follow this standard format:
```typescript
{
  type: string
  data?: any
  timestamp: string
}
```

### 1. Join Room
- **Message Type**: `join_room`
- **Send Payload**:
  ```typescript
  {
    type: "join_room"
    data: {
      room_id: string
    }
    timestamp: string
  }
  ```
- **Expected Response**: Connection confirmation and room state sync

### 2. Leave Room
- **Message Type**: `leave_room`
- **Send Payload**:
  ```typescript
  {
    type: "leave_room"
    data: {
      room_id: string
    }
    timestamp: string
  }
  ```
- **Expected Response**: Disconnection confirmation

### 3. Chat Message
- **Message Type**: `chat_message`
- **Send Payload**:
  ```typescript
  {
    type: "chat_message"
    data: {
      message: string
    }
    timestamp: string
  }
  ```
- **Receive Payload**:
  ```typescript
  {
    type: "chat_message"
    data: {
      message: {
        id: string
        user: {
          id: string
          username: string
          firstName: string
          lastName: string
          avatar?: string
        }
        message: string
        timestamp: string
        type: "message" | "system"
      }
    }
  }
  ```

### 4. Video Control
- **Message Type**: `video_control`
- **Send Payload**:
  ```typescript
  {
    type: "video_control"
    data: {
      action: "play" | "pause" | "seek"
      value?: number // For seek action (timestamp in seconds)
    }
    timestamp: string
  }
  ```
- **Expected Response**: Video state synchronization to all participants

### 5. Party Control
- **Message Type**: `party:control`
- **Send Payload**:
  ```typescript
  {
    type: "party:control"
    data: {
      party_id: string
      action: "play" | "pause" | "skip" | "end_party"
      seconds?: number // For skip action
    }
    timestamp: string
  }
  ```
- **Expected Response**: Party state update to all participants

### 6. Reaction
- **Message Type**: `reaction`
- **Send Payload**:
  ```typescript
  {
    type: "reaction"
    data: {
      reaction: "heart" | "like" | "laugh" | "wow" | "sad" | "angry"
    }
    timestamp: string
  }
  ```
- **Receive Payload**:
  ```typescript
  {
    type: "reaction"
    data: {
      user_id: string
      username: string
      reaction: string
      timestamp: string
    }
  }
  ```

### 7. Kick Participant
- **Message Type**: `kick_participant`
- **Send Payload**:
  ```typescript
  {
    type: "kick_participant"
    data: {
      participant_id: string
    }
    timestamp: string
  }
  ```
- **Expected Response**: Participant removal confirmation

## WebSocket Event Handlers (Received Messages)

### 1. Sync State
- **Message Type**: `sync_state`
- **Receive Payload**:
  ```typescript
  {
    type: "sync_state"
    data: {
      sync_state: {
        currentTime: number
        isPlaying: boolean
        duration: number
        playbackRate: number
      }
    }
  }
  ```
- **Purpose**: Synchronizes video playback state across all participants

### 2. Participant Joined
- **Message Type**: `participant_joined`
- **Receive Payload**:
  ```typescript
  {
    type: "participant_joined"
    data: {
      participant: {
        id: string
        user: {
          id: string
          username: string
          firstName: string
          lastName: string
          avatar?: string
        }
        joinedAt: string
        isHost: boolean
      }
    }
  }
  ```
- **Purpose**: Notifies when a new participant joins the party

### 3. Participant Left
- **Message Type**: `participant_left`
- **Receive Payload**:
  ```typescript
  {
    type: "participant_left"
    data: {
      participant_id: string
      username: string
    }
  }
  ```
- **Purpose**: Notifies when a participant leaves the party

### 4. Video Sync Events
- **Message Type**: `video_play`, `video_pause`, `video_seek`
- **Receive Payload**:
  ```typescript
  {
    type: "video_play" | "video_pause" | "video_seek"
    data: {
      currentTime: number
      isPlaying: boolean
      seekTime?: number // For seek events
      initiatedBy: string // User ID who triggered the action
    }
  }
  ```
- **Purpose**: Real-time video synchronization across all participants

### 5. Party State Update
- **Message Type**: `party_state_update`
- **Receive Payload**:
  ```typescript
  {
    type: "party_state_update"
    data: {
      party: {
        id: string
        status: "active" | "paused" | "ended"
        currentVideo: Video
        settings: PartySettings
        participantCount: number
      }
    }
  }
  ```
- **Purpose**: Updates party information and settings

### 6. Error Messages
- **Message Type**: `error`
- **Receive Payload**:
  ```typescript
  {
    type: "error"
    data: {
      code: string
      message: string
      details?: any
    }
  }
  ```
- **Purpose**: Error handling and user feedback

### 7. Connection Status
- **Message Type**: `connection_status`
- **Receive Payload**:
  ```typescript
  {
    type: "connection_status"
    data: {
      status: "connected" | "disconnected" | "reconnecting"
      participantCount: number
      latency?: number
    }
  }
  ```
- **Purpose**: Connection health monitoring

### 8. Typing Indicator
- **Message Type**: `typing_start`, `typing_stop`
- **Send/Receive Payload**:
  ```typescript
  {
    type: "typing_start" | "typing_stop"
    data: {
      user_id: string
      username: string
    }
    timestamp: string
  }
  ```
- **Purpose**: Show typing indicators in chat

### 9. Voice Chat Events
- **Message Type**: `voice_chat_join`, `voice_chat_leave`, `voice_chat_mute`, `voice_chat_unmute`
- **Send/Receive Payload**:
  ```typescript
  {
    type: "voice_chat_join" | "voice_chat_leave" | "voice_chat_mute" | "voice_chat_unmute"
    data: {
      user_id: string
      isMuted?: boolean // For mute/unmute events
    }
    timestamp: string
  }
  ```
- **Purpose**: Voice chat functionality management

### 10. Screen Share Events
- **Message Type**: `screen_share_start`, `screen_share_stop`
- **Send/Receive Payload**:
  ```typescript
  {
    type: "screen_share_start" | "screen_share_stop"
    data: {
      user_id: string
      stream_id?: string // For WebRTC stream identification
    }
    timestamp: string
  }
  ```
- **Purpose**: Screen sharing functionality