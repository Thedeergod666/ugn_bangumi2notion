part of 'detail_page.dart';

class RatingChart extends StatelessWidget {
  const RatingChart({
    super.key,
    required this.ratingCount,
    required this.total,
  });

  final Map<String, int> ratingCount;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;

    // Bangumi ratings are 1-10
    final counts = List.generate(10, (index) {
      final key = (index + 1).toString();
      return ratingCount[key] ?? 0;
    });

    final maxCount = counts.reduce((a, b) => a > b ? a : b);

    return Container(
      height: 180,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(10, (index) {
          // 1 star (left) to 10 stars (right)
          final count = counts[index];
          final ratio = maxCount == 0 ? 0.0 : count / maxCount;

          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: ratio.clamp(0.05, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.tertiary.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${index + 1}',
                    style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
