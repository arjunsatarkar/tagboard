import gleam/list
import gleam/string
import gleam/uri

const tag_proto = "tagboard-tag:"

pub fn parse_tags_string(tags_string: String) -> List(String) {
  tags_string
  |> string.split(" ")
  |> list.filter(fn(s) { !string.is_empty(s) })
  |> list.map(string.lowercase)
  |> list.map(uri.percent_encode)
  |> list.map(fn(percent_encoded) { tag_proto <> percent_encoded })
}

pub fn create_tags_string_from_tag_uris(tags: List(String)) -> String {
  tags
  |> list.map(fn(tag_uri) {
    case uri.percent_decode(tag_uri) {
      Ok(decoded) -> string.remove_prefix(decoded, tag_proto)
      Error(Nil) -> "%INVALID_TAG%"
    }
  })
  |> string.join(" ")
}
