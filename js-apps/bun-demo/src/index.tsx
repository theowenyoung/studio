import { serve, file } from "bun"

const server = serve({
  port: process.env.PORT || 3000,
  
  async fetch(req) {
    const url = new URL(req.url);
    
    // API routes
    if (url.pathname === "/health") {
      return new Response("OK", { status: 200 });
    }
    
    if (url.pathname === "/api/hello") {
      if (req.method === "GET") {
        return Response.json({
          message: "Hello, world!",
          method: "GET",
        });
      }
      if (req.method === "PUT") {
        return Response.json({
          message: "Hello, world!",
          method: "PUT",
        });
      }
    }
    
    if (url.pathname.startsWith("/api/hello/")) {
      const name = url.pathname.split("/")[3];
      return Response.json({
        message: `Hello, ${name}!`,
      });
    }
    
    // Static files from dist directory
    if (process.env.NODE_ENV === "production") {
      try {
        const filePath = url.pathname === "/" ? "/index.html" : url.pathname;
        const staticFile = file(`./dist${filePath}`);
        if (await staticFile.exists()) {
          return new Response(staticFile);
        }
      } catch (error) {
        console.log(`Static file not found: ${url.pathname}`);
      }
    }
    
    // Fallback to index.html for SPA routing
    const indexFile = process.env.NODE_ENV === "production" 
      ? file("./dist/index.html")
      : file("./src/index.html");
    
    return new Response(indexFile, {
      headers: {
        "Content-Type": "text/html",
      },
    });
  },

  development: process.env.NODE_ENV !== "production" && {
    // Enable browser hot reloading in development
    hmr: true,

    // Echo console logs from the browser to the server
    console: true,
  },
});

console.log(`🚀 Server running at ${server.url}`);
