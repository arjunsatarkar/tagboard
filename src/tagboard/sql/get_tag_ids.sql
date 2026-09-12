SELECT
    id
FROM
    items
WHERE
    uri = ANY ($1)
