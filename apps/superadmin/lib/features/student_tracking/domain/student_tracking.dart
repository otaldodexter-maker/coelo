import 'dart:collection';

final class StudentTrackingChild {
  const StudentTrackingChild({
    required this.id,
    required this.name,
    required this.institutionName,
    this.institutionId = '',
  });
  final String id;
  final String name;
  final String institutionName;
  final String institutionId;
}

final class StudentTrackingCursor {
  const StudentTrackingCursor({required this.name, required this.id});
  final String name;
  final String id;
}

final class StudentTrackingChildPage {
  StudentTrackingChildPage({required List<StudentTrackingChild> items, this.nextCursor})
    : items = UnmodifiableListView(items);
  final List<StudentTrackingChild> items;
  final StudentTrackingCursor? nextCursor;
}

final class StudentTrackingContext {
  const StudentTrackingContext({required this.id, required this.name});
  final String id;
  final String name;
}

final class StudentTrackingPeriod {
  const StudentTrackingPeriod({required this.id, required this.label});
  final String id;
  final String label;
}

final class StudentTrackingAssessment {
  const StudentTrackingAssessment({
    required this.id,
    this.instrumentId = '',
    required this.title,
    required this.value,
    required this.normalized,
    this.version = 1,
    this.observation,
  });
  final String id;
  final String instrumentId;
  final String title;
  final String value;
  final double normalized;
  final int version;
  final String? observation;
}

final class StudentTrackingCompetency {
  const StudentTrackingCompetency({
    this.id = '',
    required this.category,
    required this.name,
    required this.normalized,
    this.version = 1,
  });
  final String id;
  final String category;
  final String name;
  final double normalized;
  final int version;
}

final class StudentTrackingCategoryScore {
  const StudentTrackingCategoryScore({required this.name, required this.normalized});
  final String name;
  final double normalized;
}

enum StudentDevelopmentKind { participation, behavior }

final class StudentDevelopmentScore {
  const StudentDevelopmentScore({
    this.id = '',
    required this.kind,
    required this.name,
    required this.normalized,
    this.version = 1,
  });
  final String id;
  final StudentDevelopmentKind kind;
  final String name;
  final double normalized;
  final int version;
}

final class StudentTrackingAttendance {
  const StudentTrackingAttendance({
    required this.total,
    required this.present,
    required this.justifiedAbsences,
    required this.unjustifiedAbsences,
    required this.late,
    required this.percentage,
  });
  final int total;
  final int present;
  final int justifiedAbsences;
  final int unjustifiedAbsences;
  final int late;
  final double percentage;
}

final class StudentAgendaEvent {
  const StudentAgendaEvent({
    required this.id,
    required this.kind,
    required this.title,
    required this.startsAt,
    this.endsAt,
    this.description,
    this.allDay = false,
  });
  final String id;
  final String kind;
  final String title;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? description;
  final bool allDay;
}

final class StudentReportCard {
  const StudentReportCard({
    required this.id,
    required this.title,
    this.summary,
    required this.publishedAt,
  });
  final String id;
  final String title;
  final String? summary;
  final DateTime publishedAt;
}

final class StudentTeacherRecommendation {
  const StudentTeacherRecommendation({
    required this.id,
    required this.text,
    required this.publishedAt,
  });
  final String id;
  final String text;
  final DateTime publishedAt;
}

final class StudentTrackingSnapshot {
  StudentTrackingSnapshot({
    required this.child,
    required List<StudentTrackingContext> contexts,
    required List<StudentTrackingPeriod> periods,
    required List<StudentTrackingAssessment> assessments,
    required List<StudentTrackingCompetency> competencies,
    required List<StudentTrackingCategoryScore> categoryScores,
    required List<StudentDevelopmentScore> development,
    required this.attendance,
    required List<StudentAgendaEvent> agenda,
    required this.pendingNotices,
    this.reportCard,
    this.recommendation,
  }) : contexts = UnmodifiableListView(contexts),
       periods = UnmodifiableListView(periods),
       assessments = UnmodifiableListView(assessments),
       competencies = UnmodifiableListView(competencies),
       categoryScores = UnmodifiableListView(categoryScores),
       development = UnmodifiableListView(development),
       agenda = UnmodifiableListView(agenda);
  final StudentTrackingChild child;
  final List<StudentTrackingContext> contexts;
  final List<StudentTrackingPeriod> periods;
  final List<StudentTrackingAssessment> assessments;
  final List<StudentTrackingCompetency> competencies;
  final List<StudentTrackingCategoryScore> categoryScores;
  final List<StudentDevelopmentScore> development;
  final StudentTrackingAttendance attendance;
  final List<StudentAgendaEvent> agenda;
  final StudentReportCard? reportCard;
  final StudentTeacherRecommendation? recommendation;
  final int pendingNotices;
}

final class StudentTrackingAgendaCursor {
  const StudentTrackingAgendaCursor({required this.startsAt, required this.id});
  final DateTime startsAt;
  final String id;
}

abstract interface class StudentTrackingRepository {
  Future<StudentTrackingChildPage> fetchChildren({
    String? query,
    StudentTrackingCursor? after,
    int limit = 20,
  });
  Future<StudentTrackingSnapshot> fetchSnapshot({
    required String childContextId,
    String? activityId,
    String? periodId,
    StudentTrackingAgendaCursor? agendaAfter,
    int agendaLimit = 20,
  });
}

class StudentTrackingException implements Exception {
  const StudentTrackingException();
}

final class StudentTrackingUnavailableException extends StudentTrackingException {
  const StudentTrackingUnavailableException();
}

final class StudentTrackingOfflineException extends StudentTrackingException {
  const StudentTrackingOfflineException();
}

final class StudentTrackingDeniedException extends StudentTrackingException {
  const StudentTrackingDeniedException();
}

final class StudentTrackingRevokedException extends StudentTrackingException {
  const StudentTrackingRevokedException();
}

final class StudentTrackingVersionConflictException extends StudentTrackingException {
  const StudentTrackingVersionConflictException();
}

final class UnavailableStudentTrackingRepository implements StudentTrackingRepository {
  const UnavailableStudentTrackingRepository();

  Future<T> _unavailable<T>() => Future<T>.error(const StudentTrackingUnavailableException());

  @override
  Future<StudentTrackingChildPage> fetchChildren({
    String? query,
    StudentTrackingCursor? after,
    int limit = 20,
  }) => _unavailable();

  @override
  Future<StudentTrackingSnapshot> fetchSnapshot({
    required String childContextId,
    String? activityId,
    String? periodId,
    StudentTrackingAgendaCursor? agendaAfter,
    int agendaLimit = 20,
  }) => _unavailable();
}
