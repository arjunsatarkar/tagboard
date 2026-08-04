import gleam/dict.{type Dict}
import gleam/regexp.{type Regexp}
import pog

pub type Context {
  Context(
    db: pog.Connection,
    static_file_mapping: StaticFileMapping,
    not_found_path: String,
    trailing_slash_regexp: Regexp,
  )
}

pub type StaticFileMapping =
  Dict(List(String), String)
