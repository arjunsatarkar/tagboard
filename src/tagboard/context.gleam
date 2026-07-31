import gleam/dict.{type Dict}
import gleam/regexp.{type Regexp}

pub type Context {
  Context(
    static_file_mapping: StaticFileMapping,
    not_found_path: String,
    trailing_slash_regexp: Regexp,
  )
}

pub type StaticFileMapping =
  Dict(List(String), String)
