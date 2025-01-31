#receiptreader/models.py
import uuid
from django.db import models
from django.contrib.auth.models import BaseUserManager, AbstractBaseUser
from django.utils import timezone
import pytz
from decimal import Decimal


class MyUserManager(BaseUserManager):
    def create_user(self, email, username, password=None):
        if not email:
            raise ValueError("Users must have an email address")
        if not username:
            raise ValueError("Users must have a username")
        user = self.model(
            email=self.normalize_email(email),
            username = username,
            password = password
        )

        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, username, password=None):
        user = self.create_user(
            email,
            username = username,
            password = password,
        )
        user.is_admin = True
        user.save(using=self._db)
        return user


class User(AbstractBaseUser):
    email = models.EmailField(
        verbose_name="email address",
        max_length=255,
        unique=True,
    )
    username = models.CharField(max_length=30, unique=False, default='default_username')
    is_active = models.BooleanField(default=True)
    is_admin = models.BooleanField(default=False)

    objects = MyUserManager()

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['username']

    def __str__(self):
        return self.email

    @property
    def is_staff(self):
        return self.is_admin


def default_receipt_title():
    warsaw_timezone = pytz.timezone("Europe/Warsaw")
    current_time = timezone.now().astimezone(warsaw_timezone)
    return 'Receipt ' + current_time.strftime(r'%Y-%m-%d %H:%M')


def receipt_upload_path(instance, filename):
    return f'receipts/{instance.unique_id}/{filename}'


class Receipt(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='receipts')
    unique_id = models.UUIDField(default=uuid.uuid4, editable=False, unique=True)
    title = models.CharField(max_length=255, default=default_receipt_title)
    text = models.TextField(null=True, blank=True, default='')
    original_image = models.ImageField(upload_to=receipt_upload_path, null=True, blank=True)
    processed_image = models.ImageField(upload_to=receipt_upload_path, null=True, blank=True)
    address = models.TextField(null=True, blank=True)
    date_of_shopping = models.DateTimeField(default=timezone.now)
    total = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal('0.00'))
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.title


class Product(models.Model):
    id = models.AutoField(primary_key=True)
    name = models.CharField(max_length=255, null=True, blank=True)
    price = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True, default=Decimal('0.00'))
    category = models.CharField(max_length=255, null=True, blank=True)
    receipt = models.ForeignKey('Receipt', on_delete=models.CASCADE, related_name='products')
    user = models.ForeignKey('User', on_delete=models.CASCADE, related_name='products')

    def __str__(self):
        return self.name if self.name else "Unnamed Product"


class UserSummary(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='summary')
    total_spent = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal('0.00'))
    category_avg = models.JSONField(default=dict)
    category_summary = models.JSONField(default=dict)
