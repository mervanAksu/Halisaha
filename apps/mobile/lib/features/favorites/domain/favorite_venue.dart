/// A venue the user favourited (favorites joined with venues).
class FavoriteVenue {
  const FavoriteVenue({
    required this.venueId,
    required this.name,
    required this.district,
    required this.address,
    this.coverPhotoPath,
  });

  /// Row shape: `{created_at, venues: {id, name, district, address, cover_photo_path}}`.
  /// Returns null when the venue is no longer visible (e.g. suspended).
  static FavoriteVenue? fromJson(Map<String, dynamic> json) {
    final venue = json['venues'];
    if (venue is! Map) return null;
    return FavoriteVenue(
      venueId: venue['id'] as String,
      name: venue['name'] as String,
      district: (venue['district'] as String?) ?? '',
      address: (venue['address'] as String?) ?? '',
      coverPhotoPath: venue['cover_photo_path'] as String?,
    );
  }

  final String venueId;
  final String name;
  final String district;
  final String address;
  final String? coverPhotoPath;
}
