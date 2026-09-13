SELECT
    items_outer.uri,
    ARRAY (
        SELECT
            items_inner.uri
        FROM
            items items_inner
        WHERE
            items_inner.id = ANY (items_outer.tags))
FROM
    items items_outer
WHERE
    items_outer.uri ILIKE '%' || $1 || '%'
ORDER BY
    items_outer.created_at DESC
LIMIT 100
