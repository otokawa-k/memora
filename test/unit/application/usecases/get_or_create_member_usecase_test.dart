import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:memora/domain/entities/member.dart';
import 'package:memora/domain/entities/user.dart';
import 'package:memora/domain/repositories/member_repository.dart';
import 'package:memora/application/usecases/get_or_create_member_usecase.dart';

import 'get_or_create_member_usecase_test.mocks.dart';

@GenerateMocks([MemberRepository])
void main() {
  late MockMemberRepository mockMemberRepository;
  late GetOrCreateMemberUseCase useCase;

  setUp(() {
    mockMemberRepository = MockMemberRepository();
    useCase = GetOrCreateMemberUseCase(mockMemberRepository);
  });

  group('GetOrCreateMemberUseCase', () {
    const testUid = 'test-uid-12345';
    const testEmail = 'test@example.com';

    final testUser = User(id: testUid, email: testEmail, isEmailVerified: true);

    test('既存メンバーが見つかった場合、trueを返す', () async {
      // arrange
      final existingMember = Member(
        id: 'member-id-1',
        accountId: testUid,
        firstName: 'Test',
        lastName: 'User',
        displayName: '表示名',
        email: testEmail,
      );

      when(
        mockMemberRepository.getMemberByAccountId(testUid),
      ).thenAnswer((_) async => existingMember);

      // act
      final result = await useCase.execute(testUser);

      // assert
      expect(result, equals(true));
      verify(mockMemberRepository.getMemberByAccountId(testUid)).called(1);
      verifyNever(mockMemberRepository.saveMember(any));
    });

    test('既存メンバーが見つからない場合、新しいメンバーを作成してtrueを返す', () async {
      // arrange
      when(
        mockMemberRepository.getMemberByAccountId(testUid),
      ).thenAnswer((_) async => null);
      when(mockMemberRepository.saveMember(any)).thenAnswer((_) async {});

      // act
      final result = await useCase.execute(testUser);

      // assert
      expect(result, equals(true));

      verify(mockMemberRepository.getMemberByAccountId(testUid)).called(1);
      verify(
        mockMemberRepository.saveMember(
          argThat(
            predicate<Member>(
              (member) =>
                  member.accountId == testUid && member.email == testEmail,
            ),
          ),
        ),
      ).called(1);
    });
  });
}
