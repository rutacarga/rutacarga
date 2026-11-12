/* Preview-only Supabase configuration for feature/roadmap-inteligencia-etapas.
   This file is intentionally branch-scoped. Never merge it into production. */
(() => {
  const host = window.location.hostname;
  if (!host.endsWith(".vercel.app")) {
    throw new Error("RUTA CARGA staging configuration is restricted to Vercel preview deployments.");
  }
  window.RUTA_CARGA_SUPABASE_CONFIG = Object.freeze({
    url: "https://euyrjjaiaskwoplvlbun.supabase.co",
    key: "sb_publishable_jwgpXUKKHr4Yqkhfux76EA_khbEionM"
  });
})();
