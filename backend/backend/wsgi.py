#backend/wsgi.py
import os

from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')

django_app = get_wsgi_application()

def https_app(environ, start_response):
    environ["wsgi.url_scheme"] = "http"
    return django_app(environ, start_response)


application = https_app
