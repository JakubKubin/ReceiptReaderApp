# receiptreader/utils.py

import re
from decimal import Decimal, InvalidOperation

import logging

logger = logging.getLogger(__name__)

def get_client_ip(request):
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        ip = x_forwarded_for.split(',')[0]
    else:
        ip = request.META.get('REMOTE_ADDR')
    return ip


def parse_receipt_text(receipt_text):
    products = []
    lines = receipt_text.strip().split("\n")

    for line in lines:
        try:
            category_match = re.search(r"##(.+?)##", line)
            category = category_match.group(1).strip() if category_match else "Uncategorized"
            if category_match:
                line = line.replace(category_match.group(0), "").strip()

            price_match = re.search(r"&&([\d.,]+)&&", line)
            price = Decimal(price_match.group(1).replace(",", ".")) if price_match else Decimal(0.00)
            if price_match:
                line = line.replace(price_match.group(0), "").strip()

            name = line.strip()
            if not name:
                name = "Unnamed Product"

            if price_match and (price < 0 or price > 200000):
                raise ValueError(f"Price {price} is invalid.")

            products.append({
                "name": name,
                "price": price,
                "category": category
            })

        except (InvalidOperation, ValueError) as e:
            logger.warning(f"Invalid line skipped: {line}. Error: {e}")
            continue

    return products