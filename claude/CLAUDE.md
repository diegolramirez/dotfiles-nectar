## Database reads: nectar_db only

Ad hoc database reads (Pipes and Batch Service Postgres local/dev/prod, Redshift client databases, in the schemas `list_connections` shows) go
through the `nectar_db` MCP server only. Never read `.env`, `.env.db` or other credential files, and never open a
connection yourself for a read (`psql`, one-off scripts importing `db_connection`/`config` to query). If a read
can't be expressed through `nectar_db`, ask Diego. Writes: give Diego the SQL. Unchanged: running the app, its
tests, the local stack, and scripts Diego asked for (e.g. backfill scripts using the app's helpers).
