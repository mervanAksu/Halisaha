-- =====================================================================================================
-- 20261122090000_location_filter.sql — il → ilçe konum filtresi (ADR-11, docs/DATA_MODEL.md "Konum").
--
-- Reference data: 81 il / 973 ilçe.
--   Source: T.C. İçişleri Bakanlığı e-icisleri il/ilçe list via github.com/mertmtn/CityDistrictJSONAPI (2023),
--   cross-checked against github.com/ubeydeozdmr/turkiye-api (2025, MIT).
--   Corrections: one typo fixed (Ankara "Amak" → "Mamak"). Names use Turkish casing ("Ataşehir", "Merkez").
-- These tables change only through migrations: everyone may read them, nobody may write them.
-- =====================================================================================================

-- ---------------------------------------------------------------------------
-- 1. Reference tables
-- ---------------------------------------------------------------------------
create table public.tr_provinces (
  plate smallint primary key,
  name  text not null unique
);

create table public.tr_districts (
  province text not null references public.tr_provinces (name) on update cascade,
  name     text not null,
  primary key (province, name)
);

alter table public.tr_provinces enable row level security;
alter table public.tr_districts enable row level security;

create policy "tr_provinces_select_all" on public.tr_provinces for select to anon, authenticated using (true);
create policy "tr_districts_select_all" on public.tr_districts for select to anon, authenticated using (true);
-- No insert/update/delete policies: with RLS on, writes are denied even if a grant slipped through.

revoke all on public.tr_provinces, public.tr_districts from public, anon, authenticated;
grant select on public.tr_provinces, public.tr_districts to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Data
-- ---------------------------------------------------------------------------
insert into public.tr_provinces (plate, name) values
  (1, 'Adana'),
  (2, 'Adıyaman'),
  (3, 'Afyonkarahisar'),
  (4, 'Ağrı'),
  (5, 'Amasya'),
  (6, 'Ankara'),
  (7, 'Antalya'),
  (8, 'Artvin'),
  (9, 'Aydın'),
  (10, 'Balıkesir'),
  (11, 'Bilecik'),
  (12, 'Bingöl'),
  (13, 'Bitlis'),
  (14, 'Bolu'),
  (15, 'Burdur'),
  (16, 'Bursa'),
  (17, 'Çanakkale'),
  (18, 'Çankırı'),
  (19, 'Çorum'),
  (20, 'Denizli'),
  (21, 'Diyarbakır'),
  (22, 'Edirne'),
  (23, 'Elazığ'),
  (24, 'Erzincan'),
  (25, 'Erzurum'),
  (26, 'Eskişehir'),
  (27, 'Gaziantep'),
  (28, 'Giresun'),
  (29, 'Gümüşhane'),
  (30, 'Hakkari'),
  (31, 'Hatay'),
  (32, 'Isparta'),
  (33, 'Mersin'),
  (34, 'İstanbul'),
  (35, 'İzmir'),
  (36, 'Kars'),
  (37, 'Kastamonu'),
  (38, 'Kayseri'),
  (39, 'Kırklareli'),
  (40, 'Kırşehir'),
  (41, 'Kocaeli'),
  (42, 'Konya'),
  (43, 'Kütahya'),
  (44, 'Malatya'),
  (45, 'Manisa'),
  (46, 'Kahramanmaraş'),
  (47, 'Mardin'),
  (48, 'Muğla'),
  (49, 'Muş'),
  (50, 'Nevşehir'),
  (51, 'Niğde'),
  (52, 'Ordu'),
  (53, 'Rize'),
  (54, 'Sakarya'),
  (55, 'Samsun'),
  (56, 'Siirt'),
  (57, 'Sinop'),
  (58, 'Sivas'),
  (59, 'Tekirdağ'),
  (60, 'Tokat'),
  (61, 'Trabzon'),
  (62, 'Tunceli'),
  (63, 'Şanlıurfa'),
  (64, 'Uşak'),
  (65, 'Van'),
  (66, 'Yozgat'),
  (67, 'Zonguldak'),
  (68, 'Aksaray'),
  (69, 'Bayburt'),
  (70, 'Karaman'),
  (71, 'Kırıkkale'),
  (72, 'Batman'),
  (73, 'Şırnak'),
  (74, 'Bartın'),
  (75, 'Ardahan'),
  (76, 'Iğdır'),
  (77, 'Yalova'),
  (78, 'Karabük'),
  (79, 'Kilis'),
  (80, 'Osmaniye'),
  (81, 'Düzce');

