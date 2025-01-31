// utils/urls.dart

const int port = 2137;

class Urls {
  static String host = 'man-ultimate-plainly.ngrok-free.app';

  static Uri get basePath => Uri(
        scheme: 'https',
        host: host,
      );

  static Uri get receiveReceiptsUrl => Uri(
        scheme: 'https',
        host: host,
        path: '/receipts/',
      );

  static Uri receiveSpecificReceiptUrl(int id) => Uri(
        scheme: 'https',
        host: host,
        path: '/receipt/$id/',
      );

  static Uri get createReceiptUrl => Uri(
        scheme: 'https',
        host: host,
        path: '/receipt/create/',
      );

  static Uri updateReceiptUrl(int id) => Uri(
        scheme: 'https',
        host: host,
        path: '/receipt/update/$id/',
      );

  static Uri deleteReceiptUrl(int id) => Uri(
        scheme: 'https',
        host: host,
        path: '/receipt/delete/$id/',
      );

  static Uri get registerPageUrl => Uri(
        scheme: 'https',
        host: host,
        path: '/register/',
      );

  static Uri get loginPageUrl => Uri(
        scheme: 'https',
        host: host,
        path: '/login/',
      );

  static Uri get logOutPageUrl => Uri(
        scheme: 'https',
        host: host,
        path: '/logout/',
      );

  static Uri get refreshTokenUrl => Uri(
        scheme: 'https',
        host: host,
        path: '/token/refresh/',
      );

  static Uri getUserDataUrl(int id) => Uri(
        scheme: 'https',
        host: host,
        path: '/user/$id/',
      );

  static Uri get getUserSummaryUrl => Uri(
        scheme: 'https',
        host: host,
        path: '/user-summary/',
      );
  static Uri getCategoryProductsUrl(String category) => Uri(
        scheme: 'https',
        host: host,
        path: '/products/category/$category/',
      );
  static Uri changeProductUrl(int id) => Uri(
        scheme: 'https',
        host: host,
        path: 'product/$id/',
      );
  static Uri get changePasswordUrl => Uri(
        scheme: 'https',
        host: host,
        path: 'user/change-password/',
      );
  static Uri getReceiptProductsUrl(int id) => Uri(
        scheme: 'https',
        host: host,
        path: 'products/$id/',
      );
}
