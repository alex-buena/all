import { SendMessageCommand, SQSClient } from "@aws-sdk/client-sqs";
import { clerkMiddleware, getAuth } from "@hono/clerk-auth";
import { db } from "@klink/db";
import { todo } from "@klink/db/schema";
import { eq } from "drizzle-orm";
import { Hono } from "hono";
import { handle, type LambdaContext, type LambdaEvent } from "hono/aws-lambda";
import { Resource } from "sst";
import { debugApp } from "./debug";

type Bindings = {
	event: LambdaEvent;
	lambdaContext: LambdaContext;
};

const app = new Hono<{ Bindings: Bindings }>();

app.use("*", clerkMiddleware());
app.get("/", (c) => {
	const auth = getAuth(c);

	if (!auth?.userId) {
		return c.json({
			message: `You are not logged in.${auth?.userId}`,
		});
	}

	return c.json({
		message: "You are logged in!",
		userId: auth.userId,
	});
});

app.get("/todo", async (c) => {
	try {
		const [insertedTodo] = await db
			.insert(todo)
			.values({
				title: "Test",
				description: "Test",
			})
			.returning();

		const todos = await db
			.select()
			.from(todo)
			.where(eq(todo.id, insertedTodo?.id!));
		return c.json({
			message: "Todo inserted",
			todos: todos,
		});
	} catch (error) {
		console.error(error);
		return c.json({
			message: "Error inserting todo",
			error: error,
		});
	}
});
app.get("/health", (c) => c.text("OK"));
app.get("/send-message", async (c) => {
	const client = new SQSClient({});
	const command = new SendMessageCommand({
		QueueUrl: Resource.KlinkQueue.url,
		MessageBody: "Hello, world!",
	});
	const result = await client.send(command);
	return c.json({
		message: "Message sent",
		result: result,
	});
});
app.route("/debug", debugApp);
export const handler = handle(app);
