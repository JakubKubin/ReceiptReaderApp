# receiptreader/views.py

from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import generics, permissions, status
from rest_framework_simplejwt.tokens import RefreshToken, AccessToken
from django.contrib.auth import get_user_model
from rest_framework.exceptions import NotFound, ValidationError
from rest_framework_simplejwt.exceptions import TokenError
from .services import extract_text_from_image, process_receipt_image, save_receipt_text, save_products
from django.http import HttpResponse
from rest_framework.views import APIView
import mimetypes

from .models import Product, Receipt, UserSummary
from .serializers import ChangePasswordSerializer, ProductSerializer, UserSerializer, ReceiptSerializer, UserListSerializer, UpdateReceiptSerializer
from .utils import get_client_ip

import logging

logger = logging.getLogger(__name__)

User = get_user_model()


@api_view(['GET'])
def get_routes(request):
    print(get_client_ip(request))
    return Response()


class BaseView:
    def log_request(self, view_name, request):
        client_ip = get_client_ip(request)
        logger.info(f"{view_name} called by user: {request.user}, IP: {client_ip}")


class UserListView(BaseView, generics.ListAPIView):
    queryset = User.objects.all()
    serializer_class = UserListSerializer

    def get(self, request, *args, **kwargs):
        self.log_request('UserListView', request)
        return super().get(request, *args, **kwargs)


