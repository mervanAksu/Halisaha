import '../features/venues/domain/pitch.dart';
import '../features/venues/domain/venue_detail.dart';
import '../features/venues/domain/venue_summary.dart';

/// Fictional venue used by the demo build. All names are invented.
class DemoVenue {
  const DemoVenue({
    required this.id,
    required this.name,
    required this.city,
    required this.district,
    required this.address,
    required this.description,
    required this.phone,
    required this.lat,
    required this.lng,
    required this.amenities,
    required this.cancellationWindowHours,
    required this.openMinutes,
    required this.closeMinutes,
    required this.pitches,
  });

  final String id;
  final String name;
  final String city;
  final String district;
  final String address;
  final String description;
  final String phone;
  final double lat;
  final double lng;
  final List<String> amenities;
  final int cancellationWindowHours;

  /// Opening / closing as minutes after midnight (Istanbul). `closeMinutes <= openMinutes`
  /// means the business day runs past midnight (12:00-06:00, or 10:00-00:00).
  final int openMinutes;
  final int closeMinutes;
  final List<Pitch> pitches;

  bool get isOvernight => closeMinutes <= openMinutes;

  int get minHourlyPriceKurus => pitches.map((p) => p.hourlyPriceKurus).reduce((a, b) => a < b ? a : b);

  static String _hhmm(int minutes) {
    final m = minutes % 1440;
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }

  String get openTime => _hhmm(openMinutes);
  String get closeTime => _hhmm(closeMinutes);

  VenueSummary toSummary({required bool isFavorite}) => VenueSummary(
        id: id,
        name: name,
        city: city,
        district: district,
        address: address,
        minHourlyPriceKurus: minHourlyPriceKurus,
        openTime: openTime,
        closeTime: closeTime,
        isFavorite: isFavorite,
      );

  VenueDetail toDetail() => VenueDetail(
        id: id,
        name: name,
        description: description,
        city: city,
        district: district,
        address: address,
        lat: lat,
        lng: lng,
        phone: phone,
        amenities: amenities,
        cancellationWindowHours: cancellationWindowHours,
        photoPaths: const [],
        pitches: pitches,
      );
}

Pitch _pitch(String id, String name, String format, {required int price, required int deposit, bool indoor = true, int order = 0}) {
  return Pitch(
    id: id,
    name: name,
    format: format,
    isIndoor: indoor,
    hourlyPriceKurus: price,
    depositKurus: deposit,
    slotMinutes: 60,
    sortOrder: order,
  );
}

/// Id of the venue that runs 12:00-06:00 (used by tests and the seeded upcoming match).
const String demoOvernightVenueId = 'demo-venue-2';

