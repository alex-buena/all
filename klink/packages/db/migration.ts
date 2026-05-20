import { migrate } from "drizzle-orm/node-postgres/migrator";
import { db } from "./drizzle";

export const handler = async () => {
	await migrate(db, {
		migrationsFolder: "./migrations",
	});
};
