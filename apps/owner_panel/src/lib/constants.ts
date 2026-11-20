export const AMENITIES: { value: string; label: string }[] = [
  { value: 'otopark', label: 'Otopark' },
  { value: 'dus', label: 'Duş' },
  { value: 'kafeterya', label: 'Kafeterya' },
  { value: 'soyunma_odasi', label: 'Soyunma odası' },
  { value: 'krampon_kiralama', label: 'Krampon kiralama' },
  { value: 'wifi', label: 'Wi-Fi' },
];

export const PITCH_FORMATS = ['5v5', '6v6', '7v7', '8v8'] as const;
export const SLOT_MINUTES = [60, 90, 120] as const;

export const WEEKDAYS: { iso: number; label: string }[] = [
  { iso: 1, label: 'Pazartesi' },
  { iso: 2, label: 'Salı' },
  { iso: 3, label: 'Çarşamba' },
  { iso: 4, label: 'Perşembe' },
  { iso: 5, label: 'Cuma' },
  { iso: 6, label: 'Cumartesi' },
  { iso: 7, label: 'Pazar' },
];

export const STAFF_ROLES = ['owner', 'admin'] as const;
