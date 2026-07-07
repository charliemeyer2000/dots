# Agent-neutral MCP server catalog — single source of truth shared across coding
# agents; home/agents.nix renders each entry into the target tool's dialect.
# Host-scoped servers live elsewhere: mcp-servers-personal.nix (darwin-personal +
# darwin-agent) and inline catalog extensions in hosts/*/default.nix (darwin-cog).
# Schema: stdio → { command; args; env?; }   remote → { type; url; headers?; }
# Remote servers use each CLI's OAuth login (no tokens here); exa reads
# EXA_API_KEY from the shell env.
# No browser MCP: browser control is the agent-browser CLI (via its skill), not a
# chrome MCP, so its tool schemas stay out of every session's baseline context.
{
  exa = {
    command = "npx";
    args = ["-y" "exa-mcp-server"];
  };
  datadog = {
    type = "http";
    url = "https://mcp.us3.datadoghq.com/api/unstable/mcp-server/mcp";
  };
  "linear" = {
    type = "http";
    url = "https://mcp.linear.app/mcp";
  };
}
