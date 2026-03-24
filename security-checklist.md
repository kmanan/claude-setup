# 🔒 Next.js Security Checklist — Lessons From Production

A practical security checklist built from real vulnerabilities found and fixed in production Next.js applications. Each item includes the **problem**, the **fix**, and **code you can copy**.

Not theoretical — every item here was a real bug that got shipped and had to be patched.

---

## 1. 🍪 Secure Your Auth Cookies

**The problem:** NextAuth's default cookie configuration doesn't set `httpOnly`, `secure`, or `sameSite` properly, leaving session tokens vulnerable to XSS theft and CSRF attacks.

**The fix:** Explicitly configure all three cookies with security flags:

```typescript
// lib/auth.ts
export const authOptions: NextAuthOptions = {
  // ... providers, callbacks ...
  cookies: {
    sessionToken: {
      name: `${process.env.NODE_ENV === 'production' ? '__Secure-' : ''}next-auth.session-token`,
      options: {
        httpOnly: true,    // JavaScript can't read this cookie (blocks XSS theft)
        sameSite: 'lax',   // Cookie only sent on same-site requests (blocks CSRF)
        path: '/',
        secure: process.env.NODE_ENV === 'production',  // HTTPS only in prod
      },
    },
    callbackUrl: {
      name: `${process.env.NODE_ENV === 'production' ? '__Secure-' : ''}next-auth.callback-url`,
      options: {
        httpOnly: true,
        sameSite: 'lax',
        path: '/',
        secure: process.env.NODE_ENV === 'production',
      },
    },
    csrfToken: {
      name: `${process.env.NODE_ENV === 'production' ? '__Host-' : ''}next-auth.csrf-token`,
      options: {
        httpOnly: true,
        sameSite: 'lax',
        path: '/',
        secure: process.env.NODE_ENV === 'production',
      },
    },
  },
  secret: process.env.NEXTAUTH_SECRET,
};
```

**Why these prefixes matter:**
- `__Secure-` — Browser enforces `secure` flag (HTTPS only), prevents cookie downgrade attacks
- `__Host-` — Strongest protection: must be HTTPS, must be from the exact host, must have `path=/`. Used for CSRF token because it's the most security-critical cookie

---

## 2. 🛡️ Type-Guard Your Subscription/Role Status

**The problem:** Subscription status stored in the database can be tampered with, corrupted, or return unexpected values. If you trust it blindly, users can escalate privileges.

**The fix:** A type guard function that validates status values and defaults to the lowest tier:

```typescript
// Whitelist of valid statuses — anything else falls back to 'free'
function isValidSubscriptionStatus(status: string): status is 'free' | 'pro' | 'trial_2day' | 'past_due' | 'canceled' {
  return ['free', 'pro', 'trial_2day', 'past_due', 'canceled'].includes(status);
}

// In your session callback:
session.user.subscriptionStatus = currentStatus && isValidSubscriptionStatus(currentStatus)
  ? currentStatus
  : 'free';  // deny-by-default: unknown status = lowest tier
```

**The key principle:** Deny by default. If anything is unexpected, the user gets the most restrictive access level, not the most permissive.

---

## 3. ✍️ Verify Webhook Signatures

**The problem:** Stripe (and other services) send webhooks to your endpoints. Without signature verification, anyone can POST fake events to your webhook URL and trigger payments, subscription changes, or data mutations.

**The fix:** Always verify the signature header before processing any event:

```typescript
// app/api/webhooks/stripe/route.ts
export async function POST(request: NextRequest) {
  const body = await request.text();  // Must use .text(), not .json()
  const signature = request.headers.get('stripe-signature');

  // Step 1: Reject unsigned requests immediately
  if (!signature) {
    return NextResponse.json({ error: 'Missing signature' }, { status: 400 });
  }

  // Step 2: Verify signature throws if invalid — catches tampering
  const event = await stripeService.constructWebhookEvent(body, signature);

  // Step 3: Only process events AFTER verification passes
  switch (event.type) {
    case 'checkout.session.completed':
      // Safe to process — signature verified this came from Stripe
      break;
  }

  return NextResponse.json({ received: true });
}
```

**Critical detail:** Use `request.text()` not `request.json()` for the body. Signature verification needs the raw body string. If you parse it as JSON first, the signature won't match.

---

## 4. 🔐 Check Auth + Ownership on Every API Route

**The problem:** Checking if a user is logged in isn't enough. You also need to verify they own the resource they're accessing. Without ownership checks, User A can access User B's data by guessing IDs.

**The fix:** Always query with both the resource ID AND the user's ID:

```typescript
// app/api/sessions/[sessionId]/teams/route.ts
export async function POST(request: Request, context: { params: { sessionId: string } }) {
  // Step 1: Verify authentication
  const session = await getServerSession(authOptions);
  if (!session?.user?.id) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  // Step 2: Validate input format
  const sessionId = parseInt(params.sessionId);
  if (isNaN(sessionId)) {
    return NextResponse.json({ error: 'Invalid session ID' }, { status: 400 });
  }

  // Step 3: Verify OWNERSHIP — query by BOTH session ID and user ID
  const sessionData = await db
    .select()
    .from(sessions)
    .where(and(
      eq(sessions.id, sessionId),
      eq(sessions.facilitatorId, parseInt(session.user.id))  // ← This is the key line
    ))
    .limit(1);

  if (sessionData.length === 0) {
    return NextResponse.json({ error: 'Session not found or unauthorized' }, { status: 404 });
  }

  // Now safe to proceed — user is authenticated AND owns this resource
}
```

**Pattern:** Auth check → Input validation → Ownership verification → Business logic. In that order, every time.

