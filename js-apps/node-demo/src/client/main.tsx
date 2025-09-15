/**
 * Vite entry point for the React app
 */

import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App";
import "./index.css";

const elem = document.getElementById("root")!;
const root = createRoot(elem);

root.render(
  <StrictMode>
    <App />
  </StrictMode>
);
