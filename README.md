# SRJ System — Backend

Backend API for the SRJ school-management admin dashboard. It handles students
and enrollment, tuition/payment processing, product & lunchbox sales, staff, and
reporting.

Built with **C# / .NET 8**, **PostgreSQL**, and **Entity Framework Core** (used
in a database-first style). Authentication is JWT-based and passwords are hashed
with Argon2.

## Tech stack

- .NET 8.0 / C# 12
- PostgreSQL 18
- EF Core 8 + Npgsql (scaffolded / database-first)
- JWT bearer authentication
- Argon2 password hashing (Isopoh)
- Swagger / Swashbuckle for API docs

## Prerequisites

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [PostgreSQL](https://www.postgresql.org/download/) 18 (with `psql` and
  `createdb` on your `PATH`)

## Installation & execution

```bash
# 1. Clone and restore dependencies
git clone <repo-url>
cd SRJBackend
dotnet restore

# 2. Create your local secrets file (see "Configuration" below)
cp .env.example .env
#    then edit .env and fill in your real values

# 3. Provision the database (see "Database" below)
createdb SRJdb
psql -d SRJdb -f database/srj_seed.sql

# 4. Build & run
dotnet run
```

The API listens on **http://localhost:4000**. In the `Development` environment,
interactive API docs are available at **http://localhost:4000/swagger**.

### Logging in

Authenticate against `POST /api/login`. The shipped seed database includes one
admin account:

| email             | password    |
|-------------------|-------------|
| `admin@srj.local` | `Admin123!` |

## Database

This project is **database-first**: the EF Core models in `Infrastructure/Models`
are scaffolded from the schema, and there are **no EF migrations**. That means the
schema itself lives in the seed dump — loading it is how you provision the database.

Everything DB-related lives in the [`database/`](database/) folder and is applied
with `psql`.

### Set up the database

```bash
createdb SRJdb
psql -d SRJdb -f database/srj_seed.sql
```

`database/srj_seed.sql` is a `pg_dump` of the **schema + anonymized sample data**
(students, enrollments, fees, lunches, payments, etc.), so you get a working
dataset to develop against immediately. All personal data has been scrubbed — see
the credentials note below.

### Maintenance scripts (optional)

- **`database/backfill_enrollment_debts.sql`** — generates any missing enrollment
  debts (admission, enrollment, monthly tuition) up to the current date. It is
  idempotent and safe to re-run:

  ```bash
  psql -d SRJdb -f database/backfill_enrollment_debts.sql
  ```

- **`database/anonymize.sql`** — the script used to scrub real personal data when
  producing the seed. Only relevant if you ever regenerate the seed from a real
  database; run it against a throwaway copy, **never** against production.

### Re-scaffolding the models

If you change the schema directly in PostgreSQL, regenerate the EF models with:

```bash
dotnet ef dbcontext scaffold "Name=ConnectionStrings:DefaultConnection" \
  Npgsql.EntityFrameworkCore.PostgreSQL \
  --output-dir Infrastructure/Models --force
```

Always use the `Name=` form so the connection string / password is read from
configuration at design time and never written into source.

## Automatic debt generation & the time simulator

Debts are generated automatically by the application:

- **On enrollment** — creating a student (first enrollment) generates the
  **admission** and **enrollment** debts; re-enrolling an existing student
  generates the **enrollment** debt only.
- **Monthly tuition** — a background scheduler generates the current month's
  **tuition** debt for every active enrollment in the current school year. It
  runs as a daily, idempotent tick (a no-op once that month's debts exist), so
  it self-heals after downtime. It is configured in `appsettings.json`:

  ```json
  "TuitionScheduler": { "Enabled": true, "IntervalHours": 24 }
  ```

Time is abstracted behind an `IClock`. The running API uses the real clock, so
you would normally have to wait for a real month boundary to see tuition
generated. To exercise the monthly logic on demand, a **virtual clock** console
lets you fast-forward through a school year and run generation at each step.

### Running the time simulator

The simulator lives in `tools/SRJBackend.TimeSimulator`. Make sure the database
is provisioned, then run it from the repo root:

```bash
dotnet run --project tools/SRJBackend.TimeSimulator
```

It starts an interactive prompt with a virtual clock set to today. You advance
the clock yourself and trigger generation:

```
Commands:
  now            show the current virtual date
  +1d [N]        advance the virtual clock by N days (default 1)
  +1m [N]        advance the virtual clock by N months (default 1)
  run            generate this month's tuition for active enrollments
  auto [N]       run + advance one month, repeated N times (default 1)
  help           show this help
  quit           exit
```

For example, `run` then `+1m` repeatedly (or `auto 10`) walks through the school
year and creates one tuition debt per active enrollment per month. Re-running at
the same date is idempotent, and non-academic months (Jan/Feb) generate nothing.

> The simulator writes to the **same database** the API uses. Point your `.env`
> at a development database when using it.

## Configuration & secrets

Secrets are **not** committed. The app reads them from a local `.env` file
(loaded via DotNetEnv in development) or from real environment variables in
production. `.NET` maps the double-underscore (`__`) in the key names to nested
configuration sections.

A committed [`.env.example`](.env.example) documents the required keys. Copy it
and fill in your own values:

```bash
cp .env.example .env
```

```dotenv
# .env  (gitignored — never commit this file)
ConnectionStrings__DefaultConnection=Host=localhost;Database=SRJdb;Username=postgres;Password=<your-password>
Jwt__Key=<your-jwt-signing-key-min-32-chars>
```

Non-secret settings (JWT issuer/audience/expiry, CORS origins, logging) live in
`appsettings.json`.

### Note on data & credentials

The seed database does **not** contain any real personal data or login
credentials. Student, staff, and family information was anonymized before
publishing, and the only login that works is the demo `admin@srj.local` account
listed above.

For your own setup, supply your own secrets: use a strong, unique PostgreSQL
password and a JWT signing key of at least 32 characters in your local `.env`.
