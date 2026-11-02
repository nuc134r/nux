import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import 'dialog_prompter.dart';

final dialogSshPrompterProvider = Provider((ref) => DialogSshPrompter(rootNavigatorKey));
