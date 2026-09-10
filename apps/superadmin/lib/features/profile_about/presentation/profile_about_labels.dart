import 'package:coelo_domain/profile_about.dart';

/// Human label of an About field, in the same idiom as the editor's other label helpers.
///
/// Every field used to be labelled with `field.key.name`, so the editor showed
/// the raw enum identifier — "displayAddress", "preciseLocation" — as the name
/// of the thing being edited. The switch is exhaustive on purpose: a new key
/// stops compiling here instead of leaking an identifier into the interface.
String profileAboutFieldLabel(ProfileAboutFieldKey value) => switch (value) {
  ProfileAboutFieldKey.displayName => 'Nome exibido',
  ProfileAboutFieldKey.description => 'Descrição',
  ProfileAboutFieldKey.displayAddress => 'Endereço exibido',
  ProfileAboutFieldKey.preciseLocation => 'Localização precisa',
  ProfileAboutFieldKey.institutionalLocation => 'Localização institucional',
  ProfileAboutFieldKey.phone => 'Telefone',
  ProfileAboutFieldKey.mobile => 'Celular',
  ProfileAboutFieldKey.email => 'E-mail',
  ProfileAboutFieldKey.website => 'Site',
  ProfileAboutFieldKey.serviceHours => 'Horário de atendimento',
  ProfileAboutFieldKey.generalHours => 'Horário geral',
  ProfileAboutFieldKey.cityState => 'Cidade e estado',
  ProfileAboutFieldKey.foundedOn => 'Fundação',
  ProfileAboutFieldKey.institutionType => 'Tipo de instituição',
  ProfileAboutFieldKey.visibleLinks => 'Vínculos visíveis',
  ProfileAboutFieldKey.institutionLink => 'Vínculo com a instituição',
  ProfileAboutFieldKey.unitLink => 'Vínculo com a unidade',
  ProfileAboutFieldKey.activityLinks => 'Vínculos com atividades',
  ProfileAboutFieldKey.teamLinks => 'Vínculos com a equipe',
  ProfileAboutFieldKey.proposal => 'Proposta',
  ProfileAboutFieldKey.methodology => 'Metodologia',
  ProfileAboutFieldKey.objective => 'Objetivo',
  ProfileAboutFieldKey.audience => 'Público',
  ProfileAboutFieldKey.materials => 'Materiais',
  ProfileAboutFieldKey.generalGuidance => 'Orientações gerais',
  ProfileAboutFieldKey.importantInformation => 'Informações importantes',
  ProfileAboutFieldKey.identityInstitutional => 'Identidade institucional',
  ProfileAboutFieldKey.inheritanceOrigin => 'Origem da herança',
  ProfileAboutFieldKey.professionalRole => 'Função profissional',
};
