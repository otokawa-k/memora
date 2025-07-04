import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:memora/domain/entities/auth_state.dart';
import 'package:memora/domain/entities/user.dart';
import 'package:memora/domain/services/auth_service.dart';
import 'package:memora/application/managers/auth_manager.dart';
import 'package:memora/application/usecases/get_or_create_member_usecase.dart';

import 'auth_manager_test.mocks.dart';

@GenerateMocks([AuthService, GetOrCreateMemberUseCase])
void main() {
  group('AuthManager', () {
    late AuthManager authManager;
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = MockAuthService();
      authManager = AuthManager(authService: mockAuthService);
    });

    test('初期状態はloading', () {
      expect(authManager.state.status, AuthStatus.loading);
    });

    group('initialize', () {
      test('initializeでauthStateChangesのリスナーが登録される', () async {
        final controller = StreamController<User?>();
        when(
          mockAuthService.authStateChanges,
        ).thenAnswer((_) => controller.stream);

        await authManager.initialize();

        expect(authManager.state.status, AuthStatus.loading);
        verify(mockAuthService.authStateChanges).called(1);

        controller.close();
      });

      test('ユーザーログイン時にauthenticated状態になる', () async {
        const user = User(
          id: 'user123',
          email: 'test@example.com',
          displayName: 'テストユーザー',
          isEmailVerified: true,
        );

        final controller = StreamController<User?>();
        when(
          mockAuthService.authStateChanges,
        ).thenAnswer((_) => controller.stream);

        await authManager.initialize();

        // act
        controller.add(user);

        // authStateChangesリスナー内の非同期処理完了を待つ
        await Future(() {});

        // assert
        expect(authManager.state.status, AuthStatus.authenticated);
        expect(authManager.state.user, user);

        controller.close();
      });

      test('ユーザーログアウト時にunauthenticated状態になる', () async {
        final controller = StreamController<User?>();
        when(
          mockAuthService.authStateChanges,
        ).thenAnswer((_) => controller.stream);

        await authManager.initialize();

        // act
        controller.add(null);

        // authStateChangesリスナー内の非同期処理完了を待つ
        await Future(() {});

        // assert
        expect(authManager.state.status, AuthStatus.unauthenticated);
        expect(authManager.state.user, isNull);

        controller.close();
      });

      test('authStateChanges経由でメンバー取得・作成処理が実行される', () async {
        // arrange
        late MockGetOrCreateMemberUseCase mockGetOrCreateMemberUseCase;
        mockGetOrCreateMemberUseCase = MockGetOrCreateMemberUseCase();

        const user = User(
          id: 'user123',
          email: 'test@example.com',
          displayName: 'テストユーザー',
          isEmailVerified: true,
        );

        // authStateChangesでユーザー状態変更をシミュレート
        final controller = StreamController<User?>();
        when(
          mockAuthService.authStateChanges,
        ).thenAnswer((_) => controller.stream);

        when(mockAuthService.getCurrentUser()).thenAnswer((_) async => user);
        when(
          mockAuthService.validateCurrentUserToken(),
        ).thenAnswer((_) async {});

        when(
          mockGetOrCreateMemberUseCase.execute(user),
        ).thenAnswer((_) async => true);

        // AuthManagerにUseCaseを依存注入
        authManager = AuthManager(
          authService: mockAuthService,
          getOrCreateMemberUseCase: mockGetOrCreateMemberUseCase,
        );

        await authManager.initialize();

        // act - authStateChangesでユーザー変更をエミット
        controller.add(user);

        // authStateChangesリスナー内の非同期処理完了を待つ
        await Future(() {});

        // assert
        verify(mockGetOrCreateMemberUseCase.execute(user)).called(1);

        controller.close();
      });

      test('認証エラー時に強制ログアウトしてerror状態になる', () async {
        // arrange
        late MockGetOrCreateMemberUseCase mockGetOrCreateMemberUseCase;
        mockGetOrCreateMemberUseCase = MockGetOrCreateMemberUseCase();

        const user = User(
          id: 'user123',
          email: 'test@example.com',
          displayName: 'テストユーザー',
          isEmailVerified: true,
        );

        // authStateChangesでユーザー状態変更をシミュレート
        final controller = StreamController<User?>();
        when(
          mockAuthService.authStateChanges,
        ).thenAnswer((_) => controller.stream);

        // validateCurrentUserToken()で認証エラーをシミュレート
        when(
          mockAuthService.validateCurrentUserToken(),
        ).thenThrow(Exception('認証トークンが無効です'));
        when(mockAuthService.signOut()).thenAnswer((_) async {});

        // AuthManagerにUseCaseを依存注入
        authManager = AuthManager(
          authService: mockAuthService,
          getOrCreateMemberUseCase: mockGetOrCreateMemberUseCase,
        );

        await authManager.initialize();

        // act - authStateChangesでユーザー変更をエミット
        controller.add(user);

        // authStateChangesリスナー内の非同期処理完了を待つ
        await Future(() {});

        // assert
        verify(mockAuthService.signOut()).called(1);
        expect(authManager.state.status, AuthStatus.error);
        expect(authManager.state.errorMessage, '認証が無効です。再度ログインしてください。');

        controller.close();
      });
    });

    group('login', () {
      test('正常にログインできる', () async {
        const user = User(
          id: 'user123',
          email: 'test@example.com',
          displayName: 'テストユーザー',
          isEmailVerified: true,
        );

        when(
          mockAuthService.signInWithEmailAndPassword(
            email: 'test@example.com',
            password: 'password123',
          ),
        ).thenAnswer((_) async => user);

        await authManager.login(
          email: 'test@example.com',
          password: 'password123',
        );

        verify(
          mockAuthService.signInWithEmailAndPassword(
            email: 'test@example.com',
            password: 'password123',
          ),
        ).called(1);
      });

      test('ログインに失敗した場合、error状態になる', () async {
        when(
          mockAuthService.signInWithEmailAndPassword(
            email: 'test@example.com',
            password: 'wrongpassword',
          ),
        ).thenThrow(Exception('ログインに失敗しました'));

        await authManager.login(
          email: 'test@example.com',
          password: 'wrongpassword',
        );

        expect(authManager.state.status, AuthStatus.error);
        expect(authManager.state.errorMessage, isNotNull);
      });
    });

    group('signup', () {
      test('正常にサインアップできる', () async {
        const user = User(
          id: 'user123',
          email: 'test@example.com',
          displayName: null,
          isEmailVerified: false,
        );

        when(
          mockAuthService.createUserWithEmailAndPassword(
            email: 'test@example.com',
            password: 'password123',
          ),
        ).thenAnswer((_) async => user);

        await authManager.signup(
          email: 'test@example.com',
          password: 'password123',
        );

        verify(
          mockAuthService.createUserWithEmailAndPassword(
            email: 'test@example.com',
            password: 'password123',
          ),
        ).called(1);
      });

      test('サインアップに失敗した場合、error状態になる', () async {
        when(
          mockAuthService.createUserWithEmailAndPassword(
            email: 'invalid-email',
            password: 'password123',
          ),
        ).thenThrow(Exception('サインアップに失敗しました'));

        await authManager.signup(
          email: 'invalid-email',
          password: 'password123',
        );

        expect(authManager.state.status, AuthStatus.error);
        expect(authManager.state.errorMessage, isNotNull);
      });
    });

    group('logout', () {
      test('正常にログアウトできる', () async {
        when(mockAuthService.signOut()).thenAnswer((_) async => {});

        await authManager.logout();

        verify(mockAuthService.signOut()).called(1);
      });

      test('ログアウトに失敗した場合、error状態になる', () async {
        when(mockAuthService.signOut()).thenThrow(Exception('ログアウトに失敗しました'));

        await authManager.logout();

        expect(authManager.state.status, AuthStatus.error);
        expect(authManager.state.errorMessage, isNotNull);
      });
    });

    group('clearError', () {
      test('エラー状態をクリアできる', () async {
        when(
          mockAuthService.signInWithEmailAndPassword(
            email: 'test@example.com',
            password: 'wrongpassword',
          ),
        ).thenThrow(Exception('ログインに失敗しました'));

        await authManager.login(
          email: 'test@example.com',
          password: 'wrongpassword',
        );

        expect(authManager.state.status, AuthStatus.error);

        authManager.clearError();

        expect(authManager.state.status, AuthStatus.unauthenticated);
        expect(authManager.state.errorMessage, isNull);
      });
    });
  });
}