final List<DemoVenue> demoVenues = <DemoVenue>[
  DemoVenue(
    id: 'demo-venue-1',
    name: 'Mavi Çim Spor Tesisleri',
    city: 'İstanbul',
    district: 'Büyükçekmece',
    address: 'Sahil Yolu Cd. No: 14',
    description: 'Deniz manzaralı, tam ışıklandırmalı üç sahalı tesis. Hafta içi akşam saatleri hızlı dolar.',
    phone: '+902120000101',
    lat: 41.0206,
    lng: 28.5785,
    amenities: const ['otopark', 'dus', 'kafeterya', 'soyunma'],
    cancellationWindowHours: 24,
    openMinutes: 9 * 60,
    closeMinutes: 23 * 60,
    pitches: [
      _pitch('demo-pitch-1a', 'Saha 1', '7v7', price: 400000, deposit: 75000, order: 1),
      _pitch('demo-pitch-1b', 'Saha 2', '6v6', price: 350000, deposit: 60000, order: 2),
      _pitch('demo-pitch-1c', 'Saha 3', '5v5', price: 300000, deposit: 50000, indoor: false, order: 3),
    ],
  ),
  DemoVenue(
    id: demoOvernightVenueId,
    name: 'Gece Kuşu Arena',
    city: 'İstanbul',
    district: 'Esenyurt',
    address: 'Hadımköy Yolu Sk. No: 3',
    description: 'Öğleden sabaha kadar açık. Vardiya çıkışı ve gece maçları için ideal.',
    phone: '+902120000102',
    lat: 41.0343,
    lng: 28.6803,
    amenities: const ['otopark', 'dus', 'wifi'],
    cancellationWindowHours: 12,
    openMinutes: 12 * 60,
    closeMinutes: 6 * 60,
    pitches: [
      _pitch('demo-pitch-2a', 'Gece 1', '7v7', price: 420000, deposit: 70000, order: 1),
      _pitch('demo-pitch-2b', 'Gece 2', '6v6', price: 360000, deposit: 60000, order: 2),
    ],
  ),
  DemoVenue(
    id: 'demo-venue-3',
    name: 'Kıyı Park Halısaha',
    city: 'İstanbul',
    district: 'Beylikdüzü',
    address: 'Yaşam Vadisi Cd. No: 27',
    description: 'Park içinde, ailece gelinebilecek sakin bir tesis. Gece yarısına kadar açık.',
    phone: '+902120000103',
    lat: 41.0021,
    lng: 28.6401,
    amenities: const ['otopark', 'kafeterya', 'wifi'],
    cancellationWindowHours: 24,
    openMinutes: 10 * 60,
    closeMinutes: 0,
    pitches: [
      _pitch('demo-pitch-3a', 'Park 1', '7v7', price: 380000, deposit: 60000, order: 1),
      _pitch('demo-pitch-3b', 'Park 2', '5v5', price: 320000, deposit: 50000, indoor: false, order: 2),
    ],
  ),
  DemoVenue(
    id: 'demo-venue-4',
    name: 'Yeşil Vadi Spor Kulübü',
    city: 'İstanbul',
    district: 'Kadıköy',
    address: 'Bağdat Cd. Çınar Sk. No: 8',
    description: 'Kadıköy sırtlarında, şehir içinde kapalı ve açık seçenekli butik tesis.',
    phone: '+902160000104',
    lat: 40.9879,
    lng: 29.0372,
    amenities: const ['dus', 'soyunma', 'kafeterya'],
    cancellationWindowHours: 24,
    openMinutes: 8 * 60,
    closeMinutes: 23 * 60,
    pitches: [
      _pitch('demo-pitch-4a', 'Vadi A', '7v7', price: 450000, deposit: 75000, order: 1),
      _pitch('demo-pitch-4b', 'Vadi B', '6v6', price: 400000, deposit: 70000, order: 2),
    ],
  ),
  DemoVenue(
    id: 'demo-venue-5',
    name: 'Atlas Spor Kompleksi',
    city: 'İstanbul',
    district: 'Ataşehir',
    address: 'Küçükbakkalköy Mh. Atlas Sk. No: 21',
    description: 'Modern soyunma odaları ve geniş otoparkıyla şirket turnuvalarının favorisi.',
    phone: '+902160000105',
    lat: 40.9923,
    lng: 29.1244,
    amenities: const ['otopark', 'dus', 'soyunma', 'wifi'],
    cancellationWindowHours: 48,
    openMinutes: 9 * 60,
    closeMinutes: 1 * 60,
    pitches: [
      _pitch('demo-pitch-5a', 'Atlas 1', '7v7', price: 440000, deposit: 75000, order: 1),
      _pitch('demo-pitch-5b', 'Atlas 2', '7v7', price: 430000, deposit: 75000, order: 2),
      _pitch('demo-pitch-5c', 'Atlas 3', '5v5', price: 310000, deposit: 50000, order: 3),
    ],
  ),
  DemoVenue(
    id: 'demo-venue-6',
    name: 'Martı Sahil Arena',
    city: 'İstanbul',
    district: 'Büyükçekmece',
    address: 'Kumburgaz Sahil Cd. No: 52',
    description: 'Yaz akşamlarında deniz kenarında oynamak isteyenler için açık saha ağırlıklı tesis.',
    phone: '+902120000106',
    lat: 41.0182,
    lng: 28.4411,
    amenities: const ['otopark', 'kafeterya'],
    cancellationWindowHours: 24,
    openMinutes: 11 * 60,
    closeMinutes: 23 * 60,
    pitches: [
      _pitch('demo-pitch-6a', 'Martı 1', '6v6', price: 340000, deposit: 50000, indoor: false, order: 1),
      _pitch('demo-pitch-6b', 'Martı 2', '5v5', price: 300000, deposit: 50000, indoor: false, order: 2),
    ],
  ),
  DemoVenue(
    id: 'demo-venue-7',
    name: 'Bornova Gol Park',
    city: 'İzmir',
    district: 'Bornova',
    address: 'Kazımdirik Mh. Gol Sk. No: 5',
    description: 'Kampüs çevresinde, öğrenci takımlarının ve mahalle liglerinin uğrak noktası kapalı ve açık saha tesisi.',
    phone: '+902320000107',
    lat: 38.4622,
    lng: 27.2214,
    amenities: const ['otopark', 'dus', 'kafeterya'],
    cancellationWindowHours: 24,
    openMinutes: 10 * 60,
    closeMinutes: 0,
    pitches: [
      _pitch('demo-pitch-7a', 'Gol 1', '7v7', price: 360000, deposit: 60000, order: 1),
      _pitch('demo-pitch-7b', 'Gol 2', '5v5', price: 280000, deposit: 50000, indoor: false, order: 2),
    ],
  ),
  DemoVenue(
    id: 'demo-venue-8',
    name: 'Efeler Spor Sahası',
    city: 'Aydın',
    district: 'Efeler',
    address: 'Hasan Efendi Mh. Spor Cd. No: 12',
    description: 'Şehir merkezine yakın, akşam saatlerinde ışıklandırmalı sakin bir halı saha.',
    phone: '+902560000108',
    lat: 37.8560,
    lng: 27.8416,
    amenities: const ['otopark', 'soyunma'],
    cancellationWindowHours: 24,
    openMinutes: 12 * 60,
    closeMinutes: 23 * 60,
    pitches: [
      _pitch('demo-pitch-8a', 'Efe 1', '6v6', price: 300000, deposit: 50000, order: 1),
      _pitch('demo-pitch-8b', 'Efe 2', '5v5', price: 260000, deposit: 40000, indoor: false, order: 2),
    ],
  ),
];
