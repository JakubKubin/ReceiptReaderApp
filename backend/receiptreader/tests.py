# receiptreader/tests.py
from django.test import TestCase
from django.urls import reverse
from django.utils import timezone
from decimal import Decimal
from rest_framework import status
from rest_framework.test import APIClient

from .utils import parse_receipt_text
from .models import User, Receipt, Product, UserSummary


class UserModelTest(TestCase):

    def test_create_user(self):
        user = User.objects.create_user(email="testuser@example.com", username="testuser", password="testpassword") # type: ignore
        self.assertEqual(user.email, "testuser@example.com")
        self.assertEqual(user.username, "testuser")
        self.assertTrue(user.check_password("testpassword"))
        self.assertFalse(user.is_admin)

    def test_create_superuser(self):
        user = User.objects.create_superuser(email="admin@example.com", username="admin", password="adminpassword") # type: ignore
        self.assertEqual(user.email, "admin@example.com")
        self.assertTrue(user.is_admin)
        self.assertTrue(user.is_staff)


class ReceiptModelTest(TestCase):

    def setUp(self):
        self.user = User.objects.create_user(email="testuser@example.com", username="testuser", password="testpassword") # type: ignore

    def test_create_receipt(self):
        receipt = Receipt.objects.create(
            user=self.user,
            title="Test Receipt",
            text="Sample text content",
            address="123 Test Street",
            date_of_shopping=timezone.now(),
            total=Decimal("19.99"),
        )
        self.assertEqual(receipt.title, "Test Receipt")
        self.assertEqual(receipt.user, self.user)
        self.assertEqual(receipt.text, "Sample text content")
        self.assertEqual(receipt.address, "123 Test Street")
        self.assertEqual(receipt.total, Decimal("19.99"))

    def test_receipt_default_title(self):
        receipt = Receipt.objects.create(user=self.user)
        self.assertTrue(receipt.title.startswith("Receipt "))
        self.assertEqual(receipt.user, self.user)

    def test_receipt_relationship_with_products(self):
        receipt = Receipt.objects.create(user=self.user, title="Test Receipt")
        Product.objects.create(name="Test Product 1", price=Decimal("10.00"), category="Category A", receipt=receipt, user = self.user)
        Product.objects.create(name="Test Product 2", price=Decimal("20.00"), category="Category B", receipt=receipt, user = self.user)

        self.assertEqual(receipt.products.count(), 2) # type: ignore
        self.assertEqual(receipt.products.first().name, "Test Product 1") # type: ignore
        self.assertEqual(receipt.products.last().price, Decimal("20.00")) # type: ignore


class ProductModelTest(TestCase):

    def setUp(self):
        self.user = User.objects.create_user(email="testuser@example.com", username="testuser", password="testpassword") # type: ignore
        self.receipt = Receipt.objects.create(user=self.user, title="Test Receipt")

    def test_create_product_with_user(self):
        product = Product.objects.create(
            name="Test Product",
            price=Decimal("15.99"),
            category="Groceries",
            receipt=self.receipt,
            user=self.user
        )
        self.assertEqual(product.name, "Test Product")
        self.assertEqual(product.price, Decimal("15.99"))
        self.assertEqual(product.category, "Groceries")
        self.assertEqual(product.receipt, self.receipt)
        self.assertEqual(product.user, self.user)

    def test_product_default_values(self):
        product = Product.objects.create(receipt=self.receipt, user=self.user)
        self.assertIsNone(product.name)
        self.assertEqual(product.price, Decimal("0.00"))
        self.assertIsNone(product.category)
        self.assertEqual(product.receipt, self.receipt)

    def test_product_string_representation(self):
        product = Product.objects.create(name="Test Product", receipt=self.receipt, user=self.user)
        self.assertEqual(str(product), "Test Product")

        unnamed_product = Product.objects.create(receipt=self.receipt, user=self.user)
        self.assertEqual(str(unnamed_product), "Unnamed Product")


