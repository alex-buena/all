/// <reference path="./.sst/platform/config.d.ts" />

export default $config({
	app(input) {
		return {
			providers: {
				aws: {
					profile: "free-klink-sst",
					region: "eu-central-1",
				},
			},
			name: "klink",
			removal: input?.stage === "production" ? "retain" : "remove",
			protect: ["production"].includes(input?.stage),
			home: "aws",
		};
	},

	async run() {
		await import("./infra/network");
		await import("./infra/api");
		const { rds } = await import("./infra/db");
		await import("./infra/queue");
		await import("./infra/migrate");

		new sst.x.DevCommand("DrizzleStudio", {
			link: [rds],
			dev: {
				command: "drizzle-kit studio",
			},
		});
	},
});
