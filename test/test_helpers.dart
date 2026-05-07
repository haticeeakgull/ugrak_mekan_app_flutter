import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test için widget wrapper
Widget makeTestableWidget(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: child,
    ),
  );
}

/// Test için MediaQuery wrapper
Widget makeTestableWidgetWithMediaQuery(Widget child, {Size? size}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size ?? const Size(375, 812)),
      child: Scaffold(
        body: child,
      ),
    ),
  );
}

/// Mock Supabase User
class MockUser {
  final String id;
  final String? email;
  final Map<String, dynamic>? userMetadata;

  MockUser({
    required this.id,
    this.email,
    this.userMetadata,
  });
}

/// Mock Cafe Data
Map<String, dynamic> createMockCafe({
  String? id,
  String? kafeAdi,
  double? latitude,
  double? longitude,
  String? ilceAdi,
  String? semtAdi,
  List<String>? vibeEtiketleri,
}) {
  return {
    'id': id ?? 'cafe_123',
    'kafe_adi': kafeAdi ?? 'Test Cafe',
    'latitude': latitude ?? 41.0082,
    'longitude': longitude ?? 28.9784,
    'ilce_adi': ilceAdi ?? 'Kadıköy',
    'semt_adi': semtAdi ?? 'Moda',
    'vibe_etiketleri': vibeEtiketleri ?? ['Sakin', 'Romantik'],
    'similarity': 0.85,
    'cafe_gorselleri': [],
    'yorumlar': [],
    'cafe_postlar': [],
  };
}

/// Mock Post Data
Map<String, dynamic> createMockPost({
  String? id,
  String? baslik,
  String? icerik,
  String? userId,
  String? cafeId,
}) {
  return {
    'id': id ?? 'post_123',
    'baslik': baslik ?? 'Test Post',
    'icerik': icerik ?? 'Test content',
    'user_id': userId ?? 'user_123',
    'cafe_id': cafeId ?? 'cafe_123',
    'created_at': DateTime.now().toIso8601String(),
    'profiles': {
      'username': 'testuser',
      'avatar_url': 'https://example.com/avatar.jpg',
    },
  };
}

/// Mock Collection Data
Map<String, dynamic> createMockCollection({
  String? id,
  String? isim,
  String? userId,
  bool? isPublic,
}) {
  return {
    'id': id ?? 'col_123',
    'isim': isim ?? 'Test Collection',
    'user_id': userId ?? 'user_123',
    'is_public': isPublic ?? true,
    'created_at': DateTime.now().toIso8601String(),
    'koleksiyon_ogeleri': [],
    'cafe_photos': [],
  };
}

/// Mock Profile Data
Map<String, dynamic> createMockProfile({
  String? id,
  String? username,
  String? fullName,
  String? avatarUrl,
  bool? isPrivate,
}) {
  return {
    'id': id ?? 'user_123',
    'username': username ?? 'testuser',
    'full_name': fullName ?? 'Test User',
    'avatar_url': avatarUrl ?? 'https://example.com/avatar.jpg',
    'is_private': isPrivate ?? false,
    'weekly_points': 0,
  };
}

/// Mock Badge Data
Map<String, dynamic> createMockBadge({
  String? id,
  String? title,
  String? description,
  int? points,
  String? rarity,
}) {
  return {
    'id': id ?? 'badge_123',
    'title': title ?? 'Test Badge',
    'description': description ?? 'Test badge description',
    'points': points ?? 10,
    'rarity': rarity ?? 'common',
    'icon_url': 'https://example.com/badge.png',
    'is_active': true,
  };
}

/// Mock Notification Data
Map<String, dynamic> createMockNotification({
  String? id,
  String? senderId,
  String? receiverId,
  String? type,
  bool? isRead,
}) {
  return {
    'id': id ?? 'notif_123',
    'sender_id': senderId ?? 'user_123',
    'receiver_id': receiverId ?? 'user_456',
    'type': type ?? 'follow',
    'is_read': isRead ?? false,
    'created_at': DateTime.now().toIso8601String(),
  };
}

