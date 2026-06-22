import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import '../db/relationship_tables.dart';

/// 关系图谱服务（Step 13b）。
///
/// **职责**：
/// - 把 `Contacts` + `Interactions` + `Favors` 聚合成**图谱数据**（节点 + 边）
/// - 用于 Web 端 / 移动端的可视化
///
/// **数据模型**：
/// - **节点** ([GraphNode]) = 一个人（contact）
/// - **边** ([GraphEdge]) = 两个人之间的互动 / 人情（**目前简化：自环 = 互动次数**）
///
/// **未来**：多联系人共同参与的人情债、群组活动 → 多边图。
class GraphService {
  GraphService._();
  static final GraphService instance = GraphService._();

  /// 生成完整关系图谱。
  ///
  /// - 仅包含未归档 (`isArchived = false`) 的联系人
  /// - 边按"互动次数 + 人情次数"加权和计算权重
  Future<RelationshipGraph> build(AppDatabase db) async {
    final contacts =
        await (db.select(db.contacts)
              ..where((c) => c.isArchived.equals(false))
              ..orderBy([
                (c) => OrderingTerm(
                  expression: c.importance,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();

    final since = DateTime.now().subtract(const Duration(days: 180));
    final interactions = await (db.select(
      db.interactions,
    )..where((i) => i.happenedAt.isBiggerOrEqualValue(since))).get();

    final favors = await (db.select(
      db.favors,
    )..where((f) => f.status.equals('open'))).get();

    // 按 contactId 聚合
    final interactionCount = <int, int>{};
    for (final i in interactions) {
      interactionCount[i.contactId] = (interactionCount[i.contactId] ?? 0) + 1;
    }
    final favorCount = <int, int>{};
    for (final f in favors) {
      favorCount[f.contactId] = (favorCount[f.contactId] ?? 0) + 1;
    }

    final nodes = <GraphNode>[];
    for (final c in contacts) {
      nodes.add(
        GraphNode(
          contactId: c.id,
          label: c.name,
          sublabel: c.relationshipType,
          importance: c.importance,
          lastContactAt: c.lastContactAt,
          interactionCount: interactionCount[c.id] ?? 0,
          favorCount: favorCount[c.id] ?? 0,
        ),
      );
    }

    // 边：当前每个 contact 自环一条（互动 + 人情）
    // 真实"关系图"需要成对的 interaction.happenedAt 配对（多对多），
    // 当前 schema 单边足够 → 用节点半径 / 颜色编码"频次"
    final edges = <GraphEdge>[];
    for (final c in contacts) {
      final iCount = interactionCount[c.id] ?? 0;
      final fCount = favorCount[c.id] ?? 0;
      if (iCount == 0 && fCount == 0) continue;
      edges.add(
        GraphEdge(
          fromId: c.id,
          toId: c.id, // 自环 = 节点的"活跃度"
          weight: iCount + fCount * 3, // 人情权重更高
        ),
      );
    }

    return RelationshipGraph(
      nodes: nodes,
      edges: edges,
      generatedAt: DateTime.now(),
    );
  }
}

/// 图谱节点 = 一个联系人。
class GraphNode {
  final int contactId;
  final String label;
  final String sublabel; // relationshipType
  final int importance; // 0-10
  final DateTime? lastContactAt;
  final int interactionCount; // 最近 180 天
  final int favorCount; // open favors

  const GraphNode({
    required this.contactId,
    required this.label,
    required this.sublabel,
    required this.importance,
    required this.lastContactAt,
    required this.interactionCount,
    required this.favorCount,
  });

  /// 距上次联系的天数。null = 从未联系 → 用 -1 表示"未知"。
  int get daysSinceLastContact {
    final t = lastContactAt;
    if (t == null) return -1;
    return DateTime.now().difference(t).inDays;
  }

  /// 节点半径系数（基于互动 + 重要度）。
  /// - 基础 1.0
  /// - 每 5 次互动 +0.5
  /// - importance 1-10 → +0.05 × importance
  double get radiusFactor {
    final interactionBoost = interactionCount / 5 * 0.5;
    final importanceBoost = importance * 0.05;
    return 1.0 + interactionBoost + importanceBoost;
  }
}

/// 图谱边 = 节点间的连接。
class GraphEdge {
  final int fromId;
  final int toId;
  final double weight; // 越粗 = 权重越大

  const GraphEdge({
    required this.fromId,
    required this.toId,
    required this.weight,
  });
}

/// 完整图谱。
class RelationshipGraph {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final DateTime generatedAt;

  const RelationshipGraph({
    required this.nodes,
    required this.edges,
    required this.generatedAt,
  });

  bool get isEmpty => nodes.isEmpty;
  int get nodeCount => nodes.length;
  int get edgeCount => edges.length;
}
