import { Server } from "tirne";
import type { Route } from "tirne";
const routes: Route[] = [
  {
    method: "GET",
    path: "/",
    handler: (req) => new Response("Hello from my framework!"),
  },
  {
    method: "GET",
    path: "/health",
    handler: (req) => new Response("OK"),
  }
];

const server = new Server(routes);

export default {
  fetch: (req: Request) => server.fetch(req),
};
