// Bulter 第 13b 步：Web 端数据可视化
//
// 验证：
// 1) GraphService → GraphNode 派生字段（daysSinceLastContact / radiusFactor）
// 2) ChartService → CategoryBar / TrendPoint / BudgetUsage
// 3) HealthTrendService → TrendSeries 统计（max/min/avg/latest/span）

import 'package:bulter/modules/health/services/health_trend_service.dart'
    as health_trend;
import 'package:bulter/modules/relationship/services/graph_service.dart';
import 'package:bulter/modules/wealth/services/chart_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GraphNode 派生字段', () {
    test('daysSinceLastContact：lastContactAt=null → -1', () {
      const n = GraphNode(
        contactId: 1,
        label: '小明',
        sublabel: 'friend',
        importance: 5,
        lastContactAt: null,
        interactionCount: 0,
        favorCount: 0,
      );
      expect(n.daysSinceLastContact, -1);
    });

    test('daysSinceLastContact：5 天前 → 5', () {
      final fiveDaysAgo = DateTime.now().subtract(const Duration(days: 5));
      final n = GraphNode(
        contactId: 1,
        label: '小明',
        sublabel: 'friend',
        importance: 5,
        lastContactAt: fiveDaysAgo,
        interactionCount: 0,
        favorCount: 0,
      );
      expect(n.daysSinceLastContact, greaterThanOrEqualTo(4));
      expect(n.daysSinceLastContact, lessThanOrEqualTo(6));
    });

    test('radiusFactor：基础 1.0', () {
      const n = GraphNode(
        contactId: 1,
        label: 'X',
        sublabel: 'friend',
        importance: 0,
        lastContactAt: null,
        interactionCount: 0,
        favorCount: 0,
      );
      expect(n.radiusFactor, 1.0);
    });

    test('radiusFactor：10 次互动 + importance 8 → 增加', () {
      const n = GraphNode(
        contactId: 1,
        label: 'X',
        sublabel: 'friend',
        importance: 8,
        lastContactAt: null,
        interactionCount: 10,
        favorCount: 0,
      );
      // 1.0 + 10/5*0.5 + 8*0.05 = 1.0 + 1.0 + 0.4 = 2.4
      expect(n.radiusFactor, 2.4);
    });
  });

  group('CategoryBar 字段', () {
    test('ratio + colorIndex', () {
      const bar = CategoryBar(
        category: 'food',
        label: '餐饮',
        amountCents: 50000,
        ratio: 0.5,
        colorIndex: 0,
      );
      expect(bar.amountCents, 50000);
      expect(bar.ratio, 0.5);
      expect(bar.colorName, 'red');
    });

    test('colorName 调色板循环', () {
      const bar7 = CategoryBar(
        category: 'food',
        label: '餐饮',
        amountCents: 100,
        ratio: 0.1,
        colorIndex: 7,
      );
      expect(bar7.colorName, 'gray');

      const bar8 = CategoryBar(
        category: 'food',
        label: '餐饮',
        amountCents: 100,
        ratio: 0.1,
        colorIndex: 8, // 循环回 0
      );
      expect(bar8.colorName, 'red');
    });
  });

  group('TrendPoint 字段（wealth）', () {
    test('netCents = income - expense', () {
      const p = TrendPoint(
        year: 2024,
        month: 4,
        incomeCents: 100000,
        expenseCents: 30000,
        label: '4月',
      );
      expect(p.netCents, 70000);
      expect(p.label, '4月');
    });
  });

  group('BudgetUsage 字段', () {
    test('isOverBudget', () {
      const ok = BudgetUsage(
        category: 'food',
        label: '餐饮',
        spentCents: 800,
        limitCents: 1000,
        ratio: 0.8,
      );
      expect(ok.isOverBudget, false);

      const over = BudgetUsage(
        category: 'food',
        label: '餐饮',
        spentCents: 1200,
        limitCents: 1000,
        ratio: 1.2,
      );
      expect(over.isOverBudget, true);
    });
  });

  group('TrendSeries 统计（health）', () {
    test('空 series → 0', () {
      const s = health_trend.TrendSeries(
        metricType: 'weight',
        label: '体重',
        unit: 'kg',
        points: [],
      );
      expect(s.isEmpty, true);
      expect(s.count, 0);
      expect(s.max, 0);
      expect(s.min, 0);
      expect(s.avg, 0);
      expect(s.latest, isNull);
      expect(s.span, 0);
    });

    test('max / min / avg / latest / span', () {
      final s = health_trend.TrendSeries(
        metricType: 'weight',
        label: '体重',
        unit: 'kg',
        points: [
          health_trend.TrendPoint(
            timestamp: DateTime(2024, 4, 1),
            value: 70,
            unit: 'kg',
          ),
          health_trend.TrendPoint(
            timestamp: DateTime(2024, 4, 8),
            value: 72,
            unit: 'kg',
          ),
          health_trend.TrendPoint(
            timestamp: DateTime(2024, 4, 15),
            value: 68,
            unit: 'kg',
          ),
        ],
      );
      expect(s.count, 3);
      expect(s.max, 72);
      expect(s.min, 68);
      expect(s.avg, 70); // (70+72+68)/3
      expect(s.latest, 68);
      expect(s.span, 4);
      expect(s.isEmpty, false);
    });
  });

  group('RelationshipGraph', () {
    test('isEmpty / nodeCount / edgeCount', () {
      final g = RelationshipGraph(
        nodes: const [
          GraphNode(
            contactId: 1,
            label: 'A',
            sublabel: 'friend',
            importance: 5,
            lastContactAt: null,
            interactionCount: 3,
            favorCount: 0,
          ),
        ],
        edges: const [GraphEdge(fromId: 1, toId: 1, weight: 1.0)],
        generatedAt: DateTime.now(),
      );
      expect(g.isEmpty, false);
      expect(g.nodeCount, 1);
      expect(g.edgeCount, 1);
    });
  });
}
