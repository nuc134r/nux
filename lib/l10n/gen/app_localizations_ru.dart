// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get about => 'О приложении';

  @override
  String get appTitle => 'nux';

  @override
  String get appVersion => 'Версия приложения';

  @override
  String get appearance => 'Оформление';

  @override
  String get cancel => 'Отмена';

  @override
  String get changelog => 'История изменений';

  @override
  String get changelogOffline =>
      'GitHub недоступен; показана история изменений этой версии.';

  @override
  String get checkForUpdates => 'Проверить обновления';

  @override
  String errorGeneric(String error) {
    return 'Что-то пошло не так: $error';
  }

  @override
  String get homeEarly =>
      'SSH, SFTP, проброс портов и редактор кода уже в пути. Эта ранняя сборка настраивает обновления, чтобы новые функции приходили к вам сразу.';

  @override
  String get homeWelcome => 'Добро пожаловать в nux';

  @override
  String get language => 'Язык';

  @override
  String get languageSystem => 'Как в системе';

  @override
  String get later => 'Позже';

  @override
  String get licenses => 'Лицензии';

  @override
  String get openReleasePage => 'Открыть страницу релиза';

  @override
  String get predictiveBack => 'Предиктивный жест «назад»';

  @override
  String get predictiveBackHint => 'Страница следует за жестом «назад»';

  @override
  String get settings => 'Настройки';

  @override
  String get sourceCode => 'Исходный код';

  @override
  String get theme => 'Тема';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeSystem => 'Как в системе';

  @override
  String get upToDate => 'Установлена последняя версия';

  @override
  String get update => 'Обновить';

  @override
  String updateAvailable(String version) {
    return 'Доступна версия nux $version';
  }

  @override
  String get updateDownloading => 'Загрузка обновления…';

  @override
  String updateFailed(String error) {
    return 'Не удалось обновить: $error';
  }

  @override
  String get updateInstalling => 'Открываем установщик…';

  @override
  String get updatePermission =>
      'Разрешите nux устанавливать приложения и попробуйте снова';

  @override
  String updateTo(String version) {
    return 'Обновить до $version';
  }

  @override
  String get updatesAuto => 'Проверять обновления автоматически';

  @override
  String get updatesBeta => 'Бета-версии';

  @override
  String get updatesBetaHint =>
      'Предлагать и предварительные версии. Они могут работать нестабильно.';

  @override
  String get whatsNew => 'Что нового';
}
