# Personal-project MCP servers — merged into the catalog by darwin-personal and
# darwin-agent only (kept off the work machine); devin-cloud picks just `life`.
# `life` is the Executor edge on the tailnet (life-infra): Caddy forces /mcp into
# browser approval, so a tool call that needs Charlie pauses on the console. One
# Executor API key per client, never in this repo — both CLIs expand `${VAR}` in
# `headers` at connect time. Macs get LIFE_MCP_API_KEY into ~/.env.local via
# `dots.onePassword.extraEnv` (modules/secrets.nix); Devin VMs get it as an org secret.
{
  life = {
    type = "http";
    url = "https://life.tail0eb43d.ts.net/mcp";
    headers."x-api-key" = "\${LIFE_MCP_API_KEY}";
  };
  posthog = {
    type = "http";
    url = "https://mcp.posthog.com/mcp";
  };
  Sanity = {
    type = "http";
    url = "https://mcp.sanity.io";
  };
  whop-docs = {
    type = "http";
    url = "https://docs.whop.com/mcp";
  };
}
