#receiptreader/serializers.py
from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import Receipt, Product
from django.urls import reverse

User = get_user_model()


class ProductSerializer(serializers.ModelSerializer):
    class Meta:
        model = Product
        fields = ['id', 'name', 'price', 'category', 'receipt', 'user']
        read_only_fields = ['receipt', 'user']

class ReceiptSerializer(serializers.ModelSerializer):
    products = ProductSerializer(many=True, read_only=True)

    class Meta:
        model = Receipt
        fields = ['id', 'user', 'title', 'text', 'processed_image', 'original_image', 'address', 'date_of_shopping', 'total', 'created_at', 'products']
        read_only_fields = ['user', 'created_at']

    def to_representation(self, instance):
        rep = super().to_representation(instance)
        request = self.context.get('request', None)

        def build_secure_url(url):
            return url.replace('http://', 'https://') if url.startswith('http://') else url

        # Processed Image URL
        if instance.processed_image and hasattr(instance.processed_image, 'url'):
            processed_filename = instance.processed_image.name.split('/')[-1]
            url = reverse('receipt-image', kwargs={
                    'pk': instance.pk,
                    'image_type': 'processed_image',
                    'filename': processed_filename
                })
            processed_image_url = build_secure_url(request.build_absolute_uri(url))
            rep['processed_image'] = processed_image_url
        else:
            rep['processed_image'] = None

        # Original Image URL
        if instance.original_image and hasattr(instance.original_image, 'url'):
            original_filename = instance.original_image.name.split('/')[-1]
            url = reverse('receipt-image', kwargs={
                    'pk': instance.pk,
                    'image_type': 'original_image',
                    'filename': original_filename
                })
            original_image_url = build_secure_url(request.build_absolute_uri(url))
            rep['original_image'] = original_image_url
        else:
            rep['original_image'] = None

        return rep

class UpdateReceiptSerializer(serializers.ModelSerializer):
    class Meta:
        model = Receipt
        fields = ['title', 'text', 'processed_image', 'original_image', 'address', 'date_of_shopping', 'total']


class UserSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    receipts = ReceiptSerializer(many=True, read_only=True)

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'receipts','password']

    @staticmethod
    def validate_email(value):
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("This email is already registered.")
        return value

    def create(self, validated_data):
        user = User(
            email=validated_data['email'],
            username=validated_data['username']
        )
        user.set_password(validated_data['password'])
        user.save()
        return user


class UserListSerializer(serializers.ModelSerializer):
    receipt_ids = serializers.PrimaryKeyRelatedField(many=True, read_only=True, source='receipts')

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'receipt_ids']


class ChangePasswordSerializer(serializers.Serializer):
    current_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(write_only=True)

    def validate(self, data):
        user = self.context['request'].user
        if not user.check_password(data.get("current_password")):
            raise serializers.ValidationError("Current password is incorrect.")
        if data.get("current_password") == data.get("new_password"):
            raise serializers.ValidationError("New password should be different from the current password.")
        return data