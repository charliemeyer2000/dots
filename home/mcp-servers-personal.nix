# Personal-project MCP servers — merged into the catalog by darwin-personal and
# darwin-agent only (kept off the work machine and headless hosts).
{
  # Dueflow's MCP gateway (Executor): every company service behind one OAuth'd
  # server — see the dueflow-gateway skill for the execute/search workflow.
  dueflow = {
    type = "http";
    url = "https://mcp.dueflow.co/mcp";
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
