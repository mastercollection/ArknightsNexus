abstract interface class UserDataImportService {
  Future<void> validateAndImport(String jsonText);
}
