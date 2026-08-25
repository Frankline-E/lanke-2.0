import {
  pgTable,
  pgEnum,
  integer,
  serial,
  varchar,
  timestamp,
} from 'drizzle-orm/pg-core'

// Define the role enum
export const roleEnum = pgEnum('role_enum', ['user', 'admin', 'super-admin'])

export const users = pgTable('users', {
  id: serial('id').primaryKey(),
  // id: integer('id').primaryKey().generatedAlwaysAsIdentity(),
  name: varchar('name', { length: 255 }).notNull(),
  email: varchar('email', { length: 255 }).notNull().unique(),
  password: varchar('password', { length: 255 }).notNull(),
  // role: varchar('role', { length: 255 }).notNull().default('user'),
  roles: roleEnum('roles').array().notNull().default(['user']),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
})

export type User = typeof users.$inferSelect
export type NewUser = typeof users.$inferInsert
