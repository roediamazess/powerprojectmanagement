
## Modal button order
- In modal footers, primary action button (Create/Update/Delete) goes on the left.
- Cancel/Close goes on the right (rightmost).
- Keep both buttons grouped on the right side of the footer.

## Skill routing
- For every request in this repo, invoke the `skills-project-router` skill first and follow it as the primary router for planning/changes, unless the user explicitly asks not to use it.

## Deployment & assets (VPS Docker)
- Treat production as Docker-first: changes are considered "applied" only after they are running inside the VPS Docker containers.
- For any UI change (Inertia/React/Vite), ensure production containers get the new build:
  - Rebuild + restart using `docker compose -f docker-compose.prod.yml up -d --build` (or run `scripts/deploy_docker.sh` if available/appropriate).
  - If assets appear unchanged, rebuild without cache and clean the `public_build` volume, then restart.
- After deploy, validate from inside the running `app` container that the expected `public/build/*` output exists (e.g., search the built `Jobsheet-*.js` for the updated markup/text).