class UserSummaryTestCase(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="testuser@example.com", username="testuser", password="testpassword") #type: ignore
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

        self.receipt = Receipt.objects.create(user=self.user, title="Test Receipt", total=Decimal("0.00"))

        self.product1 = Product.objects.create(name="Product 1", price=Decimal("10.00"), category="Groceries", receipt=self.receipt, user=self.user)
        self.product2 = Product.objects.create(name="Product 2", price=Decimal("20.00"), category="Groceries", receipt=self.receipt, user=self.user)
        self.product3 = Product.objects.create(name="Product 3", price=Decimal("50.00"), category="Electronics", receipt=self.receipt, user=self.user)

    def test_summary_creation(self):
        summary = UserSummary.objects.get(user=self.user)
        self.assertEqual(summary.total_spent, Decimal("80.00"))
        self.assertEqual(summary.category_avg["Groceries"], Decimal("15.00"))
        self.assertEqual(summary.category_avg["Electronics"], Decimal("50.00"))
        self.assertEqual(summary.category_summary["Groceries"], Decimal("30.00"))
        self.assertEqual(summary.category_summary["Electronics"], Decimal("50.00"))

    def test_summary_update_on_product_addition(self):
        Product.objects.create(name="Product 4", price=Decimal("40.00"), category="Groceries", receipt=self.receipt, user=self.user)
        summary = UserSummary.objects.get(user=self.user)
        self.assertEqual(summary.total_spent, Decimal("120.00"))
        self.assertEqual(summary.category_summary["Groceries"], Decimal("70.00"))

    def test_summary_update_on_product_deletion(self):
        self.product1.delete()
        summary = UserSummary.objects.get(user=self.user)
        self.assertEqual(summary.total_spent, Decimal("70.00"))
        self.assertEqual(summary.category_summary["Groceries"], Decimal("20.00"))


class ReceiptTextParsingTest(TestCase):

    def test_valid_receipt_text(self):
        receipt_text = "Pizza Bufala &&15.98&& ##Food##"
        products = parse_receipt_text(receipt_text)

        self.assertEqual(len(products), 1)
        self.assertEqual(products[0]["name"], "Pizza Bufala")
        self.assertEqual(products[0]["price"], Decimal("15.98"))
        self.assertEqual(products[0]["category"], "Food")

    def test_uncorrect_prices(self):
        receipt_text = "Invalid Product &&-5.00&& ##Food##\nUnnamed &&123abc&& ##Misc##"
        products = parse_receipt_text(receipt_text)

        self.assertEqual(len(products), 2)

    def test_mixed_valid_and_invalid(self):
        receipt_text = "Pizza Bufala &&15.98&& ##Food##\nUnnamed &&7128430129847&& ##Misc##"
        products = parse_receipt_text(receipt_text)

        self.assertEqual(len(products), 1)
        self.assertEqual(products[0]["name"], "Pizza Bufala")
        self.assertEqual(products[0]["price"], Decimal("15.98"))
        self.assertEqual(products[0]["category"], "Food")

    def test_missing_price(self):
        receipt_text = "Pizza Bufala ##Food##"
        products = parse_receipt_text(receipt_text)

        self.assertEqual(len(products), 1)
        self.assertEqual(products[0]["name"], "Pizza Bufala")
        self.assertEqual(products[0]["price"], Decimal("0.00"))
        self.assertEqual(products[0]["category"], "Food")

    def test_multiple_valid_products(self):
        receipt_text = """Pizza Bufala &&15.98&& ##Food##
                           Soda &&1.50&& ##Drink##"""
        products = parse_receipt_text(receipt_text)

        self.assertEqual(len(products), 2)
        self.assertEqual(products[0]["name"], "Pizza Bufala")
        self.assertEqual(products[0]["price"], Decimal("15.98"))
        self.assertEqual(products[0]["category"], "Food")

        self.assertEqual(products[1]["name"], "Soda")
        self.assertEqual(products[1]["price"], Decimal("1.50"))
        self.assertEqual(products[1]["category"], "Drink")

    def test_with_only_name(self):
        receipt_text = "InvalidLineWithoutMarkers"
        products = parse_receipt_text(receipt_text)

        self.assertEqual(len(products), 1)
        self.assertEqual(products[0]["name"], "InvalidLineWithoutMarkers")
        self.assertEqual(products[0]["price"], Decimal("0.00"))
        self.assertEqual(products[0]["category"], "Uncategorized")


