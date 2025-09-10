# Copilot Instructions for ButtonNotifier Plugin

## Repository Overview

This repository contains the **ButtonNotifier** SourceMod plugin, which monitors and logs button presses and trigger activations in Source engine games. The plugin notifies administrators when players interact with buttons and triggers, with configurable spam protection and user preferences for notification display (console vs chat).

### Key Features
- Real-time monitoring of `func_button` and trigger entities (`trigger_once`, `trigger_multiple`, `trigger_teleport`)
- Admin-only notifications with spam protection
- User-configurable preferences (console/chat display) stored via client cookies
- Integration with EntWatch plugin (optional dependency)
- Colored chat messages using MultiColors library

## Technical Environment

### Language & Platform
- **Language**: SourcePawn (.sp files)
- **Platform**: SourceMod 1.11+ (minimum version specified in sourceknight.yaml)
- **Compiler**: SourcePawn compiler (spcomp) via SourceKnight build system
- **Target**: Source engine game servers (CS:GO, CS2, etc.)

### Build System
- **Primary Tool**: SourceKnight - automated build and dependency management
- **Configuration**: `sourceknight.yaml` in repository root
- **Build Command**: Uses GitHub Actions with `maxime1907/action-sourceknight@v1`
- **Output**: Compiled `.smx` files in `/addons/sourcemod/plugins/`

### Dependencies
1. **SourceMod** (1.11.0-git6917+): Core scripting platform
2. **SDK Tools**: Game-specific functions (included with SourceMod)
3. **CS:GO/CS2**: Counter-Strike specific functions (included with SourceMod)
4. **Client Preferences**: Cookie system for user settings (included with SourceMod)
5. **MultiColors**: Colored chat message library (from srcdslab/sm-plugin-MultiColors)
6. **EntWatch** (optional): Special item detection (from srcdslab/sm-plugin-EntWatch)

## File Structure

```
/addons/sourcemod/scripting/
├── ButtonNotifier.sp          # Main plugin source code
└── include/                   # Include files (from dependencies)
    ├── multicolors.inc        # Color formatting functions
    └── EntWatch.inc           # EntWatch integration (optional)

/.github/
├── workflows/ci.yml           # GitHub Actions CI/CD pipeline
└── dependabot.yml            # Automated dependency updates

/sourceknight.yaml            # Build configuration and dependencies
/.gitignore                   # Git ignore patterns (excludes .smx, build artifacts)
```

## Code Style & Standards

### SourcePawn Conventions
- **Indentation**: 4-space tabs (use tabs, not spaces)
- **Variables**: 
  - Local variables and parameters: `camelCase`
  - Global variables: `PascalCase` with `g_` prefix
  - Functions: `PascalCase`
- **Required pragmas**:
  ```sourcepawn
  #pragma semicolon 1
  #pragma newdecls required
  ```

### Naming Patterns in This Codebase
- ConVars: `g_c` prefix (e.g., `g_cBlockSpam`)
- Handles: `g_h` prefix (e.g., `g_hPreferences`)
- Integer arrays: `g_i` prefix (e.g., `g_iButtonsDisplay`)
- Boolean arrays: `g_b` prefix (e.g., `g_bTriggered`)

### Required Includes & Pragmas
```sourcepawn
#pragma semicolon 1                    // Require semicolons
#include <sourcemod>                   // Core SourceMod functionality
#include <sdktools>                    // SDK tools for entity manipulation
#include <cstrike>                     // Counter-Strike specific functions
#include <clientprefs>                 // Client cookie system
#include <multicolors>                 // Colored chat messages
#undef REQUIRE_PLUGIN                  // Allow optional plugins
#tryinclude <EntWatch>                 // Optional EntWatch integration
#define REQUIRE_PLUGIN                 // Re-enable plugin requirements
#pragma newdecls required             // Use new declaration syntax
```

### Memory Management
- Use `delete` for cleanup without null checks (SourceMod handles null gracefully)
- Avoid `.Clear()` on StringMap/ArrayList - use `delete` and recreate instead
- Always set handles to `INVALID_HANDLE` or `null` after deletion

## Development Guidelines

### Plugin Info Block
```sourcepawn
public Plugin myinfo =
{
    name = "Button & Triggers Notifier",
    author = "Silence, maxime1907, .Rushaway",
    description = "Logs button and trigger presses to the chat.",
    version = "2.1.1",  // Update this when making changes
    url = ""
};
```

