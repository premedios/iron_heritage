// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wger_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(wgerRepository)
final wgerRepositoryProvider = WgerRepositoryProvider._();

final class WgerRepositoryProvider
    extends $FunctionalProvider<WgerRepository, WgerRepository, WgerRepository>
    with $Provider<WgerRepository> {
  WgerRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wgerRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wgerRepositoryHash();

  @$internal
  @override
  $ProviderElement<WgerRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WgerRepository create(Ref ref) {
    return wgerRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WgerRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WgerRepository>(value),
    );
  }
}

String _$wgerRepositoryHash() => r'55a5f21480f7a655c7c457f9cd52e93d2e140c85';

@ProviderFor(isSynced)
final isSyncedProvider = IsSyncedProvider._();

final class IsSyncedProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  IsSyncedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isSyncedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isSyncedHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return isSynced(ref);
  }
}

String _$isSyncedHash() => r'd1f520a659f6540bbf9854841950bc2b5152fd3c';

@ProviderFor(runSync)
final runSyncProvider = RunSyncProvider._();

final class RunSyncProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  RunSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'runSyncProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$runSyncHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return runSync(ref);
  }
}

String _$runSyncHash() => r'8174ab3961d718b49a2938a4c464deca35c96e5e';
