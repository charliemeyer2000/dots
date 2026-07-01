# Agent-neutral MCP server catalog — single source of truth shared across coding
# agents; home/agents.nix renders each entry into the target tool's dialect.
# Schema: stdio → { command; args; env?; }   remote → { type; url; headers?; }
# Remote servers use each CLI's OAuth login (no tokens here); exa reads
# EXA_API_KEY from the shell env.
{
  chrome-devtools = {
    command = "npx";
    args = ["chrome-devtools-mcp@latest" "--channel" "stable"];
  };
  exa = {
    command = "npx";
    args = ["-y" "exa-mcp-server"];
  };
  datadog = {
    type = "http";
    url = "https://mcp.us3.datadoghq.com/api/unstable/mcp-server/mcp";
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
  "linear" = {
    type = "http";
    url = "https://mcp.linear.app/mcp";
  };
}
