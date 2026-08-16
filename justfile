run: build-frontend
    gleam run

build: build-frontend
    gleam build

build-frontend:
    mkdir -p priv/frontend
    cd tagboard-frontend && node index
    rsync --archive tagboard-frontend/build/* priv/frontend

migrate:
    gleam run -m migrate