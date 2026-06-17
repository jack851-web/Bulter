import 'package:flutter/material.dart';

/// Bulter 设计系统 Token
///
/// 设计语言融合 Cal.com（白底黑 CTA + Cal Sans）与 Clay.com（暖白画布 + 饱和特征卡片）：
/// - 画布底色 #FAF6EE
/// - 主 CTA 纯黑
/// - 6 模块品牌色
class BulterColors {
  BulterColors._();

  // 画布与基础色
  static const Color canvas = Color(0xFFFAF6EE);        // 暖白画布
  static const Color surface = Color(0xFFFFFFFF);       // 卡片白
  static const Color surfaceMuted = Color(0xFFF3ECDE);  // 次级背景
  static const Color divider = Color(0x1A000000);        // 分割线（10% 黑）

  // 文字色阶
  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textTertiary = Color(0xFF9A9A9A);
  static const Color textOnDark = Color(0xFFFAF6EE);

  // CTA 与交互
  static const Color cta = Color(0xFF000000);            // 主 CTA 纯黑
  static const Color ctaPressed = Color(0xFF1F1F1F);
  static const Color ctaText = Color(0xFFFAF6EE);

  // 6 模块品牌色（来自 01-architecture.md §三）
  static const Color butler = Color(0xFFFFB084);        // 中枢 桃色
  static const Color relationship = Color(0xFFFF4D8B);  // 关系 玫粉
  static const Color growth = Color(0xFF1A3A3A);        // 成长 深青
  static const Color wealth = Color(0xFFE8B94A);        // 财富 赭金
  static const Color thought = Color(0xFFB8A4ED);       // 思想 薰衣草
  static const Color health = Color(0xFF10B981);        // 健康 翠绿
  static const Color memory = Color(0xFF7C6CF0);        // 记忆 紫

  // 状态色
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFE8B94A);
  static const Color error = Color(0xFFE45757);
  static const Color info = Color(0xFF4D8AFF);
}

/// 间距 token（4 基数）
class BulterSpacing {
  BulterSpacing._();
  static const double xxs = 2;
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;
}

/// 圆角 token
class BulterRadius {
  BulterRadius._();
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double pill = 999;
}

/// 字号 token
class BulterFontSize {
  BulterFontSize._();
  static const double caption = 11;
  static const double footnote = 12;
  static const double body = 14;
  static const double bodyLg = 15;
  static const double titleS = 16;
  static const double titleM = 18;
  static const double titleL = 22;
  static const double displayS = 28;
  static const double displayM = 34;
  static const double displayL = 44;
}

class BulterFontWeight {
  BulterFontWeight._();
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight heavy = FontWeight.w800;
}

/// 阴影 token
class BulterShadow {
  BulterShadow._();
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];
  static const List<BoxShadow> fab = [
    BoxShadow(
      color: Color(0x29000000),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];
}

/// 应用 ThemeData 构建器
class BulterTheme {
  BulterTheme._();

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: BulterColors.canvas,
      canvasColor: BulterColors.canvas,
      colorScheme: const ColorScheme.light(
        primary: BulterColors.cta,
        onPrimary: BulterColors.ctaText,
        secondary: BulterColors.butler,
        onSecondary: BulterColors.textPrimary,
        surface: BulterColors.surface,
        onSurface: BulterColors.textPrimary,
        error: BulterColors.error,
        onError: BulterColors.textOnDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: BulterColors.canvas,
        foregroundColor: BulterColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: BulterColors.textPrimary,
          fontSize: BulterFontSize.titleM,
          fontWeight: BulterFontWeight.semibold,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: BulterFontSize.displayL,
          fontWeight: BulterFontWeight.heavy,
          color: BulterColors.textPrimary,
          height: 1.1,
        ),
        displayMedium: TextStyle(
          fontSize: BulterFontSize.displayM,
          fontWeight: BulterFontWeight.bold,
          color: BulterColors.textPrimary,
          height: 1.15,
        ),
        displaySmall: TextStyle(
          fontSize: BulterFontSize.displayS,
          fontWeight: BulterFontWeight.bold,
          color: BulterColors.textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: BulterFontSize.titleL,
          fontWeight: BulterFontWeight.semibold,
          color: BulterColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: BulterFontSize.titleM,
          fontWeight: BulterFontWeight.semibold,
          color: BulterColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: BulterFontSize.titleS,
          fontWeight: BulterFontWeight.semibold,
          color: BulterColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: BulterFontSize.bodyLg,
          fontWeight: FontWeight.w400,
          color: BulterColors.textPrimary,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          fontSize: BulterFontSize.body,
          fontWeight: FontWeight.w400,
          color: BulterColors.textPrimary,
          height: 1.45,
        ),
        bodySmall: TextStyle(
          fontSize: BulterFontSize.footnote,
          color: BulterColors.textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: BulterFontSize.caption,
          color: BulterColors.textTertiary,
          fontWeight: BulterFontWeight.medium,
        ),
      ),
      cardTheme: const CardThemeData(
        color: BulterColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(BulterRadius.xl)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: BulterColors.divider,
        thickness: 0.5,
        space: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: BulterColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(BulterRadius.xxl)),
        ),
      ),
      iconTheme: const IconThemeData(
        color: BulterColors.textPrimary,
        size: 20,
      ),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );
  }
}
