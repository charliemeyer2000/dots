# Personal-project MCP servers — merged into the catalog by darwin-personal and
# darwin-agent only (kept off the work machine); devin-cloud picks just `life`.
# `life` is the Executor edge on the tailnet (life-infra): Caddy forces /mcp into
# browser approval, so a tool call that needs Charlie pauses on the console. Its
# definition is read from the `life` plugin's .mcp.json (config/agents/plugins/life)
# so the plugin and the catalog can't drift. One Executor API key per client, never
# in this repo — both CLIs expand `${VAR}` in `headers` at connect time. Macs get
# LIFE_MCP_API_KEY into ~/.env.local via `dots.onePassword.extraEnv`
# (modules/secrets.nix); Devin VMs get it as an org secret.
{
  life = (builtins.fromJSON (builtins.readFile ../config/agents/plugins/life/.mcp.json)).mcpServers.life;
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
  # iOS Simulator tools for Dueflow's Expo app: build/run, AX tree, tap/type,
  # screenshots (Sentry's ex-XcodeBuildMCP), and Maestro for E2E flows.
  MobileBuildMCP = {
    command = "npx";
    args = ["-y" "mobilebuildmcp@2.7.1" "mcp"];
    env.MOBILEBUILDMCP_ENABLED_WORKFLOWS = "simulator,ui-automation,debugging";
  };
  maestro = {
    command = "maestro";
    args = ["mcp"];
  };
}
