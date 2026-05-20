import { defineConfig } from "drizzle-kit";
import { Resource } from "sst";

console.log(
	Resource.KlinkPostgresDb.host,
	Resource.KlinkPostgresDb.port,
	Resource.KlinkPostgresDb.username,
	Resource.KlinkPostgresDb.password,
	Resource.KlinkPostgresDb.database,
);
export default defineConfig({
	dialect: "postgresql",
	// Pick up all our schema files
	schema: ["packages/db/schema/**/*.sql.ts"],
	out: "./migrations",
	dbCredentials: {
		host: Resource.KlinkPostgresDb.host,
		port: Resource.KlinkPostgresDb.port,
		user: Resource.KlinkPostgresDb.username,
		password: Resource.KlinkPostgresDb.password,
		database: Resource.KlinkPostgresDb.database,
		ssl: false,
	},
});
