import 'pitch.dart';

class VenueDetail {
  const VenueDetail({
    required this.id,
    required this.name,
    required this.description,
    required this.district,
    required this.address,
    required this.cancellationWindowHours,
    required this.photoPaths,
    required this.amenities,
    required this.pitches,
    this.lat,
    this.lng,
    this.phone,
    this.coverPhotoPath,
  });

  factory VenueDetail.fromJson(Map<String, dynamic> json) {
    final rawPitches = (json['pitches'] as List?) ?? const [];
    final pitches = rawPitches
        .map((e) => Pitch.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((p) => p.isActive)
        .toList()
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
      });
    return VenueDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
      district: (json['district'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      phone: json['phone'] as String?,
      coverPhotoPath: json['cover_photo_path'] as String?,
      photoPaths: ((json['photo_paths'] as List?) ?? const []).map((e) => e as String).toList(),
      amenities: ((json['amenities'] as List?) ?? const []).map((e) => e as String).toList(),
      cancellationWindowHours: (json['cancellation_window_hours'] as num?)?.toInt() ?? 24,
      pitches: pitches,
    );
  }

  final String id;
  final String name;
  final String description;
  final String district;
  final String address;
  final double? lat;
  final double? lng;
  final String? phone;
  final String? coverPhotoPath;
  final List<String> photoPaths;
  final List<String> amenities;
  final int cancellationWindowHours;
  final List<Pitch> pitches;

  /// Cover first, then the remaining photos without duplicates.
  List<String> get galleryPaths {
    final result = <String>[];
    if (coverPhotoPath != null && coverPhotoPath!.isNotEmpty) result.add(coverPhotoPath!);
    for (final p in photoPaths) {
      if (!result.contains(p)) result.add(p);
    }
    return result;
  }
}
