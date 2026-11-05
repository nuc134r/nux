// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get abortOperation => 'Прервать';

  @override
  String get about => 'О приложении';

  @override
  String get activity => 'Активность';

  @override
  String activityDisconnected(String host) {
    return '$host: соединение потеряно';
  }

  @override
  String activityDownload(String name) {
    return 'Скачивание $name';
  }

  @override
  String get activityEarlier => 'Ранее';

  @override
  String get activityEmpty =>
      'Пока пусто. Здесь появятся команды git, передачи файлов, перенаправления, обновления и сообщения.';

  @override
  String activityForwardBack(String name) {
    return 'Перенаправление $name снова работает';
  }

  @override
  String activityForwardFailed(String name) {
    return 'Перенаправление $name остановлено';
  }

  @override
  String activityNew(int count) {
    return 'новых: $count';
  }

  @override
  String get activityNow => 'Выполняется';

  @override
  String activityRunning(int count) {
    return 'выполняется: $count';
  }

  @override
  String activityUpdate(String version) {
    return 'Доступна версия nux $version';
  }

  @override
  String activityUpload(String name) {
    return 'Загрузка $name';
  }

  @override
  String get addForward => 'Добавить проброс';

  @override
  String get addHost => 'Добавить хост';

  @override
  String get addKey => 'Добавить клавишу';

  @override
  String get addPortForwarding => 'Добавить проброс порта';

  @override
  String get addRow => 'Добавить ряд';

  @override
  String get addressHint => 'Адрес или поиск';

  @override
  String addressVia(String address, String jump) {
    return '$address через $jump';
  }

  @override
  String get advanced => 'Дополнительно';

  @override
  String get algEcdsa =>
      'Кривые NIST. Для серверов и политик, которые требуют ECDSA.';

  @override
  String get algEd25519 =>
      'Компактный, быстрый и надёжный. Поддерживается всеми серверами последних лет.';

  @override
  String get algRsa =>
      'Для старых серверов. Создание на телефоне занимает время.';

  @override
  String get allBranches => 'Все ветки';

  @override
  String allRules(int count) {
    return 'Все ($count)';
  }

  @override
  String get allow => 'Разрешить';

  @override
  String get amend => 'Исправить последний';

  @override
  String get appTitle => 'nux';

  @override
  String get appVersion => 'Версия приложения';

  @override
  String get appearance => 'Оформление';

  @override
  String get ascending => 'По возрастанию';

  @override
  String get authentication => 'Вход';

  @override
  String get authenticationHint =>
      'nux предлагает отмеченные ключи по порядку, затем пароль, затем спрашивает сервер, что ещё нужно.';

  @override
  String get backgroundAllSet => 'Всё настроено';

  @override
  String get backgroundAllSetHint =>
      'Подключения работают в фоне и показывают уведомление. Ничего делать не нужно.';

  @override
  String get backgroundChannel => 'Фоновые подключения';

  @override
  String get backgroundHint => 'Остаётся на связи, пока nux в фоне';

  @override
  String get backupSettings => 'Резервная копия';

  @override
  String get batteryLabel => 'Оптимизация батареи';

  @override
  String get batteryOff =>
      'Оптимизируется: некоторые телефоны всё равно останавливают фоновые подключения';

  @override
  String get batteryOn =>
      'Без ограничений: Android не останавливает фоновые подключения';

  @override
  String get binaryOrEmptyDiff =>
      'Нечего показать (двоичный файл или изменились только права)';

  @override
  String get blame => 'Авторы строк';

  @override
  String get bookmarkFolder => 'Добавить папку в закладки';

  @override
  String get bookmarks => 'Закладки';

  @override
  String get branchName => 'Имя ветки';

  @override
  String branchNotMerged(String branch) {
    return 'В $branch есть коммиты, которых нет в других ветках. Всё равно удалить? Они пропадут.';
  }

  @override
  String get branches => 'Ветки';

  @override
  String get browseFiles => 'Файлы';

  @override
  String get browser => 'Браузер';

  @override
  String bytesCount(String bytes) {
    return '$bytes байт';
  }

  @override
  String get cancel => 'Отмена';

  @override
  String cannotCarryBody(String branch) {
    return 'В $branch изменены те же файлы. Спрятать изменения в stash и переключиться?';
  }

  @override
  String get cannotCarryTitle => 'Не удаётся перенести изменения';

  @override
  String cannotWriteBody(String name) {
    return 'Ваш пользователь не может записать $name. Сохранить как root через sudo? Владелец и права файла сохранятся.';
  }

  @override
  String get cannotWriteContent =>
      'Приложение, открывшее этот файл, не разрешает nux его менять. Поделитесь им, чтобы сохранить копию в другом месте.';

  @override
  String get cannotWriteTitle => 'Нет прав на запись';

  @override
  String get carryThem => 'Перенести';

  @override
  String get change => 'Изменить';

  @override
  String get changedOnServer => 'Файл изменился на сервере';

  @override
  String changedOnServerBody(String name) {
    return '$name изменили на сервере после того, как вы его открыли. Перезаписать вашей версией или отказаться от своих правок и загрузить новую?';
  }

  @override
  String get changelog => 'История изменений';

  @override
  String get changelogOffline =>
      'GitHub недоступен; показана история изменений этой версии.';

  @override
  String get changesSection => 'Изменения';

  @override
  String get checkForUpdates => 'Проверить обновления';

  @override
  String get clear => 'Очистить';

  @override
  String get clearFinished => 'Убрать завершённые';

  @override
  String get clearLog => 'Очистить журнал';

  @override
  String get clearLogBody =>
      'Всё записанное, включая прошлые запуски, будет удалено.';

  @override
  String get clearLogTitle => 'Очистить журнал?';

  @override
  String get clearSelection => 'Снять выделение';

  @override
  String get clipboardEmpty => 'Буфер обмена пуст';

  @override
  String get close => 'Закрыть';

  @override
  String get closeOtherTabs => 'Закрыть другие вкладки';

  @override
  String get closeTab => 'Закрыть вкладку';

  @override
  String get closeWorkspace => 'Закрыть рабочую область';

  @override
  String get colors => 'Цвета';

  @override
  String get commit => 'Коммит';

  @override
  String get commitDetails => 'Коммит';

  @override
  String get commitMessage => 'Сообщение коммита';

  @override
  String get committed => 'Закоммичено';

  @override
  String conflictBlock(int index, int count) {
    return 'Конфликт $index из $count';
  }

  @override
  String conflictsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count конфликта',
      many: '$count конфликтов',
      few: '$count конфликта',
      one: '$count конфликт',
      zero: 'Конфликтов не осталось',
    );
    return '$_temp0';
  }

  @override
  String get connect => 'Подключиться';

  @override
  String get connected => 'Подключено';

  @override
  String get continueAction => 'Продолжить';

  @override
  String get continueOperation => 'Продолжить';

  @override
  String get copied => 'Скопировано';

  @override
  String get copy => 'Копировать';

  @override
  String get copyAll => 'Скопировать всё';

  @override
  String get copyHash => 'Копировать хеш';

  @override
  String get copyLink => 'Копировать ссылку';

  @override
  String copyOf(String name) {
    return '$name (копия)';
  }

  @override
  String get copyPath => 'Копировать путь';

  @override
  String get create => 'Создать';

  @override
  String get currentPassphrase => 'Текущая парольная фраза';

  @override
  String get currentWorkspace => 'Открыта сейчас';

  @override
  String cursorPosition(int line, int column) {
    return 'Стр $line, стлб $column';
  }

  @override
  String cursorPositionSelected(int line, int column, int count) {
    return 'Стр $line, стлб $column (выделено $count)';
  }

  @override
  String get customizeKeys => 'Настроить…';

  @override
  String daysAgo(int count) {
    return '$count дн. назад';
  }

  @override
  String get delete => 'Удалить';

  @override
  String get deleteAnyway => 'Всё равно удалить';

  @override
  String get deleteBranch => 'Удалить ветку';

  @override
  String deleteBranchTitle(String branch) {
    return 'Удалить $branch?';
  }

  @override
  String get deleteConnectionBody =>
      'Сохранённый пароль тоже удалится. Доверенные ключи хоста и SSH-ключи останутся.';

  @override
  String deleteConnectionJumpers(String names) {
    return 'Через него подключаются эти хосты, они будут подключаться напрямую: $names';
  }

  @override
  String deleteConnectionTitle(String name) {
    return 'Удалить $name?';
  }

  @override
  String deleteFileTitle(String name) {
    return 'Удалить $name?';
  }

  @override
  String get deleteFilesBody =>
      'Папки удаляются вместе с содержимым. Это нельзя отменить.';

  @override
  String deleteFilesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Удалить $count объектов?',
      few: 'Удалить $count объекта?',
      one: 'Удалить $count объект?',
    );
    return '$_temp0';
  }

  @override
  String get deleteKeyBody =>
      'Закрытый ключ будет стёрт с устройства. Если копии нет, восстановить его будет нельзя.';

  @override
  String deleteKeyTitle(String name) {
    return 'Удалить ключ $name?';
  }

  @override
  String deleteKeyUsed(String names) {
    return 'Закрытый ключ будет стёрт с устройства и убран из этих хостов: $names. Если копии нет, восстановить его будет нельзя.';
  }

  @override
  String get deleteUntrackedBody =>
      'Файла ещё нет в git, поэтому он будет удалён.';

  @override
  String get deleteWorkspace => 'Удалить рабочую область';

  @override
  String get deleteWorkspaceBody =>
      'Её вкладки закроются. Файлы на хосте не меняются.';

  @override
  String deleteWorkspaceTitle(String name) {
    return 'Удалить $name?';
  }

  @override
  String deleted(String name) {
    return 'Удалено: $name';
  }

  @override
  String get descending => 'По убыванию';

  @override
  String destinationFrom(String host) {
    return 'Куда (со стороны $host)';
  }

  @override
  String get destinationHere => 'Куда (на этом устройстве)';

  @override
  String get detachedHead => 'отсоединённый HEAD';

  @override
  String get details => 'Подробнее';

  @override
  String get devicePort => 'Порт на этом устройстве';

  @override
  String get discard => 'Отменить правки';

  @override
  String get discardChanges => 'Отменить изменения';

  @override
  String get discardChangesBody => 'Сделанные правки не сохранены.';

  @override
  String get discardChangesGitBody =>
      'Всё изменённое после последнего коммита пропадёт. Это нельзя отменить.';

  @override
  String discardChangesGitTitle(String name) {
    return 'Отменить изменения в $name?';
  }

  @override
  String discardChangesTitle(String name) {
    return 'Отменить правки в $name?';
  }

  @override
  String get discardMine => 'Отказаться от своих';

  @override
  String get disconnect => 'Отключиться';

  @override
  String get disconnectAll => 'Отключить все';

  @override
  String get divergedBody =>
      'И в этой ветке, и на сервере есть новые коммиты. Rebase ставит ваши поверх серверных (прямая история); merge объединяет их коммитом слияния.';

  @override
  String get divergedTitle => 'Ветки разошлись';

  @override
  String get doneEditing => 'Закончить правку';

  @override
  String get download => 'Скачать';

  @override
  String get downloadFolder => 'Скачать папку';

  @override
  String get duplicate => 'Дублировать';

  @override
  String get duplicateTab => 'Ещё один терминал на этом хосте';

  @override
  String get edit => 'Изменить';

  @override
  String get editAsText => 'Изменить как текст';

  @override
  String get editForward => 'Изменить проброс';

  @override
  String get editHost => 'Изменить хост';

  @override
  String get editKey => 'Клавиша';

  @override
  String get editor => 'Редактор';

  @override
  String get editorFontSize => 'Размер текста в файлах';

  @override
  String get editorKeys => 'Клавиши редактора';

  @override
  String get editorLineSpacing => 'Межстрочный интервал редактора';

  @override
  String get emptyFolder => 'Пустая папка';

  @override
  String get encoding => 'Кодировка';

  @override
  String get equivalentCommand => 'То же в терминале';

  @override
  String errorGeneric(String error) {
    return 'Что-то пошло не так: $error';
  }

  @override
  String explainDynamic(String port, String host) {
    return 'SOCKS5-прокси на localhost:$port: приложения, которые его используют, выходят в интернет через $host.';
  }

  @override
  String explainDynamicShared(String port, String host) {
    return 'SOCKS5-прокси на порту $port этого устройства, доступный вашей сети: всё идёт через $host.';
  }

  @override
  String explainLocal(String port, String target, String host) {
    return 'Приложения на этом устройстве подключаются к localhost:$port и попадают на $target так, как его видит $host.';
  }

  @override
  String explainLocalShared(String port, String target, String host) {
    return 'Устройства в вашей сети подключаются к порту $port этого устройства и попадают на $target так, как его видит $host.';
  }

  @override
  String explainRemote(String host, String port, String target) {
    return 'Программы на $host подключаются к его порту $port и попадают на $target так, как его видит это устройство.';
  }

  @override
  String explainZeroTierTcp(String port, String target, String network) {
    return 'Приложения на этом устройстве подключаются к localhost:$port и попадают на $target в сети ZeroTier $network. Без SSH.';
  }

  @override
  String explainZeroTierUdp(String port, String target, String network) {
    return 'UDP-пакеты на localhost:$port уходят на $target в сети ZeroTier $network, ответы возвращаются. Подходит для игр, DNS, VoIP.';
  }

  @override
  String get explorer => 'Проводник';

  @override
  String get exportPassphraseTitle =>
      'Парольная фраза для экспортируемого ключа';

  @override
  String get exportPrivateKey => 'Экспортировать закрытый ключ';

  @override
  String get exportPrivateKeyHint => 'В виде зашифрованного файла OpenSSH';

  @override
  String get exportPrivateKeyWarning =>
      'Любой, у кого есть этот файл и его парольная фраза, сможет войти везде, где принимается этот ключ. Экспортируйте только для переноса на доверенное устройство. Затем вы зададите парольную фразу для файла.';

  @override
  String get exportSettings => 'Экспорт настроек';

  @override
  String get exportSettingsHint =>
      'Файл с настройками (без хостов, ключей и паролей)';

  @override
  String get extraKeys => 'Дополнительные клавиши';

  @override
  String get fetch => 'Получить (fetch)';

  @override
  String get fetched => 'Получено';

  @override
  String get fileDisconnected => 'Соединение потеряно';

  @override
  String get fileExists => 'Объект с таким именем уже есть';

  @override
  String get fileNotFound => 'Не найдено';

  @override
  String get filePermissionDenied => 'Нет доступа';

  @override
  String filesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файлах',
      many: '$count файлах',
      few: '$count файлах',
      one: '$count файле',
    );
    return '$_temp0';
  }

  @override
  String get find => 'Найти';

  @override
  String get fingerprint => 'Отпечаток';

  @override
  String get folderEmpty => 'Папка пуста';

  @override
  String get folderField => 'Папка';

  @override
  String get folderNotEmpty => 'Папка не пуста';

  @override
  String folderOnlyHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Здесь только $count скрытых объектов',
      few: 'Здесь только $count скрытых объекта',
      one: 'Здесь только $count скрытый объект',
    );
    return '$_temp0';
  }

  @override
  String get folderPath => 'Папка';

  @override
  String get followApp => 'Как в приложении';

  @override
  String get font => 'Шрифт';

  @override
  String get fontSize => 'Размер шрифта';

  @override
  String get forcePush => 'Принудительно (with lease)';

  @override
  String get forget => 'Забыть';

  @override
  String get forgetHostBody =>
      'При следующем подключении nux покажет ключ сервера и снова спросит, доверять ли ему.';

  @override
  String forgetHostTitle(String host) {
    return 'Забыть ключ $host?';
  }

  @override
  String forgotten(String host) {
    return 'Ключ $host забыт';
  }

  @override
  String get forwardActive => 'Работает';

  @override
  String forwardActiveConnections(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Работает · $count подключений',
      few: 'Работает · $count подключения',
      one: 'Работает · $count подключение',
    );
    return '$_temp0';
  }

  @override
  String forwardActiveTraffic(int open, String bytesIn, String bytesOut) {
    return 'Работает · открыто: $open · ↓ $bytesIn ↑ $bytesOut';
  }

  @override
  String get forwardAutoStart => 'Запускать вместе с nux';

  @override
  String forwardBindDenied(int port) {
    return 'Это устройство не разрешает слушать порт $port';
  }

  @override
  String forwardConflict(String name) {
    return 'Этот порт уже занят другим правилом: $name';
  }

  @override
  String forwardConnections(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count соединения',
      many: '$count соединений',
      few: '$count соединения',
      one: '$count соединение',
    );
    return '$_temp0';
  }

  @override
  String get forwardDynamic => 'SOCKS';

  @override
  String get forwardDynamicHint =>
      'Прокси на этом устройстве: приложения выходят в интернет через сервер (ssh -D)';

  @override
  String get forwardFailed => 'Ошибка';

  @override
  String get forwardHereToThere => 'Сюда → туда';

  @override
  String get forwardLocal => 'Локальный';

  @override
  String get forwardLocalHint =>
      'Порт на этом устройстве ведёт к тому, что доступно только серверу, например к его базе данных (ssh -L)';

  @override
  String get forwardLowPort =>
      'Приложения Android могут слушать только порты от 1024';

  @override
  String get forwardOff => 'Выключен';

  @override
  String forwardPortInUse(int port) {
    return 'Порт $port на этом устройстве уже занят';
  }

  @override
  String forwardReconnecting(int attempt) {
    return 'Соединение потеряно, переподключение (попытка $attempt)…';
  }

  @override
  String get forwardRemote => 'Удалённый';

  @override
  String get forwardRemoteHint =>
      'Порт на сервере ведёт к тому, что доступно этому устройству, например к dev-серверу на телефоне (ssh -R)';

  @override
  String get forwardRemoteRefused =>
      'Сервер отказался слушать этот порт (занят или проброс выключен в sshd_config)';

  @override
  String get forwardShared => 'Разрешить другим устройствам в сети';

  @override
  String get forwardSharedHint =>
      'Слушать на всех интерфейсах, а не только на этом устройстве';

  @override
  String get forwardStarting => 'Запуск…';

  @override
  String get forwardThereToHere => 'Туда → сюда';

  @override
  String forwardingActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Работают $count пробросов портов',
      few: 'Работают $count проброса портов',
      one: 'Работает $count проброс портов',
    );
    return '$_temp0';
  }

  @override
  String get forwardingBackgroundHint =>
      'Проброс продолжает работать, пока nux в фоне; об этом напоминает уведомление. Закрытие nux из списка недавних приложений его останавливает.';

  @override
  String get forwardingChannel => 'Проброс портов';

  @override
  String forwardingTraffic(String bytesIn, String bytesOut) {
    return '↓ $bytesIn  ↑ $bytesOut';
  }

  @override
  String get forwardings => 'Пробросы';

  @override
  String forwardingsOn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count проброса включено',
      many: '$count пробросов включено',
      few: '$count проброса включено',
      one: '$count проброс включён',
    );
    return '$_temp0';
  }

  @override
  String get generate => 'Создать';

  @override
  String get generateKey => 'Создать ключ';

  @override
  String get generateKeyHint =>
      'Новая пара ключей, созданная на этом устройстве';

  @override
  String get generating => 'Создание…';

  @override
  String get generatingRsa =>
      'Создание RSA-ключа. На телефоне это может занять минуту.';

  @override
  String get gitCancelled => 'отменено';

  @override
  String get gitCommand => 'Команда';

  @override
  String get gitEarlier => 'Команды';

  @override
  String gitExitCode(int code) {
    return 'код $code';
  }

  @override
  String gitFailed(String command, String message) {
    return 'git $command: $message';
  }

  @override
  String get gitNoOutput => '(нет вывода)';

  @override
  String get gitOutput => 'Вывод git';

  @override
  String get gitOutputEmpty => 'Команд git ещё не было';

  @override
  String get gitOutputShow => 'Вывод';

  @override
  String get gitSignInBody =>
      'Удалённый репозиторий просит имя и пароль. На GitHub, GitLab и подобных вместо пароля используйте токен доступа.';

  @override
  String gitSignInTitle(String remote) {
    return 'Вход в $remote';
  }

  @override
  String get gitSignInWrong =>
      'Удалённый репозиторий их не принял. Попробуйте ещё раз.';

  @override
  String get goBack => 'Назад';

  @override
  String get goForward => 'Вперёд';

  @override
  String get goToLine => 'Перейти к строке';

  @override
  String get groupField => 'Группа';

  @override
  String get hiddenFiles => 'Скрытые файлы';

  @override
  String get hide => 'Скрыть';

  @override
  String get hideHiddenFiles => 'Скрыть скрытые файлы';

  @override
  String get history => 'История';

  @override
  String get home => 'Главная';

  @override
  String get homeEarly =>
      'SSH, SFTP, проброс портов и редактор кода уже в пути. Эта ранняя сборка настраивает обновления, чтобы новые функции приходили к вам сразу.';

  @override
  String get homeWelcome => 'Добро пожаловать в nux';

  @override
  String get hostField => 'Хост';

  @override
  String hostKeyChangedBody(String host) {
    return '$host предъявил не тот ключ, что раньше. Если сервер не переустанавливали и не перенастраивали, соединение может перехватываться. Не доверяйте новому ключу, если не знаете причину изменения.';
  }

  @override
  String get hostKeyChangedTitle => 'Ключ сервера изменился!';

  @override
  String get hostKeyCompareHint =>
      'На сервере: ssh-keygen -lf /etc/ssh/ssh_host_*_key.pub';

  @override
  String hostKeyNewTypeBody(String host) {
    return '$host предъявил ключ типа, которому вы раньше для него не доверяли. Обычно это безопасно (например, после обновления сервера), но сверьте отпечаток.';
  }

  @override
  String get hostKeyNewTypeTitle => 'Новый тип ключа';

  @override
  String get hostKeyPresented => 'Предъявленный ключ';

  @override
  String get hostKeyTrust => 'Доверять';

  @override
  String get hostKeyTrustNew => 'Доверять новому ключу';

  @override
  String get hostKeyTrustedBefore => 'Ранее доверенные';

  @override
  String hostKeyUnknownBody(String host) {
    return 'Это первое подключение к $host. Перед тем как доверять, сверьте отпечаток ниже с отпечатком сервера.';
  }

  @override
  String get hostKeyUnknownTitle => 'Новый сервер';

  @override
  String get hosts => 'Хосты';

  @override
  String hoursAgo(int count) {
    return '$count ч назад';
  }

  @override
  String get imageUnreadable => 'Не удалось открыть изображение';

  @override
  String get importAction => 'Импортировать';

  @override
  String get importFormatsHint => 'OpenSSH, PEM, PKCS#8 или PuTTY (.ppk)';

  @override
  String get importFromClipboard => 'Вставить из буфера обмена';

  @override
  String get importFromFile => 'Импортировать из файла';

  @override
  String get importKey => 'Импортировать ключ';

  @override
  String get importKeyPassphraseTitle => 'У этого ключа есть парольная фраза';

  @override
  String get importKeyStaysEncrypted =>
      'nux сохранит его зашифрованным той же парольной фразой.';

  @override
  String get importedKey => 'Импортированный ключ';

  @override
  String get installOnServer => 'Установить на сервер';

  @override
  String get installOnServerHint =>
      'Добавляет открытый ключ в ~/.ssh/authorized_keys через текущий способ входа (как ssh-copy-id)';

  @override
  String installingKey(String name) {
    return 'Установка ключа на $name…';
  }

  @override
  String get invalidFileName => 'Имя не может содержать /';

  @override
  String get invalidNetworkId =>
      'Идентификатор сети — 16 шестнадцатеричных цифр';

  @override
  String get invalidNumber => 'Введите число';

  @override
  String get invalidPort => '1–65535';

  @override
  String get join => 'Подключиться';

  @override
  String get joinNetwork => 'Подключиться к сети';

  @override
  String get jumpHost => 'Промежуточный хост';

  @override
  String get jumpHostHint =>
      'Подключаться через другой сохранённый хост (как ProxyJump)';

  @override
  String get justNow => 'только что';

  @override
  String get keepAlive => 'Keep-alive, секунды';

  @override
  String get keepAliveHint =>
      'Пингует сервер, чтобы простаивающее соединение не обрывалось. 0 — выключить.';

  @override
  String get keepBoth => 'Оба';

  @override
  String get keepEditing => 'Продолжить правку';

  @override
  String get keepPassphrase => 'Хранить ключ защищённым этой парольной фразой';

  @override
  String get keepTheirs => 'Их';

  @override
  String get keepYours => 'Ваше';

  @override
  String keyAlreadyImported(String name) {
    return 'Этот ключ уже есть: $name';
  }

  @override
  String get keyAlternates => 'При долгом нажатии';

  @override
  String get keyAlternatesHint => 'Через пробел, например () (( [';

  @override
  String get keyComment => 'Комментарий';

  @override
  String get keyCommentHint =>
      'Добавляется в конец открытого ключа и помогает узнать его на серверах';

  @override
  String get keyEditorHint =>
      'Нажмите на клавишу, чтобы изменить её; удерживайте и перетаскивайте, чтобы переместить (или в «Убрать»). + добавляет клавишу в ряд.';

  @override
  String get keyHasPassphrase => 'Защищён парольной фразой';

  @override
  String keyInstalled(String name) {
    return 'Установлен на $name';
  }

  @override
  String get keyInvalid => 'Это не закрытый ключ, который nux может прочитать';

  @override
  String get keyIsPublic =>
      'Это открытый ключ. Импортируйте закрытый (файл без .pub).';

  @override
  String get keyNameHint => 'например, Телефон';

  @override
  String get keyNeedsPassphrase => 'Для этого ключа нужна парольная фраза';

  @override
  String get keyNeedsUnlock => 'Требуется разблокировка устройства';

  @override
  String get keyNoPassphrase => 'Без парольной фразы';

  @override
  String keyNowUsed(String name) {
    return '$name теперь сначала входит с этим ключом';
  }

  @override
  String get keyStorageHint =>
      'Закрытый ключ хранится в защищённом хранилище устройства';

  @override
  String get keyType => 'Тип';

  @override
  String get keyTypes => 'Вводит';

  @override
  String keyUnsupported(String detail) {
    return 'Ключ не поддерживается: $detail';
  }

  @override
  String keyWasInstalled(String name) {
    return '$name уже принимает этот ключ';
  }

  @override
  String get keys => 'Ключи';

  @override
  String get keysCustom => 'Свои';

  @override
  String keysCustomHelp(String keys) {
    return 'Один ряд на строку, клавиши через пробел. Варианты по долгому нажатию идут после клавиши через запятую: (,(),(( — это ( с вариантами () и ((. Обратная косая черта делает следующий символ обычным: \\, \\\\ \\(пробел). Удерживайте клавишу с вариантами, чтобы выбрать; остальные клавиши повторяются; удерживание Ctrl или Alt фиксирует их.\n\nСпециальные клавиши: $keys';
  }

  @override
  String get keysOneRow => 'Один ряд';

  @override
  String get keysTwoRows => 'Два ряда';

  @override
  String get keysTwoRowsSymbols => 'Два ряда, больше символов';

  @override
  String get knownHosts => 'Известные хосты';

  @override
  String get knownHostsEmpty =>
      'Доверенных серверов пока нет. Ключ сервера сохраняется здесь, когда вы доверяете ему при первом подключении.';

  @override
  String get knownHostsHint =>
      'Ключи серверов, которым вы доверяете. nux предупредит, если сервер предъявит другой ключ.';

  @override
  String get language => 'Язык';

  @override
  String get languageSystem => 'Как в системе';

  @override
  String get largerText => 'Крупнее';

  @override
  String lastSeen(String date) {
    return 'Последний раз: $date';
  }

  @override
  String get later => 'Позже';

  @override
  String get leave => 'Покинуть';

  @override
  String get leaveNetworkBody =>
      'Хосты и перенаправления через эту сеть не будут подключаться, пока вы снова не подключитесь к ней.';

  @override
  String leaveNetworkTitle(String name) {
    return 'Покинуть $name?';
  }

  @override
  String get licenses => 'Лицензии';

  @override
  String get lineEndings => 'Концы строк';

  @override
  String lineField(int count) {
    return 'Строка (1–$count)';
  }

  @override
  String get linkTargetLabel => 'Ссылается на';

  @override
  String get loadAll => 'Загрузить всё';

  @override
  String get logAll => 'Все';

  @override
  String get logEmpty => 'Журнал пуст';

  @override
  String get logErrors => 'Ошибки';

  @override
  String get logHint =>
      'Сохраняется между запусками; старые строки удаляются. В отправленном журнале хосты и адреса скрыты; пароли и ключи не записываются никогда.';

  @override
  String get logInMemory => 'Хранится только в памяти';

  @override
  String logSize(String size, String max) {
    return '$size из максимум $max';
  }

  @override
  String get logTileHint =>
      'Что делал nux, для поиска проблем: размер, просмотр, отправка';

  @override
  String get logTitle => 'Журнал';

  @override
  String get logWarnings => 'Предупреждения';

  @override
  String get markResolved => 'Сохранить и отметить решённым';

  @override
  String get matchCase => 'Учитывать регистр';

  @override
  String get merge => 'Merge';

  @override
  String minutesAgo(int count) {
    return '$count мин назад';
  }

  @override
  String get modifiedLabel => 'Изменён';

  @override
  String get more => 'Ещё';

  @override
  String get move => 'Переместить';

  @override
  String get moveTo => 'Переместить в…';

  @override
  String nSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Выбрано $count',
      few: 'Выбрано $count',
      one: 'Выбран $count',
    );
    return '$_temp0';
  }

  @override
  String get nameField => 'Название';

  @override
  String get nameOptional => 'Название (необязательно)';

  @override
  String get newBranch => 'Новая ветка';

  @override
  String get newBrowserTab => 'Новая вкладка браузера';

  @override
  String get newFolder => 'Новая папка';

  @override
  String get newPassphrase => 'Новая парольная фраза';

  @override
  String get newRow => 'Новый ряд';

  @override
  String get newTab => 'Новая вкладка';

  @override
  String get newTag => 'Новый тег';

  @override
  String get newWorkspace => 'Новая рабочая область';

  @override
  String get next => 'Следующее';

  @override
  String get noChanges => 'Изменений нет';

  @override
  String get noColor => 'Без цвета';

  @override
  String get noCommits => 'Коммитов пока нет';

  @override
  String get noDifferences => 'Различий нет';

  @override
  String get noForwards => 'Пробросов портов пока нет';

  @override
  String get noHosts => 'Хостов пока нет';

  @override
  String get noHostsHint =>
      'Добавьте сервер или введите user@host, чтобы подключиться сразу.';

  @override
  String get noKeysHint =>
      'Ключи позволяют входить без пароля. Создайте ключ здесь или импортируйте тот, которым уже пользуетесь.';

  @override
  String get noKeysYet => 'Ключей пока нет';

  @override
  String get noPreview => 'Нет превью';

  @override
  String get noStashes => 'Ничего не спрятано';

  @override
  String get noTabs => 'Нет открытых вкладок';

  @override
  String get noTabsHint => 'Откройте список хостов или подключитесь к серверу.';

  @override
  String get noTags => 'Тегов нет';

  @override
  String get noTransfers => 'Передач нет';

  @override
  String get noWorkspace => 'Без рабочей области';

  @override
  String get noWorkspaceCard =>
      'Открытые вкладки не относятся ни к одной рабочей области';

  @override
  String get noWorkspaceHint =>
      'Рабочая область — папка на хосте со своими вкладками, деревом проекта и статусом git. Откройте её из файлового менеджера (⋮ → Открыть как рабочую область) или добавьте здесь.';

  @override
  String get noWrap => 'Не переносить строки';

  @override
  String get none => 'Нет';

  @override
  String get notASettingsFile => 'Это не файл настроек nux';

  @override
  String get notCommittedYet => 'Ещё не закоммичено';

  @override
  String get notGitRepo => 'Не git-репозиторий';

  @override
  String get notNow => 'Не сейчас';

  @override
  String get nothingFound => 'Ничего не найдено';

  @override
  String get notificationsBlocked =>
      'Включите их в настройках Android: Приложения → nux → Уведомления';

  @override
  String get notificationsLabel => 'Уведомления';

  @override
  String get notificationsOff =>
      'Выключены: фоновые подключения работают без уведомления';

  @override
  String get notificationsOn =>
      'Разрешены: уведомление показывает, что работает в фоне';

  @override
  String get ok => 'ОК';

  @override
  String get open => 'Открыть';

  @override
  String get openAsWorkspace => 'Открыть как рабочую область';

  @override
  String get openFileAt => 'Открыть файл';

  @override
  String get openInBrowserTab => 'Открыть во вкладке браузера';

  @override
  String get openInFileBrowser => 'Открыть в файловом менеджере';

  @override
  String get openInOtherApp => 'Открыть в другом приложении';

  @override
  String get openLinkQuestion => 'Открыть ссылку?';

  @override
  String get openReleasePage => 'Открыть страницу релиза';

  @override
  String get openTerminal => 'Открыть терминал';

  @override
  String get openTerminalHere => 'Открыть терминал здесь';

  @override
  String get openWorkspace => 'Открыть';

  @override
  String get operationCherryPick => 'Cherry-pick';

  @override
  String get operationMerge => 'Слияние';

  @override
  String get operationRebase => 'Rebase';

  @override
  String get operationRevert => 'Revert';

  @override
  String get orSpecialKey => 'Или специальная клавиша';

  @override
  String get organize => 'Упорядочить';

  @override
  String get otherDevices => 'Подключения из LAN';

  @override
  String get outdent => 'Уменьшить отступ';

  @override
  String get overwrite => 'Перезаписать';

  @override
  String get ownerLabel => 'Владелец';

  @override
  String partiallyLoaded(String loaded, String total) {
    return 'Показаны первые $loaded из $total';
  }

  @override
  String get passphrase => 'Парольная фраза';

  @override
  String get passphraseChanged => 'Парольная фраза изменена';

  @override
  String get passphraseOptionalHint =>
      'Необязательно. Спрашивается при использовании ключа.';

  @override
  String get passphraseRemoved => 'Парольная фраза удалена';

  @override
  String get passphraseWrong => 'Неверная парольная фраза';

  @override
  String get passphrasesDiffer => 'Парольные фразы не совпадают';

  @override
  String get password => 'Пароль';

  @override
  String passwordFor(String address) {
    return 'Пароль для $address';
  }

  @override
  String get passwordKeepHint =>
      'Пароль сохранён. Оставьте пустым, чтобы не менять.';

  @override
  String get passwordOrToken => 'Пароль или токен';

  @override
  String get passwordWrong => 'Сервер не принял пароль';

  @override
  String get paste => 'Вставить';

  @override
  String get pathOnServer => 'Путь на сервере';

  @override
  String get permExecute => 'Запуск';

  @override
  String get permGroup => 'Группа';

  @override
  String get permOthers => 'Остальные';

  @override
  String get permOwner => 'Владелец';

  @override
  String get permRead => 'Чтение';

  @override
  String get permWrite => 'Запись';

  @override
  String get permissions => 'Права доступа';

  @override
  String permissionsOf(String name) {
    return 'Права доступа: $name';
  }

  @override
  String get pickProtocol => 'Выберите TCP, UDP или оба';

  @override
  String get pinTab => 'Закрепить';

  @override
  String get pingFailed => 'нет ответа';

  @override
  String pingMs(int ms) {
    return '$ms мс';
  }

  @override
  String get pinnedTabs => 'Закреплённые';

  @override
  String get portField => 'Порт';

  @override
  String get portForwarding => 'Проброс портов';

  @override
  String portForwardingOn(String name) {
    return 'Проброс · $name';
  }

  @override
  String get portHere => 'Порт здесь';

  @override
  String portOnHost(String host) {
    return 'Порт на $host';
  }

  @override
  String get portSuggested => 'Предложен: не занят другими пробросами';

  @override
  String portsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count порта',
      many: '$count портов',
      few: '$count порта',
      one: '$count порт',
    );
    return '$_temp0';
  }

  @override
  String get previous => 'Предыдущее';

  @override
  String get protection => 'Защита';

  @override
  String get publicKey => 'Открытый ключ';

  @override
  String get publish => 'Опубликовать';

  @override
  String get publishBranchBody =>
      'Этой ветки ещё нет на сервере. Отправить её в origin и отслеживать?';

  @override
  String publishBranchTitle(String branch) {
    return 'Опубликовать $branch?';
  }

  @override
  String get pull => 'Подтянуть (pull)';

  @override
  String get pulled => 'Подтянуто';

  @override
  String get push => 'Отправить (push)';

  @override
  String get pushNothing =>
      'Нечего отправлять: на сервере уже есть все эти коммиты.';

  @override
  String pushPreviewTitle(String upstream) {
    return 'Отправить в $upstream';
  }

  @override
  String get pushRejectedBody =>
      'Кто-то отправил коммиты в эту ветку, или вы переписали уже отправленные. Сначала подтяните их, или отправьте принудительно: ветка на сервере заменится, только если она такая же, как при последнем fetch, так что чужая новая работа случайно не пропадёт.';

  @override
  String get pushRejectedTitle => 'На сервере есть более новые коммиты';

  @override
  String get pushTag => 'Отправить тег';

  @override
  String get pushed => 'Отправлено';

  @override
  String get qrCode => 'QR-код';

  @override
  String get quickOpen => 'Быстрое открытие';

  @override
  String get quickOpenHint => 'Имя файла, например main';

  @override
  String get reachThroughZeroTier => 'Подключаться через ZeroTier';

  @override
  String get reachThroughZeroTierHint =>
      'Для хостов без публичного адреса: nux сам подключается к сети, VPN-приложение не нужно';

  @override
  String get rebase => 'Rebase';

  @override
  String get recommended => 'рекомендуется';

  @override
  String get reconnect => 'Переподключиться';

  @override
  String get redoEdit => 'Повторить';

  @override
  String get refresh => 'Обновить';

  @override
  String get regex => 'Регулярное выражение';

  @override
  String get reload => 'Перезагрузить';

  @override
  String get reloadPage => 'Обновить';

  @override
  String get rememberForWorkspace => 'Запомнить для этой рабочей области';

  @override
  String get rememberUntilClosed => 'Запомнить, пока nux открыт';

  @override
  String get removeBookmark => 'Убрать из закладок';

  @override
  String get removeKey => 'Убрать';

  @override
  String get rename => 'Переименовать';

  @override
  String get renameBranch => 'Переименовать ветку';

  @override
  String get repeatPassphrase => 'Повторите парольную фразу';

  @override
  String get replace => 'Заменить';

  @override
  String get replaceAll => 'Заменить все';

  @override
  String get replaceWith => 'Заменить на';

  @override
  String get requireUnlock => 'Требовать разблокировку устройства';

  @override
  String get requireUnlockHint =>
      'Отпечаток, лицо или блокировка экрана перед каждым использованием';

  @override
  String get required => 'Обязательное поле';

  @override
  String get resolveConflicts => 'Разрешить конфликты';

  @override
  String get restore => 'Восстановить';

  @override
  String get restoreSettings => 'Восстановить настройки';

  @override
  String restoreSettingsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'В файле $count настроек. Они заменят текущие настройки.',
      few: 'В файле $count настройки. Они заменят текущие настройки.',
      one: 'В файле $count настройка. Она заменит текущие настройки.',
    );
    return '$_temp0';
  }

  @override
  String get restoreSettingsTitle => 'Восстановить настройки?';

  @override
  String get resume => 'Продолжить';

  @override
  String get save => 'Сохранить';

  @override
  String get saveAndConnect => 'Сохранить и подключиться';

  @override
  String get saveAs => 'Сохранить как…';

  @override
  String get saveAsRoot => 'Сохранить как root';

  @override
  String get savePassword => 'Сохранить пароль';

  @override
  String get savePasswordHint => 'Хранится в защищённом хранилище устройства';

  @override
  String get saveWithEncoding => 'Сохранить в кодировке';

  @override
  String savedAs(String name) {
    return 'Сохранено: $name';
  }

  @override
  String savedAsRoot(String name) {
    return '$name сохранён как root';
  }

  @override
  String savedFile(String name) {
    return 'Сохранено: $name';
  }

  @override
  String get searchHosts => 'Поиск хостов';

  @override
  String get searchInFiles => 'Поиск по файлам';

  @override
  String get searchInFilesHint => 'Что найти';

  @override
  String searchMatches(int count, String files) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count совпадения в $files',
      many: '$count совпадений в $files',
      few: '$count совпадения в $files',
      one: '$count совпадение в $files',
    );
    return '$_temp0';
  }

  @override
  String get selectAll => 'Выбрать всё';

  @override
  String get serverPort => 'Порт на сервере';

  @override
  String get serverVsYours => 'Сервер → ваше';

  @override
  String get settings => 'Настройки';

  @override
  String get settingsRestored => 'Настройки восстановлены';

  @override
  String get share => 'Поделиться';

  @override
  String get shareFile => 'Поделиться';

  @override
  String get shareLog => 'Поделиться журналом';

  @override
  String get shareLogHint =>
      'Что делал nux, включая прошлые запуски и сбои, текстовым файлом со скрытыми хостами и адресами';

  @override
  String get show => 'Показать';

  @override
  String get showAsText => 'Показать как текст';

  @override
  String get showChanges => 'Показать изменения';

  @override
  String get showHiddenFiles => 'Показать скрытые файлы';

  @override
  String get showRendered => 'Показать с оформлением';

  @override
  String get showSource => 'Показать исходный текст';

  @override
  String get showTabs => 'Показать вкладки';

  @override
  String get sideBySide => 'Рядом';

  @override
  String get signIn => 'Войти';

  @override
  String get signOff => 'Подписать (sign-off)';

  @override
  String get sizeLabel => 'Размер';

  @override
  String get skipKey => 'Пропустить ключ';

  @override
  String get smallerText => 'Мельче';

  @override
  String get socksPortHint =>
      'Укажите этот порт как SOCKS5-прокси в приложениях (обычно 1080)';

  @override
  String get sortByDate => 'По дате';

  @override
  String get sortByName => 'По имени';

  @override
  String get sortBySize => 'По размеру';

  @override
  String get sortMenu => 'Сортировка';

  @override
  String get sortModified => 'Дата изменения';

  @override
  String get sortName => 'Имя';

  @override
  String get sortSize => 'Размер';

  @override
  String get sourceCode => 'Исходный код';

  @override
  String get ssh => 'SSH';

  @override
  String get sshAuthFailed => 'Сервер отклонил предложенные ключи и пароль';

  @override
  String get sshCancelled => 'Отменено';

  @override
  String get sshConnectionMissing => 'Этот хост удалён';

  @override
  String sshConnectionsOpen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count SSH-подключений',
      few: '$count SSH-подключения',
      one: '$count SSH-подключение',
    );
    return '$_temp0';
  }

  @override
  String get sshHostKeyRejected => 'Ключу сервера не доверились';

  @override
  String sshOtherError(String detail) {
    return 'Не удалось подключиться: $detail';
  }

  @override
  String sshUnreachable(String detail) {
    return 'Сервер недоступен: $detail';
  }

  @override
  String sshVia(String error, String via) {
    return '$error (через $via)';
  }

  @override
  String get stage => 'Подготовить';

  @override
  String get stageAll => 'Подготовить всё';

  @override
  String get stageHunk => 'Подготовить эту часть';

  @override
  String get staged => 'Подготовлено';

  @override
  String get startWithNux => 'Автозапуск';

  @override
  String get stashApply => 'Применить';

  @override
  String stashBeforeSwitch(String from, String to) {
    return 'На $from, перед переключением на $to';
  }

  @override
  String get stashChanges => 'Спрятать изменения (stash)';

  @override
  String get stashDrop => 'Удалить';

  @override
  String get stashMessage => 'Заметка (необязательно)';

  @override
  String get stashPop => 'Применить и убрать';

  @override
  String get stashThem => 'Спрятать';

  @override
  String get stashed => 'Спрятано';

  @override
  String get stashes => 'Спрятанное (stash)';

  @override
  String get statusBar => 'Строка состояния';

  @override
  String get stopAll => 'Остановить все';

  @override
  String get stopEditing => 'Закончить правку';

  @override
  String get sudoNotAllowed =>
      'Этому пользователю нельзя использовать sudo на этом сервере';

  @override
  String get sudoPassword => 'Пароль для sudo';

  @override
  String get sudoWrongPassword => 'Неверный пароль';

  @override
  String switchWithChangesBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Есть $count незакоммиченных изменений.',
      few: 'Есть $count незакоммиченных изменения.',
      one: 'Есть $count незакоммиченное изменение.',
    );
    return '$_temp0 Перенести их на другую ветку или спрятать в stash (они будут ждать в списке stash)?';
  }

  @override
  String switchWithChangesTitle(String branch) {
    return 'Переключиться на $branch?';
  }

  @override
  String get switchWorkspace => 'Сменить рабочую область';

  @override
  String switchedStashed(String branch) {
    return 'Теперь на $branch; изменения в списке stash';
  }

  @override
  String tabClosed(String title) {
    return 'Вкладка «$title» закрыта';
  }

  @override
  String get tagMessage =>
      'Сообщение (необязательно, будет аннотированный тег)';

  @override
  String get tagName => 'Имя тега';

  @override
  String get tags => 'Теги';

  @override
  String get targetHost => 'Куда';

  @override
  String get targetHostLocalHint =>
      'Как его видит сервер: localhost — это сам сервер';

  @override
  String get targetHostRemoteHint =>
      'Как его видит это устройство: localhost — это само устройство';

  @override
  String get targetHostZeroTierHint =>
      'Адрес устройства в ZeroTier, например 10.147.17.5';

  @override
  String get terminal => 'Терминал';

  @override
  String get terminalAndEditor => 'Терминал и редактор';

  @override
  String get terminalAndEditorHint =>
      'Цвета, шрифты, размер текста и межстрочный интервал';

  @override
  String terminalConnecting(String address) {
    return 'Подключение к $address…';
  }

  @override
  String get terminalDisconnected => 'Отключено';

  @override
  String get terminalFontSize => 'Размер текста в терминале';

  @override
  String get terminalHere => 'Терминал здесь';

  @override
  String get terminalKeys => 'Клавиши терминала';

  @override
  String get terminalLineSpacing => 'Межстрочный интервал в терминале';

  @override
  String get terminalPressEnter => 'Нажмите Enter, чтобы переподключиться';

  @override
  String get text => 'Текст';

  @override
  String get textSize => 'Размер текста';

  @override
  String get textSizeHint =>
      'Также в меню ⋮ вкладки или щипком двумя пальцами по тексту.';

  @override
  String get theRemote => 'удалённый репозиторий';

  @override
  String get theServer => 'сервер';

  @override
  String get theme => 'Тема';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeSystem => 'Как в системе';

  @override
  String get thisBranch => 'Эта ветка';

  @override
  String get throughSsh => 'Через SSH';

  @override
  String get throughZeroTier => 'ZeroTier';

  @override
  String get transferCancelled => 'Отменено — можно продолжить с того же места';

  @override
  String get transferDownloaded => 'Скачано';

  @override
  String get transferQueued => 'В очереди';

  @override
  String get transferUploaded => 'Загружено';

  @override
  String get transfers => 'Передачи';

  @override
  String transfersActive(int count) {
    return 'активных: $count';
  }

  @override
  String get tryAgain => 'Повторить';

  @override
  String udpNeedsHostItself(String host) {
    return 'UDP идёт напрямую через ZeroTier, поэтому только на порт самого $host';
  }

  @override
  String get undo => 'Отменить';

  @override
  String get undoEdit => 'Отменить';

  @override
  String unlockKey(String name) {
    return 'Разблокировать $name';
  }

  @override
  String unlockKeyReason(String name) {
    return 'Использовать ключ $name';
  }

  @override
  String get unpinTab => 'Открепить';

  @override
  String unresolvedLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Осталось выбрать $count блока',
      many: 'Осталось выбрать $count блоков',
      few: 'Осталось выбрать $count блока',
      one: 'Осталось выбрать $count блок',
    );
    return '$_temp0';
  }

  @override
  String get unstage => 'Убрать из подготовки';

  @override
  String get unstageAll => 'Убрать всё';

  @override
  String get unstageHunk => 'Убрать эту часть';

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
  String get upload => 'Загрузить на сервер';

  @override
  String get uploadFolder => 'Загрузить папку';

  @override
  String get uploadHere => 'Загрузить сюда';

  @override
  String uploadHereHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файлов для загрузки: откройте папку для них',
      few: '$count файла для загрузки: откройте папку для них',
      one: '$count файл для загрузки: откройте папку для него',
    );
    return '$_temp0';
  }

  @override
  String uploadSharedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Загрузить $count файлов на',
      few: 'Загрузить $count файла на',
      one: 'Загрузить $count файл на',
    );
    return '$_temp0';
  }

  @override
  String get useKey => 'Использовать ключ';

  @override
  String useKeyFor(String name) {
    return 'Входить на $name с этим ключом?';
  }

  @override
  String get usedBy => 'Используется';

  @override
  String get usedByNone => 'Этот ключ пока не используется ни одним хостом';

  @override
  String get usernameField => 'Имя пользователя';

  @override
  String get versionControl => 'Контроль версий';

  @override
  String viaZeroTier(String network) {
    return 'ZeroTier $network';
  }

  @override
  String get viewMenu => 'Вид';

  @override
  String get webViewUnavailable => 'Здесь нельзя показать веб-страницы';

  @override
  String get whatsNew => 'Что нового';

  @override
  String get workspaces => 'Рабочие области';

  @override
  String get wrapLines => 'Переносить строки';

  @override
  String get yesterday => 'вчера';

  @override
  String get zerotierNetwork => 'Сеть ZeroTier';

  @override
  String get ztAbout =>
      'nux запускает собственный узел ZeroTier, независимый от приложения ZeroTier на телефоне, поэтому ему не нужно разрешение VPN. Сеть доступна только самому nux.';

  @override
  String get ztAccessDenied =>
      'Нет доступа: разрешите этот узел в контроллере сети';

  @override
  String get ztAutoStart => 'Запускать вместе с nux';

  @override
  String get ztNetworkIdle => 'Узел выключен';

  @override
  String get ztNetworks => 'Сети';

  @override
  String get ztNoNetworks => 'Сетей пока нет';

  @override
  String get ztNoNetworksHint =>
      'Подключитесь по 16-значному идентификатору из my.zerotier.com или своего контроллера';

  @override
  String get ztNode => 'Узел ZeroTier';

  @override
  String get ztNodeIdHint =>
      'Идентификатор этого узла: разрешите его в контроллере сети';

  @override
  String get ztNotFound => 'Такой сети нет';

  @override
  String get ztOffline => 'Запущен, ищет серверы ZeroTier…';

  @override
  String get ztOnline => 'В сети';

  @override
  String get ztRequesting =>
      'Ожидание контроллера сети (разрешите там этот узел)';

  @override
  String get ztStarting => 'Запуск…';

  @override
  String get ztStopped => 'Выключен';

  @override
  String get ztWaitingAddress => 'Подключено, ожидание адреса';
}