### Plugin Structure
- **OnPluginStart()**: Initialize ConVars, cookies, hooks, handle late loading
- **OnMapStart()**: Set up entity hooks via timer
- **OnMapEnd()**: Clean up entity output hooks
- **Event handlers**: Reset state on round start

### Entity Interaction
- Hook entity outputs using `HookEntityOutput()` for buttons and triggers
- Use timer-delayed hooking to ensure entities are fully loaded
- Check entity validity with `IsValidEntity()` before processing

### Client Management
- Always validate clients with `IsValidClient()` helper function
- Handle late loading scenarios for client cookies
- Respect client preferences stored in cookies

### Admin Notifications
- Check admin permissions: `GetAdminFlag(GetUserAdmin(i), Admin_Generic)`
- Include SourceTV in admin checks: `IsClientSourceTV(i)`
- Provide dual output: console and chat based on user preference

## Build & Testing Process

### Local Development
1. **Install SourceKnight**: Follow installation from their repository
2. **Build plugin**: Run build command from repository root
3. **Dependencies**: Automatically downloaded and configured via sourceknight.yaml

### CI/CD Pipeline
- **Trigger**: Push, PR, or manual dispatch
- **Build**: Ubuntu 24.04 with SourceKnight action
- **Artifacts**: Packaged plugin files uploaded as build artifacts
- **Release**: Automatic tagging and release creation for main branch

### Testing Checklist
- [ ] Plugin compiles without errors or warnings
- [ ] No memory leaks (check with SourceMod profiler)
- [ ] Button press notifications work correctly
- [ ] Trigger activation notifications work correctly
- [ ] Spam protection functions as expected
- [ ] Client preferences save and load properly
- [ ] Admin permissions are respected
- [ ] Optional EntWatch integration works when available

## Common Development Tasks

### Adding New Entity Types
1. Add `HookEntityOutput()` call in `Timer_HookButtons()`
2. Add corresponding `UnhookEntityOutput()` call in `OnMapEnd()`
3. Create or modify event handler function
4. Test on map with the new entity type

### Modifying Notification Format
- Update format strings in `ButtonPressed()` and `TriggerTouched()` functions
- Maintain consistency between console and chat outputs
- Use MultiColors formatting for chat messages: `{color}text{/color}`

### Adding Configuration Options
1. Create ConVar in `OnPluginStart()`
2. Add to `AutoExecConfig()` call
3. Use ConVar values in relevant functions
4. Update plugin version if significant change

### Client Preference System
- Preferences stored as concatenated string in cookies
- Read in `ReadClientCookies()`, written in `SetClientCookies()`
- Menu system in `NotifierSetting()` and `NotifierSettingHandler()`

## Integration Points

### EntWatch Plugin
- Optional dependency using `#tryinclude <EntWatch>`
- Check `EntWatch_IsSpecialItem()` to avoid duplicate notifications
- Gracefully handle when EntWatch is not loaded

### MultiColors Library
- Required for colored chat messages
- Use `CPrintToChat()` instead of `PrintToChat()`
- Color codes: `{red}`, `{lightgreen}`, `{blue}`, `{white}`, `{grey}`

## Performance Considerations

### Entity Management
- Hook/unhook entity outputs properly to prevent memory leaks
- Use entity IDs as array indices where possible for O(1) lookups
- Reset trigger state arrays efficiently in `Event_RoundStart()`

### Client Iteration
- Cache admin status checks where possible
- Minimize string operations in frequently called functions
- Use efficient client validation patterns

### Spam Protection
- Time-based tracking with minimal overhead
- Array-based storage for per-client state
- Configurable delay periods via ConVars

## Debugging & Troubleshooting

### Common Issues
- **Entity hooks not working**: Ensure timer delay in `OnMapStart()`
- **Missing notifications**: Check admin permissions and client validation
- **Memory leaks**: Verify proper cleanup in `OnMapEnd()`
- **Build failures**: Check SourceMod version compatibility

### Logging
- Server console logging for all events
- Use `PrintToServer()` for permanent log records
- Debug with `LogMessage()` when troubleshooting

### Dependencies
- All dependencies automatically managed by SourceKnight
- Check `sourceknight.yaml` for version specifications
- Update dependency versions in YAML if compatibility issues arise

## Version Management

- Follow semantic versioning: `MAJOR.MINOR.PATCH`
- Update version in plugin info block when making changes
- Automated tagging and releases via GitHub Actions
- Archive previous versions as GitHub releases