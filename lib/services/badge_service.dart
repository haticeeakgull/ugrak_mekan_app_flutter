import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Rozet Servisi - Otomatik ve AI destekli rozet yönetimi
class BadgeService {
  final _supabase = Supabase.instance.client;

  /// Badge ikonunu Supabase Storage'dan getir
  String getBadgeIconUrl(String iconName) {
    // Eğer tam URL verilmişse direkt döndür
    if (iconName.startsWith('http')) {
      return iconName;
    }
    
    // .png uzantısı yoksa ekle
    final fileName = iconName.endsWith('.png') ? iconName : '$iconName.png';
    
    // Supabase Storage'dan public URL oluştur
    return _supabase.storage
        .from('badge_icons')
        .getPublicUrl(fileName);
  }

  /// Kullanıcının tüm rozetlerini getir
  Future<List<Map<String, dynamic>>> getUserBadges(String userId) async {
    try {
      final response = await _supabase
          .from('user_badges')
          .select('''
            *,
            badges!badge_id (
              *,
              badge_categories!category_id (name, icon)
            ),
            ilce_isimli_kafeler!user_badges_cafe_id_fkey (kafe_adi)
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      // Icon URL'lerini düzenle
      final badges = List<Map<String, dynamic>>.from(response);
      for (var badge in badges) {
        if (badge['badges'] != null && badge['badges']['icon_url'] != null) {
          badge['badges']['icon_url'] = getBadgeIconUrl(badge['badges']['icon_url']);
        }
      }

      return badges;
    } catch (e) {
      debugPrint('❌ Rozet getirme hatası: $e');
      return [];
    }
  }

  /// Kullanıcının rozet ilerlemesini getir
  Future<List<Map<String, dynamic>>> getBadgeProgress(String userId) async {
    try {
      final response = await _supabase
          .from('user_badge_progress')
          .select('''
            *,
            badges!badge_id (
              title,
              description,
              icon_url,
              rarity,
              points
            )
          ''')
          .eq('user_id', userId)
          .order('current_progress', ascending: false)
          .limit(5);

      // Icon URL'lerini düzenle
      final progress = List<Map<String, dynamic>>.from(response);
      for (var item in progress) {
        if (item['badges'] != null && item['badges']['icon_url'] != null) {
          item['badges']['icon_url'] = getBadgeIconUrl(item['badges']['icon_url']);
        }
      }

      return progress;
    } catch (e) {
      debugPrint('❌ İlerleme getirme hatası: $e');
      return [];
    }
  }

  /// Kullanıcının toplam rozet puanını getir
  Future<int> getUserBadgePoints(String userId) async {
    try {
      final response = await _supabase
          .rpc('get_user_badge_points', params: {'p_user_id': userId});

      return response as int? ?? 0;
    } catch (e) {
      debugPrint('❌ Puan getirme hatası: $e');
      return 0;
    }
  }

  /// Kullanıcının kategoriye göre rozet sayısını getir
  Future<Map<String, int>> getUserBadgesByCategory(String userId) async {
    try {
      final response = await _supabase
          .rpc('get_user_badges_by_category', params: {'p_user_id': userId});

      final Map<String, int> result = {};
      for (var item in response) {
        result[item['category_name']] = item['badge_count'];
      }
      return result;
    } catch (e) {
      debugPrint('❌ Kategori rozet getirme hatası: $e');
      return {};
    }
  }

  /// Tüm aktif rozetleri getir
  Future<List<Map<String, dynamic>>> getAllBadges() async {
    try {
      final response = await _supabase
          .from('badges')
          .select('''
            *,
            badge_categories!category_id (name, icon, display_order)
          ''')
          .eq('is_active', true)
          .order('points', ascending: false);

      // Icon URL'lerini düzenle
      final badges = List<Map<String, dynamic>>.from(response);
      for (var badge in badges) {
        if (badge['icon_url'] != null) {
          badge['icon_url'] = getBadgeIconUrl(badge['icon_url']);
        }
      }

      return badges;
    } catch (e) {
      debugPrint('❌ Tüm rozetleri getirme hatası: $e');
      return [];
    }
  }

  /// Kullanıcının rozet kazanma kriterlerini kontrol et
  Future<void> checkBadgeProgress(String userId) async {
    try {
      debugPrint('🔍 Rozet kontrolü başlatılıyor: $userId');

      // Tüm otomatik rozetleri getir
      final badges = await _supabase
          .from('badges')
          .select()
          .eq('badge_type', 'auto')
          .eq('is_active', true);

      for (var badge in badges) {
        await _checkSingleBadge(userId, badge);
      }

      debugPrint('✅ Rozet kontrolü tamamlandı');
    } catch (e) {
      debugPrint('❌ Rozet kontrolü hatası: $e');
    }
  }

  /// Tek bir rozet için kontrol yap
  Future<void> _checkSingleBadge(
    String userId,
    Map<String, dynamic> badge,
  ) async {
    try {
      final criteria = badge['criteria'] as Map<String, dynamic>?;
      if (criteria == null) return;

      // Kullanıcı bu rozeti zaten kazanmış mı?
      final existingBadge = await _supabase
          .from('user_badges')
          .select()
          .eq('user_id', userId)
          .eq('badge_id', badge['id'])
          .maybeSingle();

      if (existingBadge != null) return; // Zaten kazanılmış

      final type = criteria['type'] as String;
      int progress = 0;
      int required = criteria['required_count'] as int? ?? 0;

      switch (type) {
        case 'post_count':
          progress = await _getPostCount(userId);
          break;
        case 'unique_cafe_count':
          progress = await _getUniqueCafeCount(userId);
          break;
        case 'follower_count':
          progress = await _getFollowerCount(userId);
          break;
        case 'time_based':
          progress = await _getTimeBasedCount(userId, criteria);
          break;
        case 'tag_count':
          progress = await _getTagBasedCount(userId, criteria);
          break;
        case 'cafe_count':
          progress = await _getCafeTypeCount(userId, criteria);
          break;
        case 'seasonal':
          progress = await _getSeasonalCount(userId, criteria);
          break;
      }

      // İlerlemeyi kaydet veya güncelle
      await _updateProgress(userId, badge['id'], progress, required);

      // Rozet kazanıldı mı?
      if (progress >= required) {
        await _awardBadge(userId, badge['id']);
      }
    } catch (e) {
      debugPrint('❌ Rozet kontrolü hatası (${badge['title']}): $e');
    }
  }

  /// Kullanıcının toplam paylaşım sayısı
  Future<int> _getPostCount(String userId) async {
    final response = await _supabase
        .from('cafe_postlar')
        .select()
        .eq('user_id', userId);

    return (response as List).length;
  }

  /// Kullanıcının benzersiz kafe sayısı
  Future<int> _getUniqueCafeCount(String userId) async {
    final response = await _supabase
        .from('cafe_postlar')
        .select('cafe_id')
        .eq('user_id', userId);

    final uniqueCafes = <String>{};
    for (var post in response) {
      if (post['cafe_id'] != null) {
        uniqueCafes.add(post['cafe_id'].toString());
      }
    }

    return uniqueCafes.length;
  }

  /// Kullanıcının takipçi sayısı
  Future<int> _getFollowerCount(String userId) async {
    final response = await _supabase
        .from('follows')
        .select()
        .eq('following_id', userId)
        .eq('status', 'following');

    return (response as List).length;
  }

  /// Zamana dayalı paylaşım sayısı (örn: gece 22:00-02:00)
  Future<int> _getTimeBasedCount(
    String userId,
    Map<String, dynamic> criteria,
  ) async {
    final timeRange = criteria['time_range'] as List;
    final startTime = timeRange[0] as String;
    final endTime = timeRange[1] as String;

    final response = await _supabase
        .from('cafe_postlar')
        .select('paylasim_tarihi')
        .eq('user_id', userId);

    int count = 0;
    for (var post in response) {
      final dateTime = DateTime.parse(post['paylasim_tarihi']);
      final hour = dateTime.hour;
      final minute = dateTime.minute;
      final timeStr = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

      // Saat aralığı kontrolü
      if (_isTimeInRange(timeStr, startTime, endTime)) {
        count++;
      }
    }

    return count;
  }

  /// Tag bazlı mekan sayısı
  Future<int> _getTagBasedCount(
    String userId,
    Map<String, dynamic> criteria,
  ) async {
    final tags = criteria['tags'] as List;

    final response = await _supabase
        .from('cafe_postlar')
        .select('cafe_id, baslik, icerik')
        .eq('user_id', userId);

    int count = 0;
    final Set<String> countedCafes = {};

    for (var post in response) {
      final cafeId = post['cafe_id']?.toString() ?? '';
      
      // Post içeriği
      final postTitle = (post['baslik'] ?? '').toString().toLowerCase();
      final postContent = (post['icerik'] ?? '').toString().toLowerCase();
      final combinedText = '$postTitle $postContent';

      // Tag kontrolü
      bool matches = false;
      for (var tag in tags) {
        if (combinedText.contains(tag.toString().toLowerCase())) {
          matches = true;
          break;
        }
      }

      if (matches && !countedCafes.contains(cafeId)) {
        countedCafes.add(cafeId);
        count++;
      }
    }

    return count;
  }

  /// Kafe tipi bazlı sayım
  Future<int> _getCafeTypeCount(
    String userId,
    Map<String, dynamic> criteria,
  ) async {
    final cafeTypes = criteria['cafe_types'] as List;
    final uniqueOnly = criteria['unique_cafes'] as bool? ?? false;

    final response = await _supabase
        .from('cafe_postlar')
        .select('cafe_id, baslik, icerik')
        .eq('user_id', userId);

    if (response == null) return 0;

    final matchedCafes = <String>{};
    int count = 0;

    for (var post in response) {
      final cafeId = post['cafe_id']?.toString();
      
      // Post içeriği
      final postTitle = (post['baslik'] ?? '').toString().toLowerCase();
      final postContent = (post['icerik'] ?? '').toString().toLowerCase();
      final combinedText = '$postTitle $postContent';

      // Tip kontrolü
      bool matches = false;
      for (var type in cafeTypes) {
        if (combinedText.contains(type.toString().toLowerCase())) {
          matches = true;
          break;
        }
      }

      if (matches) {
        if (uniqueOnly && cafeId != null) {
          matchedCafes.add(cafeId);
        } else {
          count++;
        }
      }
    }

    return uniqueOnly ? matchedCafes.length : count;
  }

  /// Sezonluk paylaşım sayısı
  Future<int> _getSeasonalCount(
    String userId,
    Map<String, dynamic> criteria,
  ) async {
    final month = criteria['month'] as int;

    final response = await _supabase
        .from('cafe_postlar')
        .select('paylasim_tarihi')
        .eq('user_id', userId);

    int count = 0;
    for (var post in response) {
      final dateTime = DateTime.parse(post['paylasim_tarihi']);
      if (dateTime.month == month) {
        count++;
      }
    }

    return count;
  }

  /// İlerlemeyi güncelle
  Future<void> _updateProgress(
    String userId,
    String badgeId,
    int current,
    int required,
  ) async {
    try {
      await _supabase.from('user_badge_progress').upsert({
        'user_id': userId,
        'badge_id': badgeId,
        'current_progress': current,
        'required_progress': required,
        'last_updated': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,badge_id');
      
    } catch (e) {
      debugPrint('❌ İlerleme güncelleme hatası: $e');
    }
  }

  /// Rozet kazan
  Future<void> _awardBadge(String userId, String badgeId) async {
    try {
      // Rozeti kullanıcıya ver
      await _supabase.from('user_badges').insert({
        'user_id': userId,
        'badge_id': badgeId,
        'cafe_id': null,
      });

      // Analitik kaydet
      await _supabase.from('badge_analytics').insert({
        'user_id': userId,
        'badge_id': badgeId,
        'trigger_action': 'auto_check',
        'earned_at': DateTime.now().toIso8601String(),
      });

      debugPrint('🎉 Rozet kazanıldı! Badge ID: $badgeId');
    } catch (e) {
      debugPrint('❌ Rozet verme hatası: $e');
    }
  }

  /// Saat aralığı kontrolü
  bool _isTimeInRange(String time, String start, String end) {
    final timeInt = int.parse(time.replaceAll(':', ''));
    final startInt = int.parse(start.replaceAll(':', ''));
    final endInt = int.parse(end.replaceAll(':', ''));

    if (startInt <= endInt) {
      return timeInt >= startInt && timeInt <= endInt;
    } else {
      // Gece yarısını geçen aralıklar için (örn: 22:00 - 02:00)
      return timeInt >= startInt || timeInt <= endInt;
    }
  }
}
