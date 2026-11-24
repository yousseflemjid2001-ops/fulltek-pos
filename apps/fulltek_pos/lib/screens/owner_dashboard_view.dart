import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';

enum _DashboardPeriod { today, week, month, all }

class OwnerDashboardView extends StatefulWidget {
  final PosStore store;
  const OwnerDashboardView({super.key, required this.store});

  @override
  State<OwnerDashboardView> createState() => _OwnerDashboardViewState();
}

class _OwnerDashboardViewState extends State<OwnerDashboardView> {
  _DashboardPeriod _period = _DashboardPeriod.today;

  static const _paymentColors = <PaymentMethod, Color>{
    PaymentMethod.cash: Color(0xFF10B981),
    PaymentMethod.bankily: Color(0xFFF59E0B),
    PaymentMethod.masrivi: Color(0xFF3B82F6),
    PaymentMethod.sedad: Color(0xFF8B5CF6),
    PaymentMethod.bimbank: Color(0xFF06B6D4),
    PaymentMethod.click: Color(0xFFEC4899),
    PaymentMethod.otherWallet: Color(0xFF14B8A6),
    PaymentMethod.karni: Color(0xFFEF4444),
  };

  static const _paymentLabels = <PaymentMethod, String>{
    PaymentMethod.cash: 'Espèces (Cash)',
    PaymentMethod.bankily: 'Bankily',
    PaymentMethod.masrivi: 'Masrvi',
    PaymentMethod.sedad: 'Sedad',
    PaymentMethod.bimbank: 'BIM-Bank',
    PaymentMethod.click: 'Click',
    PaymentMethod.otherWallet: 'Autres Portefeuilles (BCI, Amanty, GazaPay...)',
    PaymentMethod.karni: 'Crédit Karni',
  };

  List<PosOrder> _ordersForPeriod(PosStore store) {
    final now = DateTime.now();
    return store.completedOrders.where((o) {
      if (o.isTraining) return false;
      final dt = o.paidAt ?? o.createdAt;
      return switch (_period) {
        _DashboardPeriod.today =>
          dt.year == now.year && dt.month == now.month && dt.day == now.day,
        _DashboardPeriod.week =>
          dt.isAfter(now.subtract(const Duration(days: 7))),
        _DashboardPeriod.month =>
          dt.isAfter(now.subtract(const Duration(days: 30))),
        _DashboardPeriod.all => true,
      };
    }).toList(growable: false);
  }

  List<ReturnRemakeCompRecord> _remakesForPeriod(PosStore store) {
    final now = DateTime.now();
    return store.remakeRecords.where((r) {
      final dt = r.createdAt;
      return switch (_period) {
        _DashboardPeriod.today =>
          dt.year == now.year && dt.month == now.month && dt.day == now.day,
        _DashboardPeriod.week =>
          dt.isAfter(now.subtract(const Duration(days: 7))),
        _DashboardPeriod.month =>
          dt.isAfter(now.subtract(const Duration(days: 30))),
        _DashboardPeriod.all => true,
      };
    }).toList(growable: false);
  }

  Map<PaymentMethod, double> _paymentBreakdown(List<PosOrder> orders) {
    final map = {for (final m in PaymentMethod.values) m: 0.0};
    for (final o in orders) {
      var remainingChange = o.changeDue;
      for (final p in o.payments) {
        var effective = p.amountMru;
        if (p.method == PaymentMethod.cash && remainingChange > 0) {
          final deducted =
              remainingChange > effective ? effective : remainingChange;
          effective -= deducted;
          remainingChange -= deducted;
        }
        map[p.method] = (map[p.method] ?? 0.0) + effective;
      }
    }
    return map;
  }

