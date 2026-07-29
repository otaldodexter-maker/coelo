import 'package:coelo_superadmin/features/people/data/fake_person_directory_repository.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:coelo_superadmin/features/people/presentation/person_form_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('create flow has identity, contextual links and review', () {
    final viewModel = PersonFormViewModel(FakePersonDirectoryRepository());

    expect(PersonFormStep.values.map((step) => step.label), [
      'Identidade',
      'Vínculos contextuais',
      'Revisão',
    ]);
    expect(viewModel.step, PersonFormStep.identity);
    viewModel.next();
    expect(viewModel.step, PersonFormStep.contexts);
    viewModel.next();
    expect(viewModel.step, PersonFormStep.review);
  });

  test('creates adult as draft and never requests auth activation', () async {
    final repository = FakePersonDirectoryRepository();
    final viewModel = PersonFormViewModel(repository)
      ..type = PersonType.adult
      ..firstName = 'Ana'
      ..lastName = 'Nova'
      ..legalName = 'Ana Nova'
      ..displayName = 'Ana Nova';

    final person = await viewModel.save();

    expect(person.status, PersonStatus.draft);
    expect(person.authLink, AuthLinkStatus.unlinked);
  });

  test('edit command changes only approved global fields and membership delta', () async {
    final repository = FakePersonDirectoryRepository();
    final original = repository.people.firstWhere((item) => item.isEditable);
    final viewModel = PersonFormViewModel(repository, original: original)
      ..displayName = 'Nome aprovado';

    final person = await viewModel.save();

    expect(person.type, original.type);
    expect(person.status, original.status);
    expect(person.authLink, original.authLink);
    expect(person.displayName, 'Nome aprovado');
  });

  test('removing a newly added membership cancels the pending add', () {
    final viewModel = PersonFormViewModel(FakePersonDirectoryRepository());
    const membership = PersonMembership(
      id: 'new-1',
      institutionId: 'institution-0',
      institutionName: 'Instituição 1',
      role: 'guardian',
    );

    viewModel
      ..addMembership(membership)
      ..removeMembership(membership);

    expect(viewModel.memberships, isEmpty);
    expect(viewModel.membershipChanges, isEmpty);
  });

  test('membership updates are consolidated by assignment', () {
    final repository = FakePersonDirectoryRepository();
    final original = repository.people.firstWhere((person) => person.type == PersonType.adult);
    final viewModel = PersonFormViewModel(repository, original: original);
    final membership = original.memberships.first;

    viewModel
      ..updateMembership(membership.copyWith(role: 'teacher'))
      ..updateMembership(membership.copyWith(role: 'coordinator'));

    expect(viewModel.membershipChanges, hasLength(1));
    expect(viewModel.membershipChanges.single.membership.role, 'coordinator');
  });

  test('removing a newly added child context cancels the pending add', () {
    final viewModel = PersonFormViewModel(FakePersonDirectoryRepository())..type = PersonType.child;
    const context = PersonChildContext(id: 'new-child-1', institutionId: 'institution-0');

    viewModel
      ..addChildContext(context)
      ..removeChildContext(context);

    expect(viewModel.childContexts, isEmpty);
    expect(viewModel.childContextChanges, isEmpty);
  });
}
