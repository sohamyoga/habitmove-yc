import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

// ─── Primary Button ───────────────────────────────────────────────────────────

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Widget? icon;
  final double? width;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 8)],
                  Text(label, style: AppTextStyles.button.copyWith(color: Colors.white)),
                ],
              ),
      ),
    );
  }
}

// ─── Secondary Button ─────────────────────────────────────────────────────────

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  const SecondaryButton({super.key, required this.label, this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[icon!, const SizedBox(width: 8)],
        Text(label),
      ],
    ),
  );
}

// ─── App Text Field ───────────────────────────────────────────────────────────

class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final bool autofocus;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.suffix,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: obscure,
    keyboardType: keyboardType,
    validator: validator,
    autofocus: autofocus,
    style: AppTextStyles.body.copyWith(color: AppColors.sage900),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffix,
    ),
  );
}

// ─── Alert Banner ─────────────────────────────────────────────────────────────

class AlertBanner extends StatelessWidget {
  final String message;
  final AlertType type;
  const AlertBanner({super.key, required this.message, this.type = AlertType.error});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (type) {
      AlertType.error   => (const Color(0xFFFEF2F2), AppColors.error, Icons.error_outline_rounded),
      AlertType.success => (const Color(0xFFF0FDF4), AppColors.success, Icons.check_circle_outline_rounded),
      AlertType.info    => (AppColors.warm50, AppColors.warm600, Icons.info_outline_rounded),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppTextStyles.body.copyWith(color: fg))),
        ],
      ),
    );
  }
}

enum AlertType { error, success, info }

// ─── Avatar ───────────────────────────────────────────────────────────────────

class UserAvatar extends StatelessWidget {
  final String initials;
  final double size;
  const UserAvatar({super.key, required this.initials, this.size = 40});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color: AppColors.sage200,
      shape: BoxShape.circle,
    ),
    child: Center(
      child: Text(
        initials,
        style: AppTextStyles.h3.copyWith(color: AppColors.sage800, fontSize: size * 0.36),
      ),
    ),
  );
}

// ─── Course Network Image ─────────────────────────────────────────────────────

class CourseImage extends StatelessWidget {
  final String? url;
  final String title;
  final double height;
  final BorderRadius? borderRadius;

  const CourseImage({
    super.key,
    this.url,
    required this.title,
    this.height = 180,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return _placeholder();
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: url!,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => _shimmer(),
        errorWidget: (_, __, ___) => _placeholder(),
      ),
    );
  }

  Widget _shimmer() => Shimmer.fromColors(
    baseColor: AppColors.sage100,
    highlightColor: AppColors.sage50,
    child: Container(height: height, color: AppColors.sage100),
  );

  Widget _placeholder() {
    final letter = title.isNotEmpty ? title[0].toUpperCase() : '?';
    return Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.sage100, AppColors.warm100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            fontFamily: 'DMSerifDisplay',
            fontSize: 56,
            color: AppColors.sage300,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

// ─── Badge / Chip ─────────────────────────────────────────────────────────────

class AppBadge extends StatelessWidget {
  final String label;
  final Color? color;
  const AppBadge({super.key, required this.label, this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: (color ?? AppColors.sage500).withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: (color ?? AppColors.sage500).withOpacity(0.3)),
    ),
    child: Text(
      label,
      style: AppTextStyles.bodySm.copyWith(
        color: color ?? AppColors.sage700,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

// ─── Skeleton Loader ─────────────────────────────────────────────────────────

class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const SkeletonBox({super.key, required this.width, required this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: AppColors.sage100,
    highlightColor: AppColors.sage50,
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.sage100,
        borderRadius: BorderRadius.circular(radius),
      ),
    ),
  );
}

// ─── Section Header ───────────────────────────────────────────────────────────

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const SectionTitle({super.key, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.displaySm),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: AppTextStyles.body.copyWith(color: AppColors.grey400)),
            ],
          ],
        ),
      ),
      if (action != null) action!,
    ],
  );
}

// ─── Star Rating ──────────────────────────────────────────────────────────────

class StarRating extends StatelessWidget {
  final int rating;
  final double size;
  const StarRating({super.key, required this.rating, this.size = 14});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) => Icon(
      i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
      color: AppColors.warm400,
      size: size,
    )),
  );
}

// ─── Price Widget ─────────────────────────────────────────────────────────────

class PriceWidget extends StatelessWidget {
  final double? price;
  final double? discountedPrice;
  final double fontSize;
  const PriceWidget({super.key, this.price, this.discountedPrice, this.fontSize = 16});

  @override
  Widget build(BuildContext context) {
    final isFree = price == null || price == 0;
    final hasDiscount = discountedPrice != null && discountedPrice! < (price ?? 0);

    if (isFree) {
      return Text('Free', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: AppColors.sage600));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '£${(hasDiscount ? discountedPrice! : price!).toStringAsFixed(2)}',
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: AppColors.sage900),
        ),
        if (hasDiscount)
          Text(
            '£${price!.toStringAsFixed(2)}',
            style: TextStyle(fontSize: fontSize - 3, color: AppColors.grey400, decoration: TextDecoration.lineThrough),
          ),
      ],
    );
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: AppColors.sage100, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.sage300, size: 36),
          ),
          const SizedBox(height: 16),
          Text(title, style: AppTextStyles.displaySm, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: AppTextStyles.body.copyWith(color: AppColors.grey400), textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 24), action!],
        ],
      ),
    ),
  );
}

// ─── Error Retry ─────────────────────────────────────────────────────────────

class ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.grey400, size: 48),
          const SizedBox(height: 12),
          Text(message, style: AppTextStyles.body.copyWith(color: AppColors.grey600), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          SecondaryButton(label: 'Retry', onPressed: onRetry),
        ],
      ),
    ),
  );
}
