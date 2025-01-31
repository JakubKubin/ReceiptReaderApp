# receiptreader/signals.py
from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from .models import Product, UserSummary
from django.db.models import Avg, Sum
from decimal import Decimal

@receiver(post_save, sender=Product)
@receiver(post_delete, sender=Product)
def update_user_summary(sender, instance, **kwargs):
    user = instance.user

    total_spent = Product.objects.filter(user=user).aggregate(total=Sum('price'))['total'] or 0.00

    category_data = Product.objects.filter(user=user).values('category').annotate(
        total_price=Sum('price'),
        avg_price=Avg('price')
    )
    category_avg = {data['category']: round(float(data['avg_price']), 2) for data in category_data}
    category_summary = {data['category']: float(data['total_price']) for data in category_data}

    UserSummary.objects.update_or_create(
        user=user,
        defaults={
            'total_spent': float(total_spent),
            'category_avg': category_avg,
            'category_summary': category_summary
        }
    )
