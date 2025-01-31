#receiptreader/apps.py
from django.apps import AppConfig  # type: ignore

class ReceiptreaderConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'receiptreader'

    def ready(self):
        import receiptreader.signals