import 'dart:ffi';
import 'dart:io';

const String _libName = 'bulter_sqlite_vec';

/// DynamicLibrary 句柄，加载 sqlite-vec 编译产物。
/// 在 Android / Linux 下为 libbulter_sqlite_vec.so，iOS / macOS 为同名 framework，
/// Windows 为 bulter_sqlite_vec.dll。
final DynamicLibrary vec0 = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();
