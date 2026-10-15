import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Una barra del [KiteBarChart].
@immutable
class KiteBar {
  const KiteBar({
    required this.label,
    required this.value,
    required this.color,
    this.tooltip,
  });

  /// Etiqueta corta del eje (p. ej. el número de lista).
  final String label;

  /// Valor de la barra.
  final double value;

  final Color color;

  /// Texto largo para el tooltip; si es nulo se usa [label].
  final String? tooltip;
}

/// Gráfico de barras verticales con la grilla y tipografía del tema.
///
/// Deliberadamente sencillo: una sola serie, sin leyenda (las etiquetas del eje
/// ya identifican cada barra) y con el tooltip como único adorno interactivo.
/// Es el complemento categórico del [KiteDonut], que muestra el reparto.
class KiteBarChart extends StatelessWidget {
  const KiteBarChart({
    super.key,
    required this.bars,
    this.height = 220,
    this.valueLabel,
  });

  final List<KiteBar> bars;
  final double height;

  /// Formatea el valor en el tooltip. Por defecto, entero.
  final String Function(double)? valueLabel;

  @override
  Widget build(BuildContext context) {
    final c = KiteColors.of(context);
    final maxValue = bars.fold<double>(
      0,
      (m, b) => b.value > m ? b.value : m,
    );
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.2;
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: c.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: Text(
                      value.round().toString(),
                      style: TextStyle(fontSize: 11, color: c.mutedForeground),
                      textAlign: TextAlign.right,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= bars.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: SizedBox(
                      width: 48,
                      child: Text(
                        bars[index].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: c.mutedForeground,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => c.foreground,
              tooltipBorderRadius: BorderRadius.circular(6),
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final bar = bars[group.x];
                final text = valueLabel?.call(rod.toY) ??
                    rod.toY.round().toString();
                return BarTooltipItem(
                  '${bar.tooltip ?? bar.label}\n$text',
                  TextStyle(
                    color: c.background,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
          barGroups: [
            for (var i = 0; i < bars.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: bars[i].value,
                    color: bars[i].color,
                    width: 26,
                    borderRadius: KiteRadius.allSm,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
