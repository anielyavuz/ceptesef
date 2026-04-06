import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/firestore_paths.dart';
import '../models/app_user.dart';
import '../models/household.dart';
import 'remote_logger_service.dart';

/// Aile planı (household) yönetim servisi
/// Household oluşturma, katılma, ayrılma ve davet kodu işlemlerini yönetir
class HouseholdService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Davet kodu karakter seti (büyük harf + rakam)
  static const String _codeChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  /// Davet kodu uzunluğu
  static const int _codeLength = 6;

  /// Davet kodu geçerlilik süresi
  static const Duration _codeTtl = Duration(hours: 24);

  // ---------------------------------------------------------------------------
  // Yardımcı metotlar
  // ---------------------------------------------------------------------------

  /// 6 haneli rastgele davet kodu üretir (A-Z, 0-9)
  String _generateInviteCode() {
    final random = Random.secure();
    return List.generate(
      _codeLength,
      (_) => _codeChars[random.nextInt(_codeChars.length)],
    ).join();
  }

  /// Households koleksiyon referansı
  CollectionReference<Map<String, dynamic>> get _householdsRef =>
      _firestore.collection(FirestorePaths.householdsCollection);

  /// Users koleksiyon referansı
  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection(FirestorePaths.usersCollection);

  // ---------------------------------------------------------------------------
  // CRUD metotları
  // ---------------------------------------------------------------------------

  /// Yeni bir household oluşturur
  /// [uid] oluşturan kullanıcının UID'si, [name] aile adı
  Future<Household> createHousehold(String uid, String name) async {
    // Kullanıcının zaten bir household'u var mı kontrol et
    final userDoc = await _usersRef.doc(uid).get();
    final existingHouseholdId = userDoc.data()?['householdId'] as String?;
    if (existingHouseholdId != null) {
      throw Exception('Kullanıcı zaten bir aile planına üye.');
    }

    final inviteCode = _generateInviteCode();
    final expiresAt = DateTime.now().add(_codeTtl);

    final docRef = _householdsRef.doc();
    final household = Household(
      id: docRef.id,
      name: name,
      ownerUid: uid,
      members: [uid],
      inviteCode: inviteCode,
      inviteCodeExpiresAt: expiresAt,
      createdAt: DateTime.now(),
    );

    // Household dokümanı oluştur ve kullanıcının householdId'sini güncelle
    final batch = _firestore.batch();
    batch.set(docRef, household.toMap());
    batch.update(_usersRef.doc(uid), {'householdId': docRef.id});
    await batch.commit();

    RemoteLoggerService.info(
      'household_created',
      extra: {'householdId': docRef.id, 'name': name},
    );

    return household;
  }

  /// Davet kodu ile mevcut bir household'a katılır
  Future<Household> joinHousehold(String uid, String inviteCode) async {
    // Kullanıcının zaten bir household'u var mı kontrol et
    final userDoc = await _usersRef.doc(uid).get();
    final existingHouseholdId = userDoc.data()?['householdId'] as String?;
    if (existingHouseholdId != null) {
      throw Exception('Kullanıcı zaten bir aile planına üye.');
    }

    // Davet koduna göre household'u bul
    final query = await _householdsRef
        .where('inviteCode', isEqualTo: inviteCode.toUpperCase().trim())
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Geçersiz davet kodu.');
    }

    final doc = query.docs.first;
    final household = Household.fromMap(doc.data(), doc.id);

    // Kodun süresinin dolup dolmadığını kontrol et
    if (household.inviteCodeExpiresAt != null &&
        household.inviteCodeExpiresAt!.isBefore(DateTime.now())) {
      throw Exception('Davet kodunun süresi dolmuş.');
    }

    // Zaten üye mi kontrol et
    if (household.members.contains(uid)) {
      throw Exception('Zaten bu aile planının üyesisiniz.');
    }

    // Üyeye ekle ve kullanıcının householdId'sini güncelle
    final batch = _firestore.batch();
    batch.update(_householdsRef.doc(household.id), {
      'members': FieldValue.arrayUnion([uid]),
    });
    batch.update(_usersRef.doc(uid), {'householdId': household.id});
    await batch.commit();

    RemoteLoggerService.info(
      'household_joined',
      extra: {'householdId': household.id},
    );

    return household.copyWith(members: [...household.members, uid]);
  }

  /// Household'dan ayrılır
  /// Owner ayrılıyorsa: başka üye varsa onu owner yapar, yoksa household'u siler
  Future<void> leaveHousehold(String uid) async {
    // Kullanıcının householdId'sini al
    final userDoc = await _usersRef.doc(uid).get();
    final householdId = userDoc.data()?['householdId'] as String?;
    if (householdId == null) {
      throw Exception('Kullanıcı herhangi bir aile planına üye değil.');
    }

    final householdDoc = await _householdsRef.doc(householdId).get();
    if (!householdDoc.exists) {
      // Household silinmiş, sadece kullanıcıyı temizle
      await _usersRef.doc(uid).update({'householdId': FieldValue.delete()});
      return;
    }

    final household = Household.fromMap(householdDoc.data()!, householdDoc.id);
    final isOwner = household.ownerUid == uid;
    final remainingMembers =
        household.members.where((m) => m != uid).toList();

    final batch = _firestore.batch();

    if (remainingMembers.isEmpty) {
      // Son üye ayrılıyor — household'u sil
      batch.delete(_householdsRef.doc(householdId));
    } else if (isOwner) {
      // Owner ayrılıyor ama başka üyeler var — ilk üyeyi owner yap
      final newOwner = remainingMembers.first;
      batch.update(_householdsRef.doc(householdId), {
        'members': FieldValue.arrayRemove([uid]),
        'ownerUid': newOwner,
      });
    } else {
      // Normal üye ayrılıyor
      batch.update(_householdsRef.doc(householdId), {
        'members': FieldValue.arrayRemove([uid]),
      });
    }

    // Kullanıcının householdId'sini temizle
    batch.update(_usersRef.doc(uid), {'householdId': FieldValue.delete()});
    await batch.commit();

    RemoteLoggerService.info(
      'household_left',
      extra: {'householdId': householdId, 'wasOwner': isOwner},
    );
  }

  /// Firestore'dan household bilgisini getirir
  Future<Household?> getHousehold(String householdId) async {
    final doc = await _householdsRef.doc(householdId).get();
    if (!doc.exists) return null;
    return Household.fromMap(doc.data()!, doc.id);
  }

  /// Household üyelerinin AppUser bilgilerini getirir
  Future<List<AppUser>> getHouseholdMembers(String householdId) async {
    final household = await getHousehold(householdId);
    if (household == null) {
      throw Exception('Aile planı bulunamadı.');
    }

    final List<AppUser> users = [];

    // Firestore 'in' sorgusu en fazla 10 eleman destekler
    // Üye sayısı genelde az olacağı için tek tek çekiyoruz
    for (final memberUid in household.members) {
      final doc = await _usersRef.doc(memberUid).get();
      if (doc.exists) {
        users.add(AppUser.fromMap(doc.data()!, doc.id));
      }
    }

    return users;
  }

  /// Yeni davet kodu üretir (sadece owner yapabilir, 24 saat TTL)
  Future<String> refreshInviteCode(
    String householdId,
    String ownerUid,
  ) async {
    final household = await getHousehold(householdId);
    if (household == null) {
      throw Exception('Aile planı bulunamadı.');
    }

    if (household.ownerUid != ownerUid) {
      throw Exception('Sadece aile planı sahibi davet kodunu yenileyebilir.');
    }

    final newCode = _generateInviteCode();
    final expiresAt = DateTime.now().add(_codeTtl);

    await _householdsRef.doc(householdId).update({
      'inviteCode': newCode,
      'inviteCodeExpiresAt': Timestamp.fromDate(expiresAt),
    });

    RemoteLoggerService.info(
      'household_invite_code_refreshed',
      extra: {'householdId': householdId},
    );

    return newCode;
  }

  /// Etkin UID'yi döner: Kullanıcı bir household'a üyeyse owner UID,
  /// değilse kendi UID'si. Veri paylaşımı için kullanılır.
  Future<String> getEffectiveUid(String uid) async {
    final userDoc = await _usersRef.doc(uid).get();
    final householdId = userDoc.data()?['householdId'] as String?;

    if (householdId == null) return uid;

    final household = await getHousehold(householdId);
    if (household == null) return uid;

    return household.ownerUid;
  }
}
