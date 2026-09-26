import 'game_state.dart';

/// Образы (внешний вид) питомцев — ТЗ 2.5.2 «Настройка внешнего вида» и
/// 2.6 «не менее 9 визуально различимых комбинаций»: 3 питомца × 3 образа.
///
/// Образ выбирает ребёнок при создании питомца и может сменить на экране
/// Питомца. Образ сохраняется на всех стадиях роста: рост показывается
/// сиянием-рамкой и значком стадии, а не сменой картинки — так выбор
/// ребёнка не «пропадает», когда питомец растёт.
///
/// Номер образа хранится в [GameStateData.petStyle] (0, 1, 2).
class PetLook {
  final String id;
  final String title;
  final String asset;

  const PetLook({required this.id, required this.title, required this.asset});
}

class PetLooks {
  const PetLooks._();

  static const String _dir = 'assets/pets/looks';

  static const List<PetLook> skorohod = <PetLook>[
    PetLook(id: 'skorohod_sport', title: 'Спортсмен', asset: '$_dir/skorohod_sport.png'),
    PetLook(id: 'skorohod_bike', title: 'Велогонщик', asset: '$_dir/skorohod_bike.png'),
    PetLook(id: 'skorohod_cozy', title: 'Уютный', asset: '$_dir/skorohod_cozy.png'),
  ];

  static const List<PetLook> kwak = <PetLook>[
    PetLook(id: 'kwak_homebody', title: 'Домосед', asset: '$_dir/kwak_homebody.png'),
    PetLook(id: 'kwak_resting', title: 'Отдыхающий', asset: '$_dir/kwak_resting.png'),
    PetLook(id: 'kwak_traveler', title: 'Путешественник', asset: '$_dir/kwak_traveler.png'),
  ];

  static const List<PetLook> tsvetik = <PetLook>[
    PetLook(id: 'tsvetik_gardener', title: 'Садовник', asset: '$_dir/tsvetik_gardener.png'),
    PetLook(id: 'tsvetik_musician', title: 'Домашний концерт', asset: '$_dir/tsvetik_musician.png'),
    PetLook(id: 'tsvetik_concert', title: 'Скрипач', asset: '$_dir/tsvetik_concert.png'),
  ];

  static List<PetLook> forPet(PetType pet) {
    switch (pet) {
      case PetType.skorohod:
        return skorohod;
      case PetType.kwak:
        return kwak;
      case PetType.tsvetik:
        return tsvetik;
    }
  }

  /// Образ по номеру; неизвестный номер (старые сохранения) → первый образ.
  static PetLook of(PetType pet, int style) {
    final looks = forPet(pet);
    return looks[style.clamp(0, looks.length - 1).toInt()];
  }

  /// Всего комбинаций «питомец × образ».
  static int get combinations =>
      PetType.values.fold<int>(0, (sum, pet) => sum + forPet(pet).length);
}
