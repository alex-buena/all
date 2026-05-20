import { readFileSync } from "node:fs";
import { join } from "node:path";
import { Hono } from "hono";
import type { LambdaContext, LambdaEvent } from "hono/aws-lambda";
import { HTTPException } from "hono/http-exception";

type Bindings = {
	event: LambdaEvent;
	lambdaContext: LambdaContext;
};

export const debugApp = new Hono<{ Bindings: Bindings }>();
const html = readFileSync(join(__dirname, "./debug_login/login.html"), "utf-8");

debugApp.use("*", async (_, next) => {
	if (process.env.NODE_ENV !== "development") {
		console.log("Debug endpoint is only available in development");
		throw new HTTPException(404);
	}
	return next();
});

debugApp.get("/", (c) => {
	return c.html(html);
});