  String _fmtMru(double v) {
    final rounded = v.round();
    final str = rounded.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      final posFromEnd = str.length - i;
      buf.write(str[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write(' ');
    }
    return '${rounded < 0 ? '-' : ''}$buf MRU';
  }

  String _periodLabel(_DashboardPeriod p) => switch (p) {
        _DashboardPeriod.today => "Aujourd'hui",
        _DashboardPeriod.week => '7 jours',
        _DashboardPeriod.month => '30 jours',
        _DashboardPeriod.all => 'Tout',
      };

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final i18n = store.i18n;
    final p = FullTekThemes.paletteOf(context);

    final orders = _ordersForPeriod(store);
    final remakes = _remakesForPeriod(store);
    final revenueTtc = orders.fold<double>(0.0, (s, o) => s + o.grossTotal);
    final revenueHt = orders.fold<double>(0.0, (s, o) => s + o.subtotalHtMru);
    final totalTva = orders.fold<double>(0.0, (s, o) => s + o.tvaAmountMru);
    final ticketsCount = orders.length;
    final itemsSoldCount = orders.fold<int>(
      0,
      (s, o) => s + o.items.fold<int>(0, (acc, l) => acc + l.quantity),
    );
    final avgBasket = ticketsCount > 0 ? revenueTtc / ticketsCount : 0.0;
    final maxTicket = orders.isEmpty
        ? 0.0
        : orders.map((o) => o.grossTotal).reduce(math.max);

    final breakdown = _paymentBreakdown(orders);
    final lowStock = store.lowStockIngredients;

    // Live floor occupancy & open orders value
    final totalTables = store.tables.length;
    final occupiedTables = store.tables.where((t) {
      final o = store.orderForTable(t.id);
      return (o != null && o.items.isNotEmpty) ||
          t.status == TableStatus.occupied ||
          t.status == TableStatus.billRequested;
    }).length;
    final openOrdersValue =
        store.waitingOrders.fold<double>(0.0, (s, o) => s + o.netTotal);

    // Voids / Remakes / Comps leakage
    final voidsTotalMru =
        remakes.fold<double>(0.0, (s, r) => s + r.amountMru);

    // Hourly revenue 08h -> 23h
    final hourly = <int, double>{for (var h = 8; h <= 23; h++) h: 0.0};
    for (final o in orders) {
      final hr = (o.paidAt ?? o.createdAt).hour.clamp(8, 23);
      hourly[hr] = (hourly[hr] ?? 0.0) + o.grossTotal;
    }

    // Channel split (Sur place / Emporter / Livraison)
    final channelRevenue = {for (final m in ServiceMode.values) m: 0.0};
    final channelCount = {for (final m in ServiceMode.values) m: 0};
    for (final o in orders) {
      channelRevenue[o.serviceMode] =
          (channelRevenue[o.serviceMode] ?? 0.0) + o.grossTotal;
      channelCount[o.serviceMode] = (channelCount[o.serviceMode] ?? 0) + 1;
    }

    // Category revenue breakdown
    final catNames = {for (final c in store.categories) c.id: '${c.icon} ${c.label(store.lang)}'};
    final catRevenue = <String, double>{};
    final catQty = <String, int>{};
    for (final o in orders) {
      for (final l in o.items) {
        final label = catNames[l.item.categoryId] ?? '📦 Sans famille';
        catRevenue[label] = (catRevenue[label] ?? 0.0) + l.lineTotal;
        catQty[label] = (catQty[label] ?? 0) + l.quantity;
      }
    }
    final rankedCategories = catRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Top dishes with qty + revenue
    final dishStats = <String, ({int qty, double rev, String icon})>{};
    for (final o in orders) {
      for (final l in o.items) {
        final name = l.item.label(store.lang);
        final prev = dishStats[name];
        dishStats[name] = (
          qty: (prev?.qty ?? 0) + l.quantity,
          rev: (prev?.rev ?? 0.0) + l.lineTotal,
          icon: l.item.icon,
        );
      }
    }
    final rankedDishes = dishStats.entries.toList()
      ..sort((a, b) => b.value.rev.compareTo(a.value.rev));

    // Staff / Waiter leaderboard
    final staffStats = <String, ({int tickets, double rev})>{};
    for (final o in orders) {
      final who = (o.serverName != null && o.serverName!.trim().isNotEmpty)
          ? o.serverName!.trim()
          : (o.cashierName ?? o.staffName);
      final prev = staffStats[who];
      staffStats[who] = (
        tickets: (prev?.tickets ?? 0) + 1,
        rev: (prev?.rev ?? 0.0) + o.grossTotal,
      );
    }
    final rankedStaff = staffStats.entries.toList()
      ..sort((a, b) => b.value.rev.compareTo(a.value.rev));

    final now = DateTime.now();
    final dateHeader =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} · '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Executive Header + Period Filter + Training Switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  p.primary.withValues(alpha: 0.14),
                  p.surface,
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.primary.withValues(alpha: 0.3)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 14,
              runSpacing: 12,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: p.primary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.insights_rounded,
                          color: p.primary, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Tableau de Bord Exécutif',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: p.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: p.success.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: p.success,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'LIVE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: p.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${store.tenantName} · Mis à jour le $dateHeader',
                          style: TextStyle(fontSize: 12, color: p.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                // Period Selector Segmented Control
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: p.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _DashboardPeriod.values.map((per) {
                      final active = _period == per;
                      return InkWell(
                        key: Key('dash_period_${per.name}'),
                        borderRadius: BorderRadius.circular(9),
                        onTap: () => setState(() => _period = per),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: active ? p.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            _periodLabel(per),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: active ? p.onPrimary : p.textMuted,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // Training Mode toggle
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: store.trainingMode
                        ? p.warning.withValues(alpha: 0.16)
                        : p.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: store.trainingMode ? p.warning : p.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school_rounded,
                          size: 17,
                          color: store.trainingMode ? p.warning : p.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        i18n.t('training_mode'),
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: p.textPrimary),
                      ),
                      const SizedBox(width: 6),
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
          ),
          const SizedBox(height: 16),

          // 2. 6 Modern Executive KPI Cards
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 1120
                  ? 3
                  : (c.maxWidth >= 660 ? 2 : 1);
              final ratio = cols == 3 ? 2.55 : (cols == 2 ? 2.4 : 3.0);
              final fcColor = store.foodCostPercent <= 35
                  ? p.success
                  : (store.foodCostPercent <= 45 ? p.warning : p.danger);

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: cols,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: ratio,
                children: [
                  _modernKpiCard(
                    key: const Key('kpi_revenue_card'),
                    title: store.tvaEnabled
                        ? 'Chiffre d\'Affaires TTC (${_periodLabel(_period)})'
                        : 'Chiffre d\'Affaires (${_periodLabel(_period)})',
                    value: _fmtMru(revenueTtc),
                    subtitle: store.tvaEnabled
                        ? 'HT : ${_fmtMru(revenueHt)}  ·  TVA ${store.tvaRatePercent.toStringAsFixed(0)}% : ${_fmtMru(totalTva)}'
                        : '$ticketsCount ticket(s) encaissé(s)',
                    badge: '$ticketsCount ticket(s)',
                    icon: Icons.payments_rounded,
                    color: p.primary,
                    p: p,
                  ),
                  _modernKpiCard(
                    key: const Key('kpi_tickets_card'),
                    title: 'Volume Tickets & Articles',
                    value: '$ticketsCount tickets',
                    subtitle: '$itemsSoldCount article(s) vendus sur la période',
                    badge: ticketsCount > 0
                        ? '${(itemsSoldCount / ticketsCount).toStringAsFixed(1)} art/ticket'
                        : '0 art/ticket',
                    icon: Icons.receipt_long_rounded,
                    color: p.accent,
                    p: p,
                  ),
                  _modernKpiCard(
                    title: 'Panier Moyen',
                    value: _fmtMru(avgBasket),
                    subtitle: 'Ticket max : ${_fmtMru(maxTicket)}',
                    badge: 'Moyenne TTC',
                    icon: Icons.shopping_bag_rounded,
                    color: p.success,
                    p: p,
                  ),
                  _modernKpiCard(
                    title: 'Marge Brute & Food Cost',
                    value: '${store.grossMarginPercent.toStringAsFixed(1)} %',
                    subtitle:
                        'Food Cost : ${store.foodCostPercent.toStringAsFixed(1)}% (${_fmtMru(store.todayFoodCostMru)})',
                    badge: store.foodCostPercent <= 35
                        ? 'Optimal'
                        : (store.foodCostPercent <= 45 ? 'À surveiller' : 'Élevé'),
                    icon: Icons.pie_chart_rounded,
                    color: fcColor,
                    p: p,
                  ),
                  _modernKpiCard(
                    title: 'Occupation Salle (En cours)',
                    value: '$occupiedTables / $totalTables tables',
                    subtitle:
                        'Encours non encaissé : ${_fmtMru(openOrdersValue)}',
                    badge: totalTables > 0
                        ? '${((occupiedTables / totalTables) * 100).round()} %'
                        : '0 %',
                    icon: Icons.table_restaurant_rounded,
                    color: p.warning,
                    p: p,
                  ),
                  _modernKpiCard(
                    title: 'Annulations, Retours & Offerts',
                    value: _fmtMru(voidsTotalMru),
                    subtitle: '${remakes.length} opération(s) tracée(s) · Contrôle anti-fraude',
                    badge: remakes.isEmpty ? 'RAS' : '⚠ ${remakes.length}',
                    icon: Icons.shield_outlined,
                    color: remakes.isEmpty ? p.success : p.danger,
                    p: p,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // 3. Visual Charts Row: Hourly Sales Curve + Payment Methods Donut
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 900;
              final hourlyCard = _buildHourlyChartCard(hourly, p);
              final donutCard = _buildPaymentDonutCard(breakdown, i18n, p);
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 58, child: hourlyCard),
                    const SizedBox(width: 14),
                    Expanded(flex: 42, child: donutCard),
                  ],
                );
              }
              return Column(
                children: [
                  hourlyCard,
                  const SizedBox(height: 14),
                  donutCard,
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // 4. Service Channels Split + Revenue by Category
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 900;
              final channelCard = _buildServiceChannelCard(
                  channelRevenue, channelCount, revenueTtc, p);
              final catCard =
                  _buildCategoryRevenueCard(rankedCategories, catQty, revenueTtc, p);
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 48, child: channelCard),
                    const SizedBox(width: 14),
                    Expanded(flex: 52, child: catCard),
                  ],
                );
              }
              return Column(
                children: [
                  channelCard,
                  const SizedBox(height: 14),
                  catCard,
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // 5. Top Selling Dishes Leaderboard + Team Performance (Servers & Cashiers)
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 900;
              final dishesCard = _buildTopDishesCard(rankedDishes, p);
              final teamCard =
                  _buildTeamPerformanceCard(rankedStaff, revenueTtc, p);
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: dishesCard),
                    const SizedBox(width: 14),
                    Expanded(child: teamCard),
                  ],
                );
              }
              return Column(
                children: [
                  dishesCard,
                  const SizedBox(height: 14),
                  teamCard,
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // 6. BOM Stock Health + Financial Pulse (Karni, Last Z, Cloud Sync)
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 900;
              final stockCard = _buildBomStockCard(lowStock, i18n, p);
              final healthCard = _buildFinancialHealthCard(store, p);
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 58, child: stockCard),
                    const SizedBox(width: 14),
                    Expanded(flex: 42, child: healthCard),
                  ],
                );
              }
              return Column(
                children: [
                  stockCard,
                  const SizedBox(height: 14),
                  healthCard,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _modernKpiCard({
    Key? key,
    required String title,
    required String value,
    required String subtitle,
    required String badge,
    required IconData icon,
    required Color color,
    required PosPalette p,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: p.textMuted,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: p.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: p.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required PosPalette p,
    required IconData icon,
    required String title,
    String? trailingBadge,
    Color? badgeColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: p.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: p.textPrimary,
                  ),
                ),
              ),
              if (trailingBadge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? p.primary).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    trailingBadge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: badgeColor ?? p.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildHourlyChartCard(Map<int, double> hourly, PosPalette p) {
    final entries = hourly.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final peak = entries.reduce((a, b) => a.value >= b.value ? a : b);
    final hasData = peak.value > 0;

    return _sectionCard(
      p: p,
      icon: Icons.show_chart_rounded,
      title: 'Évolution du CA par Heure (08h → 23h)',
      trailingBadge: hasData
          ? '🔥 Pic ${peak.key}h : ${_fmtMru(peak.value)}'
          : 'En attente de ventes',
      badgeColor: hasData ? p.warning : p.textMuted,
      child: Column(
        children: [
          SizedBox(
            height: 210,
            child: CustomPaint(
              size: const Size(double.infinity, 210),
              painter: _HourlyRevenueChartPainter(
                entries: entries,
                primaryColor: p.primary,
                accentColor: p.accent,
                gridColor: p.border,
                textColor: p.textMuted,
                peakHour: hasData ? peak.key : -1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final h in const [8, 10, 12, 14, 16, 18, 20, 22])
                Text(
                  '${h}h',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: h == peak.key && hasData
                        ? FontWeight.w900
                        : FontWeight.w600,
                    color: h == peak.key && hasData ? p.primary : p.textMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDonutCard(
      Map<PaymentMethod, double> breakdown, dynamic i18n, PosPalette p) {
    final total = breakdown.values.fold<double>(0.0, (a, b) => a + b);
    final activeSegments = PaymentMethod.values
        .map((m) => (
              method: m,
              amount: breakdown[m] ?? 0.0,
              color: _paymentColors[m] ?? p.primary,
            ))
        .toList();

    return _sectionCard(
      p: p,
      icon: Icons.donut_large_rounded,
      title: 'Répartition des Paiements (7 modes)',
      trailingBadge: _fmtMru(total),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 146,
            height: 146,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(146, 146),
                  painter: _PaymentDonutPainter(
                    segments: activeSegments,
                    emptyColor: p.surfaceAlt,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: p.textMuted,
                      ),
                    ),
                    Text(
                      total > 0 ? '${total.round()}' : '0',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: p.textPrimary,
                      ),
                    ),
                    Text(
                      'MRU',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: p.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: activeSegments.map((s) {
                final pct = total > 0 ? (s.amount / total) * 100 : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: s.color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          _paymentLabels[s.method] ?? s.method.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${pct.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: p.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 72,
                        child: Text(
                          _fmtMru(s.amount),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: s.amount > 0 ? p.textPrimary : p.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceChannelCard(
    Map<ServiceMode, double> rev,
    Map<ServiceMode, int> count,
    double totalRev,
    PosPalette p,
  ) {
    final colors = {
      ServiceMode.dineIn: const Color(0xFF10B981),
      ServiceMode.takeaway: const Color(0xFFF59E0B),
      ServiceMode.delivery: const Color(0xFF3B82F6),
    };

    return _sectionCard(
      p: p,
      icon: Icons.storefront_rounded,
      title: 'Canaux de Service (Sur place · Emporter · Livraison)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Horizontal Stacked Distribution Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: totalRev <= 0
                  ? Container(color: p.surfaceAlt)
                  : Row(
                      children: ServiceMode.values.map((m) {
                        final v = rev[m] ?? 0.0;
                        if (v <= 0) return const SizedBox.shrink();
                        return Expanded(
                          flex: math.max(1, v.round()),
                          child: Container(color: colors[m]),
                        );
                      }).toList(),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: ServiceMode.values.map((m) {
              final r = rev[m] ?? 0.0;
              final c = count[m] ?? 0;
              final pct = totalRev > 0 ? (r / totalRev) * 100 : 0.0;
              final col = colors[m]!;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                      right: m == ServiceMode.delivery ? 0 : 8),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: p.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: col.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${m.emoji} ${m.label(widget.store.lang)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: col,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _fmtMru(r),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          color: p.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$c cmd · ${pct.toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 11, color: p.textMuted),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRevenueCard(
    List<MapEntry<String, double>> ranked,
    Map<String, int> qtyMap,
    double totalRev,
    PosPalette p,
  ) {
    final maxVal = ranked.isNotEmpty ? ranked.first.value : 1.0;
    return _sectionCard(
      p: p,
      icon: Icons.category_rounded,
      title: 'Chiffre d\'Affaires par Famille',
      trailingBadge: '${ranked.length} famille(s)',
      child: ranked.isEmpty
          ? _emptyHint('Aucune vente enregistrée sur cette période.', p)
          : Column(
              children: ranked.take(6).map((e) {
                final ratio = maxVal > 0 ? (e.value / maxVal).clamp(0.0, 1.0) : 0.0;
                final share = totalRev > 0 ? (e.value / totalRev) * 100 : 0.0;
                final qty = qtyMap[e.key] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${e.key} ($qty art.)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: p.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${share.toStringAsFixed(0)}% · ${_fmtMru(e.value)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: p.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 8,
                          backgroundColor: p.surfaceAlt,
                          color: p.primary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildTopDishesCard(
    List<MapEntry<String, ({int qty, double rev, String icon})>> ranked,
    PosPalette p,
  ) {
    final maxRev = ranked.isNotEmpty ? ranked.first.value.rev : 1.0;
    const medals = ['🥇', '🥈', '🥉'];

    return _sectionCard(
      p: p,
      icon: Icons.emoji_events_rounded,
      title: 'Top Plats les Plus Rentables',
      trailingBadge: 'Top ${math.min(6, ranked.length)}',
      badgeColor: p.vipGold,
      child: ranked.isEmpty
          ? _emptyHint('Aucun plat vendu sur cette période.', p)
          : Column(
              children: ranked.take(6).toList().asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final ratio =
                    maxRev > 0 ? (item.value.rev / maxRev).clamp(0.0, 1.0) : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          i < 3 ? medals[i] : '#${i + 1}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: i < 3 ? 16 : 12,
                            fontWeight: FontWeight.w900,
                            color: p.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.value.icon} ${item.key}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: p.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${item.value.qty}x · ${_fmtMru(item.value.rev)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: p.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 6,
                                backgroundColor: p.surfaceAlt,
                                color: i == 0 ? p.vipGold : p.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildTeamPerformanceCard(
    List<MapEntry<String, ({int tickets, double rev})>> rankedStaff,
    double totalRev,
    PosPalette p,
  ) {
    return _sectionCard(
      p: p,
      icon: Icons.groups_rounded,
      title: 'Performance Équipe (Serveurs & Caissiers)',
      trailingBadge: '${rankedStaff.length} actif(s)',
      child: rankedStaff.isEmpty
          ? _emptyHint('Aucune vente par opérateur sur cette période.', p)
          : Column(
              children: rankedStaff.take(6).map((e) {
                final avg =
                    e.value.tickets > 0 ? e.value.rev / e.value.tickets : 0.0;
                final share = totalRev > 0 ? (e.value.rev / totalRev) * 100 : 0.0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: p.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: p.primary.withValues(alpha: 0.16),
                        child: Text(
                          e.key.isNotEmpty ? e.key[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: p.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: p.textPrimary,
                              ),
                            ),
                            Text(
                              '${e.value.tickets} ticket(s) · Panier moy. ${_fmtMru(avg)}',
                              style: TextStyle(fontSize: 11, color: p.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _fmtMru(e.value.rev),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: p.primary,
                            ),
                          ),
                          Text(
                            '${share.toStringAsFixed(0)} % du CA',
                            style: TextStyle(fontSize: 10.5, color: p.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildBomStockCard(
      List<Ingredient> lowStock, dynamic i18n, PosPalette p) {
    final stockValuation = widget.store.ingredients
        .fold<double>(0.0, (s, i) => s + (i.currentStock * i.pmpCostMru));
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_rounded, color: p.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${i18n.t('stock_title')} · Valeur ${_fmtMru(stockValuation)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: p.textPrimary),
                ),
              ),
              if (lowStock.isNotEmpty)
                Container(
                  key: const Key('low_stock_alert_badge'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: p.danger.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '⚠ ${lowStock.length} ${i18n.t('stock_low_alert')}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: p.danger),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.store.ingredients.isEmpty)
            _emptyHint('Aucun ingrédient configuré.', p)
          else
            ...widget.store.ingredients.take(8).map((ing) {
              final low = ing.isLowStock;
              final maxScale = math.max(ing.minStock * 2.5, ing.currentStock);
              final ratio =
                  maxScale > 0 ? (ing.currentStock / maxScale).clamp(0.0, 1.0) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          low
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline_rounded,
                          color: low ? p.danger : p.success,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            ing.label(widget.store.lang),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              color: p.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '${ing.currentStock.toStringAsFixed(1)} / min ${ing.minStock} ${ing.unit}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: low ? p.danger : p.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        backgroundColor: p.surfaceAlt,
                        color: low ? p.danger : p.success,
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

  Widget _buildFinancialHealthCard(PosStore store, PosPalette p) {
    final totalKarniDue =
        store.karniCustomers.fold<double>(0.0, (s, c) => s + c.balanceDueMru);
    final lastZ = store.closingsZ.isNotEmpty ? store.closingsZ.first : null;

    return _sectionCard(
      p: p,
      icon: Icons.account_balance_wallet_rounded,
      title: 'Santé Trésorerie & Synchronisation',
      child: Column(
        children: [
          _healthRow(
            icon: Icons.menu_book_rounded,
            color: totalKarniDue > 0 ? p.warning : p.success,
            title: 'Créances Karni (Crédit Clients)',
            subtitle: '${store.karniCustomers.length} client(s) suivi(s)',
            value: _fmtMru(totalKarniDue),
            p: p,
          ),
          const SizedBox(height: 10),
          _healthRow(
            icon: Icons.receipt_rounded,
            color: lastZ == null
                ? p.textMuted
                : (lastZ.cashVarianceMru == 0
                    ? p.success
                    : (lastZ.cashVarianceMru > 0 ? p.primary : p.danger)),
            title: lastZ != null
                ? 'Dernière Clôture ${lastZ.id} (${lastZ.cashierName})'
                : 'Aucune Clôture Z enregistrée',
            subtitle: lastZ != null
                ? '${lastZ.ordersCount} ticket(s) · CA ${_fmtMru(lastZ.totalExpectedMru)}'
                : 'Effectuez une Clôture Z en fin de journée',
            value: lastZ != null
                ? 'Écart ${lastZ.cashVarianceMru >= 0 ? '+' : ''}${lastZ.cashVarianceMru.round()} MRU'
                : '—',
            p: p,
          ),
          const SizedBox(height: 10),
          _healthRow(
            icon: Icons.cloud_done_rounded,
            color: store.pendingSyncCount == 0 ? p.success : p.warning,
            title: 'Synchronisation Cloud API',
            subtitle: store.cloudConnected
                ? 'Connecté à api.full-tek.com'
                : 'Mode hors-ligne actif',
            value: store.pendingSyncCount == 0
                ? 'À jour ✓'
                : '${store.pendingSyncCount} en attente',
            p: p,
          ),
        ],
      ),
    );
  }

  Widget _healthRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String value,
    required PosPalette p,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: p.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: p.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyHint(String text, PosPalette p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontSize: 12.5, color: p.textMuted),
        ),
      ),
    );
  }
}

/// Custom-painted modern Gradient Bar + Smooth Area Chart for Hourly Sales.
class _HourlyRevenueChartPainter extends CustomPainter {
  final List<MapEntry<int, double>> entries;
  final Color primaryColor;
  final Color accentColor;
  final Color gridColor;
  final Color textColor;
  final int peakHour;

  const _HourlyRevenueChartPainter({
    required this.entries,
    required this.primaryColor,
    required this.accentColor,
    required this.gridColor,
    required this.textColor,
    required this.peakHour,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;
    final maxVal =
        entries.map((e) => e.value).fold<double>(0.0, math.max);
    final ceiling = maxVal > 0 ? maxVal * 1.18 : 1000.0;
    const topPad = 14.0;
    const bottomPad = 8.0;
    final chartH = size.height - topPad - bottomPad;

    // Horizontal dashed/subtle grid lines
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.65)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = topPad + (chartH * i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final slotW = size.width / entries.length;
    final barW = (slotW * 0.56).clamp(6.0, 22.0);

    final linePoints = <Offset>[];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final ratio = (e.value / ceiling).clamp(0.0, 1.0);
      final cx = slotW * i + slotW / 2;
      final barH = ratio * chartH;
      final topY = topPad + chartH - barH;
      linePoints.add(Offset(cx, topY));

      if (e.value > 0) {
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(cx - barW / 2, topY, barW, barH),
          topLeft: const Radius.circular(6),
          topRight: const Radius.circular(6),
        );
        final isPeak = e.key == peakHour;
        final barPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isPeak
                ? [const Color(0xFFF59E0B), const Color(0xFFF59E0B).withValues(alpha: 0.35)]
                : [primaryColor, primaryColor.withValues(alpha: 0.25)],
          ).createShader(rect.outerRect);
        canvas.drawRRect(rect, barPaint);
      } else {
        // Minimal baseline tick so the chart feels alive even at 0
        final tickRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - barW / 2, topPad + chartH - 3, barW, 3),
          const Radius.circular(2),
        );
        canvas.drawRRect(
          tickRect,
          Paint()..color = gridColor.withValues(alpha: 0.5),
        );
      }
    }

    // Smooth trend line overlay when there is data
    if (maxVal > 0 && linePoints.length >= 2) {
      final path = Path()..moveTo(linePoints.first.dx, linePoints.first.dy);
      for (var i = 1; i < linePoints.length; i++) {
        final prev = linePoints[i - 1];
        final curr = linePoints[i];
        final midX = (prev.dx + curr.dx) / 2;
        path.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = accentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );

      // Peak dot
      for (var i = 0; i < entries.length; i++) {
        if (entries[i].value > 0) {
          final pt = linePoints[i];
          final isPeak = entries[i].key == peakHour;
          canvas.drawCircle(
            pt,
            isPeak ? 5.0 : 3.2,
            Paint()
              ..color = isPeak ? const Color(0xFFF59E0B) : accentColor,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HourlyRevenueChartPainter old) => true;
}

/// Custom-painted Donut Chart for the 7 Mauritanian payment methods.
class _PaymentDonutPainter extends CustomPainter {
  final List<({PaymentMethod method, double amount, Color color})> segments;
  final Color emptyColor;

  const _PaymentDonutPainter({
    required this.segments,
    required this.emptyColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 10;
    const strokeW = 18.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final total = segments.fold<double>(0.0, (s, e) => s + e.amount);
    if (total <= 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = emptyColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW,
      );
      return;
    }

    double startAngle = -math.pi / 2;
    const gap = 0.04;
    final activeCount = segments.where((s) => s.amount > 0).length;

    for (final s in segments) {
      if (s.amount <= 0) continue;
      final sweep = (s.amount / total) * (math.pi * 2);
      final effectiveSweep =
          activeCount > 1 ? math.max(0.05, sweep - gap) : sweep;
      canvas.drawArc(
        rect,
        startAngle,
        effectiveSweep,
        false,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PaymentDonutPainter old) => true;
}
