# Django Watch Party Backend - Issues Fix TODO

**Total Issues: 163 (1 Error + 162 Warnings)**  
**Priority: High → Medium → Low**

## 🚨 CRITICAL ERRORS (1)

### E001: Schema Generation Error
- **File**: `apps/notifications/serializers.py`
- **Issue**: Field name `timezone` is not valid for model `NotificationPreferences`
- **Fix**: Add `@extend_schema_field` decorator or check model field definition

## 🔧 HIGH PRIORITY FIXES (Security + Core Issues)

### Security Configuration (2 issues)
1. **SSL Redirect** (security.W008)
   - **Files**: `watchparty/settings/base.py`, `watchparty/settings/development.py`
   - **Fix**: Set `SECURE_SSL_REDIRECT = True` for production environments
   
2. **Session Cookie Security** (security.W012)
   - **Files**: `watchparty/settings/base.py`, `watchparty/settings/development.py`
   - **Fix**: Set `SESSION_COOKIE_SECURE = True` for production environments

### Core Model Issues (15 issues)
3. **Username Field Resolution** 
   - **Files**: Multiple serializers referencing `username` field
   - **Issue**: User model has `username = None`, but serializers still reference it
   - **Affected Files**:
     - `apps/events/serializers.py` (EventOrganizerSerializer)
     - `apps/interactive/serializers.py` (InteractiveUserBasicSerializer)
   - **Fix**: Replace `username` with `email` or `get_full_name()` method

## 🔄 MEDIUM PRIORITY FIXES (API Schema Issues)

### Missing Serializer Classes (65 issues - W002)
**Strategy**: Convert function-based views to class-based views or add serializer classes

#### Admin Panel Views (13 views)
- **File**: `apps/admin_panel/views.py`
- **Functions to fix**:
  - `admin_analytics_overview` → Create `AdminAnalyticsOverviewSerializer`
  - `admin_broadcast_message` → Create `AdminBroadcastMessageSerializer`
  - `admin_bulk_user_actions` → Create `AdminBulkUserActionsSerializer`
  - `admin_content_moderation` → Create `AdminContentModerationSerializer`
  - `admin_content_reports` → Create `AdminContentReportsSerializer`
  - `admin_delete_party` → Create `AdminDeletePartySerializer`
  - `admin_export_users` → Create `AdminExportUsersSerializer`
  - `admin_parties_list` → Create `AdminPartiesListSerializer`
  - `admin_send_notification` → Create `AdminSendNotificationSerializer`
  - `admin_suspend_user` → Create `AdminSuspendUserSerializer`
  - `admin_system_health` → Create `AdminSystemHealthSerializer`
  - `admin_unsuspend_user` → Create `AdminUnsuspendUserSerializer`
  - `admin_users_list` → Create `AdminUsersListSerializer`

#### Analytics Views (23 views)
- **Files**: 
  - `apps/analytics/views.py` (4 views)
  - `apps/analytics/advanced_views.py` (4 views)
  - `apps/analytics/dashboard_views.py` (6 views)
  - `apps/analytics/views_advanced.py` (9 views)
- **Solution**: Create corresponding serializer classes for each view

#### Authentication Views (7 views)
- **File**: `apps/authentication/views.py`
- **Functions**: `ForgotPasswordView`, `LogoutView`, `PasswordChangeView`, `RegisterView`, `ResendVerificationView`, `ResetPasswordView`, `VerifyEmailView`

#### Other Apps (22 views)
- **Billing**: 3 views (`SubscriptionCancelView`, `SubscriptionResumeView`, `stripe_webhook`)
- **Chat**: 3 views (`get_active_users`, `join_chat_room`, `leave_chat_room`)
- **Events**: 4 views (`join_event`, `leave_event`, `respond_to_invitation`, `rsvp_event`)
- **Integrations**: 12 views (various OAuth and integration endpoints)

### Failed Queryset Resolution (12 issues - W001)
**Issue**: Views accessing `self.pk` or user objects during schema generation

#### Event Views
- **File**: `apps/events/views.py`
- **Views**: `EventAttendeesView`, `EventInvitationListCreateView`, `EventListCreateView`, `EventSearchView`, `MyAttendingEventsView`, `MyEventsView`
- **Fix**: Add `getattr(self, "swagger_fake_view", False)` checks in `get_queryset()`