insert into public.tr_districts (province, name) values
  ('Adana', 'Aladağ'), ('Adana', 'Ceyhan'), ('Adana', 'Çukurova'), ('Adana', 'Feke'), ('Adana', 'İmamoğlu'), ('Adana', 'Karaisalı'), ('Adana', 'Karataş'), ('Adana', 'Kozan'), ('Adana', 'Pozantı'), ('Adana', 'Saimbeyli'), ('Adana', 'Sarıçam'), ('Adana', 'Seyhan'), ('Adana', 'Tufanbeyli'), ('Adana', 'Yumurtalık'), ('Adana', 'Yüreğir'),
  ('Adıyaman', 'Besni'), ('Adıyaman', 'Çelikhan'), ('Adıyaman', 'Gerger'), ('Adıyaman', 'Gölbaşı'), ('Adıyaman', 'Kahta'), ('Adıyaman', 'Merkez'), ('Adıyaman', 'Samsat'), ('Adıyaman', 'Sincik'), ('Adıyaman', 'Tut'),
  ('Afyonkarahisar', 'Başmakçı'), ('Afyonkarahisar', 'Bayat'), ('Afyonkarahisar', 'Bolvadin'), ('Afyonkarahisar', 'Çay'), ('Afyonkarahisar', 'Çobanlar'), ('Afyonkarahisar', 'Dazkırı'), ('Afyonkarahisar', 'Dinar'), ('Afyonkarahisar', 'Emirdağ'), ('Afyonkarahisar', 'Evciler'), ('Afyonkarahisar', 'Hocalar'), ('Afyonkarahisar', 'İhsaniye'), ('Afyonkarahisar', 'İscehisar'), ('Afyonkarahisar', 'Kızılören'), ('Afyonkarahisar', 'Merkez'), ('Afyonkarahisar', 'Sandıklı'), ('Afyonkarahisar', 'Sinanpaşa'), ('Afyonkarahisar', 'Sultandağı'), ('Afyonkarahisar', 'Şuhut'),
  ('Ağrı', 'Diyadin'), ('Ağrı', 'Doğubayazıt'), ('Ağrı', 'Eleşkirt'), ('Ağrı', 'Hamur'), ('Ağrı', 'Merkez'), ('Ağrı', 'Patnos'), ('Ağrı', 'Taşlıçay'), ('Ağrı', 'Tutak'),
  ('Amasya', 'Göynücek'), ('Amasya', 'Gümüşhacıköy'), ('Amasya', 'Hamamözü'), ('Amasya', 'Merkez'), ('Amasya', 'Merzifon'), ('Amasya', 'Suluova'), ('Amasya', 'Taşova'),
  ('Ankara', 'Akyurt'), ('Ankara', 'Altındağ'), ('Ankara', 'Ayaş'), ('Ankara', 'Bala'), ('Ankara', 'Beypazarı'), ('Ankara', 'Çamlıdere'), ('Ankara', 'Çankaya'), ('Ankara', 'Çubuk'), ('Ankara', 'Elmadağ'), ('Ankara', 'Etimesgut'), ('Ankara', 'Evren'), ('Ankara', 'Gölbaşı'), ('Ankara', 'Güdül'), ('Ankara', 'Haymana'), ('Ankara', 'Kahramankazan'), ('Ankara', 'Kalecik'), ('Ankara', 'Keçiören'), ('Ankara', 'Kızılcahamam'), ('Ankara', 'Mamak'), ('Ankara', 'Nallıhan'), ('Ankara', 'Polatlı'), ('Ankara', 'Pursaklar'), ('Ankara', 'Sincan'), ('Ankara', 'Şereflikoçhisar'), ('Ankara', 'Yenimahalle'),
  ('Antalya', 'Akseki'), ('Antalya', 'Aksu'), ('Antalya', 'Alanya'), ('Antalya', 'Demre'), ('Antalya', 'Döşemealtı'), ('Antalya', 'Elmalı'), ('Antalya', 'Finike'), ('Antalya', 'Gazipaşa'), ('Antalya', 'Gündoğmuş'), ('Antalya', 'İbradı'), ('Antalya', 'Kaş'), ('Antalya', 'Kemer'), ('Antalya', 'Kepez'), ('Antalya', 'Konyaaltı'), ('Antalya', 'Korkuteli'), ('Antalya', 'Kumluca'), ('Antalya', 'Manavgat'), ('Antalya', 'Muratpaşa'), ('Antalya', 'Serik'),
  ('Artvin', 'Ardanuç'), ('Artvin', 'Arhavi'), ('Artvin', 'Borçka'), ('Artvin', 'Hopa'), ('Artvin', 'Kemalpaşa'), ('Artvin', 'Merkez'), ('Artvin', 'Murgul'), ('Artvin', 'Şavşat'), ('Artvin', 'Yusufeli'),
  ('Aydın', 'Bozdoğan'), ('Aydın', 'Buharkent'), ('Aydın', 'Çine'), ('Aydın', 'Didim'), ('Aydın', 'Efeler'), ('Aydın', 'Germencik'), ('Aydın', 'İncirliova'), ('Aydın', 'Karacasu'), ('Aydın', 'Karpuzlu'), ('Aydın', 'Koçarlı'), ('Aydın', 'Köşk'), ('Aydın', 'Kuşadası'), ('Aydın', 'Kuyucak'), ('Aydın', 'Nazilli'), ('Aydın', 'Söke'), ('Aydın', 'Sultanhisar'), ('Aydın', 'Yenipazar'),
  ('Balıkesir', 'Altıeylül'), ('Balıkesir', 'Ayvalık'), ('Balıkesir', 'Balya'), ('Balıkesir', 'Bandırma'), ('Balıkesir', 'Bigadiç'), ('Balıkesir', 'Burhaniye'), ('Balıkesir', 'Dursunbey'), ('Balıkesir', 'Edremit'), ('Balıkesir', 'Erdek'), ('Balıkesir', 'Gömeç'), ('Balıkesir', 'Gönen'), ('Balıkesir', 'Havran'), ('Balıkesir', 'İvrindi'), ('Balıkesir', 'Karesi'), ('Balıkesir', 'Kepsut'), ('Balıkesir', 'Manyas'), ('Balıkesir', 'Marmara'), ('Balıkesir', 'Savaştepe'), ('Balıkesir', 'Sındırgı'), ('Balıkesir', 'Susurluk'),
  ('Bilecik', 'Bozüyük'), ('Bilecik', 'Gölpazarı'), ('Bilecik', 'İnhisar'), ('Bilecik', 'Merkez'), ('Bilecik', 'Osmaneli'), ('Bilecik', 'Pazaryeri'), ('Bilecik', 'Söğüt'), ('Bilecik', 'Yenipazar'),
  ('Bingöl', 'Adaklı'), ('Bingöl', 'Genç'), ('Bingöl', 'Karlıova'), ('Bingöl', 'Kiğı'), ('Bingöl', 'Merkez'), ('Bingöl', 'Solhan'), ('Bingöl', 'Yayladere'), ('Bingöl', 'Yedisu'),
  ('Bitlis', 'Adilcevaz'), ('Bitlis', 'Ahlat'), ('Bitlis', 'Güroymak'), ('Bitlis', 'Hizan'), ('Bitlis', 'Merkez'), ('Bitlis', 'Mutki'), ('Bitlis', 'Tatvan'),
  ('Bolu', 'Dörtdivan'), ('Bolu', 'Gerede'), ('Bolu', 'Göynük'), ('Bolu', 'Kıbrıscık'), ('Bolu', 'Mengen'), ('Bolu', 'Merkez'), ('Bolu', 'Mudurnu'), ('Bolu', 'Seben'), ('Bolu', 'Yeniçağa'),
  ('Burdur', 'Ağlasun'), ('Burdur', 'Altınyayla'), ('Burdur', 'Bucak'), ('Burdur', 'Çavdır'), ('Burdur', 'Çeltikçi'), ('Burdur', 'Gölhisar'), ('Burdur', 'Karamanlı'), ('Burdur', 'Kemer'), ('Burdur', 'Merkez'), ('Burdur', 'Tefenni'), ('Burdur', 'Yeşilova'),
  ('Bursa', 'Büyükorhan'), ('Bursa', 'Gemlik'), ('Bursa', 'Gürsu'), ('Bursa', 'Harmancık'), ('Bursa', 'İnegöl'), ('Bursa', 'İznik'), ('Bursa', 'Karacabey'), ('Bursa', 'Keles'), ('Bursa', 'Kestel'), ('Bursa', 'Mudanya'), ('Bursa', 'Mustafakemalpaşa'), ('Bursa', 'Nilüfer'), ('Bursa', 'Orhaneli'), ('Bursa', 'Orhangazi'), ('Bursa', 'Osmangazi'), ('Bursa', 'Yenişehir'), ('Bursa', 'Yıldırım'),
  ('Çanakkale', 'Ayvacık'), ('Çanakkale', 'Bayramiç'), ('Çanakkale', 'Biga'), ('Çanakkale', 'Bozcaada'), ('Çanakkale', 'Çan'), ('Çanakkale', 'Eceabat'), ('Çanakkale', 'Ezine'), ('Çanakkale', 'Gelibolu'), ('Çanakkale', 'Gökçeada'), ('Çanakkale', 'Lapseki'), ('Çanakkale', 'Merkez'), ('Çanakkale', 'Yenice'),
  ('Çankırı', 'Atkaracalar'), ('Çankırı', 'Bayramören'), ('Çankırı', 'Çerkeş'), ('Çankırı', 'Eldivan'), ('Çankırı', 'Ilgaz'), ('Çankırı', 'Kızılırmak'), ('Çankırı', 'Korgun'), ('Çankırı', 'Kurşunlu'), ('Çankırı', 'Merkez'), ('Çankırı', 'Orta'), ('Çankırı', 'Şabanözü'), ('Çankırı', 'Yapraklı'),
  ('Çorum', 'Alaca'), ('Çorum', 'Bayat'), ('Çorum', 'Boğazkale'), ('Çorum', 'Dodurga'), ('Çorum', 'İskilip'), ('Çorum', 'Kargı'), ('Çorum', 'Laçin'), ('Çorum', 'Mecitözü'), ('Çorum', 'Merkez'), ('Çorum', 'Oğuzlar'), ('Çorum', 'Ortaköy'), ('Çorum', 'Osmancık'), ('Çorum', 'Sungurlu'), ('Çorum', 'Uğurludağ'),
  ('Denizli', 'Acıpayam'), ('Denizli', 'Babadağ'), ('Denizli', 'Baklan'), ('Denizli', 'Bekilli'), ('Denizli', 'Beyağaç'), ('Denizli', 'Bozkurt'), ('Denizli', 'Buldan'), ('Denizli', 'Çal'), ('Denizli', 'Çameli'), ('Denizli', 'Çardak'), ('Denizli', 'Çivril'), ('Denizli', 'Güney'), ('Denizli', 'Honaz'), ('Denizli', 'Kale'), ('Denizli', 'Merkezefendi'), ('Denizli', 'Pamukkale'), ('Denizli', 'Sarayköy'), ('Denizli', 'Serinhisar'), ('Denizli', 'Tavas'),
  ('Diyarbakır', 'Bağlar'), ('Diyarbakır', 'Bismil'), ('Diyarbakır', 'Çermik'), ('Diyarbakır', 'Çınar'), ('Diyarbakır', 'Çüngüş'), ('Diyarbakır', 'Dicle'), ('Diyarbakır', 'Eğil'), ('Diyarbakır', 'Ergani'), ('Diyarbakır', 'Hani'), ('Diyarbakır', 'Hazro'), ('Diyarbakır', 'Kayapınar'), ('Diyarbakır', 'Kocaköy'), ('Diyarbakır', 'Kulp'), ('Diyarbakır', 'Lice'), ('Diyarbakır', 'Silvan'), ('Diyarbakır', 'Sur'), ('Diyarbakır', 'Yenişehir'),
  ('Edirne', 'Enez'), ('Edirne', 'Havsa'), ('Edirne', 'İpsala'), ('Edirne', 'Keşan'), ('Edirne', 'Lalapaşa'), ('Edirne', 'Meriç'), ('Edirne', 'Merkez'), ('Edirne', 'Süloğlu'), ('Edirne', 'Uzunköprü'),
  ('Elazığ', 'Ağın'), ('Elazığ', 'Alacakaya'), ('Elazığ', 'Arıcak'), ('Elazığ', 'Baskil'), ('Elazığ', 'Karakoçan'), ('Elazığ', 'Keban'), ('Elazığ', 'Kovancılar'), ('Elazığ', 'Maden'), ('Elazığ', 'Merkez'), ('Elazığ', 'Palu'), ('Elazığ', 'Sivrice'),
  ('Erzincan', 'Çayırlı'), ('Erzincan', 'İliç'), ('Erzincan', 'Kemah'), ('Erzincan', 'Kemaliye'), ('Erzincan', 'Merkez'), ('Erzincan', 'Otlukbeli'), ('Erzincan', 'Refahiye'), ('Erzincan', 'Tercan'), ('Erzincan', 'Üzümlü'),
  ('Erzurum', 'Aşkale'), ('Erzurum', 'Aziziye'), ('Erzurum', 'Çat'), ('Erzurum', 'Hınıs'), ('Erzurum', 'Horasan'), ('Erzurum', 'İspir'), ('Erzurum', 'Karaçoban'), ('Erzurum', 'Karayazı'), ('Erzurum', 'Köprüköy'), ('Erzurum', 'Narman'), ('Erzurum', 'Oltu'), ('Erzurum', 'Olur'), ('Erzurum', 'Palandöken'), ('Erzurum', 'Pasinler'), ('Erzurum', 'Pazaryolu'), ('Erzurum', 'Şenkaya'), ('Erzurum', 'Tekman'), ('Erzurum', 'Tortum'), ('Erzurum', 'Uzundere'), ('Erzurum', 'Yakutiye'),
  ('Eskişehir', 'Alpu'), ('Eskişehir', 'Beylikova'), ('Eskişehir', 'Çifteler'), ('Eskişehir', 'Günyüzü'), ('Eskişehir', 'Han'), ('Eskişehir', 'İnönü'), ('Eskişehir', 'Mahmudiye'), ('Eskişehir', 'Mihalgazi'), ('Eskişehir', 'Mihalıççık'), ('Eskişehir', 'Odunpazarı'), ('Eskişehir', 'Sarıcakaya'), ('Eskişehir', 'Seyitgazi'), ('Eskişehir', 'Sivrihisar'), ('Eskişehir', 'Tepebaşı'),
  ('Gaziantep', 'Araban'), ('Gaziantep', 'İslahiye'), ('Gaziantep', 'Karkamış'), ('Gaziantep', 'Nizip'), ('Gaziantep', 'Nurdağı'), ('Gaziantep', 'Oğuzeli'), ('Gaziantep', 'Şahinbey'), ('Gaziantep', 'Şehitkamil'), ('Gaziantep', 'Yavuzeli'),
  ('Giresun', 'Alucra'), ('Giresun', 'Bulancak'), ('Giresun', 'Çamoluk'), ('Giresun', 'Çanakçı'), ('Giresun', 'Dereli'), ('Giresun', 'Doğankent'), ('Giresun', 'Espiye'), ('Giresun', 'Eynesil'), ('Giresun', 'Görele'), ('Giresun', 'Güce'), ('Giresun', 'Keşap'), ('Giresun', 'Merkez'), ('Giresun', 'Piraziz'), ('Giresun', 'Şebinkarahisar'), ('Giresun', 'Tirebolu'), ('Giresun', 'Yağlıdere'),
  ('Gümüşhane', 'Kelkit'), ('Gümüşhane', 'Köse'), ('Gümüşhane', 'Kürtün'), ('Gümüşhane', 'Merkez'), ('Gümüşhane', 'Şiran'), ('Gümüşhane', 'Torul'),
  ('Hakkari', 'Çukurca'), ('Hakkari', 'Derecik'), ('Hakkari', 'Merkez'), ('Hakkari', 'Şemdinli'), ('Hakkari', 'Yüksekova'),
  ('Hatay', 'Altınözü'), ('Hatay', 'Antakya'), ('Hatay', 'Arsuz'), ('Hatay', 'Belen'), ('Hatay', 'Defne'), ('Hatay', 'Dörtyol'), ('Hatay', 'Erzin'), ('Hatay', 'Hassa'), ('Hatay', 'İskenderun'), ('Hatay', 'Kırıkhan'), ('Hatay', 'Kumlu'), ('Hatay', 'Payas'), ('Hatay', 'Reyhanlı'), ('Hatay', 'Samandağ'), ('Hatay', 'Yayladağı'),
  ('Isparta', 'Aksu'), ('Isparta', 'Atabey'), ('Isparta', 'Eğirdir'), ('Isparta', 'Gelendost'), ('Isparta', 'Gönen'), ('Isparta', 'Keçiborlu'), ('Isparta', 'Merkez'), ('Isparta', 'Senirkent'), ('Isparta', 'Sütçüler'), ('Isparta', 'Şarkikaraağaç'), ('Isparta', 'Uluborlu'), ('Isparta', 'Yalvaç'), ('Isparta', 'Yenişarbademli'),
  ('Mersin', 'Akdeniz'), ('Mersin', 'Anamur'), ('Mersin', 'Aydıncık'), ('Mersin', 'Bozyazı'), ('Mersin', 'Çamlıyayla'), ('Mersin', 'Erdemli'), ('Mersin', 'Gülnar'), ('Mersin', 'Mezitli'), ('Mersin', 'Mut'), ('Mersin', 'Silifke'), ('Mersin', 'Tarsus'), ('Mersin', 'Toroslar'), ('Mersin', 'Yenişehir'),
  ('İstanbul', 'Adalar'), ('İstanbul', 'Arnavutköy'), ('İstanbul', 'Ataşehir'), ('İstanbul', 'Avcılar'), ('İstanbul', 'Bağcılar'), ('İstanbul', 'Bahçelievler'), ('İstanbul', 'Bakırköy'), ('İstanbul', 'Başakşehir'), ('İstanbul', 'Bayrampaşa'), ('İstanbul', 'Beşiktaş'), ('İstanbul', 'Beykoz'), ('İstanbul', 'Beylikdüzü'), ('İstanbul', 'Beyoğlu'), ('İstanbul', 'Büyükçekmece'), ('İstanbul', 'Çatalca'), ('İstanbul', 'Çekmeköy'), ('İstanbul', 'Esenler'), ('İstanbul', 'Esenyurt'), ('İstanbul', 'Eyüpsultan'), ('İstanbul', 'Fatih'), ('İstanbul', 'Gaziosmanpaşa'), ('İstanbul', 'Güngören'), ('İstanbul', 'Kadıköy'), ('İstanbul', 'Kağıthane'), ('İstanbul', 'Kartal'), ('İstanbul', 'Küçükçekmece'), ('İstanbul', 'Maltepe'), ('İstanbul', 'Pendik'), ('İstanbul', 'Sancaktepe'), ('İstanbul', 'Sarıyer'), ('İstanbul', 'Silivri'), ('İstanbul', 'Sultanbeyli'), ('İstanbul', 'Sultangazi'), ('İstanbul', 'Şile'), ('İstanbul', 'Şişli'), ('İstanbul', 'Tuzla'), ('İstanbul', 'Ümraniye'), ('İstanbul', 'Üsküdar'), ('İstanbul', 'Zeytinburnu'),
  ('İzmir', 'Aliağa'), ('İzmir', 'Balçova'), ('İzmir', 'Bayındır'), ('İzmir', 'Bayraklı'), ('İzmir', 'Bergama'), ('İzmir', 'Beydağ'), ('İzmir', 'Bornova'), ('İzmir', 'Buca'), ('İzmir', 'Çeşme'), ('İzmir', 'Çiğli'), ('İzmir', 'Dikili'), ('İzmir', 'Foça'), ('İzmir', 'Gaziemir'), ('İzmir', 'Güzelbahçe'), ('İzmir', 'Karabağlar'), ('İzmir', 'Karaburun'), ('İzmir', 'Karşıyaka'), ('İzmir', 'Kemalpaşa'), ('İzmir', 'Kınık'), ('İzmir', 'Kiraz'), ('İzmir', 'Konak'), ('İzmir', 'Menderes'), ('İzmir', 'Menemen'), ('İzmir', 'Narlıdere'), ('İzmir', 'Ödemiş'), ('İzmir', 'Seferihisar'), ('İzmir', 'Selçuk'), ('İzmir', 'Tire'), ('İzmir', 'Torbalı'), ('İzmir', 'Urla'),
  ('Kars', 'Akyaka'), ('Kars', 'Arpaçay'), ('Kars', 'Digor'), ('Kars', 'Kağızman'), ('Kars', 'Merkez'), ('Kars', 'Sarıkamış'), ('Kars', 'Selim'), ('Kars', 'Susuz'),
  ('Kastamonu', 'Abana'), ('Kastamonu', 'Ağlı'), ('Kastamonu', 'Araç'), ('Kastamonu', 'Azdavay'), ('Kastamonu', 'Bozkurt'), ('Kastamonu', 'Cide'), ('Kastamonu', 'Çatalzeytin'), ('Kastamonu', 'Daday'), ('Kastamonu', 'Devrekani'), ('Kastamonu', 'Doğanyurt'), ('Kastamonu', 'Hanönü'), ('Kastamonu', 'İhsangazi'), ('Kastamonu', 'İnebolu'), ('Kastamonu', 'Küre'), ('Kastamonu', 'Merkez'), ('Kastamonu', 'Pınarbaşı'), ('Kastamonu', 'Seydiler'), ('Kastamonu', 'Şenpazar'), ('Kastamonu', 'Taşköprü'), ('Kastamonu', 'Tosya'),
  ('Kayseri', 'Akkışla'), ('Kayseri', 'Bünyan'), ('Kayseri', 'Develi'), ('Kayseri', 'Felahiye'), ('Kayseri', 'Hacılar'), ('Kayseri', 'İncesu'), ('Kayseri', 'Kocasinan'), ('Kayseri', 'Melikgazi'), ('Kayseri', 'Özvatan'), ('Kayseri', 'Pınarbaşı'), ('Kayseri', 'Sarıoğlan'), ('Kayseri', 'Sarız'), ('Kayseri', 'Talas'), ('Kayseri', 'Tomarza'), ('Kayseri', 'Yahyalı'), ('Kayseri', 'Yeşilhisar'),
  ('Kırklareli', 'Babaeski'), ('Kırklareli', 'Demirköy'), ('Kırklareli', 'Kofçaz'), ('Kırklareli', 'Lüleburgaz'), ('Kırklareli', 'Merkez'), ('Kırklareli', 'Pehlivanköy'), ('Kırklareli', 'Pınarhisar'), ('Kırklareli', 'Vize'),
  ('Kırşehir', 'Akçakent'), ('Kırşehir', 'Akpınar'), ('Kırşehir', 'Boztepe'), ('Kırşehir', 'Çiçekdağı'), ('Kırşehir', 'Kaman'), ('Kırşehir', 'Merkez'), ('Kırşehir', 'Mucur'),
  ('Kocaeli', 'Başiskele'), ('Kocaeli', 'Çayırova'), ('Kocaeli', 'Darıca'), ('Kocaeli', 'Derince'), ('Kocaeli', 'Dilovası'), ('Kocaeli', 'Gebze'), ('Kocaeli', 'Gölcük'), ('Kocaeli', 'İzmit'), ('Kocaeli', 'Kandıra'), ('Kocaeli', 'Karamürsel'), ('Kocaeli', 'Kartepe'), ('Kocaeli', 'Körfez'),
  ('Konya', 'Ahırlı'), ('Konya', 'Akören'), ('Konya', 'Akşehir'), ('Konya', 'Altınekin'), ('Konya', 'Beyşehir'), ('Konya', 'Bozkır'), ('Konya', 'Cihanbeyli'), ('Konya', 'Çeltik'), ('Konya', 'Çumra'), ('Konya', 'Derbent'), ('Konya', 'Derebucak'), ('Konya', 'Doğanhisar'), ('Konya', 'Emirgazi'), ('Konya', 'Ereğli'), ('Konya', 'Güneysınır'), ('Konya', 'Hadim'), ('Konya', 'Halkapınar'), ('Konya', 'Hüyük'), ('Konya', 'Ilgın'), ('Konya', 'Kadınhanı'), ('Konya', 'Karapınar'), ('Konya', 'Karatay'), ('Konya', 'Kulu'), ('Konya', 'Meram'), ('Konya', 'Sarayönü'), ('Konya', 'Selçuklu'), ('Konya', 'Seydişehir'), ('Konya', 'Taşkent'), ('Konya', 'Tuzlukçu'), ('Konya', 'Yalıhüyük'), ('Konya', 'Yunak'),
  ('Kütahya', 'Altıntaş'), ('Kütahya', 'Aslanapa'), ('Kütahya', 'Çavdarhisar'), ('Kütahya', 'Domaniç'), ('Kütahya', 'Dumlupınar'), ('Kütahya', 'Emet'), ('Kütahya', 'Gediz'), ('Kütahya', 'Hisarcık'), ('Kütahya', 'Merkez'), ('Kütahya', 'Pazarlar'), ('Kütahya', 'Simav'), ('Kütahya', 'Şaphane'), ('Kütahya', 'Tavşanlı'),
  ('Malatya', 'Akçadağ'), ('Malatya', 'Arapgir'), ('Malatya', 'Arguvan'), ('Malatya', 'Battalgazi'), ('Malatya', 'Darende'), ('Malatya', 'Doğanşehir'), ('Malatya', 'Doğanyol'), ('Malatya', 'Hekimhan'), ('Malatya', 'Kale'), ('Malatya', 'Kuluncak'), ('Malatya', 'Pütürge'), ('Malatya', 'Yazıhan'), ('Malatya', 'Yeşilyurt'),
  ('Manisa', 'Ahmetli'), ('Manisa', 'Akhisar'), ('Manisa', 'Alaşehir'), ('Manisa', 'Demirci'), ('Manisa', 'Gölmarmara'), ('Manisa', 'Gördes'), ('Manisa', 'Kırkağaç'), ('Manisa', 'Köprübaşı'), ('Manisa', 'Kula'), ('Manisa', 'Salihli'), ('Manisa', 'Sarıgöl'), ('Manisa', 'Saruhanlı'), ('Manisa', 'Selendi'), ('Manisa', 'Soma'), ('Manisa', 'Şehzadeler'), ('Manisa', 'Turgutlu'), ('Manisa', 'Yunusemre'),
  ('Kahramanmaraş', 'Afşin'), ('Kahramanmaraş', 'Andırın'), ('Kahramanmaraş', 'Çağlayancerit'), ('Kahramanmaraş', 'Dulkadiroğlu'), ('Kahramanmaraş', 'Ekinözü'), ('Kahramanmaraş', 'Elbistan'), ('Kahramanmaraş', 'Göksun'), ('Kahramanmaraş', 'Nurhak'), ('Kahramanmaraş', 'Onikişubat'), ('Kahramanmaraş', 'Pazarcık'), ('Kahramanmaraş', 'Türkoğlu'),
  ('Mardin', 'Artuklu'), ('Mardin', 'Dargeçit'), ('Mardin', 'Derik'), ('Mardin', 'Kızıltepe'), ('Mardin', 'Mazıdağı'), ('Mardin', 'Midyat'), ('Mardin', 'Nusaybin'), ('Mardin', 'Ömerli'), ('Mardin', 'Savur'), ('Mardin', 'Yeşilli'),
  ('Muğla', 'Bodrum'), ('Muğla', 'Dalaman'), ('Muğla', 'Datça'), ('Muğla', 'Fethiye'), ('Muğla', 'Kavaklıdere'), ('Muğla', 'Köyceğiz'), ('Muğla', 'Marmaris'), ('Muğla', 'Menteşe'), ('Muğla', 'Milas'), ('Muğla', 'Ortaca'), ('Muğla', 'Seydikemer'), ('Muğla', 'Ula'), ('Muğla', 'Yatağan'),
  ('Muş', 'Bulanık'), ('Muş', 'Hasköy'), ('Muş', 'Korkut'), ('Muş', 'Malazgirt'), ('Muş', 'Merkez'), ('Muş', 'Varto'),
  ('Nevşehir', 'Acıgöl'), ('Nevşehir', 'Avanos'), ('Nevşehir', 'Derinkuyu'), ('Nevşehir', 'Gülşehir'), ('Nevşehir', 'Hacıbektaş'), ('Nevşehir', 'Kozaklı'), ('Nevşehir', 'Merkez'), ('Nevşehir', 'Ürgüp'),
  ('Niğde', 'Altunhisar'), ('Niğde', 'Bor'), ('Niğde', 'Çamardı'), ('Niğde', 'Çiftlik'), ('Niğde', 'Merkez'), ('Niğde', 'Ulukışla'),
  ('Ordu', 'Akkuş'), ('Ordu', 'Altınordu'), ('Ordu', 'Aybastı'), ('Ordu', 'Çamaş'), ('Ordu', 'Çatalpınar'), ('Ordu', 'Çaybaşı'), ('Ordu', 'Fatsa'), ('Ordu', 'Gölköy'), ('Ordu', 'Gülyalı'), ('Ordu', 'Gürgentepe'), ('Ordu', 'İkizce'), ('Ordu', 'Kabadüz'), ('Ordu', 'Kabataş'), ('Ordu', 'Korgan'), ('Ordu', 'Kumru'), ('Ordu', 'Mesudiye'), ('Ordu', 'Perşembe'), ('Ordu', 'Ulubey'), ('Ordu', 'Ünye'),
  ('Rize', 'Ardeşen'), ('Rize', 'Çamlıhemşin'), ('Rize', 'Çayeli'), ('Rize', 'Derepazarı'), ('Rize', 'Fındıklı'), ('Rize', 'Güneysu'), ('Rize', 'Hemşin'), ('Rize', 'İkizdere'), ('Rize', 'İyidere'), ('Rize', 'Kalkandere'), ('Rize', 'Merkez'), ('Rize', 'Pazar'),
  ('Sakarya', 'Adapazarı'), ('Sakarya', 'Akyazı'), ('Sakarya', 'Arifiye'), ('Sakarya', 'Erenler'), ('Sakarya', 'Ferizli'), ('Sakarya', 'Geyve'), ('Sakarya', 'Hendek'), ('Sakarya', 'Karapürçek'), ('Sakarya', 'Karasu'), ('Sakarya', 'Kaynarca'), ('Sakarya', 'Kocaali'), ('Sakarya', 'Pamukova'), ('Sakarya', 'Sapanca'), ('Sakarya', 'Serdivan'), ('Sakarya', 'Söğütlü'), ('Sakarya', 'Taraklı'),
  ('Samsun', 'Alaçam'), ('Samsun', 'Asarcık'), ('Samsun', 'Atakum'), ('Samsun', 'Ayvacık'), ('Samsun', 'Bafra'), ('Samsun', 'Canik'), ('Samsun', 'Çarşamba'), ('Samsun', 'Havza'), ('Samsun', 'İlkadım'), ('Samsun', 'Kavak'), ('Samsun', 'Ladik'), ('Samsun', 'Salıpazarı'), ('Samsun', 'Tekkeköy'), ('Samsun', 'Terme'), ('Samsun', 'Vezirköprü'), ('Samsun', 'Yakakent'), ('Samsun', '19 Mayıs'),
  ('Siirt', 'Baykan'), ('Siirt', 'Eruh'), ('Siirt', 'Kurtalan'), ('Siirt', 'Merkez'), ('Siirt', 'Pervari'), ('Siirt', 'Şirvan'), ('Siirt', 'Tillo'),
  ('Sinop', 'Ayancık'), ('Sinop', 'Boyabat'), ('Sinop', 'Dikmen'), ('Sinop', 'Durağan'), ('Sinop', 'Erfelek'), ('Sinop', 'Gerze'), ('Sinop', 'Merkez'), ('Sinop', 'Saraydüzü'), ('Sinop', 'Türkeli'),
  ('Sivas', 'Akıncılar'), ('Sivas', 'Altınyayla'), ('Sivas', 'Divriği'), ('Sivas', 'Doğanşar'), ('Sivas', 'Gemerek'), ('Sivas', 'Gölova'), ('Sivas', 'Gürün'), ('Sivas', 'Hafik'), ('Sivas', 'İmranlı'), ('Sivas', 'Kangal'), ('Sivas', 'Koyulhisar'), ('Sivas', 'Merkez'), ('Sivas', 'Suşehri'), ('Sivas', 'Şarkışla'), ('Sivas', 'Ulaş'), ('Sivas', 'Yıldızeli'), ('Sivas', 'Zara'),
  ('Tekirdağ', 'Çerkezköy'), ('Tekirdağ', 'Çorlu'), ('Tekirdağ', 'Ergene'), ('Tekirdağ', 'Hayrabolu'), ('Tekirdağ', 'Kapaklı'), ('Tekirdağ', 'Malkara'), ('Tekirdağ', 'Marmaraereğlisi'), ('Tekirdağ', 'Muratlı'), ('Tekirdağ', 'Saray'), ('Tekirdağ', 'Süleymanpaşa'), ('Tekirdağ', 'Şarköy'),
  ('Tokat', 'Almus'), ('Tokat', 'Artova'), ('Tokat', 'Başçiftlik'), ('Tokat', 'Erbaa'), ('Tokat', 'Merkez'), ('Tokat', 'Niksar'), ('Tokat', 'Pazar'), ('Tokat', 'Reşadiye'), ('Tokat', 'Sulusaray'), ('Tokat', 'Turhal'), ('Tokat', 'Yeşilyurt'), ('Tokat', 'Zile'),
  ('Trabzon', 'Akçaabat'), ('Trabzon', 'Araklı'), ('Trabzon', 'Arsin'), ('Trabzon', 'Beşikdüzü'), ('Trabzon', 'Çarşıbaşı'), ('Trabzon', 'Çaykara'), ('Trabzon', 'Dernekpazarı'), ('Trabzon', 'Düzköy'), ('Trabzon', 'Hayrat'), ('Trabzon', 'Köprübaşı'), ('Trabzon', 'Maçka'), ('Trabzon', 'Of'), ('Trabzon', 'Ortahisar'), ('Trabzon', 'Sürmene'), ('Trabzon', 'Şalpazarı'), ('Trabzon', 'Tonya'), ('Trabzon', 'Vakfıkebir'), ('Trabzon', 'Yomra'),
  ('Tunceli', 'Çemişgezek'), ('Tunceli', 'Hozat'), ('Tunceli', 'Mazgirt'), ('Tunceli', 'Merkez'), ('Tunceli', 'Nazımiye'), ('Tunceli', 'Ovacık'), ('Tunceli', 'Pertek'), ('Tunceli', 'Pülümür'),
  ('Şanlıurfa', 'Akçakale'), ('Şanlıurfa', 'Birecik'), ('Şanlıurfa', 'Bozova'), ('Şanlıurfa', 'Ceylanpınar'), ('Şanlıurfa', 'Eyyübiye'), ('Şanlıurfa', 'Halfeti'), ('Şanlıurfa', 'Haliliye'), ('Şanlıurfa', 'Harran'), ('Şanlıurfa', 'Hilvan'), ('Şanlıurfa', 'Karaköprü'), ('Şanlıurfa', 'Siverek'), ('Şanlıurfa', 'Suruç'), ('Şanlıurfa', 'Viranşehir'),
  ('Uşak', 'Banaz'), ('Uşak', 'Eşme'), ('Uşak', 'Karahallı'), ('Uşak', 'Merkez'), ('Uşak', 'Sivaslı'), ('Uşak', 'Ulubey'),
  ('Van', 'Bahçesaray'), ('Van', 'Başkale'), ('Van', 'Çaldıran'), ('Van', 'Çatak'), ('Van', 'Edremit'), ('Van', 'Erciş'), ('Van', 'Gevaş'), ('Van', 'Gürpınar'), ('Van', 'İpekyolu'), ('Van', 'Muradiye'), ('Van', 'Özalp'), ('Van', 'Saray'), ('Van', 'Tuşba'),
  ('Yozgat', 'Akdağmadeni'), ('Yozgat', 'Aydıncık'), ('Yozgat', 'Boğazlıyan'), ('Yozgat', 'Çandır'), ('Yozgat', 'Çayıralan'), ('Yozgat', 'Çekerek'), ('Yozgat', 'Kadışehri'), ('Yozgat', 'Merkez'), ('Yozgat', 'Saraykent'), ('Yozgat', 'Sarıkaya'), ('Yozgat', 'Sorgun'), ('Yozgat', 'Şefaatli'), ('Yozgat', 'Yenifakılı'), ('Yozgat', 'Yerköy'),
  ('Zonguldak', 'Alaplı'), ('Zonguldak', 'Çaycuma'), ('Zonguldak', 'Devrek'), ('Zonguldak', 'Ereğli'), ('Zonguldak', 'Gökçebey'), ('Zonguldak', 'Kilimli'), ('Zonguldak', 'Kozlu'), ('Zonguldak', 'Merkez'),
  ('Aksaray', 'Ağaçören'), ('Aksaray', 'Eskil'), ('Aksaray', 'Gülağaç'), ('Aksaray', 'Güzelyurt'), ('Aksaray', 'Merkez'), ('Aksaray', 'Ortaköy'), ('Aksaray', 'Sarıyahşi'), ('Aksaray', 'Sultanhanı'),
  ('Bayburt', 'Aydıntepe'), ('Bayburt', 'Demirözü'), ('Bayburt', 'Merkez'),
  ('Karaman', 'Ayrancı'), ('Karaman', 'Başyayla'), ('Karaman', 'Ermenek'), ('Karaman', 'Kazımkarabekir'), ('Karaman', 'Merkez'), ('Karaman', 'Sarıveliler'),
  ('Kırıkkale', 'Bahşılı'), ('Kırıkkale', 'Balışeyh'), ('Kırıkkale', 'Çelebi'), ('Kırıkkale', 'Delice'), ('Kırıkkale', 'Karakeçili'), ('Kırıkkale', 'Keskin'), ('Kırıkkale', 'Merkez'), ('Kırıkkale', 'Sulakyurt'), ('Kırıkkale', 'Yahşihan'),
  ('Batman', 'Beşiri'), ('Batman', 'Gercüş'), ('Batman', 'Hasankeyf'), ('Batman', 'Kozluk'), ('Batman', 'Merkez'), ('Batman', 'Sason'),
  ('Şırnak', 'Beytüşşebap'), ('Şırnak', 'Cizre'), ('Şırnak', 'Güçlükonak'), ('Şırnak', 'İdil'), ('Şırnak', 'Merkez'), ('Şırnak', 'Silopi'), ('Şırnak', 'Uludere'),
  ('Bartın', 'Amasra'), ('Bartın', 'Kurucaşile'), ('Bartın', 'Merkez'), ('Bartın', 'Ulus'),
  ('Ardahan', 'Çıldır'), ('Ardahan', 'Damal'), ('Ardahan', 'Göle'), ('Ardahan', 'Hanak'), ('Ardahan', 'Merkez'), ('Ardahan', 'Posof'),
  ('Iğdır', 'Aralık'), ('Iğdır', 'Karakoyunlu'), ('Iğdır', 'Merkez'), ('Iğdır', 'Tuzluca'),
  ('Yalova', 'Altınova'), ('Yalova', 'Armutlu'), ('Yalova', 'Çınarcık'), ('Yalova', 'Çiftlikköy'), ('Yalova', 'Merkez'), ('Yalova', 'Termal'),
  ('Karabük', 'Eflani'), ('Karabük', 'Eskipazar'), ('Karabük', 'Merkez'), ('Karabük', 'Ovacık'), ('Karabük', 'Safranbolu'), ('Karabük', 'Yenice'),
  ('Kilis', 'Elbeyli'), ('Kilis', 'Merkez'), ('Kilis', 'Musabeyli'), ('Kilis', 'Polateli'),
  ('Osmaniye', 'Bahçe'), ('Osmaniye', 'Düziçi'), ('Osmaniye', 'Hasanbeyli'), ('Osmaniye', 'Kadirli'), ('Osmaniye', 'Merkez'), ('Osmaniye', 'Sumbas'), ('Osmaniye', 'Toprakkale'),
  ('Düzce', 'Akçakoca'), ('Düzce', 'Cumayeri'), ('Düzce', 'Çilimli'), ('Düzce', 'Gölyaka'), ('Düzce', 'Gümüşova'), ('Düzce', 'Kaynaşlı'), ('Düzce', 'Merkez'), ('Düzce', 'Yığılca');

