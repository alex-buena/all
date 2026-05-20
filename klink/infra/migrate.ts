import { rds } from "./db";
import { vpc } from "./network";

const migration = new sst.aws.Function("DBMigrations", {
	vpc,
	link: [rds],
	copyFiles: [
		{
			from: "migrations",
			to: "./migrations",
		},
	],
	handler: "packages/db/migration.handler",
});

if (!$dev) {
	new aws.lambda.Invocation("DBMigrations", {
		input: Date.now().toString(),
		functionName: migration.name,
	});
}
