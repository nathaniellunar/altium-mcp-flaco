# Architecture

## Components

1. **MCP host (Node.js, TypeScript)**  
   Implements MCP over **stdio** for Cursor and other clients. Registers tools,
   validates configuration, serializes bridge requests.

2. **Workspace directory** (default `%USERPROFILE%\.altium-mcp\workspace`)  
   Contains `request.json`, `response.json`, and a synced copy of `AltiumScript/`
   (DelphiScript project `Altium_API.PrjScr` and units).

3. **Altium Designer**  
   Launched with  
   `-RScriptingSystem:RunScript(ProjectName="...Altium_API.PrjScr"|ProcName="Altium_API>Run")`  
   so the `Run` procedure reads the request, executes PCB/SCH logic, and writes
   the response.

4. **Bridge lock**  
   File `.bridge.lock` under the workspace prevents concurrent script runs from
   corrupting request/response files.

## Protocol

- Request body: see [schemas/bridge-request.schema.json](../schemas/bridge-request.schema.json).  
  The DelphiScript parser expects a `"command"` field (plus parameters);  
  `protocolVersion` is included for forward compatibility.

- Response body: [schemas/bridge-response.schema.json](../schemas/bridge-response.schema.json).

## Third-party DelphiScript

Scripts under `altium-scripts/` are derived from the MIT-licensed
[coffeenmusic/altium-mcp](https://github.com/coffeenmusic/altium-mcp) with a
small addition for the `ping` command. See [NOTICE](../NOTICE).

## Version matrix

Manual testing is required per **Altium Designer** major release (API drift).
Target: **AD22+** on **Windows 10/11**.
