# Web R/DataSHIELD (webds)

R in the browser with [webR](https://github.com/r-wasm/webr): console, editor tabs, file browser, plot and help viewers. DataSHIELD client packages (DSI, DSOpal) can be installed and connect to public Opal servers.

Live: https://www.obiba.org/webDS/

## Deployment notes

- **Cross-origin isolation**: webR needs `SharedArrayBuffer` for interrupt (Ctrl+C) and `readline()`, so pages must be served with `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`. The dev server sends them (`quasar.config.ts`). On static hosts that cannot (GitHub Pages), `public/coi-serviceworker.js` adds them; the page reloads once on first visit.
- **GitHub Pages**: `.github/workflows/pages.yml` builds and deploys on push to `master`. `PUBLIC_PATH` sets the base path (`/<repo>/`).
- **webR assets and packages** are loaded from the webR CDN (`webr.r-wasm.org`, `repo.r-wasm.org`).
- **HTTP from R** (curl/httr, used by opalr): webR tunnels TCP through a WebSocket relay run by r-universe (`ws.r-universe.dev`). TLS is end to end, but only servers reachable from the internet work. httr's connect timeout is raised to 60s (`src/stores/init.R`); the relay appears to cap connections at about 30s.
- **Fetch transport** (prototype, ~10x faster): `options(webds.fetch = "<opal host>")` sends httr requests to that host from the browser instead of through the relay. The Opal server must support the `X-Opal-Session` header and allow CORS from the page origin (opal branch `feat/session-header`); `dev/opal-cors-proxy.py` simulates that in front of an unpatched Opal.
- **Files** live in the in-memory webR file system and are lost on reload: download what you want to keep.

## Development

### Install the dependencies

```bash
npm install
```

### Start the app in development mode (HMR, error reporting, etc.)

```bash
npm run dev
```

### Build the app for production

```bash
npm run build
```
