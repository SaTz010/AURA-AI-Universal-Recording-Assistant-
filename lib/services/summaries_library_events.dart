import 'package:flutter/foundation.dart';

class SummariesLibraryEvents {
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void notifyChanged() {
    revision.value++;
  }
}
