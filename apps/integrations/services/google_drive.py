import logging
import os
from datetime import timedelta
from typing import Callable, Dict, List, Optional, Sequence

from django.conf import settings
from django.utils import timezone
from google.auth.transport.requests import Request
from google.oauth2 import service_account
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload

from ..models import GoogleDriveFile, UserServiceConnection

logger = logging.getLogger(__name__)

CLIENT_ID_SETTING_NAMES: Sequence[str] = (
    'GOOGLE_DRIVE_CLIENT_ID',
    'GOOGLE_OAUTH2_CLIENT_ID',
)
CLIENT_SECRET_SETTING_NAMES: Sequence[str] = (
    'GOOGLE_DRIVE_CLIENT_SECRET',
    'GOOGLE_OAUTH2_CLIENT_SECRET',
)


def _first_non_empty_setting(names: Sequence[str]) -> str:
    for name in names:
        value = getattr(settings, name, '')
        if value:
            return value
    return ''


def _normalize_expiry(expiry):
    if not expiry:
        return None
    if timezone.is_naive(expiry):
        return timezone.make_aware(expiry)
    return expiry


class GoogleDriveService:
    """Service abstraction for Google Drive API integration."""

    SUPPORTED_VIDEO_TYPES = [
        'video/mp4',
        'video/quicktime',
        'video/x-msvideo',  # AVI
        'video/x-ms-wmv',   # WMV
        'video/webm',
        'video/ogg',
        'video/3gpp',
        'video/x-flv',
        'video/x-matroska',  # MKV
    ]

    SCOPES = [
        'https://www.googleapis.com/auth/drive.readonly',
        'https://www.googleapis.com/auth/drive.metadata.readonly',
        'https://www.googleapis.com/auth/drive.file',
        'https://www.googleapis.com/auth/userinfo.profile',
        'https://www.googleapis.com/auth/userinfo.email',
    ]

    WATCH_PARTY_FOLDER_NAME = 'Watch Party Videos'

    def __init__(
        self,
        user_connection: Optional[UserServiceConnection] = None,
        *,
        access_token: Optional[str] = None,
        refresh_token: Optional[str] = None,
        token_expiry=None,
        credentials: Optional[Credentials] = None,
        drive_service=None,
        on_credentials_updated: Optional[Callable[[Credentials], None]] = None,
    ) -> None:
        self.user_connection = user_connection
        self.access_token = access_token
        self.refresh_token = refresh_token
        self.token_expiry = _normalize_expiry(token_expiry)
        self.on_credentials_updated = on_credentials_updated
        self.credentials: Optional[Credentials] = credentials
        self.service = drive_service

        if self.service is None:
            self._initialize_service()

    # ------------------------------------------------------------------
    # Credential helpers
    # ------------------------------------------------------------------
    def _initialize_service(self) -> None:
        try:
            credentials = self._get_credentials()
            if not credentials:
                logger.error('Failed to initialize Google Drive credentials')
                return

            self.credentials = credentials
            self._refresh_credentials_if_needed()
            self.service = build('drive', 'v3', credentials=self.credentials)
        except Exception as exc:  # pragma: no cover - defensive logging
            logger.error('Error initializing Google Drive service: %s', exc)
            self.service = None

    def _get_credentials(self) -> Optional[Credentials]:
        if self.credentials:
            return self.credentials

        if self.user_connection:
            return self._get_user_connection_credentials()

        if self.access_token or self.refresh_token:
            return self._build_credentials_from_tokens(
                self.access_token,
                self.refresh_token,
                self.token_expiry,
            )

        return self._get_service_account_credentials()

    def _get_user_connection_credentials(self) -> Optional[Credentials]:
        if not self.user_connection or not self.user_connection.access_token:
            return None

        return self._build_credentials_from_tokens(
            self.user_connection.access_token,
            self.user_connection.refresh_token,
            self.user_connection.token_expires_at,
        )

    def _build_credentials_from_tokens(
        self,
        access_token: Optional[str],
        refresh_token: Optional[str],
        expiry,
    ) -> Optional[Credentials]:
        if not access_token and not refresh_token:
            return None

        client_id = _first_non_empty_setting(CLIENT_ID_SETTING_NAMES)
        client_secret = _first_non_empty_setting(CLIENT_SECRET_SETTING_NAMES)

        if not client_id or not client_secret:
            logger.warning('Google Drive OAuth credentials are not configured.')
            return None

        credentials = Credentials(
            token=access_token,
            refresh_token=refresh_token,
            token_uri='https://oauth2.googleapis.com/token',
            client_id=client_id,
            client_secret=client_secret,
            scopes=self.SCOPES,
        )

        normalized_expiry = _normalize_expiry(expiry)
        if normalized_expiry:
            credentials.expiry = normalized_expiry

        return credentials

    def _get_service_account_credentials(self) -> Optional[Credentials]:
        service_account_file = getattr(settings, 'GOOGLE_SERVICE_ACCOUNT_FILE', '')
        if not service_account_file or not os.path.exists(service_account_file):
            logger.warning('Service account file not found or not configured')
            return None

        try:
            return service_account.Credentials.from_service_account_file(
                service_account_file,
                scopes=self.SCOPES,
            )
        except Exception as exc:  # pragma: no cover - defensive logging
            logger.error('Error loading service account credentials: %s', exc)
            return None

    def _refresh_credentials_if_needed(self) -> None:
        if not self.credentials:
            return

        if self.credentials.expired and self.credentials.refresh_token:
            try:
                self.credentials.refresh(Request())
            except Exception as exc:  # pragma: no cover - defensive logging
                logger.error('Error refreshing Google Drive credentials: %s', exc)
                raise

        self._persist_credentials(self.credentials)

    def _persist_credentials(self, credentials: Credentials) -> None:
        if not credentials:
            return

        if self.user_connection:
            fields_to_update = ['access_token', 'updated_at']
            self.user_connection.access_token = credentials.token

            if credentials.refresh_token:
                self.user_connection.refresh_token = credentials.refresh_token
                fields_to_update.append('refresh_token')

            if getattr(credentials, 'expiry', None):
                self.user_connection.token_expires_at = _normalize_expiry(credentials.expiry)
                fields_to_update.append('token_expires_at')

            # Remove duplicates while preserving order
            unique_fields = list(dict.fromkeys(fields_to_update))
            self.user_connection.save(update_fields=unique_fields)
        elif self.on_credentials_updated:
            self.on_credentials_updated(credentials)

    def _ensure_service_initialized(self) -> None:
        if not self.service:
            raise Exception('Google Drive service not initialized')

    # ------------------------------------------------------------------
    # OAuth helpers
    # ------------------------------------------------------------------
    def get_oauth_url(self, redirect_uri: str, state: Optional[str] = None) -> str:
        client_id = _first_non_empty_setting(CLIENT_ID_SETTING_NAMES)
        if not client_id:
            raise ValueError('Google Drive client ID is not configured.')

        base_url = 'https://accounts.google.com/o/oauth2/v2/auth'
        params = {
            'client_id': client_id,
            'response_type': 'code',
            'scope': ' '.join(self.SCOPES),
            'redirect_uri': redirect_uri,
            'access_type': 'offline',
            'prompt': 'consent',
        }

        if state:
            params['state'] = state

        from urllib.parse import urlencode

        return f"{base_url}?{urlencode(params)}"

    def exchange_code_for_tokens(self, code: str, redirect_uri: str) -> Dict:
        import requests

        client_id = _first_non_empty_setting(CLIENT_ID_SETTING_NAMES)
        client_secret = _first_non_empty_setting(CLIENT_SECRET_SETTING_NAMES)

        if not client_id or not client_secret:
            raise ValueError('Google Drive OAuth credentials are not configured.')

        token_url = 'https://oauth2.googleapis.com/token'
        data = {
            'client_id': client_id,
            'client_secret': client_secret,
            'code': code,
            'grant_type': 'authorization_code',
            'redirect_uri': redirect_uri,
        }

        try:
            response = requests.post(token_url, data=data)
            response.raise_for_status()
            return response.json()
        except requests.RequestException as exc:
            logger.error('Error exchanging code for tokens: %s', exc)
            raise Exception(f'Failed to exchange code for tokens: {exc}')

    # ------------------------------------------------------------------
    # File operations
    # ------------------------------------------------------------------
    def get_user_info(self) -> Dict:
        self._ensure_service_initialized()

        try:
            credentials = self.credentials or getattr(self.service, '_http', {}).credentials
            user_service = build('oauth2', 'v2', credentials=credentials)
            return user_service.userinfo().get().execute()
        except HttpError as exc:
            logger.error('Error getting user info: %s', exc)
            raise Exception(f'Failed to get user info: {exc}')

    def list_files(self, page_size: int = 50, page_token: str = None, query: str = None) -> Dict:
        self._ensure_service_initialized()

        try:
            if not query:
                video_queries = [f"mimeType='{mime}'" for mime in self.SUPPORTED_VIDEO_TYPES]
                query = f"({' or '.join(video_queries)}) and trashed=false"

            request_params = {
                'pageSize': min(page_size, 1000),
                'fields': 'nextPageToken, files(id, name, mimeType, size, createdTime, modifiedTime, parents, webViewLink, thumbnailLink, videoMediaMetadata)',
                'q': query,
                'orderBy': 'modifiedTime desc',
            }

            if page_token:
                request_params['pageToken'] = page_token

            result = self.service.files().list(**request_params).execute()
            files_data = result.get('files', [])
            self._sync_files_to_database(files_data)

            return {
                'files': files_data,
                'next_page_token': result.get('nextPageToken'),
                'total_count': len(files_data),
            }
        except HttpError as exc:
            logger.error('Error listing files: %s', exc)
            raise Exception(f'Failed to list files: {exc}')

    def list_videos(self, folder_id: Optional[str] = None, page_size: int = 50) -> List[Dict]:
        self._ensure_service_initialized()

        video_queries = [f"mimeType='{mime}'" for mime in self.SUPPORTED_VIDEO_TYPES]
        conditions = ["trashed=false", f"({' or '.join(video_queries)})"]
        if folder_id:
            conditions.append(f"'{folder_id}' in parents")

        query = ' and '.join(conditions)
        result = self.list_files(page_size=page_size, query=query)
        files_data = result.get('files', [])

        return [self._format_file_info(file_data) for file_data in files_data]

    def get_file_info(self, file_id: str) -> Dict:
        self._ensure_service_initialized()

        try:
            file_info = self.service.files().get(
                fileId=file_id,
                fields='id, name, mimeType, size, createdTime, modifiedTime, webViewLink, thumbnailLink, videoMediaMetadata, parents',
            ).execute()

            self._sync_single_file_to_database(file_info)
            return self._format_file_info(file_info)
        except HttpError as exc:
            logger.error('Error getting file info for %s: %s', file_id, exc)
            raise Exception(f'Failed to get file info: {exc}')

    def get_streaming_url(self, file_id: str, force_refresh: bool = False) -> str:
        self._ensure_service_initialized()

        try:
            if not force_refresh and self.user_connection:
                drive_file = GoogleDriveFile.objects.filter(
                    connection=self.user_connection,
                    file_id=file_id,
                ).first()

                if drive_file and drive_file.is_stream_url_valid():
                    return drive_file.stream_url

            file_info = self.get_file_info(file_id)
            stream_url = self.get_download_url(file_id)

            if self.user_connection:
                drive_file, _ = GoogleDriveFile.objects.get_or_create(
                    connection=self.user_connection,
                    file_id=file_id,
                    defaults={'file_name': file_info.get('name', '')},
                )
                drive_file.stream_url = stream_url
                drive_file.stream_url_expires_at = timezone.now() + timedelta(hours=1)
                drive_file.file_name = file_info.get('name', '')
                drive_file.mime_type = file_info.get('mime_type', '')
                drive_file.save()

            return stream_url or file_info.get('web_view_link', '')
        except HttpError as exc:
            logger.error('Error getting streaming URL for %s: %s', file_id, exc)
            raise Exception(f'Failed to get streaming URL: {exc}')

    def generate_streaming_url(self, file_id: str, force_refresh: bool = False) -> str:
        return self.get_streaming_url(file_id, force_refresh=force_refresh)

    def get_download_url(self, file_id: str) -> str:
        if not file_id:
            return ''
        return f'https://www.googleapis.com/drive/v3/files/{file_id}?alt=media'

    def upload_file(self, file_path: str, name: Optional[str] = None, folder_id: Optional[str] = None) -> Dict:
        self._ensure_service_initialized()

        metadata = {'name': name or os.path.basename(file_path)}
        if folder_id:
            metadata['parents'] = [folder_id]

        media = MediaFileUpload(file_path, resumable=True)

        try:
            created = self.service.files().create(
                body=metadata,
                media_body=media,
                fields='id, name, mimeType, size',
            ).execute()

            self._sync_single_file_to_database(created)

            return {
                'id': created.get('id'),
                'name': created.get('name'),
                'mime_type': created.get('mimeType'),
                'size': int(created.get('size')) if created.get('size') else None,
            }
        except HttpError as exc:
            logger.error('Error uploading file to Google Drive: %s', exc)
            raise Exception(f'Failed to upload file: {exc}')

    def delete_file(self, file_id: str) -> bool:
        self._ensure_service_initialized()

        try:
            self.service.files().delete(fileId=file_id).execute()
            if self.user_connection:
                GoogleDriveFile.objects.filter(
                    connection=self.user_connection,
                    file_id=file_id,
                ).delete()
            return True
        except HttpError as exc:
            logger.error('Error deleting file %s: %s', file_id, exc)
            return False

    def get_or_create_watch_party_folder(self, folder_name: str = None) -> Optional[str]:
        self._ensure_service_initialized()

        folder_name = folder_name or self.WATCH_PARTY_FOLDER_NAME
        query = (
            "mimeType='application/vnd.google-apps.folder' "
            f"and name='{folder_name}' and 'root' in parents and trashed=false"
        )

        try:
            result = self.service.files().list(
                q=query,
                spaces='drive',
                fields='files(id, name)',
                pageSize=1,
            ).execute()

            files = result.get('files', [])
            if files:
                return files[0]['id']

            metadata = {
                'name': folder_name,
                'mimeType': 'application/vnd.google-apps.folder',
            }

            created = self.service.files().create(body=metadata, fields='id').execute()
            return created.get('id')
        except HttpError as exc:
            logger.error('Error ensuring Watch Party folder: %s', exc)
            raise Exception(f'Failed to ensure Watch Party folder: {exc}')

    def search_files(self, query: str, file_type: str = 'video') -> List[Dict]:
        self._ensure_service_initialized()

        try:
            search_query = f"name contains '{query}' and trashed=false"

            if file_type == 'video':
                video_queries = [f"mimeType='{mime}'" for mime in self.SUPPORTED_VIDEO_TYPES]
                search_query += f" and ({' or '.join(video_queries)})"

            result = self.service.files().list(
                q=search_query,
                pageSize=50,
                fields='files(id, name, mimeType, size, thumbnailLink, videoMediaMetadata)',
            ).execute()

            files = result.get('files', [])
            self._sync_files_to_database(files)

            return [self._format_file_info(file_data) for file_data in files]
        except HttpError as exc:
            logger.error('Error searching files: %s', exc)
            raise Exception(f'Failed to search files: {exc}')

    def check_file_permissions(self, file_id: str) -> Dict:
        self._ensure_service_initialized()

        try:
            permissions = self.service.permissions().list(fileId=file_id).execute()
            file_info = self.service.files().get(
                fileId=file_id,
                fields='id, name, shared, webViewLink',
            ).execute()

            return {
                'file_info': file_info,
                'permissions': permissions.get('permissions', []),
                'is_public': any(p.get('type') == 'anyone' for p in permissions.get('permissions', [])),
                'can_stream': True,
            }
        except HttpError as exc:
            logger.error('Error checking file permissions: %s', exc)
            return {
                'file_info': {},
                'permissions': [],
                'is_public': False,
                'can_stream': False,
            }

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------
    def _format_file_info(self, file_data: Dict) -> Dict:
        video_metadata = file_data.get('videoMediaMetadata') or {}
        duration_ms = video_metadata.get('durationMillis')
        duration_seconds = int(int(duration_ms) / 1000) if duration_ms else None

        resolution = None
        if video_metadata.get('width') and video_metadata.get('height'):
            resolution = f"{video_metadata['width']}x{video_metadata['height']}"

        size = file_data.get('size')
        size_value = int(size) if size is not None else None

        return {
            'id': file_data.get('id'),
            'name': file_data.get('name'),
            'mime_type': file_data.get('mimeType'),
            'size': size_value,
            'created_time': file_data.get('createdTime'),
            'modified_time': file_data.get('modifiedTime'),
            'web_view_link': file_data.get('webViewLink'),
            'thumbnail_url': file_data.get('thumbnailLink'),
            'video_metadata': video_metadata,
            'duration': duration_seconds,
            'resolution': resolution,
            'download_url': self.get_download_url(file_data.get('id')) if file_data.get('id') else None,
        }

    def _sync_files_to_database(self, files_data: List[Dict]) -> None:
        if not self.user_connection:
            return

        for file_data in files_data:
            self._sync_single_file_to_database(file_data)

    def _sync_single_file_to_database(self, file_data: Dict) -> Optional[GoogleDriveFile]:
        if not self.user_connection:
            return None

        try:
            file_obj, created = GoogleDriveFile.objects.get_or_create(
                connection=self.user_connection,
                file_id=file_data['id'],
                defaults={
                    'file_name': file_data.get('name', ''),
                    'mime_type': file_data.get('mimeType', ''),
                },
            )

            file_obj.file_name = file_data.get('name', '')
            file_obj.mime_type = file_data.get('mimeType', '')
            file_obj.file_size = int(file_data.get('size', 0)) if file_data.get('size') else None
            file_obj.is_video = file_data.get('mimeType') in self.SUPPORTED_VIDEO_TYPES
            file_obj.thumbnail_url = file_data.get('thumbnailLink', '')

            video_metadata = file_data.get('videoMediaMetadata', {})
            if video_metadata:
                duration_ms = video_metadata.get('durationMillis')
                if duration_ms:
                    file_obj.duration = timedelta(milliseconds=int(duration_ms))
                width = video_metadata.get('width')
                height = video_metadata.get('height')
                if width and height:
                    file_obj.resolution = f"{width}x{height}"

            file_obj.drive_metadata = file_data
            file_obj.can_stream = file_obj.is_video
            file_obj.save()

            if created:
                logger.info('Created new GoogleDriveFile: %s', file_obj.file_name)

            return file_obj
        except Exception as exc:  # pragma: no cover - defensive logging
            logger.error('Error syncing file to database: %s', exc)
            return None


