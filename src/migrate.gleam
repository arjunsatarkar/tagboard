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
    pog.query("CREATE EXTENSION IF NOT EXISTS pg_trgm;") |> pog.execute(db)

  let assert Ok(_) =
    pog.query(
      "CREATE TABLE IF NOT EXISTS items (
        id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        uri TEXT UNIQUE NOT NULL,
        tags BIGINT ARRAY NOT NULL DEFAULT '{}',
        created_at TIMESTAMP NOT NULL,
        modified_at TIMESTAMP NOT NULL
       )",
    )
    |> pog.execute(db)

  let assert Ok(_) =
    pog.query(
      "CREATE INDEX IF NOT EXISTS idx_gin__items__tags ON items USING GIN (tags)",
    )
    |> pog.execute(db)

  let assert Ok(_) =
    pog.query(
      "CREATE INDEX IF NOT EXISTS idx__items__created_at ON items (created_at)",
    )
    |> pog.execute(db)

  let assert Ok(_) =
    pog.query(
      "CREATE INDEX IF NOT EXISTS idx__items__modified_at ON items (modified_at)",
    )
    |> pog.execute(db)

  let assert Ok(_) =
    pog.query(
      "CREATE INDEX IF NOT EXISTS idx_trgm__items__uri ON items USING GIN (uri gin_trgm_ops)",
    )
    |> pog.execute(db)
}
