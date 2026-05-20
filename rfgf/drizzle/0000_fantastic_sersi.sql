CREATE TABLE `app_kv` (
	`key` text PRIMARY KEY NOT NULL,
	`value` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `flag_library_items` (
	`id` text PRIMARY KEY NOT NULL,
	`text` text NOT NULL,
	`normalized_text` text NOT NULL,
	`source_type` text NOT NULL,
	`is_active` integer DEFAULT true NOT NULL,
	`created_by_player_id` text,
	`created_at` integer NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `ux_flag_library_normalized_text` ON `flag_library_items` (`normalized_text`);--> statement-breakpoint
CREATE INDEX `idx_flag_library_active` ON `flag_library_items` (`is_active`,`source_type`);--> statement-breakpoint
CREATE TABLE `flag_stats` (
	`flag_id` text PRIMARY KEY NOT NULL,
	`draw_count` integer DEFAULT 0 NOT NULL,
	`keep_count` integer DEFAULT 0 NOT NULL,
	`dump_count` integer DEFAULT 0 NOT NULL,
	`last_seen_at` integer,
	FOREIGN KEY (`flag_id`) REFERENCES `flag_library_items`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE TABLE `profile_flags` (
	`id` text PRIMARY KEY NOT NULL,
	`session_id` text NOT NULL,
	`player_id` text NOT NULL,
	`profile_id` text NOT NULL,
	`flag_id` text,
	`flag_text_snapshot` text NOT NULL,
	`drawn_turn_no` integer NOT NULL,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`session_id`) REFERENCES `sessions`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`player_id`) REFERENCES `session_players`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`profile_id`) REFERENCES `profiles`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`flag_id`) REFERENCES `flag_library_items`(`id`) ON UPDATE no action ON DELETE set null
);
--> statement-breakpoint
CREATE INDEX `idx_profile_flags_profile_turn` ON `profile_flags` (`profile_id`,`drawn_turn_no`);--> statement-breakpoint
CREATE TABLE `profiles` (
	`id` text PRIMARY KEY NOT NULL,
	`session_id` text NOT NULL,
	`player_id` text NOT NULL,
	`status` text DEFAULT 'active' NOT NULL,
	`started_turn_no` integer NOT NULL,
	`ended_turn_no` integer,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`session_id`) REFERENCES `sessions`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`player_id`) REFERENCES `session_players`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `idx_profiles_session_player` ON `profiles` (`session_id`,`player_id`);--> statement-breakpoint
CREATE UNIQUE INDEX `ux_profiles_one_active_per_player` ON `profiles` (`player_id`) WHERE "profiles"."status" = 'active';--> statement-breakpoint
CREATE TABLE `session_events` (
	`id` text PRIMARY KEY NOT NULL,
	`session_id` text NOT NULL,
	`turn_no` integer NOT NULL,
	`player_id` text,
	`event_type` text NOT NULL,
	`event_payload` text,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`session_id`) REFERENCES `sessions`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`player_id`) REFERENCES `session_players`(`id`) ON UPDATE no action ON DELETE set null
);
--> statement-breakpoint
CREATE INDEX `idx_session_events_session_turn` ON `session_events` (`session_id`,`turn_no`);--> statement-breakpoint
CREATE TABLE `session_players` (
	`id` text PRIMARY KEY NOT NULL,
	`session_id` text NOT NULL,
	`name` text NOT NULL,
	`seat_index` integer NOT NULL,
	`current_profile_id` text,
	`current_streak` integer DEFAULT 0 NOT NULL,
	`longest_streak` integer DEFAULT 0 NOT NULL,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`session_id`) REFERENCES `sessions`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE UNIQUE INDEX `ux_session_players_session_seat` ON `session_players` (`session_id`,`seat_index`);--> statement-breakpoint
CREATE INDEX `idx_session_players_session` ON `session_players` (`session_id`);--> statement-breakpoint
CREATE INDEX `idx_session_players_current_profile` ON `session_players` (`current_profile_id`);--> statement-breakpoint
CREATE TABLE `sessions` (
	`id` text PRIMARY KEY NOT NULL,
	`status` text DEFAULT 'active' NOT NULL,
	`turn_no` integer DEFAULT 1 NOT NULL,
	`active_player_index` integer DEFAULT 0 NOT NULL,
	`started_at` integer NOT NULL,
	`ended_at` integer,
	`created_at` integer NOT NULL
);
--> statement-breakpoint
CREATE INDEX `idx_sessions_status` ON `sessions` (`status`);--> statement-breakpoint
CREATE TABLE `turn_decisions` (
	`id` text PRIMARY KEY NOT NULL,
	`turn_id` text NOT NULL,
	`decision` text NOT NULL,
	`streak_before` integer NOT NULL,
	`streak_after` integer NOT NULL,
	`next_profile_id` text,
	`decided_at` integer NOT NULL,
	FOREIGN KEY (`turn_id`) REFERENCES `turns`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`next_profile_id`) REFERENCES `profiles`(`id`) ON UPDATE no action ON DELETE set null
);
--> statement-breakpoint
CREATE UNIQUE INDEX `ux_turn_decisions_turn_id` ON `turn_decisions` (`turn_id`);--> statement-breakpoint
CREATE INDEX `idx_turn_decisions_decision` ON `turn_decisions` (`decision`);--> statement-breakpoint
CREATE TABLE `turns` (
	`id` text PRIMARY KEY NOT NULL,
	`session_id` text NOT NULL,
	`turn_no` integer NOT NULL,
	`actor_player_id` text NOT NULL,
	`profile_id` text NOT NULL,
	`drawn_profile_flag_id` text,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`session_id`) REFERENCES `sessions`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`actor_player_id`) REFERENCES `session_players`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`profile_id`) REFERENCES `profiles`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`drawn_profile_flag_id`) REFERENCES `profile_flags`(`id`) ON UPDATE no action ON DELETE set null
);
--> statement-breakpoint
CREATE UNIQUE INDEX `ux_turns_session_turn` ON `turns` (`session_id`,`turn_no`);--> statement-breakpoint
CREATE INDEX `idx_turns_session_actor` ON `turns` (`session_id`,`actor_player_id`);