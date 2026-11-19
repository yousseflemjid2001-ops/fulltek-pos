import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';

class OwnerDashboardView extends StatelessWidget {
  final PosStore store;
  const OwnerDashboardView({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final i18n = store.i18n;
    final p = FullTekThemes.paletteOf(context);
    final breakdown = store.revenueByPaymentMethod;
    final lowStock = store.lowStockIngredients;
    final topDishes = store.topSellingDishes;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header + Training Mode toggle
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.analytics_rounded, color: p.primary, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    i18n.t('nav_dashboard'),
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: p.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: store.trainingMode
                      ? p.warning.withValues(alpha: 0.16)
                      : p.surface,
                  borderRadius: BorderRadius.circular(p.radius),
                  border: Border.all(
                      color: store.trainingMode ? p.warning : p.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.school_rounded,
                        size: 18,
                        color: store.trainingMode ? p.warning : p.textMuted),
                    const SizedBox(width: 8),
                    Text(
                      i18n.t('training_mode'),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: p.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      key: const Key('dashboard_training_switch'),
                      value: store.trainingMode,
                      onChanged: (_) => store.toggleTrainingMode(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4 KPI Cards
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 520 ? 2 : 1);
              final cards = [
                _kpiCard(
                  i18n.t('kpi_revenue_today'),
                  '${store.todayRevenueMru.toStringAsFixed(0)} MRU',
                  Icons.payments_rounded,
                  p.primary,
                  p,
                  key: const Key('kpi_revenue_card'),
                ),
                _kpiCard(
                  i18n.t('kpi_tickets'),
                  '${store.todayTicketsCount}',
                  Icons.receipt_long_rounded,
                  p.accent,
                  p,
                  key: const Key('kpi_tickets_card'),
                ),
                _kpiCard(
                  i18n.t('kpi_avg_basket'),
                  '${store.averageBasketMru.toStringAsFixed(0)} MRU',
                  Icons.shopping_basket_rounded,
                  p.success,
                  p,
                ),
                _kpiCard(
                  '${i18n.t('kpi_food_cost')} / ${i18n.t('kpi_gross_margin')}',
                  '${store.foodCostPercent.toStringAsFixed(1)}% / ${store.grossMarginPercent.toStringAsFixed(1)}%',
                  Icons.pie_chart_rounded,
                  p.vipGold,
                  p,
                ),
              ];
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: cols,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: cols == 1 ? 3.2 : 2.1,
                children: cards,
              );
            },
          ),
          const SizedBox(height: 16),

          // Payment breakdown + Top dishes
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 820;
              final payCard = _buildPaymentBreakdownCard(breakdown, i18n, p);
              final stockCard = _buildBomStockCard(lowStock, i18n, p);
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: payCard),
                    const SizedBox(width: 14),
                    Expanded(child: stockCard),
                  ],
                );
              }
              return Column(
                children: [
                  payCard,
                  const SizedBox(height: 14),
                  stockCard,
                ],
              );
            },
          ),

          if (topDishes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(p.radius),
                border: Border.all(color: p.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.t('kpi_top_dishes'),
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: p.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: topDishes.take(6).map((e) {
                      return Chip(
                        avatar: CircleAvatar(
                          backgroundColor: p.primary,
                          child: Text('${e.value}',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: p.onPrimary)),
                        ),
                        label: Text(e.key),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kpiCard(
    String title,
    String value,
    IconData icon,
    Color color,
    PosPalette p, {
    Key? key,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(p.radius),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: p.textMuted)),
                const SizedBox(height: 4),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: p.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBreakdownCard(
      Map<PaymentMethod, double> breakdown, dynamic i18n, PosPalette p) {
    final total = breakdown.values.fold(0.0, (a, b) => a + b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(p.radius),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.t('kpi_payment_breakdown'),
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: p.textPrimary),
          ),
          const SizedBox(height: 12),
          ...PaymentMethod.values.map((m) {
            final amt = breakdown[m] ?? 0.0;
            final ratio = total > 0 ? (amt / total).clamp(0.0, 1.0) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(m.name.toUpperCase(),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: p.textPrimary)),
                      Text('${amt.toStringAsFixed(0)} MRU',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: p.primary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 6,
                      backgroundColor: p.surfaceAlt,
                      color: p.primary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBomStockCard(
      List<Ingredient> lowStock, dynamic i18n, PosPalette p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(p.radius),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                i18n.t('stock_title'),
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: p.textPrimary),
              ),
              if (lowStock.isNotEmpty)
                Container(
                  key: const Key('low_stock_alert_badge'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: p.danger.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '⚠ ${lowStock.length} ${i18n.t('stock_low_alert')}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: p.danger),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...store.ingredients.map((ing) {
            final low = ing.isLowStock;
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                low ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
                color: low ? p.danger : p.success,
                size: 18,
              ),
              title: Text(ing.label(store.lang),
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: p.textPrimary)),
              subtitle: Text(
                '${i18n.t('stock_min')}: ${ing.minStock} ${ing.unit} · PMP ${ing.pmpCostMru.toStringAsFixed(0)} MRU',
                style: TextStyle(fontSize: 11, color: p.textMuted),
              ),
              trailing: Text(
                '${ing.currentStock.toStringAsFixed(2)} ${ing.unit}',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: low ? p.danger : p.primary),
              ),
            );
          }),
        ],
      ),
    );
  }
}
