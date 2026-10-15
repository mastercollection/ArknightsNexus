import '../domain/user_data.dart';

abstract interface class UserDataRepository {
  Future<UserData> read();

  Future<void> write(UserData data);

  Future<void> backup();
}
