#receiptreader/urls.py
from django.urls import path

from . import views
from .views import ChangePasswordView, ProductDetailView, ProductsByCategoryView, ProductsByReceiptView, RegisterView, LoginView, ReceiptListView, ReceiptDetailView, ShowReceiptImage, UserListView, UserDetailView, ReceiptCreateView, UpdateReceiptView, DeleteReceiptView, LogoutAPIView, UserSummaryView
from rest_framework_simplejwt.views import TokenRefreshView

urlpatterns = [
    path('', views.get_routes, name='get-routes'),
    path('token/refresh/', TokenRefreshView.as_view()),
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', LoginView.as_view(), name='login'),
    path('logout/', LogoutAPIView.as_view(), name='logout'),
    path('receipts/', ReceiptListView.as_view(), name='receipt-list'),
    path('receipt/<int:pk>/', ReceiptDetailView.as_view(), name='receipt-detail'),
    path('receipt/create/', ReceiptCreateView.as_view(), name='receipt-create'),
    path('receipt/update/<int:pk>/', UpdateReceiptView.as_view(), name='receipt-update'),
    path('receipt/delete/<int:pk>/', DeleteReceiptView.as_view(), name='receipt-delete'),
    path('receipts/<int:pk>/image/<str:image_type>/<str:filename>/', ShowReceiptImage.as_view(), name='receipt-image'),
    path('users/', UserListView.as_view(), name='user-list'),
    path('user/<int:pk>/', UserDetailView.as_view(), name='user-detail'),
    path('user-summary/', UserSummaryView.as_view(), name='user-summary'),
    path('user/change-password/', ChangePasswordView.as_view(), name='change-password'),
    path('products/category/<str:category>/', ProductsByCategoryView.as_view(), name='products-by-category'),
    path('product/<int:pk>/', ProductDetailView.as_view(), name='product-detail'),
    path('products/<int:receipt_id>/', ProductsByReceiptView.as_view(), name='products-by-receipt'),
]