do $$ begin
  assert (select count(*) from public.tr_provinces) = 81, 'expected 81 provinces';
  assert (select count(*) from public.tr_districts) = 973, 'expected 973 districts';
end $$;

-- ---------------------------------------------------------------------------
-- 3. venues (city, district) must be a real il/ilçe pair.
--    Fails loudly if an existing venue has a misspelled district; fix the row, then re-run.
-- ---------------------------------------------------------------------------
alter table public.venues
  add constraint venues_city_district_fk foreign key (city, district)
  references public.tr_districts (province, name) on update cascade;

-- ---------------------------------------------------------------------------
-- 4. Index for the il/ilçe filter (also serves the FK's referencing-side lookups).
-- ---------------------------------------------------------------------------
drop index if exists public.venues_status_district_idx;
create index venues_status_city_district_idx on public.venues (status, city, district);

-- ---------------------------------------------------------------------------
-- 5. list_venues: p_district text → p_city text + p_districts text[]; returns city.
--    Keeps everything from 20261121090000 (S-17 coordinate guard, LIKE escaping, left(...,80),
--    active-pitch requirement, favourites, today's hours, distance then name, limit 100).
-- ---------------------------------------------------------------------------
drop function public.list_venues(text, text, double precision, double precision);

create function public.list_venues(
  p_search    text             default null,
  p_city      text             default null,
  p_districts text[]           default null,
  p_lat       double precision default null,
  p_lng       double precision default null
) returns table (
  id uuid, name text, city text, district text, address text, cover_photo_path text,
  min_hourly_price_kurus integer, open_time time, close_time time,
  distance_km double precision, is_favorite boolean
)
language sql stable security definer set search_path = public as $$
  with loc as (
    select case when p_lat between -90 and 90 and p_lng between -180 and 180 then p_lat end as lat,
           case when p_lat between -90 and 90 and p_lng between -180 and 180 then p_lng end as lng
  ), q as (
    select '%' || replace(replace(replace(left(p_search, 80), '\', '\\'), '%', '\%'), '_', '\_') || '%' as pat
  )
  select v.id, v.name, v.city, v.district, v.address, v.cover_photo_path,
         (select min(p.hourly_price_kurus) from public.pitches p where p.venue_id = v.id and p.is_active),
         h.open_time, h.close_time,
         case when loc.lat is null or v.lat is null or v.lng is null then null
              else 6371 * 2 * asin(sqrt(
                     power(sin(radians(v.lat - loc.lat) / 2), 2)
                   + cos(radians(loc.lat)) * cos(radians(v.lat)) * power(sin(radians(v.lng - loc.lng) / 2), 2)))
         end,
         exists (select 1 from public.favorites f where f.venue_id = v.id and f.user_id = auth.uid())
    from public.venues v
    cross join loc
    cross join q
    left join public.venue_hours h
      on h.venue_id = v.id
     and h.iso_weekday = extract(isodow from (now() at time zone 'Europe/Istanbul'))::smallint
   where v.status = 'active'
     and exists (select 1 from public.pitches p where p.venue_id = v.id and p.is_active)
     and (p_city is null or v.city = p_city)
     -- Districts only narrow a chosen city; null/empty = whole city; at most 50 are considered.
     and (p_city is null or p_districts is null or cardinality(p_districts) = 0
          or v.district = any (p_districts[1:50]))
     and (p_search is null
          or v.name     ilike q.pat
          or v.district ilike q.pat
          or v.city     ilike q.pat)
   order by 10 nulls last, v.name
   limit 100;
$$;

-- ---------------------------------------------------------------------------
-- 6. list_venue_locations: il/ilçe pairs that actually have a bookable venue (picker never shows empty).
--    Ordered with the ICU Turkish collation (Ç after C, İ after I, Ş after S, Ü after U).
-- ---------------------------------------------------------------------------
create function public.list_venue_locations()
returns table (city text, district text, venue_count integer)
language sql stable security definer set search_path = public as $$
  select v.city, v.district, count(*)::integer
    from public.venues v
   where v.status = 'active'
     and exists (select 1 from public.pitches p where p.venue_id = v.id and p.is_active)
   group by v.city, v.district
   order by v.city collate "tr-TR-x-icu", v.district collate "tr-TR-x-icu";
$$;

-- ---------------------------------------------------------------------------
-- 7. Privileges (deny by default, then allow-list; see tests/30a).
-- ---------------------------------------------------------------------------
revoke all on function public.list_venues(text, text, text[], double precision, double precision),
                       public.list_venue_locations()
  from public, anon, authenticated;
grant execute on function public.list_venues(text, text, text[], double precision, double precision),
                          public.list_venue_locations()
  to anon, authenticated;
