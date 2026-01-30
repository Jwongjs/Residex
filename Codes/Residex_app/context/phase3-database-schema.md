# Phase 3: Database Schema Extension - Detailed Steps

**Current State:**
- Database file: `lib/data/database/app_database.dart`
- Schema version: 1
- Existing tables: Users, Groups, Bills, ReceiptItems
- Existing DAOs: UserDao, GroupDao, BillDao

---

## Step 1: Create New Table Files

Create each file in `lib/data/database/tables/`

### 1.1 Chore Tables

**File: `chores_table.dart`**
```dart
import 'package:drift/drift.dart';

/// Chore definitions
class Chores extends Table {
  TextColumn get id => text()();
  TextColumn get propertyId => text().references(Groups, #id)();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get frequency => text()(); // daily, weekly, monthly, custom
  IntColumn get frequencyDays => integer().nullable()(); // for custom frequency
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}
```

**File: `chore_assignments_table.dart`**
```dart
import 'package:drift/drift.dart';

/// Who does what chore and when
class ChoreAssignments extends Table {
  TextColumn get id => text()();
  TextColumn get choreId => text().references(Chores, #id)();
  TextColumn get userId => text().references(Users, #id)();
  DateTimeColumn get dueDate => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, completed, overdue, skipped
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

**File: `chore_rotations_table.dart`**
```dart
import 'package:drift/drift.dart';

