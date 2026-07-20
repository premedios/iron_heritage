// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'smart_alternatives_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(smartAlternativesService)
final smartAlternativesServiceProvider = SmartAlternativesServiceProvider._();

final class SmartAlternativesServiceProvider
    extends
        $FunctionalProvider<
          SmartAlternativesService,
          SmartAlternativesService,
          SmartAlternativesService
        >
    with $Provider<SmartAlternativesService> {
  SmartAlternativesServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'smartAlternativesServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$smartAlternativesServiceHash();

  @$internal
  @override
  $ProviderElement<SmartAlternativesService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SmartAlternativesService create(Ref ref) {
    return smartAlternativesService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SmartAlternativesService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SmartAlternativesService>(value),
    );
  }
}

String _$smartAlternativesServiceHash() =>
    r'fe8a13097d679a06be91a45940a11017db5f54aa';