---

## 5. 🔢 Validate Dynamic Route Parameters

**The problem:** URL parameters come in as strings. If you pass them directly to database queries without parsing, you get type coercion bugs or injection vectors.

**The fix:** Parse and validate before any database query:

```typescript
// Parse the string parameter to a number
const sessionIdNum = parseInt(sessionId);

// Check if parsing actually produced a valid number
if (isNaN(sessionIdNum)) {
  return NextResponse.json(
    { error: 'Invalid session ID format' },
    { status: 400 }
  );
}

// Now safe to use in query — it's a validated integer
const teamData = await db
  .select()
  .from(teams)
  .where(and(
    eq(teams.teamId, params.teamId),
    eq(teams.sessionId, sessionIdNum)  // Both IDs checked — prevents cross-session access
  ));
```

**Why both IDs:** Querying by `teamId` alone could return a team from a different session. Always include the session/parent ID in the query to prevent cross-resource access.

---

## 6. 🌍 Validate Environment Variables at Startup

**The problem:** Missing environment variables cause cryptic runtime errors deep in your application. A missing `STRIPE_SECRET_KEY` might not crash until someone tries to check out — hours after deployment.

**The fix:** Validate all required vars at startup, fail fast with a clear message:

```typescript
// lib/config.ts
export function validateConfig() {
  if (process.env.NODE_ENV === 'production') {
    const requiredVars = [
      'DATABASE_URL',
      'NEXTAUTH_SECRET',
      'GOOGLE_CLIENT_ID',
      'GOOGLE_CLIENT_SECRET',
      'STRIPE_SECRET_KEY',
      'STRIPE_PUBLISHABLE_KEY',
      'DEEPSEEK_API_KEY'
    ];

    const missing = requiredVars.filter(varName => !process.env[varName]);

    if (missing.length > 0) {
      throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
    }
  }
  return true;
}
```

**Important:** Only enforce in production. In development, use placeholder values so the app can start without a full environment. But never let a production deploy succeed with missing secrets.

---

## 7. 📦 Patch Framework CVEs Immediately

**The problem:** Framework vulnerabilities (Next.js, React, etc.) get CVEs assigned and exploits published fast. Staying on `^15.0.0` when `15.5.9` patches a critical vulnerability is asking for trouble.

**The fix:** Pin minimum versions and update promptly:

```json
{
  "dependencies": {
    "next": "^15.0.5",
    "react": "^19.0.1",
    "react-dom": "^19.0.1",
    "lucide-react": "^0.468.0"
  }
}
```

**Practical process:**
1. `npm audit` regularly (or set up GitHub Dependabot / Snyk)
2. When a CVE drops, check if you're affected: `npm ls <package>`
3. Update the minimum version in `package.json`
4. `npm install` and test
5. Commit with the CVE number: `"Security: Patch CVE-2025-66478 - Update Next.js to 15.5.9"`

---

## 8. 🚫 Use an ORM With Parameterized Queries

**The problem:** Raw SQL with string concatenation = SQL injection. This is the most basic security rule and still the most commonly broken.

**The fix:** Use an ORM (Drizzle, Prisma, etc.) that parameterizes queries automatically:

```typescript
// ✅ Safe — Drizzle parameterizes this automatically
const user = await db
  .select()
  .from(users)
  .where(eq(users.email, customerEmail))
  .limit(1);

// ❌ Dangerous — string interpolation in SQL
const user = await db.execute(
  `SELECT * FROM users WHERE email = '${customerEmail}'`  // SQL injection!
);
```

If you must use raw SQL, use parameterized queries:

```typescript
// ✅ Safe — parameterized
const user = await db.execute(
  sql`SELECT * FROM users WHERE email = ${customerEmail}`
);
```

---

## 9. 🔄 Always Fetch Fresh Auth State From Database

**The problem:** JWT tokens cache user data (subscription status, roles, etc.) at sign-in time. If a user's subscription expires or gets revoked, their cached JWT still says "pro" until the token expires.

**The fix:** Re-fetch from database on every session callback:

```typescript
async session({ session, token }) {
  // ALWAYS fetch fresh user data — never trust the cached token
  const dbUser = await db
    .select()
    .from(users)
    .where(eq(users.googleId, token.googleId as string))
    .limit(1);

  if (dbUser.length > 0) {
    // Check time-limited access expiration
    let currentStatus = dbUser[0].subscriptionStatus;
    if (dbUser[0].trialAccessEnd && currentStatus === 'trial_2day') {
      if (new Date() >= new Date(dbUser[0].trialAccessEnd)) {
        await db.update(users)
          .set({ subscriptionStatus: 'free' })
          .where(eq(users.id, dbUser[0].id));
        currentStatus = 'free';
      }
    }

    session.user.subscriptionStatus = isValidSubscriptionStatus(currentStatus)
      ? currentStatus
      : 'free';
  }
  return session;
}
```

**The trade-off:** This adds a DB query per session check. Worth it for subscription gating. For truly high-traffic apps, cache the status in Redis with a short TTL instead of skipping the check entirely.

---

## 🧠 The Mental Model

Every API endpoint should follow this order:

```
1. 🔐 Authentication    — Is the user logged in?
2. ✅ Input validation   — Are the inputs well-formed?
3. 👤 Authorization      — Does this user own this resource?
4. 💼 Business logic     — Actually do the thing
5. 📦 Response           — Return only what the client needs
```

Skip any step and you have a vulnerability. Every time.

---

## 📄 License

MIT — use this however you want. Built from real production incidents at [Kryton Labs](https://krytonlabs.com).
