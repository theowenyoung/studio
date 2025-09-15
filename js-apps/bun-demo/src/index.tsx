import { serve, file } from "bun";
import { Pool } from "pg";

// 数据库连接配置
const pool = new Pool({
  host: process.env.POSTGRES_HOST || 'localhost',
  port: parseInt(process.env.POSTGRES_PORT || '5432'),
  database: process.env.POSTGRES_DB || 'test_demo_production',
  user: process.env.POSTGRES_USER || 'test_demo_user',
  password: process.env.TEST_DEMO_POSTGRES_PASSWORD || 'test-demo-secure-password-123',
  max: 10,
});

// 初始化数据库表
async function initDatabase() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS demo_records (
        id SERIAL PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        content TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log("📊 数据库表初始化成功");
  } catch (error) {
    console.error("❌ 数据库初始化失败:", error);
  }
}

// 启动时初始化数据库
initDatabase();

const server = serve({
  port: process.env.PORT || 3000,
  
  async fetch(req) {
    const url = new URL(req.url);
    
    // 健康检查
    if (url.pathname === "/health") {
      return new Response("OK", { status: 200 });
    }

    // 记录相关的 API
    if (url.pathname === "/api/records") {
      if (req.method === "GET") {
        try {
          const result = await pool.query(
            "SELECT * FROM demo_records ORDER BY created_at DESC"
          );
          return Response.json({
            success: true,
            data: result.rows
          });
        } catch (error) {
          return Response.json({
            success: false,
            error: error.message
          }, { status: 500 });
        }
      }
      
      if (req.method === "POST") {
        try {
          const body = await req.json();
          const { title, content } = body;
          
          if (!title) {
            return Response.json({
              success: false,
              error: "标题不能为空"
            }, { status: 400 });
          }
          
          const result = await pool.query(
            "INSERT INTO demo_records (title, content) VALUES ($1, $2) RETURNING *",
            [title, content || ""]
          );
          
          return Response.json({
            success: true,
            data: result.rows[0]
          });
        } catch (error) {
          return Response.json({
            success: false,
            error: error.message
          }, { status: 500 });
        }
      }
    }
    
    // 保留原有的测试 API
    if (url.pathname === "/api/hello") {
      if (req.method === "GET") {
        return Response.json({
          message: "Hello, world!",
          method: "GET",
        });
      }
    }
    
    if (url.pathname.startsWith("/api/hello/")) {
      const name = url.pathname.split("/")[3];
      return Response.json({
        message: `Hello, ${name}!`,
      });
    }
    
    // Handle static files (development and production)
    const staticExtensions = ['.tsx', '.ts', '.js', '.jsx', '.css', '.svg', '.png', '.jpg', '.gif'];
    const hasStaticExtension = staticExtensions.some(ext => url.pathname.endsWith(ext));
    
    if (hasStaticExtension) {
      try {
        let staticFile;
        if (process.env.NODE_ENV === "production") {
          staticFile = file(`./dist${url.pathname}`);
        } else {
          // In development, serve from src directory
          staticFile = file(`./src${url.pathname}`);
        }
        
        if (await staticFile.exists()) {
          // Set appropriate content type
          const headers = new Headers();
          if (url.pathname.endsWith('.css')) {
            headers.set('Content-Type', 'text/css');
          } else if (url.pathname.endsWith('.js') || url.pathname.endsWith('.tsx') || url.pathname.endsWith('.ts') || url.pathname.endsWith('.jsx')) {
            headers.set('Content-Type', 'application/javascript');
          } else if (url.pathname.endsWith('.svg')) {
            headers.set('Content-Type', 'image/svg+xml');
          }
          
          return new Response(staticFile, { headers });
        }
      } catch (error) {
        console.log(`Static file not found: ${url.pathname}`);
      }
    }
    
    // Static files from dist directory (production fallback)
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
