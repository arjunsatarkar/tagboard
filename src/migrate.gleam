import dream_config/loader as config
import gleam/erlang/process
import gleam/otp/static_supervisor as supervisor
import pog
import wisp

pub fn main() {
  wisp.configure_logger()

  let assert Ok(_) = config.load_dotenv()

  let assert Ok(db_connection_uri) = config.get_required("DB_CONNECTION_URI")

  let pool_name = process.new_name("pog_db_pool")

  let assert Ok(db_config) = pog.url_config(pool_name, db_connection_uri)
  let pool_child =
    db_config
    |> pog.supervised

  let assert Ok(_) =
    supervisor.new(supervisor.RestForOne)
    |> supervisor.add(pool_child)
    |> supervisor.start

  let db = pog.named_connection(pool_name)
  let assert Ok(_) =
    pog.query(
      "CREATE TABLE IF NOT EXISTS items(
        id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        uri TEXT UNIQUE NOT NULL,
        tags BIGINT ARRAY
       )",
    )
    |> pog.execute(db)
  let assert Ok(_) =
    pog.query(
      "CREATE INDEX IF NOT EXISTS idx_gin__items__tags on items USING gin(tags)",
    )
    |> pog.execute(db)
}
