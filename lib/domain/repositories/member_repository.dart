import 'package:memora/domain/entities/member.dart';

abstract class MemberRepository {
  Future<List<Member>> getMembers();
  Future<void> saveMember(Member member);
  Future<void> updateMember(Member member);
  Future<void> deleteMember(String memberId);
  Future<Member?> getMemberById(String memberId);
  Future<Member?> getMemberByAccountId(String accountId);
  Future<List<Member>> getMembersByAdministratorId(String administratorId);
}
