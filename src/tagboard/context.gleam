import gleam/dict.{type Dict}

pub type Context {
  Context(static_file_mapping: StaticFileMapping, not_found_path: String)
}

pub type StaticFileMapping =
  Dict(List(String), String)
