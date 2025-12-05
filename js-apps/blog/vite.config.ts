import { vitePlugin as remix } from "@remix-run/dev";
import { installGlobals } from "@remix-run/node";
import { defineConfig } from "vite";
import tsconfigPaths from "vite-tsconfig-paths";

installGlobals();

export default defineConfig({
  plugins: [
    remix({
      // 移除 Vercel preset，使用标准构建
      ssr: false, // 禁用 SSR，生成纯静态站点
    }),
    tsconfigPaths(),
  ],
  build: {
    outDir: "build/client", // 输出目录
  },
});
