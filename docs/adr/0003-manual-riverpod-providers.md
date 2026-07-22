# Manual Riverpod providers

Riverpod providers are declared manually. Stable `riverpod_generator` releases require analyzer ranges that conflict with the required stable `freezed 3.2.5` and `json_serializable 6.14.x` combination; removing provider generation preserves those supported pins without adopting a Freezed prerelease. Reconsider generated providers when the stable dependency ranges converge.
