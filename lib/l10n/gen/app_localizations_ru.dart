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
  String get addHost => 'Добавить хост';

  @override
  String get addKey => 'Добавить ключ';

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
  String get appTitle => 'nux';

  @override
  String get appVersion => 'Версия приложения';

  @override
  String get appearance => 'Оформление';

  @override
  String get authentication => 'Вход';

  @override
  String get authenticationHint =>
      'nux предлагает отмеченные ключи по порядку, затем пароль, затем спрашивает сервер, что ещё нужно.';

  @override
  String get bookmarkFolder => 'Добавить папку в закладки';

  @override
  String get bookmarks => 'Закладки';

  @override
  String get browseFiles => 'Файлы';

  @override
  String get cancel => 'Отмена';

  @override
  String get change => 'Изменить';

  @override
  String get changelog => 'История изменений';

  @override
  String get changelogOffline =>
      'GitHub недоступен; показана история изменений этой версии.';

  @override
  String get checkForUpdates => 'Проверить обновления';

  @override
  String get clearFinished => 'Убрать завершённые';

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
  String get connect => 'Подключиться';

  @override
  String get continueAction => 'Продолжить';

  @override
  String get copied => 'Скопировано';

  @override
  String get copy => 'Копировать';

  @override
  String get copyAll => 'Скопировать всё';

  @override
  String copyOf(String name) {
    return '$name (копия)';
  }

  @override
  String get copyPath => 'Копировать путь';

  @override
  String get currentPassphrase => 'Текущая парольная фраза';

  @override
  String get delete => 'Удалить';

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
  String deleted(String name) {
    return 'Удалено: $name';
  }

  @override
  String get disconnect => 'Отключиться';

  @override
  String get download => 'Скачать';

  @override
  String get duplicate => 'Дублировать';

  @override
  String get duplicateTab => 'Ещё один терминал на этом хосте';

  @override
  String get edit => 'Изменить';

  @override
  String get editHost => 'Изменить хост';

  @override
  String errorGeneric(String error) {
    return 'Что-то пошло не так: $error';
  }

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
  String get fileDisconnected => 'Соединение потеряно';

  @override
  String get fileExists => 'Объект с таким именем уже есть';

  @override
  String get fileNotFound => 'Не найдено';

  @override
  String get filePermissionDenied => 'Нет доступа';

  @override
  String get find => 'Найти';

  @override
  String get fingerprint => 'Отпечаток';

  @override
  String get folderEmpty => 'Папка пуста';

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
  String get foldersNotDownloaded =>
      'Папки пока не скачиваются; в очередь добавлены только файлы';

  @override
  String get fontSize => 'Размер шрифта';

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
  String get groupField => 'Группа';

  @override
  String get hide => 'Скрыть';

  @override
  String get hideHiddenFiles => 'Скрыть скрытые файлы';

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
  String get invalidNumber => 'Введите число';

  @override
  String get invalidPort => '1–65535';

  @override
  String get jumpHost => 'Промежуточный хост';

  @override
  String get jumpHostHint =>
      'Подключаться через другой сохранённый хост (как ProxyJump)';

  @override
  String get keepAlive => 'Keep-alive, секунды';

  @override
  String get keepAliveHint =>
      'Пингует сервер, чтобы простаивающее соединение не обрывалось. 0 — выключить.';

  @override
  String get keepPassphrase => 'Хранить ключ защищённым этой парольной фразой';

  @override
  String keyAlreadyImported(String name) {
    return 'Этот ключ уже есть: $name';
  }

  @override
  String get keyComment => 'Комментарий';

  @override
  String get keyCommentHint =>
      'Добавляется в конец открытого ключа и помогает узнать его на серверах';

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
  String lastSeen(String date) {
    return 'Последний раз: $date';
  }

  @override
  String get later => 'Позже';

  @override
  String get licenses => 'Лицензии';

  @override
  String get loadAll => 'Загрузить всё';

  @override
  String get matchCase => 'Учитывать регистр';

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
  String get newFolder => 'Новая папка';

  @override
  String get newPassphrase => 'Новая парольная фраза';

  @override
  String get newTab => 'Новая вкладка';

  @override
  String get next => 'Следующее';

  @override
  String get noColor => 'Без цвета';

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
  String get noTabs => 'Нет открытых вкладок';

  @override
  String get noTabsHint => 'Откройте список хостов или подключитесь к серверу.';

  @override
  String get noTransfers => 'Передач нет';

  @override
  String get noWrap => 'Не переносить строки';

  @override
  String get none => 'Нет';

  @override
  String get notNow => 'Не сейчас';

  @override
  String get ok => 'ОК';

  @override
  String get open => 'Открыть';

  @override
  String get openReleasePage => 'Открыть страницу релиза';

  @override
  String get openTerminal => 'Открыть терминал';

  @override
  String get organize => 'Упорядочить';

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
  String get passwordWrong => 'Сервер не принял пароль';

  @override
  String get paste => 'Вставить';

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
  String get pinTab => 'Закрепить';

  @override
  String get pinnedTabs => 'Закреплённые';

  @override
  String get portField => 'Порт';

  @override
  String get predictiveBack => 'Предиктивный жест «назад»';

  @override
  String get predictiveBackHint => 'Страница следует за жестом «назад»';

  @override
  String get previous => 'Предыдущее';

  @override
  String get protection => 'Защита';

  @override
  String get publicKey => 'Открытый ключ';

  @override
  String get qrCode => 'QR-код';

  @override
  String get quickConnect => 'Быстрое подключение';

  @override
  String get quickConnectHint =>
      'Сохранится в хосты, будут предложены все ваши ключи';

  @override
  String get recommended => 'рекомендуется';

  @override
  String get reconnect => 'Переподключиться';

  @override
  String get refresh => 'Обновить';

  @override
  String get regex => 'Регулярное выражение';

  @override
  String get reload => 'Перезагрузить';

  @override
  String get rememberUntilClosed => 'Запомнить, пока nux открыт';

  @override
  String get removeBookmark => 'Убрать из закладок';

  @override
  String get rename => 'Переименовать';

  @override
  String get repeatPassphrase => 'Повторите парольную фразу';

  @override
  String get requireUnlock => 'Требовать разблокировку устройства';

  @override
  String get requireUnlockHint =>
      'Отпечаток, лицо или блокировка экрана перед каждым использованием';

  @override
  String get required => 'Обязательное поле';

  @override
  String get resume => 'Продолжить';

  @override
  String get save => 'Сохранить';

  @override
  String get saveAndConnect => 'Сохранить и подключиться';

  @override
  String get saveAs => 'Сохранить как…';

  @override
  String get savePassword => 'Сохранить пароль';

  @override
  String get savePasswordHint => 'Хранится в защищённом хранилище устройства';

  @override
  String savedAs(String name) {
    return 'Сохранено: $name';
  }

  @override
  String get searchHosts => 'Поиск хостов';

  @override
  String get selectAll => 'Выбрать всё';

  @override
  String get settings => 'Настройки';

  @override
  String get share => 'Поделиться';

  @override
  String get show => 'Показать';

  @override
  String get showAsText => 'Показать как текст';

  @override
  String get showHiddenFiles => 'Показать скрытые файлы';

  @override
  String get showRendered => 'Показать с оформлением';

  @override
  String get showSource => 'Показать исходный текст';

  @override
  String get showTabs => 'Показать вкладки';

  @override
  String get skipKey => 'Пропустить ключ';

  @override
  String get sortByDate => 'По дате';

  @override
  String get sortByName => 'По имени';

  @override
  String get sortBySize => 'По размеру';

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
  String tabClosed(String title) {
    return 'Вкладка «$title» закрыта';
  }

  @override
  String get terminal => 'Терминал';

  @override
  String terminalConnecting(String address) {
    return 'Подключение к $address…';
  }

  @override
  String get terminalDisconnected => 'Отключено';

  @override
  String get terminalHere => 'Терминал здесь';

  @override
  String get terminalPressEnter => 'Нажмите Enter, чтобы переподключиться';

  @override
  String get theme => 'Тема';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeSystem => 'Как в системе';

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
  String get tryAgain => 'Повторить';

  @override
  String get undo => 'Отменить';

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
  String get whatsNew => 'Что нового';

  @override
  String get wrapLines => 'Переносить строки';
}
