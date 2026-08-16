///|
pub extend YamlError with Debug::{to_repr}

///|
pub extend Event with Eq::{equal, not_equal}

///|
pub extend Event with Debug::{to_repr}

///|
pub extend Marker with Debug::{to_repr}

///|
pub extend Marker with Eq::{equal, not_equal}

///|
pub extend TScalarStyle with Eq::{equal, not_equal}

///|
pub extend TScalarStyle with Debug::{to_repr}

///|
pub extend Tag with Eq::{equal, not_equal}

///|
pub extend Tag with Debug::{to_repr}

///|
pub extend Yaml with Eq::{equal, not_equal}

///|
pub extend Yaml with Debug::{to_repr}

///|
pub extend Yaml with ToJson::{to_json}
