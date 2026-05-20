import { drizzle } from "drizzle-orm/node-postgres";
import { Pool } from "pg";
import { Resource } from "sst";
import * as schema from "./schema/todo.sql";

const host = Resource.KlinkPostgresDb.host;

const pool = new Pool({
	host,
	port: Resource.KlinkPostgresDb.port,
	user: Resource.KlinkPostgresDb.username,
	password: Resource.KlinkPostgresDb.password,
	database: Resource.KlinkPostgresDb.database,
	ssl: false,
});

export const db = drizzle(pool, { schema });
