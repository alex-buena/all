import { vpc } from "./network";

if (
	process.env.NODE_ENV === "development" &&
	!(
		process.env.POSTGRES_HOST &&
		process.env.POSTGRES_PORT &&
		process.env.POSTGRES_USER &&
		process.env.POSTGRES_PASSWORD &&
		process.env.POSTGRES_DB
	)
) {
	throw new Error(
		"POSTGRES_HOST, POSTGRES_PORT, POSTGRES_USER, POSTGRES_PASSWORD, and POSTGRES_DB must be set",
	);
}

export const rds = new sst.aws.Postgres("KlinkPostgresDb", {
	vpc,
	dev: {
		host: process.env.POSTGRES_HOST,
		port: process.env.POSTGRES_PORT
			? parseInt(process.env.POSTGRES_PORT, 10)
			: undefined,
		username: process.env.POSTGRES_USER,
		password: process.env.POSTGRES_PASSWORD,
		database: process.env.POSTGRES_DB,
	},
});
