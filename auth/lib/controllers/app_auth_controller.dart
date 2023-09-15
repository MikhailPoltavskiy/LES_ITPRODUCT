import 'package:auth/models/user.dart';
import 'package:auth/utils/app_env.dart';
import 'package:auth/utils/app_response.dart';
import 'package:auth/utils/app_utils.dart';
import 'package:conduit_core/conduit_core.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';

class AppAuthController extends ResourceController {
  final ManagedContext managedContext;

  AppAuthController(this.managedContext);

  @Operation.post()
  Future<AppResponse> signIn(@Bind.body() User user) async {
    if (user.password == null || user.username == null) {
      return AppResponse.badRequest(
          message: 'Поля password, username обязательны');
    }

    try {
      final qFindUser = Query<User>(managedContext)
        ..where((table) => table.username).equalTo(user.username)
        ..returningProperties(
            (table) => [table.id, table.salt, table.hashPassword]);
      final findUser = await qFindUser.fetchOne();
      if (findUser == null) {
        throw QueryException.input('Пользователь не найден', []);
      }
      final requestHasPassword =
          generatePasswordHash(user.password ?? '', findUser.salt ?? '');
      if (requestHasPassword == findUser.hashPassword) {
        await _updateTokens(findUser.id ?? -1, managedContext);
        final newUser =
            await managedContext.fetchObjectWithID<User>(findUser.id);
        return AppResponse.ok(
            body: newUser?.backing.contents, message: 'Успешная авторизация');
      } else {
        throw QueryException.input('Пароль не верный', []);
      }
    } catch (error) {
      return AppResponse.serverError(error, message: 'Ошибка авторизации');
    }
  }

  @Operation.put()
  Future<AppResponse> signUp(@Bind.body() User user) async {
    if (user.password == null || user.username == null || user.email == null) {
      return AppResponse.badRequest(
          message: "Поля password, username, email обязательны");
    }

    final salt = generateRandomSalt();
    final hashPassword = generatePasswordHash(user.password ?? '', salt);

    try {
      late final int id;
      await managedContext.transaction((transaction) async {
        final qCreateUser = Query<User>(transaction)
          ..values.username = user.username
          ..values.email = user.email
          ..values.salt = salt
          ..values.hashPassword = hashPassword;
        final createdUser = await qCreateUser.insert();
        id = createdUser.asMap()["id"];
        await _updateTokens(id, transaction);
      });
      final userData = await managedContext.fetchObjectWithID<User>(id);
      return AppResponse.ok(
        body: userData?.backing.contents,
        message: 'Успешная регистрация',
      );
    } catch (error) {
      return AppResponse.serverError(error, message: 'Ошибка регистрации');
    }
  }

  Future<void> _updateTokens(int id, ManagedContext transaction) async {
    final Map<String, dynamic> tokens = _getTokens(id);
    final qUpdateTokens = Query<User>(transaction)
      ..where((user) => user.id).equalTo(id)
      ..values.accessToken = tokens["access"]
      ..values.refreshToken = tokens["refresh"];
    await qUpdateTokens.updateOne();
  }

  @Operation.post('refresh')
  Future<AppResponse> refreshToken(
      @Bind.path("refresh") String refreshToken) async {
    try {
      final id = AppUtils.getIdFromToken(refreshToken);
      final user = await managedContext.fetchObjectWithID<User>(id);
      if (user?.refreshToken != refreshToken) {
        return AppResponse.unauthorized(message: 'Token is not valid');
      } else {
        await _updateTokens(id, managedContext);
        final user = await managedContext.fetchObjectWithID<User>(id);
        return AppResponse.ok(
            body: user?.backing.contents,
            message: 'Успешное обновление токенов');
      }
    } catch (error) {
      return AppResponse.serverError(error,
          message: 'Ошибка обновления токенов');
    }
  }
}

Map<String, dynamic> _getTokens(int id) {
  final key = AppEnv.secretKey;
  final accessClaimSet =
      JwtClaim(maxAge: Duration(minutes: AppEnv.time), otherClaims: {'id': id});
  final refreshClaimSet = JwtClaim(otherClaims: {'id': id});
  final tokens = <String, dynamic>{};
  tokens["access"] = issueJwtHS256(accessClaimSet, key);
  tokens["refresh"] = issueJwtHS256(refreshClaimSet, key);
  return tokens;
}
