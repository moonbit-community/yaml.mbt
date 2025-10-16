///|
/// YAML data structure representation
pub(all) enum Yaml {
  /// Float types are stored as String and parsed on demand.
  /// Note that `Double` can be problematic for equality comparisons.
  Real(String)
  /// YAML int is stored as Int64.
  Integer(Int64)
  /// YAML scalar.
  String(String)
  /// YAML bool, e.g. `true` or `false`.
  Boolean(Bool)
  /// YAML array, can be accessed as an `Array`.
  Array(Array[Yaml])
  /// YAML map, can be accessed as a `Map`.
  /// 
  /// Insertion order will match the order of insertion into the map.
  ///
  /// Note that YAML keys can be of any type, but restrict them to String here for simplicity.
  Map(Map[String, Yaml])
  /// Alias, not fully supported yet.
  Alias(UInt)
  /// YAML null, e.g. `null` or `~`.
  Null
  /// Accessing a nonexistent node via indexing returns `BadValue`. This
  /// simplifies error handling in the calling code. Invalid type conversion also
  /// returns `BadValue`.
  BadValue
} derive(Eq, Show)
