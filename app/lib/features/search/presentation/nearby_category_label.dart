import '../../../l10n/generated/app_localizations.dart';
import '../domain/nearby_category.dart';

/// Nama kategori dalam bahasa [l10n] ("Stesen minyak", "Kedai gunting").
String nearbyCategoryLabel(AppLocalizations l10n, NearbyCategory c) =>
    switch (c) {
      NearbyCategory.fuel => l10n.searchCatFuel,
      NearbyCategory.food => l10n.searchCatFood,
      NearbyCategory.mosque => l10n.searchCatMosque,
      NearbyCategory.toilets => l10n.searchCatToilet,
      NearbyCategory.parking => l10n.searchCatParking,
      NearbyCategory.hospital => l10n.searchCatHospital,
      NearbyCategory.barber => l10n.searchCatBarber,
      NearbyCategory.pharmacy => l10n.searchCatPharmacy,
      NearbyCategory.clinic => l10n.searchCatClinic,
      NearbyCategory.atm => l10n.searchCatAtm,
      NearbyCategory.bank => l10n.searchCatBank,
      NearbyCategory.convenience => l10n.searchCatConvenience,
      NearbyCategory.supermarket => l10n.searchCatSupermarket,
      NearbyCategory.mall => l10n.searchCatMall,
      NearbyCategory.carWash => l10n.searchCatCarWash,
      NearbyCategory.workshop => l10n.searchCatWorkshop,
      NearbyCategory.tyres => l10n.searchCatTyres,
      NearbyCategory.laundry => l10n.searchCatLaundry,
      NearbyCategory.hotel => l10n.searchCatHotel,
      NearbyCategory.police => l10n.searchCatPolice,
      NearbyCategory.postOffice => l10n.searchCatPostOffice,
      NearbyCategory.evCharging => l10n.searchCatEvCharging,
      NearbyCategory.trainStation => l10n.searchCatTrainStation,
    };
