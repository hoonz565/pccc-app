import '../data/auth_models.dart';
import '../../facilities/data/facility_models.dart';

enum AppSessionStatus {
  bootstrapping,
  unauthenticated,
  authenticatedNeedsFacility,
  authenticatedReady,
  recoverableBootstrapFailure,
}

class AppSessionState {
  const AppSessionState._({
    required this.status,
    this.user,
    this.facilities = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  const AppSessionState.bootstrapping()
    : this._(status: AppSessionStatus.bootstrapping);

  const AppSessionState.unauthenticated({
    bool isLoading = false,
    String? errorMessage,
  }) : this._(
         status: AppSessionStatus.unauthenticated,
         isLoading: isLoading,
         errorMessage: errorMessage,
       );

  const AppSessionState.authenticatedNeedsFacility({
    required AuthUser user,
    bool isLoading = false,
    String? errorMessage,
  }) : this._(
         status: AppSessionStatus.authenticatedNeedsFacility,
         user: user,
         isLoading: isLoading,
         errorMessage: errorMessage,
       );

  const AppSessionState.authenticatedReady({
    required AuthUser user,
    required List<Facility> facilities,
    bool isLoading = false,
    String? errorMessage,
  }) : this._(
         status: AppSessionStatus.authenticatedReady,
         user: user,
         facilities: facilities,
         isLoading: isLoading,
         errorMessage: errorMessage,
       );

  const AppSessionState.recoverableBootstrapFailure(String message)
    : this._(
        status: AppSessionStatus.recoverableBootstrapFailure,
        errorMessage: message,
      );

  final AppSessionStatus status;
  final AuthUser? user;
  final List<Facility> facilities;
  final bool isLoading;
  final String? errorMessage;

  AppSessionState withInteraction({
    bool isLoading = false,
    String? errorMessage,
  }) => AppSessionState._(
    status: status,
    user: user,
    facilities: facilities,
    isLoading: isLoading,
    errorMessage: errorMessage,
  );
}