class RegisterView(BaseView, generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = UserSerializer

    def create(self, request, *args, **kwargs):
        self.log_request('RegisterView', request)
        serializer = self.get_serializer(data=request.data)
        try:
            serializer.is_valid(raise_exception=True)
            user = serializer.save()
            refresh = RefreshToken.for_user(user)
            access_token = AccessToken.for_user(user)
            logger.info(f"User {user.pk} registered successfully")
            return Response({
                'refresh': str(refresh),
                'access': str(access_token),
                'user': {'id': user.pk}
            }, status=status.HTTP_201_CREATED)
        except ValidationError as ve:
            logger.warning(f"Registration failed: {ve}")
            return Response({'error': 'User with this email already exists'}, status=status.HTTP_400_BAD_REQUEST)


class LoginView(BaseView, generics.GenericAPIView):
    serializer_class = UserSerializer

    def post(self, request, *args, **kwargs):
        self.log_request('LoginView', request)
        email = request.data.get('email', '<no email provided>')
        logger.debug(f"Login attempt with email: {email}")

        password = request.data.get('password')
        user = User.objects.filter(email=email).first()
        if user and user.check_password(password):
            refresh = RefreshToken.for_user(user)
            access_token = AccessToken.for_user(user)
            logger.info(f"User {user.pk} logged in successfully")
            return Response({
                'refresh': str(refresh),
                'access': str(access_token),
                'user': {'id': user.pk}
            })
        elif not user:
            logger.warning(f"Login failed: User with email {email} does not exist")
            return Response({'error': 'User does not exist'}, status=status.HTTP_404_NOT_FOUND)
        else:
            logger.warning(f"Invalid credentials for user with email: {email}")
            return Response({'error': 'Invalid Credentials'}, status=status.HTTP_400_BAD_REQUEST)


class LogoutAPIView(BaseView, generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        self.log_request('LogoutAPIView', request)
        try:
            refresh_token = request.data["refresh"]
            token = RefreshToken(refresh_token)
            token.blacklist()
            logger.info(f"User {request.user.pk} logged out successfully")
            return Response({"detail": "Successfully logged out."}, status=status.HTTP_200_OK)
        except KeyError:
            logger.error("Logout failed: Refresh token is required.")
            return Response({"error": "Refresh token is required."}, status=status.HTTP_400_BAD_REQUEST)
        except TokenError as e:
            logger.error(f"Logout failed: {e}", exc_info=True)
            return Response({"error": "Invalid token."}, status=status.HTTP_401_UNAUTHORIZED)


class ReceiptCreateView(BaseView, generics.CreateAPIView):
    queryset = Receipt.objects.all()
    serializer_class = ReceiptSerializer
    permission_classes = [permissions.IsAuthenticated]

    def perform_create(self, serializer):
        self.log_request('ReceiptCreateView', self.request)
        try:
            instance = serializer.save(user=self.request.user)
            receipt_image = instance.original_image
            logger.debug(f"Received image: {receipt_image}")

            if receipt_image:
                try:
                    processed_image_file, instance.text = process_receipt_image(instance)

                    original_filename = receipt_image.name.split('/')[-1]
                    processed_filename = 'processed_' + original_filename
                    instance.processed_image.save(processed_filename, processed_image_file)
                    save_receipt_text(instance)
                    instance.save()
                    logger.info(f"Processed image saved for receipt {instance.pk}")
                except Exception as e:
                    logger.error(f"Image processing failed: {str(e)}", exc_info=True)
                    raise ValidationError(f"Image processing failed: {str(e)}")
            else:
                logger.warning("No image provided for receipt creation")
        except Exception as e:
            logger.error(f"Error in ReceiptCreateView: {str(e)}", exc_info=True)
            raise


class ReceiptListView(BaseView, generics.ListCreateAPIView):
    serializer_class = ReceiptSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        self.log_request('ReceiptListView', self.request)
        return Receipt.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        self.log_request('ReceiptListView - Create', self.request)
        serializer.save(user=self.request.user)


class ReceiptDetailView(BaseView, generics.RetrieveUpdateDestroyAPIView):
    serializer_class = ReceiptSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Receipt.objects.filter(user=self.request.user)

    def retrieve(self, request, *args, **kwargs):
        self.log_request('ReceiptDetailView - Retrieve', self.request)
        return super().retrieve(request, *args, **kwargs)

    def destroy(self, request, *args, **kwargs):
        self.log_request('ReceiptDetailView - Destroy', self.request)
        return super().destroy(request, *args, **kwargs)


class UpdateReceiptView(BaseView, generics.UpdateAPIView):
    queryset = Receipt.objects.all()
    serializer_class = UpdateReceiptSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'pk'

    def update(self, request, *args, **kwargs):
        self.log_request('UpdateReceiptView', request)
        instance = self.get_object()
        partial = kwargs.pop('partial', True)
        serializer = self.get_serializer(instance, data=request.data, partial=partial)

        if not serializer.is_valid():
            logger.error(f"Serialization error: {serializer.errors}")
            return Response({"error": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        serializer.save()

        try:
            if 'original_image' in request.FILES:
                self.reprocess_original_image(instance)
            if 'processed_image' in request.FILES:
                self.process_processed_image(instance)

            save_products(instance)
            instance.save()

            logger.info(f"Receipt {instance.pk} updated successfully")
            return Response({"message": "Updated successfully"})
        except Exception as e:
            logger.error(f"Error updating receipt {instance.pk}: {str(e)}", exc_info=True)
            return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    def reprocess_original_image(self, instance):
        if instance.processed_image:
            instance.processed_image.delete(save=False)

        try:
            processed_image_file, instance.text = process_receipt_image(instance)
            original_filename = instance.original_image.name.split('/')[-1]
            processed_filename = 'processed_' + original_filename

            instance.processed_image.save(processed_filename, processed_image_file)

            save_receipt_text(instance)
            logger.info(f"Reprocessed original image for receipt {instance.pk}")
        except Exception as e:
            logger.error(f"Image processing failed: {str(e)}", exc_info=True)
            raise ValidationError(f"Image processing failed: {str(e)}")

    def process_processed_image(self, instance):
        try:
            instance.text = extract_text_from_image(instance.processed_image.path)

            save_receipt_text(instance)
            logger.info(f"Processed image updated for receipt {instance.pk}")
        except Exception as e:
            logger.error(f"Processing processed_image failed: {str(e)}", exc_info=True)
            raise ValidationError(f"Processing processed_image failed: {str(e)}")


class ShowReceiptImage(BaseView, APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, pk, filename, image_type, format=None):
        self.log_request('ShowReceiptImage', request)
        try:
            receipt = Receipt.objects.get(pk=pk, user=request.user)
        except Receipt.DoesNotExist:
            logger.warning(f"Receipt {pk} not found for user {request.user.pk}")
            return Response({'error': 'Receipt not found'}, status=status.HTTP_404_NOT_FOUND)

        if image_type == 'processed_image':
            image_field = receipt.processed_image
        elif image_type == 'original_image':
            image_field = receipt.original_image
        else:
            logger.error(f"Invalid image type requested: {image_type}")
            return Response({'error': 'Invalid image type'}, status=status.HTTP_400_BAD_REQUEST)

        if not image_field or image_field.name.split('/')[-1] != filename:
            logger.warning(f"Image {filename} not found for receipt {pk}")
            return Response({'error': 'Image not found'}, status=status.HTTP_404_NOT_FOUND)

        image_path = image_field.path
        try:
            with open(image_path, 'rb') as image_file:
                mime_type, _ = mimetypes.guess_type(image_path)
                response = HttpResponse(image_file.read(), content_type=mime_type)
                response['Content-Disposition'] = f'inline; filename="{filename}"'
                logger.info(f"Serving image {filename} for receipt {pk}")
                return response
        except IOError:
            logger.error(f"Image file not found at {image_path}", exc_info=True)
            return Response({'error': 'Image file not found'}, status=status.HTTP_404_NOT_FOUND)


class DeleteReceiptView(BaseView, generics.DestroyAPIView):
    queryset = Receipt.objects.all()
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        self.log_request('DeleteReceiptView', self.request)
        receipt = super().get_object()
        if receipt.user != self.request.user:
            logger.warning(f"Unauthorized delete attempt on receipt {receipt.pk} by user {self.request.user.pk}")
            raise NotFound("Receipt not found")
        return receipt

    def delete(self, request, *args, **kwargs):
        receipt = self.get_object()
        logger.info(f"Deleting receipt {receipt.pk} for user {request.user.pk}")
        return super().delete(request, *args, **kwargs)


class UserDetailView(BaseView, generics.RetrieveAPIView):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        self.log_request('UserDetailView', self.request)
        pk = self.kwargs.get('pk')
        try:
            user = User.objects.get(pk=pk)
            if user != self.request.user:
                logger.warning(f"Unauthorized access attempt to user {pk} by user {self.request.user.pk}")
                raise NotFound("User not found")
            logger.info(f"UserDetailView accessed by user {self.request.user.pk}")
            return user
        except User.DoesNotExist:
            logger.error(f"User {pk} does not exist", exc_info=True)
            raise NotFound("User not found")


class UserSummaryView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        product_count = Product.objects.filter(user=request.user).count()

        if product_count == 0:
            logger.info(f"User {request.user.pk} has no products.")
            return Response({"info": "User does not have any products."}, status=200)

        try:
            summary = UserSummary.objects.get(user=request.user)
        except UserSummary.DoesNotExist:
            logger.error(f"UserSummary not found for user {request.user.pk}", exc_info=True)
            return Response({"error": "No summary available"}, status=404)

        if not summary:
            return Response({"error": "No summary available"}, status=404)

        return Response({
            "total_spent": summary.total_spent,
            "category_avg": summary.category_avg,
            "category_summary": summary.category_summary,
        }, status=status.HTTP_200_OK)


class ChangePasswordView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        serializer = ChangePasswordSerializer(data=request.data, context={'request': request})
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        try:
            user = request.user
            new_password = serializer.validated_data.get("new_password") # type: ignore
            user.set_password(new_password)
            user.save()
            return Response(
                {"success": "Password updated successfully."},
                status=status.HTTP_200_OK,
            )
        except Exception as e:
            return Response(
                {"error": f"An error occurred: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )


class ProductsByCategoryView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, category, *args, **kwargs):
        products = Product.objects.filter(
            user=request.user,
            category=category
        ).order_by('-price')

        if not products.exists():
            return Response(
                {"error": "No products found for this category."},
                status=status.HTTP_404_NOT_FOUND
            )

        result = [
            {
                "id": product.id,
                "name": product.name,
                "price": product.price,
                "receipt_title": product.receipt.title,
                "receipt_date": product.receipt.date_of_shopping,
            }
            for product in products
        ]
        return Response(result, status=status.HTTP_200_OK, content_type="application/json; charset=utf-8")


class ProductDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Product.objects.all()
    serializer_class = ProductSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Product.objects.filter(user=self.request.user)

    def perform_update(self, serializer):
        instance = self.get_object()
        if instance.user != self.request.user:
            return Response({"error": "You do not hove perrmision to that acction"}, status=status.HTTP_403_FORBIDDEN)

        serializer.save()

    def perform_destroy(self, instance):
        if instance.user != self.request.user:
            return Response({"error": "You do not hove perrmision to that acction"}, status=status.HTTP_403_FORBIDDEN)
        instance.delete()


class ProductsByReceiptView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, receipt_id, *args, **kwargs):

        try:
            receipt = Receipt.objects.get(id=receipt_id, user=request.user)
        except Receipt.DoesNotExist:
            return Response(
                {"error": "Receipt not found or does not belong to the user."},
                status=status.HTTP_404_NOT_FOUND
            )

        products = Product.objects.filter(receipt=receipt)

        if not products.exists():
            return Response(
                {"error": "No products found for the specified receipt."},
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = ProductSerializer(products, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK, content_type="application/json; charset=utf-8")