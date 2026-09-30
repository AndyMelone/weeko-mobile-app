import '../core/widgets/status_tag.dart';
import '../data/models/models.dart';

TagKind tagOfSession(Session s) => switch (s.status) {
  SessionStatus.prevue => s.isRattrapage ? TagKind.rattrapage : TagKind.prevue,
  SessionStatus.manquee => s.noRedo ? TagKind.sansRattrapage : TagKind.manquee,
  SessionStatus.faite => TagKind.faite,
  SessionStatus.rattrapee => TagKind.rattrapee,
};

TagKind tagOfStatus(SessionStatus st) => switch (st) {
  SessionStatus.prevue => TagKind.prevue,
  SessionStatus.faite => TagKind.faite,
  SessionStatus.manquee => TagKind.manquee,
  SessionStatus.rattrapee => TagKind.rattrapee,
};
