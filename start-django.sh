cd /opt/watch-party-backend
source venv/bin/activate
set -a && source .env && set +a
exec gunicorn --workers 2 --worker-class gevent --worker-connections 100 --bind 127.0.0.1:8000 --timeout 120 --keep-alive 5 --preload --access-logfile /var/log/watchparty/gunicorn_access.log --error-logfile /var/log/watchparty/gunicorn_error.log config.wsgi:application