/// Mock Follow Data
Map<String, dynamic> createMockFollow({
  String? followerId,
  String? followingId,
  String? status,
}) {
  return {
    'follower_id': followerId ?? 'user_123',
    'following_id': followingId ?? 'user_456',
    'status': status ?? 'following',
    'created_at': DateTime.now().toIso8601String(),
  };
}

/// Mock Comment Data
Map<String, dynamic> createMockComment({
  String? id,
  String? cafeId,
  String? userId,
  String? yorumMetni,
  int? puan,
}) {
  return {
    'id': id ?? 'comment_123',
    'cafe_id': cafeId ?? 'cafe_123',
    'kullanici_id': userId ?? 'user_123',
    'yorum_metni': yorumMetni ?? 'Great place!',
    'puan': puan ?? 5,
    'created_at': DateTime.now().toIso8601String(),
  };
}

/// Mock Missing Cafe Report Data
Map<String, dynamic> createMockMissingCafeReport({
  String? id,
  String? kullaniciId,
  String? kafeAdi,
  double? latitude,
  double? longitude,
  String? durum,
}) {
  return {
    'id': id ?? 'report_123',
    'kullanici_id': kullaniciId ?? 'user_123',
    'kafe_adi': kafeAdi ?? 'Missing Cafe',
    'latitude': latitude ?? 41.0082,
    'longitude': longitude ?? 28.9784,
    'notlar': 'Test notes',
    'durum': durum ?? 'beklemede',
    'created_at': DateTime.now().toIso8601String(),
  };
}

/// Wait for async operations
Future<void> pumpAndSettle(WidgetTester tester) async {
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

/// Find widget by type
Finder findWidgetByType<T>() {
  return find.byType(T);
}

/// Find widget by key
Finder findWidgetByKey(String key) {
  return find.byKey(Key(key));
}

/// Find text widget
Finder findTextWidget(String text) {
  return find.text(text);
}

/// Verify widget exists
void verifyWidgetExists(Finder finder) {
  expect(finder, findsOneWidget);
}

/// Verify widget does not exist
void verifyWidgetDoesNotExist(Finder finder) {
  expect(finder, findsNothing);
}

/// Verify text exists
void verifyTextExists(String text) {
  expect(find.text(text), findsOneWidget);
}

/// Tap widget
Future<void> tapWidget(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Enter text
Future<void> enterText(WidgetTester tester, Finder finder, String text) async {
  await tester.enterText(finder, text);
  await tester.pumpAndSettle();
}

/// Scroll widget
Future<void> scrollWidget(
  WidgetTester tester,
  Finder finder,
  Offset offset,
) async {
  await tester.drag(finder, offset);
  await tester.pumpAndSettle();
}

/// Mock DateTime for testing
DateTime createMockDateTime({
  int? year,
  int? month,
  int? day,
  int? hour,
  int? minute,
}) {
  return DateTime(
    year ?? 2024,
    month ?? 1,
    day ?? 1,
    hour ?? 12,
    minute ?? 0,
  );
}

/// Calculate time difference
Duration calculateTimeDifference(DateTime start, DateTime end) {
  return end.difference(start);
}

/// Format date for testing
String formatDateForTest(DateTime date) {
  return date.toIso8601String();
}

/// Parse date from string
DateTime parseDateFromString(String dateString) {
  return DateTime.parse(dateString);
}

/// Validate email format
bool isValidEmail(String email) {
  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  return emailRegex.hasMatch(email);
}

/// Validate coordinate range
bool isValidLatitude(double lat) {
  return lat >= -90 && lat <= 90;
}

bool isValidLongitude(double lng) {
  return lng >= -180 && lng <= 180;
}

/// Generate random string for testing
String generateRandomString(int length) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return List.generate(length, (index) => chars[index % chars.length]).join();
}

/// Create mock embedding
List<double> createMockEmbedding({int dimension = 384}) {
  return List.generate(dimension, (i) => i.toDouble());
}

/// Validate embedding dimension
bool isValidEmbeddingDimension(List<double> embedding, int expectedDimension) {
  return embedding.length == expectedDimension;
}
