enum ConnectivityStatus { checking, apiUnavailable, databaseUnavailable, ready }

class ConnectivityState {
  const ConnectivityState(this.status);

  const ConnectivityState.checking() : status = ConnectivityStatus.checking;

  final ConnectivityStatus status;
}
