import '../entities/visa_application.dart';

abstract class ApplicationRepository {
  Future<List<VisaApplication>> listApplications({String? userId});
  Future<VisaApplication?> getApplication(String id);
  Future<VisaApplication> createApplication(VisaApplication application);
  Future<VisaApplication> updateApplication(VisaApplication application);
}
