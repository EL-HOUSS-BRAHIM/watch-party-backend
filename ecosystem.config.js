module.exports = {
  apps: [
    {
      name: 'watchparty-django',
      script: 'gunicorn',
      args: '--workers 4 --worker-class gevent --worker-connections 1000 --bind 127.0.0.1:8000 --timeout 120 --keep-alive 5 --preload --access-logfile /var/log/watchparty/gunicorn_access.log --error-logfile /var/log/watchparty/gunicorn_error.log config.wsgi:application',
      cwd: '/workspaces/watch-party-backend',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false,
      max_memory_restart: '1G',
      env: {
        NODE_ENV: 'production',
        DJANGO_SETTINGS_MODULE: 'config.settings.production',
        PYTHONPATH: '/workspaces/watch-party-backend'
      },
      log_file: '/var/log/watchparty/pm2_django.log',
      out_file: '/var/log/watchparty/pm2_django_out.log',
      error_file: '/var/log/watchparty/pm2_django_error.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
    },
    {
      name: 'watchparty-daphne',
      script: 'daphne',
      args: '-b 127.0.0.1 -p 8002 --access-log /var/log/watchparty/daphne_access.log config.asgi:application',
      cwd: '/workspaces/watch-party-backend',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false,
      max_memory_restart: '512M',
      env: {
        NODE_ENV: 'production',
        DJANGO_SETTINGS_MODULE: 'config.settings.production',
        PYTHONPATH: '/workspaces/watch-party-backend'
      },
      log_file: '/var/log/watchparty/pm2_daphne.log',
      out_file: '/var/log/watchparty/pm2_daphne_out.log',
      error_file: '/var/log/watchparty/pm2_daphne_error.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
    },
    {
      name: 'watchparty-celery-worker',
      script: 'celery',
      args: '-A config worker -l info --concurrency=2',
      cwd: '/workspaces/watch-party-backend',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false,
      max_memory_restart: '512M',
      env: {
        NODE_ENV: 'production',
        DJANGO_SETTINGS_MODULE: 'config.settings.production',
        PYTHONPATH: '/workspaces/watch-party-backend'
      },
      log_file: '/var/log/watchparty/pm2_celery_worker.log',
      out_file: '/var/log/watchparty/pm2_celery_worker_out.log',
      error_file: '/var/log/watchparty/pm2_celery_worker_error.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
    },
    {
      name: 'watchparty-celery-beat',
      script: 'celery',
      args: '-A config beat -l info --scheduler django_celery_beat.schedulers:DatabaseScheduler',
      cwd: '/workspaces/watch-party-backend',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false,
      max_memory_restart: '256M',
      env: {
        NODE_ENV: 'production',
        DJANGO_SETTINGS_MODULE: 'config.settings.production',
        PYTHONPATH: '/workspaces/watch-party-backend'
      },
      log_file: '/var/log/watchparty/pm2_celery_beat.log',
      out_file: '/var/log/watchparty/pm2_celery_beat_out.log',
      error_file: '/var/log/watchparty/pm2_celery_beat_error.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
    }
  ]
};