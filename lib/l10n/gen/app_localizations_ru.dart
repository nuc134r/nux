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
  String get addForward => 'Добавить проброс';

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
  String allRules(int count) {
    return 'Все ($count)';
  }

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
  String get backgroundChannel => 'Фоновые подключения';

  @override
  String get backgroundHint => 'Остаётся на связи, пока nux в фоне';

  @override
  String get bookmarkFolder => 'Добавить папку в закладки';

  @override
  String get bookmarks => 'Закладки';

  @override
  String get browseFiles => 'Файлы';

  @override
  String bytesCount(String bytes) {
    return '$bytes байт';
  }

  @override
  String get cancel => 'Отмена';

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
  String daysAgo(int count) {
    return '$count дн. назад';
  }

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
  String get devicePort => 'Порт на этом устройстве';

  @override
  String get discard => 'Отменить правки';

  @override
  String get discardChangesBody => 'Сделанные правки не сохранены.';

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
  String get doneEditing => 'Закончить правку';

  @override
  String get download => 'Скачать';

  @override
  String get duplicate => 'Дублировать';

  @override
  String get duplicateTab => 'Ещё один терминал на этом хосте';

  @override
  String get edit => 'Изменить';

  @override
  String get editForward => 'Изменить проброс';

  @override
  String get editHost => 'Изменить хост';

  @override
  String get editorFontSize => 'Размер текста в файлах';

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
  String get forwardDynamic => 'SOCKS';

  @override
  String get forwardDynamicHint =>
      'Прокси на этом устройстве: приложения выходят в интернет через сервер (ssh -D)';

  @override
  String get forwardFailed => 'Ошибка';

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
  String get keepEditing => 'Продолжить правку';

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
  String get licenses => 'Лицензии';

  @override
  String get linkTargetLabel => 'Ссылается на';

  @override
  String get loadAll => 'Загрузить всё';

  @override
  String get matchCase => 'Учитывать регистр';

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
  String get openLinkQuestion => 'Открыть ссылку?';

  @override
  String get openReleasePage => 'Открыть страницу релиза';

  @override
  String get openTerminal => 'Открыть терминал';

  @override
  String get organize => 'Упорядочить';

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
  String get portForwarding => 'Проброс портов';

  @override
  String portForwardingOn(String name) {
    return 'Проброс · $name';
  }

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
  String get reachThroughZeroTier => 'Подключаться через ZeroTier';

  @override
  String get reachThroughZeroTierHint =>
      'Для хостов без публичного адреса: nux сам подключается к сети, VPN-приложение не нужно';

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
  String savedFile(String name) {
    return 'Сохранено: $name';
  }

  @override
  String get searchHosts => 'Поиск хостов';

  @override
  String get selectAll => 'Выбрать всё';

  @override
  String get serverPort => 'Порт на сервере';

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
  String get stopAll => 'Остановить все';

  @override
  String get stopEditing => 'Закончить правку';

  @override
  String tabClosed(String title) {
    return 'Вкладка «$title» закрыта';
  }

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
  String get tryAgain => 'Повторить';

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
  String viaZeroTier(String network) {
    return 'ZeroTier $network';
  }

  @override
  String get whatsNew => 'Что нового';

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
