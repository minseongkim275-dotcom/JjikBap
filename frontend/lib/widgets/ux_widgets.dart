import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// 도허티 임계 - 스켈레톤 로딩 UI
class SkeletonLoader extends StatelessWidget {
  final double height;
  final double? width;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    this.height = 20,
    this.width,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// 대시보드 스켈레톤 UI
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 칼로리 카드 스켈레톤
          const SkeletonLoader(height: 180, borderRadius: 16),
          const SizedBox(height: 16),
          // 영양소 카드들 스켈레톤
          Row(
            children: [
              const Expanded(child: SkeletonLoader(height: 80, borderRadius: 16)),
              const SizedBox(width: 8),
              const Expanded(child: SkeletonLoader(height: 80, borderRadius: 16)),
              const SizedBox(width: 8),
              const Expanded(child: SkeletonLoader(height: 80, borderRadius: 16)),
              const SizedBox(width: 8),
              const Expanded(child: SkeletonLoader(height: 80, borderRadius: 16)),
            ],
          ),
          const SizedBox(height: 24),
          // 음식 추가 섹션 스켈레톤
          const SkeletonLoader(height: 200, borderRadius: 16),
        ],
      ),
    );
  }
}

/// 분석 중 shimmer 로딩 위젯
class AnalyzingShimmer extends StatelessWidget {
  const AnalyzingShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          Shimmer.fromColors(
            baseColor: Colors.orange.shade300,
            highlightColor: Colors.orange.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome, color: Colors.orange.shade400, size: 28),
                const SizedBox(width: 12),
                Text(
                  'AI가 분석하고 있어요',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 분석 결과 프리뷰 스켈레톤
          const SkeletonLoader(height: 24, borderRadius: 8),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(child: SkeletonLoader(height: 40, borderRadius: 10)),
              SizedBox(width: 8),
              Expanded(child: SkeletonLoader(height: 40, borderRadius: 10)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: const [
              Expanded(child: SkeletonLoader(height: 40, borderRadius: 10)),
              SizedBox(width: 8),
              Expanded(child: SkeletonLoader(height: 40, borderRadius: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 피크엔드 법칙 - 저장 성공 다이얼로그
class SuccessDialog extends StatefulWidget {
  final String message;
  final VoidCallback? onDismiss;

  const SuccessDialog({
    super.key,
    required this.message,
    this.onDismiss,
  });

  @override
  State<SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<SuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _checkAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );
    _controller.forward();

    // 2초 후 자동 닫힘
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        Navigator.of(context).pop();
        widget.onDismiss?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _checkAnimation,
                builder: (context, child) {
                  return Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 48 * _checkAnimation.value,
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                widget.message,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '잘하고 있어요! 계속 기록해보세요',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 폰 레스토프 효과 - 강조 CTA 버튼
class PrimaryCTAButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const PrimaryCTAButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: onPressed != null
              ? [const Color(0xFF43A047), const Color(0xFF2E7D32)]
              : [Colors.grey.shade300, Colors.grey.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: const Color(0xFF4CAF50).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(icon, color: Colors.white, size: 26),
                const SizedBox(width: 12),
                Text(
                  isLoading ? '저장 중...' : label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 성공 다이얼로그 표시 헬퍼 함수
void showSuccessDialog(BuildContext context, String message, {VoidCallback? onDismiss}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => SuccessDialog(
      message: message,
      onDismiss: onDismiss,
    ),
  );
}
