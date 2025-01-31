# receiptreader/services.py
import os
from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
from rest_framework.exceptions import ValidationError
import cv2
from .utils import parse_receipt_text
from .models import Product
from preprocessing import preprocess
from imagemaneger import image_to_text
import logging

logger = logging.getLogger(__name__)


def process_receipt_image(instance):
    image_path = instance.original_image.path
    image_np = cv2.imread(image_path)
    if image_np is None:
        raise ValidationError("Failed to read image")

    processed_image_np = preprocess(image_np)
    success, encoded_image = cv2.imencode('.png', processed_image_np)
    if not success:
        raise ValidationError("Failed to encode the processed image")

    processed_image_text = image_to_text(processed_image_np, 'pol')
    processed_image_file = ContentFile(encoded_image.tobytes())

    return processed_image_file, processed_image_text

def save_receipt_text(instance):
    directory = os.path.dirname(instance.original_image.path)
    text_file_path = os.path.join(directory, 'receipt_text.txt')
    with default_storage.open(text_file_path, 'wb') as text_file:
        text_file.write(instance.text.encode('utf-8'))


def extract_text_from_image(image_path):
    image_np = cv2.imread(image_path)
    if image_np is None:
        raise Exception("Failed to read image")

    text_image = image_to_text(image_np, 'pol')
    return text_image


def save_products(instance):
    try:
        products_data = parse_receipt_text(instance.text)
        if not products_data:
            logger.warning(f"No products found in receipt text: {instance.text}")

        instance.products.all().delete()

        for product_data in products_data:
            Product.objects.create(
                name=product_data['name'],
                price=product_data['price'],
                category=product_data['category'],
                receipt=instance,
                user=instance.user
            )
        logger.info(f"Products saved successfully for receipt {instance.pk}")
    except Exception as e:
        logger.error(f"Error saving products for receipt {instance.pk}: {str(e)}", exc_info=True)
        raise ValidationError("Error saving products.")