class ChangePasswordTest(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="testuser@example.com", username="testuser", password="oldpassword") # type: ignore
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

    def test_change_password_success(self):
        response = self.client.post("/user/change-password/", {
            "current_password": "oldpassword",
            "new_password": "newpassword"
        })
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_change_password_invalid_current(self):
        response = self.client.post("/user/change-password/", {
            "current_password": "wrongpassword",
            "new_password": "newpassword"
        })
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_change_password_same_as_current(self):
        response = self.client.post("/user/change-password/", {
            "current_password": "oldpassword",
            "new_password": "oldpassword"
        })
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)


class ProductsByCategoryTest(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="testuser@example.com", username="testuser", password="testpassword") #type: ignore
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

        self.other_user = User.objects.create_user(email="otheruser@example.com", username="otheruser", password="otherpassword") #type: ignore

        self.receipt1 = Receipt.objects.create(user=self.user, title="Receipt 1")
        self.receipt2 = Receipt.objects.create(user=self.user, title="Receipt 2")

        self.product1 = Product.objects.create(name="Product 1", price=Decimal("10.00"), category="Food", receipt=self.receipt1, user=self.user)
        self.product2 = Product.objects.create(name="Product 2", price=Decimal("20.00"), category="Food", receipt=self.receipt1, user=self.user)
        self.product3 = Product.objects.create(name="Product 3", price=Decimal("30.00"), category="Electronics", receipt=self.receipt2, user=self.user)

        self.other_product = Product.objects.create(name="Other Product", price=Decimal("15.00"), category="Food", receipt=self.receipt1, user=self.other_user)

    def test_get_products_by_category_success(self):
        response = self.client.get(reverse('products-by-category', args=['Food']))
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        self.assertEqual(len(response.json()), 2)
        self.assertEqual(response.json()[0]["name"], "Product 2")
        self.assertEqual(response.json()[1]["name"], "Product 1")

    def test_get_products_by_category_no_products(self):
        response = self.client.get(reverse('products-by-category', args=['Toys']))
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertEqual(response.json()["error"], "No products found for this category.")

    def test_get_products_by_category_unauthorized_access(self):
        self.client.force_authenticate(user=self.other_user) #type: ignore
        response = self.client.get(reverse('products-by-category', args=['Food']))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.json()), 1)
        self.assertEqual(response.json()[0]["name"], "Other Product")

    def test_get_products_by_category_not_authenticated(self):
        self.client.logout()
        response = self.client.get(reverse('products-by-category', args=['Food']))
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)


class ProductDetailViewTest(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="testuser@example.com", username="testuser", password="testpassword") #type: ignore
        self.other_user = User.objects.create_user(email="otheruser@example.com", username="otheruser", password="otherpassword") #type: ignore
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

        self.receipt = Receipt.objects.create(user=self.user, title="Test Receipt")
        self.product = Product.objects.create(name="Test Product", price=Decimal("10.00"), category="Food", receipt=self.receipt, user=self.user)

    def test_retrieve_product(self):
        response = self.client.get(reverse('product-detail', args=[self.product.id]))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.json()["name"], "Test Product")

    def test_update_product(self):
        response = self.client.put(reverse('product-detail', args=[self.product.id]), {
            "name": "Updated Product",
            "price": "15.00",
            "category": "Updated Category"
        })
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.product.refresh_from_db()
        self.assertEqual(self.product.name, "Updated Product")
        self.assertEqual(self.product.price, Decimal("15.00"))
        self.assertEqual(self.product.category, "Updated Category")

    def test_delete_product(self):
        response = self.client.delete(reverse('product-detail', args=[self.product.id]))
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(Product.objects.filter(id=self.product.id).exists())

    def test_unauthorized_access(self):
        self.client.force_authenticate(user=self.other_user) #type: ignore
        response = self.client.get(reverse('product-detail', args=[self.product.id]))
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)