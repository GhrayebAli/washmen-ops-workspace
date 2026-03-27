# Washmen Ops Workspace

## Domain
Washmen is a laundry and dry-cleaning pickup/delivery service operating in the UAE. This workspace powers the internal ops dashboard used by operations staff to manage orders, customers, drivers, facilities, and claims.

Key concepts:
- **Order**: customer's laundry request with pickup/delivery slots, items, and status lifecycle
- **Customer**: end user who places orders (has addresses, cards, preferences)
- **Driver**: handles pickup and delivery, assigned by dispatchers
- **Facility / Laundry**: where garments are processed
- **Claim**: customer complaint about damaged or missing items
- **Credit**: store credit applied to customer accounts
- **Timeslot**: available pickup/delivery windows

## Repos

### ops-frontend (port 3000)
React frontend — the ops dashboard UI.

**Stack**: React 18, TypeScript, MUI v7 (Material UI), MUI X (DataGrid Pro, DatePickers, Charts), Redux Toolkit, Axios, React Router v6, SASS, Loadable Components. Package manager: yarn.

**Key patterns**:
- Feature modules in `src/features/` — each feature exports a module with its own routes (e.g., `features/orders/orders.module.tsx`)
- Features: orders, customers, drivers, payments, laundry, dashboard, claims, admin, live, settings
- Lazy loading via `@loadable/component` in `src/app/app.routes.tsx`
- API clients in `src/api/` — uses Axios instances (`INTERNAL_OPS_API` for port 1339, `OPS_API` for legacy)
- API files export async functions that return typed responses (e.g., `src/api/ordersAPI.ts`)
- Shared components in `src/components/`
- TypeScript interfaces in `src/interfaces/`
- Custom hooks in `src/hooks/`
- MUI theme in `src/theme/`
- Auth via Cognito in `src/auth/` — do not modify

**Adding a new page**:
1. Create feature module in `src/features/<name>/`
2. Export module component from `src/features/<name>/index.ts`
3. Add route in `src/app/app.routes.tsx` using `AsyncFeature`
4. Add API functions in `src/api/<name>.ts` using `INTERNAL_OPS_API`
5. Add TypeScript interfaces in `src/interfaces/<name>.interface.ts`

### internal-public-api (port 1339)
Sails.js backend — API gateway that the frontend calls. Proxies to internal microservices.

**Stack**: Sails.js v1, Node.js. Package manager: npm.

**Key patterns**:
- Controllers in `api/controllers/<domain>/` using Sails actions2 format (inputs/exits/fn)
- Routes defined in `config/routes.js` — RESTful: `'GET /customers/:customerId': 'CustomerController.get'`
- Business logic in helpers: `api/helpers/controllers/<domain>/`
- Calls microservices via `@washmen/sails-hook-*` packages (e.g., `sails.hooks.srvOrder.order.dashboard.list()`)
- All routes require `isAuthenticated` policy by default — defined in `config/policies.js`
- Custom responses in `api/responses/`

**Adding a new endpoint**:
1. Create controller in `api/controllers/<domain>/<action>.js` using actions2 format
2. Add route in `config/routes.js`
3. Add business logic in `api/helpers/controllers/<domain>/<action>.js` if complex
4. Policy is inherited (`isAuthenticated`) — do not create new policies

### srv-internal-user-backend (port 2339)
Sails.js backend — internal user data service. Owns DynamoDB data and PostgreSQL views.

**Stack**: Sails.js v1, Node.js, DynamoDB (via `@washmen/sails-dynamodb-wm-vogels`), PostgreSQL views (read-only). Package manager: npm.

**Key patterns**:
- Same Sails actions2 pattern as internal-public-api
- DynamoDB models in `api/models/dynamodb/`
- PostgreSQL view models in `api/models/postgres/` — these are read-only views, do not modify
- Controllers in `api/controllers/<domain>/`

## Request Flow
```
User → ops-frontend (React) → internal-public-api (Sails, port 1339) → srv-internal-user-backend (port 2339)
                                                                     → remote microservices via sails-hook-* packages
```

The frontend never calls srv-internal-user-backend directly. All requests go through internal-public-api.

## Remote Microservices (not editable from this workspace)
These are accessed via `@washmen/sails-hook-*` packages inside internal-public-api:
- billing, catalog, claims, customer, driver, facility, facility-ops, instruction, order, payment, promo

Do not attempt to modify the behavior of these services. You can only call their existing APIs through the hook packages.
