# commit_3 — 自建 bulter_sqlite_vec 本地 FFI 插件

- **版本**：0.2.1（向后兼容的修复版本）
- **commit 类型**：`fix(storage)` / `build(android)`
- **影响范围**：Android 构建系统、sqlite-vec 扩展加载方式
- **关联审查报告**：[code_review_report.md](file:///d:/others/app/Bulter/doc/code-quality/code_review_report.md)

## 背景

Step 2 提交后，Android 端执行 `flutter build apk` 在 Gradle 阶段报错：

```
* What went wrong:
Execution failed for task ':sqlite_vec:configureCMakeDebug[arm64-v8a]'.
  CMake Error at CMakeLists.txt:8 (add_library):
    Cannot find source file: sqlite-vec.c
    No SOURCES given to target: sqlite_vec
```

## 根因

依赖的 pub 包 **`sqlite_vec-0.1.7-alpha.3`**（即 `ningpengtao-coder/sqlite-vec` 派生）有严重打包缺陷：

| 缺失文件 | 期望来源 | 包内是否存在 |
|---|---|---|
| `src/sqlite-vec.c` | 上游仓库 `../../sqlite-vec.c` | ❌ 缺失 |
| `src/sqlite-vec.h` | 上游仓库 `../../sqlite-vec.h` | ❌ 缺失（仓库只发 `sqlite-vec.h.tmpl`）|
| `src/sqlite3ext.h` | sqlite3 扩展头 | ❌ 全局缓存均无 |

包内 `Makefile` 显示其依赖构建期从 workspace 根目录拷贝源文件，但 `pub publish` 阶段未带任何 .c / .h。直接结果是**任何 Android 平台都会阻断**。

## 修复

按用户决策，采用 **本地 FFI 插件** 方案，把 sqlite-vec 源码完整 vendoring 到工程内，**永久摆脱对外部 alpha 包的依赖**。

### 新增文件

```
src/plugins/bulter_sqlite_vec/
├── pubspec.yaml                          # 本地插件元数据
├── lib/bulter_sqlite_vec.dart            # DynamicLibrary vec0 句柄
├── src/                                  # vendored 源码
│   ├── CMakeLists.txt                    # 构建 libbulter_sqlite_vec.so
│   ├── sqlite-vec.c                      # 309 KB（GitHub asg017/sqlite-vec v0.1.7-alpha.3）
│   ├── sqlite-vec.h                      # 自模板 + VERSION 字段生成
│   ├── sqlite3ext.h                      # 651 KB（SQLite 3.47 amalgamation）
│   └── sqlite3.h                         # 38 KB（同上）
├── android/
│   ├── build.gradle                      # externalNativeBuild 指向 src/CMakeLists.txt
│   └── src/main/AndroidManifest.xml
├── ios/
│   ├── Classes/bulter_sqlite_vec.c       # 占位
│   └── bulter_sqlite_vec.podspec         # source_files 指向 ../src/sqlite-vec.c
├── linux/CMakeLists.txt + *_plugin.cc    # CMake 集成
├── macos/Classes/ + .podspec             # 同 iOS
└── windows/CMakeLists.txt                # 同 Linux
```

### 修改文件

- `src/pubspec.yaml` — 移除 `sqlite_vec: ^0.1.0`，改用 `bulter_sqlite_vec: { path: plugins/bulter_sqlite_vec }`
- `src/lib/db/connection.dart` — import 切换为 `package:bulter_sqlite_vec/bulter_sqlite_vec.dart`，入口符号仍为 `sqlite3_vec_init`

### 验证

| 验证项 | 结果 |
|---|---|
| `flutter analyze` | ✅ No issues found |
| `flutter test` | ✅ 26/26 全过（Windows 桌面无 .dll 时按设计降级）|
| `flutter build apk --debug` | ✅ `Built build/app/outputs/flutter-apk/app-debug.apk`（94.9s）|
| sqlite-vec 扩展注册 | ✅ Android APK 包含 `libbulter_sqlite_vec.so` |

## 后续清理

- `lib/db/connection.dart` 内 `print` 噪声属 S-2 严重问题遗留，仍待替换为 `debugPrint` 或统一日志抽象 `BulterLog`，并在 `analysis_options.yaml` 启用 `avoid_print: true`。
- 旧版 `sqlite_vec` 包残留问题：现 `pubspec.lock` 中已不再包含此包，pub 缓存中的破损包不影响构建。

## 引用

- 上游仓库：[asg017/sqlite-vec @ v0.1.7-alpha.3](https://github.com/asg017/sqlite-vec/tree/v0.1.7-alpha.3)
- SQLite amalgamation：[sqlite-amalgamation-3470000](https://www.sqlite.org/2024/sqlite-amalgamation-3470000.zip)
- 原审查报告：[code_review_report.md](file:///d:/others/app/Bulter/doc/code-quality/code_review_report.md) §"严重问题 S-1/S-2"
