import { rds } from "./db";
import { vpc } from "./network";
import { queue } from "./queue";

if (!process.env.CLERK_PUBLISHABLE_KEY || !process.env.CLERK_SECRET_KEY) {
	throw new Error("Clerk Keys are not set");
}

new sst.aws.Function("KlinkApi", {
	vpc,
	url: true,
	link: [rds, queue],
	environment: {
		CLERK_PUBLISHABLE_KEY: process.env.CLERK_PUBLISHABLE_KEY,
		CLERK_SECRET_KEY: process.env.CLERK_SECRET_KEY,
		NODE_ENV: process.env.NODE_ENV || "development",
	},
	memory: "512 MB",
	copyFiles: [
		{
			from: "packages/functions/src/debug_login/login.html",
			to: "./debug_login/login.html",
		},
	],
	handler: "packages/functions/src/api.handler",
});
