-- The WITH is to make sure we always get an id back
WITH r AS (
INSERT INTO items (uri, created_at, modified_at)
        VALUES ($1, $2, $3)
    ON CONFLICT
        DO NOTHING
    RETURNING
        id)
    SELECT
        *
    FROM
        r
    UNION
    SELECT
        id
    FROM
        items
    WHERE
        uri = $1