/// Rotation schedule for chores
class ChoreRotations extends Table {
  TextColumn get id => text()();
  TextColumn get choreId => text().references(Chores, #id)();
  TextColumn get userIdsJson => text()(); // JSON array of user IDs in rotation order
  IntColumn get currentIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastRotatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

---

### 1.2 Maintenance Ticket Tables

**File: `maintenance_tickets_table.dart`**
```dart
import 'package:drift/drift.dart';

/// Maintenance ticket records
class MaintenanceTickets extends Table {
  TextColumn get id => text()();
  TextColumn get propertyId => text().references(Groups, #id)();
  TextColumn get reporterId => text().references(Users, #id)();
  TextColumn get title => text()();
  TextColumn get description => text()();
  TextColumn get category => text()(); // plumbing, electrical, appliance, structural, other
  TextColumn get priority => text().withDefault(const Constant('medium'))(); // low, medium, high, urgent
  TextColumn get status => text().withDefault(const Constant('open'))(); // open, in_progress, resolved, closed
  TextColumn get assignedTo => text().nullable()(); // external contractor or management
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

**File: `ticket_comments_table.dart`**
```dart
import 'package:drift/drift.dart';

/// Comments and updates on tickets
class TicketComments extends Table {
  TextColumn get id => text()();
  TextColumn get ticketId => text().references(MaintenanceTickets, #id)();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get content => text()();
  BoolColumn get isInternal => boolean().withDefault(const Constant(false))(); // internal notes vs public
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
```

**File: `ticket_attachments_table.dart`**
```dart
import 'package:drift/drift.dart';

/// Photos and documents attached to tickets
class TicketAttachments extends Table {
  TextColumn get id => text()();
  TextColumn get ticketId => text().references(MaintenanceTickets, #id)();
  TextColumn get filePath => text()();
  TextColumn get fileType => text()(); // image, pdf, video
  TextColumn get caption => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
```

---

### 1.3 Digital Handover Tables

**File: `handover_sessions_table.dart`**
```dart
import 'package:drift/drift.dart';

/// Handover events between residents
class HandoverSessions extends Table {
  TextColumn get id => text()();
  TextColumn get propertyId => text().references(Groups, #id)();
  TextColumn get outgoingUserId => text().references(Users, #id)();
  TextColumn get incomingUserId => text().nullable().references(Users, #id)();
  TextColumn get status => text().withDefault(const Constant('draft'))(); // draft, in_progress, pending_review, completed
  DateTimeColumn get scheduledDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

**File: `handover_items_table.dart`**
```dart
import 'package:drift/drift.dart';

/// Individual items to check during handover
class HandoverItems extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(HandoverSessions, #id)();
  TextColumn get category => text()(); // kitchen, bathroom, bedroom, living, utilities, keys
  TextColumn get itemName => text()();
  TextColumn get condition => text().nullable()(); // excellent, good, fair, poor, damaged
  TextColumn get notes => text().nullable()();
  TextColumn get photoBefore => text().nullable()(); // file path
  TextColumn get photoAfter => text().nullable()(); // file path
  BoolColumn get isChecked => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
```

**File: `ghost_overlays_table.dart`**
```dart
import 'package:drift/drift.dart';

/// Reference photos for ghost overlay comparison
class GhostOverlays extends Table {
  TextColumn get id => text()();
  TextColumn get propertyId => text().references(Groups, #id)();
  TextColumn get roomName => text()();
  TextColumn get description => text().nullable()();
  TextColumn get overlayImagePath => text()();
  RealColumn get cameraPositionX => real().nullable()(); // For AR positioning
  RealColumn get cameraPositionY => real().nullable()();
  RealColumn get cameraPositionZ => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
```

---

### 1.4 Honor System Tables

*Inspired by competitive gaming honor systems (LoL, CS:GO) - 5-tier level system with Trust Factor*

**File: `honor_profiles_table.dart`**
```dart
import 'package:drift/drift.dart';

/// User honor profiles with level and trust factor
class HonorProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  IntColumn get honorLevel => integer().withDefault(const Constant(2))(); // 0-5, default 2 (Neutral)
  RealColumn get trustFactor => real().withDefault(const Constant(0.7))(); // k-factor 0.0-1.0+
  DateTimeColumn get levelChangedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get consecutiveCleanDays => integer().withDefault(const Constant(0))();
  IntColumn get confirmedReportsMade => integer().withDefault(const Constant(0))();
  IntColumn get falseReportsMade => integer().withDefault(const Constant(0))();
  IntColumn get confirmedReportsAgainst => integer().withDefault(const Constant(0))();
  BoolColumn get isRestricted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastUpdated => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
```

**File: `honor_reports_table.dart`**
```dart
import 'package:drift/drift.dart';

/// Reports submitted against users
class HonorReports extends Table {
  TextColumn get id => text()();
  TextColumn get reporterId => text().references(Users, #id)();
  TextColumn get reportedUserId => text().references(Users, #id)();
  TextColumn get propertyId => text().references(Groups, #id)();
  TextColumn get category => text()(); // griefing_damage, toxic_noise, afk_nonpayment, cheating_lease_violation
  TextColumn get description => text()();
  TextColumn get evidenceJson => text().nullable()(); // JSON array of photo paths, timestamps
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, ai_review, tribunal, confirmed, insufficient, false_report
  RealColumn get reporterKFactor => real()(); // Reporter's k-factor at time of report
  TextColumn get aiAnalysis => text().nullable()(); // JSON of AI triage results
  TextColumn get tribunalVerdict => text().nullable()(); // JSON of tribunal decision
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

**File: `honor_events_table.dart`**
```dart
import 'package:drift/drift.dart';

/// Honor level change history and audit trail
class HonorEvents extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get eventType => text()(); // level_up, level_down, report_confirmed, report_false, clean_streak, tribunal_verdict
  IntColumn get previousLevel => integer().nullable()();
  IntColumn get newLevel => integer().nullable()();
  RealColumn get previousKFactor => real().nullable()();
  RealColumn get newKFactor => real().nullable()();
  TextColumn get reason => text()();
  TextColumn get relatedEntityId => text().nullable()(); // ID of report, etc.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
```

**File: `tribunal_sessions_table.dart`**
```dart
import 'package:drift/drift.dart';

/// Tribunal review sessions for severe reports
class TribunalSessions extends Table {
  TextColumn get id => text()();
  TextColumn get reportId => text().references(HonorReports, #id)();
  TextColumn get reviewerIdsJson => text()(); // JSON array of Level 4-5 user IDs
  TextColumn get votesJson => text().nullable()(); // JSON {userId: 'confirmed'|'insufficient'|'false'}
  IntColumn get requiredVotes => integer().withDefault(const Constant(3))();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, in_progress, completed
  TextColumn get finalVerdict => text().nullable()(); // confirmed, insufficient, false_report
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

**File: `redemption_programs_table.dart`**
```dart
import 'package:drift/drift.dart';

/// Redemption tracking for users recovering from low honor levels
class RedemptionPrograms extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  IntColumn get startingLevel => integer()(); // Level when program started
  IntColumn get targetLevel => integer()(); // Level to achieve
  TextColumn get programType => text()(); // behavior_course, clean_period, appeal
  TextColumn get requirementsJson => text()(); // JSON of specific requirements
  TextColumn get progressJson => text().nullable()(); // JSON of progress tracking
  TextColumn get status => text().withDefault(const Constant('active'))(); // active, completed, failed
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get cleanDaysRequired => integer().withDefault(const Constant(30))();
  IntColumn get cleanDaysAchieved => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
```

### 1.4.1 Fiscal Score Tables (Payment Reliability)

**File: `fiscal_scores_table.dart`**
```dart
import 'package:drift/drift.dart';

/// Individual resident fiscal scores (payment reliability)
class FiscalScores extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get propertyId => text().references(Groups, #id)();
  IntColumn get score => integer().withDefault(const Constant(500))(); // 0-1000
  IntColumn get onTimePayments => integer().withDefault(const Constant(0))();
  IntColumn get latePayments => integer().withDefault(const Constant(0))();
  IntColumn get missedPayments => integer().withDefault(const Constant(0))();
  IntColumn get currentStreak => integer().withDefault(const Constant(0))(); // consecutive on-time payments
  DateTimeColumn get lastUpdated => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
```

---

### 1.5 Community Board Tables

**File: `community_posts_table.dart`**
```dart
import 'package:drift/drift.dart';

/// Community announcements and posts
class CommunityPosts extends Table {
  TextColumn get id => text()();
  TextColumn get propertyId => text().references(Groups, #id)();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get postType => text().withDefault(const Constant('general'))(); // announcement, question, event, marketplace, general
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  IntColumn get viewCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

**File: `post_reactions_table.dart`**
```dart
import 'package:drift/drift.dart';

/// Reactions on posts
class PostReactions extends Table {
  TextColumn get id => text()();
  TextColumn get postId => text().references(CommunityPosts, #id)();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get reactionType => text()(); // like, love, helpful, funny

  @override
  Set<Column> get primaryKey => {id};
}
```

**File: `post_comments_table.dart`**
```dart
import 'package:drift/drift.dart';

/// Comments on community posts
class PostComments extends Table {
  TextColumn get id => text()();
  TextColumn get postId => text().references(CommunityPosts, #id)();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get parentCommentId => text().nullable()(); // For nested replies
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
```

---

## Step 2: Create DAO Files

Create each file in `lib/data/database/daos/`

### 2.1 ChoreDao

**File: `chore_dao.dart`**
```dart
import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/chores_table.dart';
import '../tables/chore_assignments_table.dart';
import '../tables/chore_rotations_table.dart';

part 'chore_dao.g.dart';

@DriftAccessor(tables: [Chores, ChoreAssignments, ChoreRotations])
class ChoreDao extends DatabaseAccessor<AppDatabase> with _$ChoreDaoMixin {
  ChoreDao(AppDatabase db) : super(db);

  // Chores CRUD
  Future<List<Chore>> getChoresByProperty(String propertyId) {
    return (select(chores)..where((c) => c.propertyId.equals(propertyId))).get();
  }

  Future<void> upsertChore(ChoresCompanion chore) {
    return into(chores).insertOnConflictUpdate(chore);
  }

  Future<void> deleteChore(String id) {
    return (delete(chores)..where((c) => c.id.equals(id))).go();
  }

  // Assignments
  Future<List<ChoreAssignment>> getAssignmentsByUser(String userId) {
    return (select(choreAssignments)..where((a) => a.userId.equals(userId))).get();
  }

  Future<List<ChoreAssignment>> getPendingAssignments(String propertyId) {
    return (select(choreAssignments)
      ..where((a) => a.status.equals('pending')))
      .get();
  }

  Future<void> upsertAssignment(ChoreAssignmentsCompanion assignment) {
    return into(choreAssignments).insertOnConflictUpdate(assignment);
  }

  Future<void> markAssignmentComplete(String id) {
    return (update(choreAssignments)..where((a) => a.id.equals(id)))
      .write(ChoreAssignmentsCompanion(
        status: const Value('completed'),
        completedAt: Value(DateTime.now()),
      ));
  }
}
```

### 2.2 MaintenanceDao

**File: `maintenance_dao.dart`**
```dart
import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/maintenance_tickets_table.dart';
import '../tables/ticket_comments_table.dart';
import '../tables/ticket_attachments_table.dart';

part 'maintenance_dao.g.dart';

@DriftAccessor(tables: [MaintenanceTickets, TicketComments, TicketAttachments])
class MaintenanceDao extends DatabaseAccessor<AppDatabase> with _$MaintenanceDaoMixin {
  MaintenanceDao(AppDatabase db) : super(db);

  // Tickets
  Future<List<MaintenanceTicket>> getTicketsByProperty(String propertyId) {
    return (select(maintenanceTickets)
      ..where((t) => t.propertyId.equals(propertyId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .get();
  }

  Future<List<MaintenanceTicket>> getOpenTickets(String propertyId) {
    return (select(maintenanceTickets)
      ..where((t) => t.propertyId.equals(propertyId) &
                     t.status.isIn(['open', 'in_progress'])))
      .get();
  }

  Future<void> upsertTicket(MaintenanceTicketsCompanion ticket) {
    return into(maintenanceTickets).insertOnConflictUpdate(ticket);
  }

  Future<void> updateTicketStatus(String id, String status) {
    return (update(maintenanceTickets)..where((t) => t.id.equals(id)))
      .write(MaintenanceTicketsCompanion(
        status: Value(status),
        resolvedAt: status == 'resolved' ? Value(DateTime.now()) : const Value.absent(),
      ));
  }

  // Comments
  Future<List<TicketComment>> getCommentsByTicket(String ticketId) {
    return (select(ticketComments)
      ..where((c) => c.ticketId.equals(ticketId))
      ..orderBy([(c) => OrderingTerm.asc(c.createdAt)]))
      .get();
  }

  Future<void> addComment(TicketCommentsCompanion comment) {
    return into(ticketComments).insert(comment);
  }

  // Attachments
  Future<List<TicketAttachment>> getAttachmentsByTicket(String ticketId) {
    return (select(ticketAttachments)..where((a) => a.ticketId.equals(ticketId))).get();
  }

  Future<void> addAttachment(TicketAttachmentsCompanion attachment) {
    return into(ticketAttachments).insert(attachment);
  }
}
```

### 2.3 HandoverDao

**File: `handover_dao.dart`**
```dart
import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/handover_sessions_table.dart';
import '../tables/handover_items_table.dart';
import '../tables/ghost_overlays_table.dart';

part 'handover_dao.g.dart';

@DriftAccessor(tables: [HandoverSessions, HandoverItems, GhostOverlays])
class HandoverDao extends DatabaseAccessor<AppDatabase> with _$HandoverDaoMixin {
  HandoverDao(AppDatabase db) : super(db);

  // Sessions
  Future<List<HandoverSession>> getSessionsByProperty(String propertyId) {
    return (select(handoverSessions)..where((s) => s.propertyId.equals(propertyId))).get();
  }

  Future<HandoverSession?> getActiveSession(String propertyId) {
    return (select(handoverSessions)
      ..where((s) => s.propertyId.equals(propertyId) &
                     s.status.isIn(['draft', 'in_progress', 'pending_review'])))
      .getSingleOrNull();
  }

  Future<void> upsertSession(HandoverSessionsCompanion session) {
    return into(handoverSessions).insertOnConflictUpdate(session);
  }

  // Items
  Future<List<HandoverItem>> getItemsBySession(String sessionId) {
    return (select(handoverItems)..where((i) => i.sessionId.equals(sessionId))).get();
  }

  Future<void> upsertItem(HandoverItemsCompanion item) {
    return into(handoverItems).insertOnConflictUpdate(item);
  }

  // Ghost Overlays
  Future<List<GhostOverlay>> getOverlaysByProperty(String propertyId) {
    return (select(ghostOverlays)..where((o) => o.propertyId.equals(propertyId))).get();
  }

  Future<void> upsertOverlay(GhostOverlaysCompanion overlay) {
    return into(ghostOverlays).insertOnConflictUpdate(overlay);
  }
}
```

### 2.4 HonorDao

**File: `honor_dao.dart`**
```dart
import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/honor_profiles_table.dart';
import '../tables/honor_reports_table.dart';
import '../tables/honor_events_table.dart';
import '../tables/tribunal_sessions_table.dart';
import '../tables/redemption_programs_table.dart';
import '../tables/fiscal_scores_table.dart';

part 'honor_dao.g.dart';

@DriftAccessor(tables: [HonorProfiles, HonorReports, HonorEvents, TribunalSessions, RedemptionPrograms, FiscalScores])
class HonorDao extends DatabaseAccessor<AppDatabase> with _$HonorDaoMixin {
  HonorDao(AppDatabase db) : super(db);

  // Honor Profiles
  Future<HonorProfile?> getHonorProfile(String userId) {
    return (select(honorProfiles)..where((p) => p.userId.equals(userId)))
      .getSingleOrNull();
  }

  Future<List<HonorProfile>> getProfilesByLevel(int level) {
    return (select(honorProfiles)
      ..where((p) => p.honorLevel.equals(level))
      ..orderBy([(p) => OrderingTerm.desc(p.trustFactor)]))
      .get();
  }

  Future<void> upsertHonorProfile(HonorProfilesCompanion profile) {
    return into(honorProfiles).insertOnConflictUpdate(profile);
  }

  Future<void> updateHonorLevel(String userId, int newLevel) {
    return (update(honorProfiles)..where((p) => p.userId.equals(userId)))
      .write(HonorProfilesCompanion(
        honorLevel: Value(newLevel),
        levelChangedAt: Value(DateTime.now()),
        lastUpdated: Value(DateTime.now()),
      ));
  }

  // Honor Reports
  Future<List<HonorReport>> getReportsByUser(String userId) {
    return (select(honorReports)
      ..where((r) => r.reportedUserId.equals(userId))
      ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
      .get();
  }

  Future<List<HonorReport>> getPendingReports() {
    return (select(honorReports)
      ..where((r) => r.status.isIn(['pending', 'ai_review', 'tribunal']))
      ..orderBy([(r) => OrderingTerm.asc(r.createdAt)]))
      .get();
  }

  Future<void> upsertReport(HonorReportsCompanion report) {
    return into(honorReports).insertOnConflictUpdate(report);
  }

  // Honor Events
  Future<List<HonorEvent>> getEventsByUser(String userId, {int limit = 50}) {
    return (select(honorEvents)
      ..where((e) => e.userId.equals(userId))
      ..orderBy([(e) => OrderingTerm.desc(e.createdAt)])
      ..limit(limit))
      .get();
  }

  Future<void> addHonorEvent(HonorEventsCompanion event) {
    return into(honorEvents).insert(event);
  }

  // Tribunal Sessions
  Future<List<TribunalSession>> getPendingTribunals() {
    return (select(tribunalSessions)
      ..where((t) => t.status.isIn(['pending', 'in_progress'])))
      .get();
  }

  Future<void> upsertTribunalSession(TribunalSessionsCompanion session) {
    return into(tribunalSessions).insertOnConflictUpdate(session);
  }

  // Redemption Programs
  Future<RedemptionProgram?> getActiveRedemption(String userId) {
    return (select(redemptionPrograms)
      ..where((r) => r.userId.equals(userId) & r.status.equals('active')))
      .getSingleOrNull();
  }

  Future<void> upsertRedemption(RedemptionProgramsCompanion program) {
    return into(redemptionPrograms).insertOnConflictUpdate(program);
  }

  // Fiscal Scores
  Future<FiscalScore?> getFiscalScore(String userId, String propertyId) {
    return (select(fiscalScores)
      ..where((s) => s.userId.equals(userId) & s.propertyId.equals(propertyId)))
      .getSingleOrNull();
  }

  Future<void> upsertFiscalScore(FiscalScoresCompanion score) {
    return into(fiscalScores).insertOnConflictUpdate(score);
  }
}
```

### 2.5 CommunityDao

**File: `community_dao.dart`**
```dart
import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/community_posts_table.dart';
import '../tables/post_reactions_table.dart';
import '../tables/post_comments_table.dart';

part 'community_dao.g.dart';

@DriftAccessor(tables: [CommunityPosts, PostReactions, PostComments])
class CommunityDao extends DatabaseAccessor<AppDatabase> with _$CommunityDaoMixin {
  CommunityDao(AppDatabase db) : super(db);

  // Posts
  Future<List<CommunityPost>> getPostsByProperty(String propertyId, {int limit = 50}) {
    return (select(communityPosts)
      ..where((p) => p.propertyId.equals(propertyId))
      ..orderBy([
        (p) => OrderingTerm.desc(p.isPinned),
        (p) => OrderingTerm.desc(p.createdAt),
      ])
      ..limit(limit))
      .get();
  }

  Future<void> upsertPost(CommunityPostsCompanion post) {
    return into(communityPosts).insertOnConflictUpdate(post);
  }

  Future<void> deletePost(String id) {
    return (delete(communityPosts)..where((p) => p.id.equals(id))).go();
  }

  Future<void> incrementViewCount(String postId) async {
    await customStatement(
      'UPDATE community_posts SET view_count = view_count + 1 WHERE id = ?',
      [postId],
    );
  }

  // Reactions
  Future<List<PostReaction>> getReactionsByPost(String postId) {
    return (select(postReactions)..where((r) => r.postId.equals(postId))).get();
  }

  Future<void> toggleReaction(PostReactionsCompanion reaction) async {
    final existing = await (select(postReactions)
      ..where((r) => r.postId.equals(reaction.postId.value) &
                     r.userId.equals(reaction.userId.value)))
      .getSingleOrNull();

    if (existing != null) {
      await (delete(postReactions)..where((r) => r.id.equals(existing.id))).go();
    } else {
      await into(postReactions).insert(reaction);
    }
  }

  // Comments
  Future<List<PostComment>> getCommentsByPost(String postId) {
    return (select(postComments)
      ..where((c) => c.postId.equals(postId))
      ..orderBy([(c) => OrderingTerm.asc(c.createdAt)]))
      .get();
  }

  Future<void> addComment(PostCommentsCompanion comment) {
    return into(postComments).insert(comment);
  }
}
```

---

## Step 3: Update app_database.dart

**File: `lib/data/database/app_database.dart`**

```dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// Existing tables
import 'tables/users_table.dart';
import 'tables/groups_table.dart';
import 'tables/bills_table.dart';
import 'tables/receipt_items_table.dart';

// NEW: Chore tables
import 'tables/chores_table.dart';
import 'tables/chore_assignments_table.dart';
import 'tables/chore_rotations_table.dart';

// NEW: Maintenance tables
import 'tables/maintenance_tickets_table.dart';
import 'tables/ticket_comments_table.dart';
import 'tables/ticket_attachments_table.dart';

// NEW: Handover tables
import 'tables/handover_sessions_table.dart';
import 'tables/handover_items_table.dart';
import 'tables/ghost_overlays_table.dart';

// NEW: Score tables
import 'tables/resident_scores_table.dart';
import 'tables/unit_scores_table.dart';
import 'tables/score_events_table.dart';

// NEW: Community tables
import 'tables/community_posts_table.dart';
import 'tables/post_reactions_table.dart';
import 'tables/post_comments_table.dart';

// Existing DAOs
import 'daos/user_dao.dart';
import 'daos/group_dao.dart';
import 'daos/bill_dao.dart';

// NEW: DAOs
import 'daos/chore_dao.dart';
import 'daos/maintenance_dao.dart';
import 'daos/handover_dao.dart';
import 'daos/score_dao.dart';
import 'daos/community_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    // Existing
    Users,
    Groups,
    Bills,
    ReceiptItems,
    // NEW: Chores
    Chores,
    ChoreAssignments,
    ChoreRotations,
    // NEW: Maintenance
    MaintenanceTickets,
    TicketComments,
    TicketAttachments,
    // NEW: Handover
    HandoverSessions,
    HandoverItems,
    GhostOverlays,
    // NEW: Scores
    ResidentScores,
    UnitScores,
    ScoreEvents,
    // NEW: Community
    CommunityPosts,
    PostReactions,
    PostComments,
  ],
  daos: [
    // Existing
    UserDao,
    GroupDao,
    BillDao,
    // NEW
    ChoreDao,
    MaintenanceDao,
    HandoverDao,
    ScoreDao,
    CommunityDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2; // INCREMENT THIS!

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Create all new tables for v2
          await m.createTable(chores);
          await m.createTable(choreAssignments);
          await m.createTable(choreRotations);
          await m.createTable(maintenanceTickets);
          await m.createTable(ticketComments);
          await m.createTable(ticketAttachments);
          await m.createTable(handoverSessions);
          await m.createTable(handoverItems);
          await m.createTable(ghostOverlays);
          await m.createTable(residentScores);
          await m.createTable(unitScores);
          await m.createTable(scoreEvents);
          await m.createTable(communityPosts);
          await m.createTable(postReactions);
          await m.createTable(postComments);
        }
      },
    );
  }

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'residex.db'));
      return NativeDatabase(file);
    });
  }
}
```

---

## Step 4: Generate Drift Code

After creating all files, run:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

This generates:
- `app_database.g.dart`
- `chore_dao.g.dart`
- `maintenance_dao.g.dart`
- `handover_dao.g.dart`
- `score_dao.g.dart`
- `community_dao.g.dart`

---

## Step 5: Verify

```bash
flutter analyze
flutter build apk --debug
```

---

## Summary Checklist

### Table Files to Create (15 files)
- [ ] `lib/data/database/tables/chores_table.dart`
- [ ] `lib/data/database/tables/chore_assignments_table.dart`
- [ ] `lib/data/database/tables/chore_rotations_table.dart`
- [ ] `lib/data/database/tables/maintenance_tickets_table.dart`
- [ ] `lib/data/database/tables/ticket_comments_table.dart`
- [ ] `lib/data/database/tables/ticket_attachments_table.dart`
- [ ] `lib/data/database/tables/handover_sessions_table.dart`
- [ ] `lib/data/database/tables/handover_items_table.dart`
- [ ] `lib/data/database/tables/ghost_overlays_table.dart`
- [ ] `lib/data/database/tables/resident_scores_table.dart`
- [ ] `lib/data/database/tables/unit_scores_table.dart`
- [ ] `lib/data/database/tables/score_events_table.dart`
- [ ] `lib/data/database/tables/community_posts_table.dart`
- [ ] `lib/data/database/tables/post_reactions_table.dart`
- [ ] `lib/data/database/tables/post_comments_table.dart`

### DAO Files to Create (5 files)
- [ ] `lib/data/database/daos/chore_dao.dart`
- [ ] `lib/data/database/daos/maintenance_dao.dart`
- [ ] `lib/data/database/daos/handover_dao.dart`
- [ ] `lib/data/database/daos/score_dao.dart`
- [ ] `lib/data/database/daos/community_dao.dart`

### Files to Modify (1 file)
- [ ] `lib/data/database/app_database.dart` - Add imports, tables, DAOs, bump version, add migration

### Commands to Run
- [ ] `flutter pub run build_runner build --delete-conflicting-outputs`
- [ ] `flutter analyze`
- [ ] `flutter build apk --debug`

---

*Total: 15 new table files + 5 new DAO files + 1 modified file = 21 file operations*
