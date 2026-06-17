import 'dart:async';

import 'package:flutter/foundation.dart';

/// 事件基类。所有跨模块事件继承该类。
abstract class BulterEvent {
  const BulterEvent();
  String get name => runtimeType.toString();
}

/// 联系人添加事件
class ContactAddedEvent extends BulterEvent {
  final String contactId;
  final String contactName;
  const ContactAddedEvent({required this.contactId, required this.contactName});
}

/// 账单超支事件
class BudgetExceededEvent extends BulterEvent {
  final String category;
  final double amount;
  final double budget;
  const BudgetExceededEvent({
    required this.category,
    required this.amount,
    required this.budget,
  });
}

/// 体检异常事件
class HealthAbnormalEvent extends BulterEvent {
  final List<String> abnormalItems;
  const HealthAbnormalEvent({required this.abnormalItems});
}

/// 目标达成事件
class GoalAchievedEvent extends BulterEvent {
  final String goalId;
  final String title;
  const GoalAchievedEvent({required this.goalId, required this.title});
}

/// 读后感完成事件
class ThoughtCompletedEvent extends BulterEvent {
  final String thoughtId;
  final String title;
  const ThoughtCompletedEvent({required this.thoughtId, required this.title});
}

/// 约定达成事件
class AppointmentReachedEvent extends BulterEvent {
  final String appointmentId;
  final String withContact;
  const AppointmentReachedEvent({
    required this.appointmentId,
    required this.withContact,
  });
}

/// 年度回顾事件
class AnnualReviewEvent extends BulterEvent {
  final int year;
  const AnnualReviewEvent({required this.year});
}

/// 事件总线（发布订阅）。
///
/// 任何模块可以 [publish] 事件，其他模块 [on] 订阅；
/// 不需要在发布方引用接收方，模块间完全解耦。
class EventBus {
  EventBus._();
  static final EventBus instance = EventBus._();

  final Map<String, List<void Function(BulterEvent)>> _listeners = {};

  /// 订阅事件；返回一个取消订阅的函数。
  void Function() on<T extends BulterEvent>(void Function(T) handler) {
    final key = T.toString();
    final list = _listeners.putIfAbsent(key, () => <void Function(BulterEvent)>[]);
    void wrapper(BulterEvent e) {
      if (e is T) handler(e);
    }
    list.add(wrapper);
    return () => list.remove(wrapper);
  }

  /// 发布事件
  void publish(BulterEvent event) {
    final list = _listeners[event.name];
    if (list == null) return;
    for (final l in List.of(list)) {
      try {
        l(event);
      } catch (e, st) {
        debugPrint('EventBus: 订阅者处理 ${event.name} 异常: $e\n$st');
      }
    }
  }

  Future<void> publishAsync(BulterEvent event) async {
    final list = _listeners[event.name];
    if (list == null) return;
    for (final l in List.of(list)) {
      try {
        l(event);
      } catch (e, st) {
        debugPrint('EventBus: 订阅者处理 ${event.name} 异常: $e\n$st');
      }
    }
  }

  void clear() {
    _listeners.clear();
  }
}