def get_drive_service_for_user(user):
    profile = getattr(user, 'profile', None)
    if profile is None or not profile.google_drive_connected:
        raise ValueError('User does not have an active Google Drive connection.')

    if not profile.google_drive_token and not profile.google_drive_refresh_token:
        raise ValueError('User is missing Google Drive OAuth credentials.')

    def _update_profile_tokens(credentials: Credentials) -> None:
        update_fields: List[str] = ['google_drive_token', 'updated_at']
        profile.google_drive_token = credentials.token or ''

        refresh_token = getattr(credentials, 'refresh_token', None)
        if refresh_token:
            profile.google_drive_refresh_token = refresh_token
            update_fields.append('google_drive_refresh_token')

        expiry = _normalize_expiry(getattr(credentials, 'expiry', None))
        profile.google_drive_token_expires_at = expiry
        update_fields.append('google_drive_token_expires_at')

        profile.save(update_fields=list(dict.fromkeys(update_fields)))

    return GoogleDriveService(
        access_token=profile.google_drive_token or None,
        refresh_token=profile.google_drive_refresh_token or None,
        token_expiry=profile.google_drive_token_expires_at,
        on_credentials_updated=_update_profile_tokens,
    )


def get_drive_service(user):
    """Backward-compatible alias for get_drive_service_for_user."""
    return get_drive_service_for_user(user)


__all__ = ['GoogleDriveService', 'get_drive_service', 'get_drive_service_for_user']