#### Moderation Views
- **File**: `apps/moderation/views.py`
- **Views**: `ReportActionListView`
- **Fix**: Add swagger fake view detection

### Type Hint Resolution Issues (83 issues - W001)

#### SerializerMethodField Type Hints (45 issues)
**Pattern**: Methods missing `@extend_schema_field` decorator
- **Files**: `apps/billing/serializers.py`, `apps/chat/serializers.py`, `apps/events/serializers.py`
- **Methods**: `is_active`, `is_visible`, `reply_count`, `attendee_count`, `is_full`, `is_ongoing`, `is_past`, `is_upcoming`, `active_user_count`
- **Fix**: Add `@extend_schema_field(OpenApiTypes.BOOL)` or appropriate type

#### Custom Field Resolution (15 issues)
**Issue**: Model properties not recognized as fields
- **Files**: `apps/notifications/serializers.py`
- **Fields**: `is_expired`, `is_urgent`, `time_since_created` on Notification model
- **Fix**: Add `@property` decorators or `@extend_schema_field` in serializers

#### OpenApiExample Resolution (23 issues)
**Issue**: Complex example objects not resolved properly
- **Files**: `apps/integrations/views.py`, `apps/mobile/views.py`
- **Fix**: Simplify examples or use direct serializer classes

## 📝 IMPLEMENTATION PLAN

### Phase 1: Critical & Security (Priority 1)
1. **Fix timezone field error** (30 min)
2. **Update security settings** (15 min)
3. **Fix username field references** (45 min)

### Phase 2: Core API Schema (Priority 2)
1. **Add missing serializer classes** (4-6 hours)
   - Create base serializers for common patterns
   - Convert function-based views to class-based views
   - Add proper serializer_class attributes

2. **Fix queryset resolution** (1 hour)
   - Add swagger fake view detection
   - Implement proper fallback querysets

### Phase 3: Type Annotations (Priority 3)
1. **Add SerializerMethodField type hints** (2-3 hours)
   - Systematically add `@extend_schema_field` decorators
   - Use appropriate OpenApiTypes

2. **Fix custom field resolution** (1 hour)
   - Add property decorators to models
   - Use `@extend_schema_field` in serializers

## 🛠️ BEST PRACTICES TO FOLLOW

### 1. Serializer Patterns
```python
# For function-based views
@extend_schema(
    request=RequestSerializer,
    responses={200: ResponseSerializer}
)
@api_view(['POST'])
def my_view(request):
    pass

# For method fields
@extend_schema_field(OpenApiTypes.BOOL)
def get_is_active(self, obj):
    return obj.is_active
```

### 2. View Patterns
```python
class MyAPIView(GenericAPIView):
    serializer_class = MySerializer
    
    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return Model.objects.none()
        return super().get_queryset()
```

### 3. Security Settings
```python
# Production settings
SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True
```

## 🎯 QUICK WINS (Can be automated)

### Script-Friendly Fixes
1. **Add type hints to serializer methods** - Can use regex to find and replace
2. **Add swagger fake view checks** - Standard pattern across views
3. **Create basic serializer templates** - Generate from existing patterns

### Manual Review Required
1. **OpenApiExample objects** - Need domain knowledge
2. **Complex queryset logic** - Requires understanding business logic
3. **Security configuration** - Environment-specific decisions

## 📊 IMPACT ASSESSMENT

### High Impact (Fixes schema generation)
- Timezone field error fix
- Missing serializer classes
- Username field references

### Medium Impact (Improves documentation)
- Type hint additions
- Custom field resolution
- Example object fixes

### Low Impact (Security hardening)
- SSL redirect settings
- Session cookie security

## ⚡ AUTOMATION OPPORTUNITIES

### Batch Operations
1. **Find all SerializerMethodField without type hints**
   ```bash
   grep -r "SerializerMethodField" --include="*.py" | grep -v "@extend_schema_field"
   ```

2. **Find all function-based API views**
   ```bash
   grep -r "@api_view" --include="*.py"
   ```

3. **Find all custom field references**
   ```bash
   grep -r "ReadOnlyField\|SerializerMethodField" --include="*.py"
   ```

### Code Generation Templates
- Serializer class templates for common CRUD operations
- Standard error response serializers
- Base view classes with proper schema configuration

---

**Estimated Total Time**: 8-12 hours
**Recommended Approach**: Fix in phases, test schema generation after each phase
**Success Metric**: Zero drf-spectacular warnings and errors
