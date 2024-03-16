# OCP-HAProxy Flake for Nix

This flake offers various versions of HAProxy, built in the style of OpenShift Ingress. It's designed to be imported into other Nix configurations and provides support for multiple HAProxy versions, each with standard and debug builds.

## Key Features

- **Multiple HAProxy Versions**: Supports various versions of HAProxy, each identified by a unique hash and optional patches.
- **Standard and Debug Builds**: For each HAProxy version, there are two builds - a standard build (`buildHAProxy`) and a debug build (`buildHAProxyDebug`).
- **Flexibility for Different Systems**: Builds are available for multiple systems, specifically `aarch64-linux` and `x86_64-linux`.
- **Default Package and DevShell Support**: Includes a default package configuration for ease of use and a development shell environment for development and testing.

## Flake Configuration

- **Inputs**: Uses Nixpkgs from the `nixos-unstable` branch.
- **Outputs**: Defines packages, overlays, a default package for each supported system, and development shells.

## Packages Definition (`packages.nix`)

- Specifies multiple versions of HAProxy, each with its own hash and optional patches.
- For each version, it generates two Nix attributes: one for the standard build and another for the debug build.
- Uses a custom builder (`package.nix`) to define the build process for HAProxy.

## Usage in Nix Configurations

To use this flake in another Nix configuration, add it as an input to your `flake.nix` and reference the packages or overlays as needed.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    ocp-haproxy.url = "github:frobware/openshift-dev?dir=haproxy";
  };

  outputs = { self, nixpkgs, ocp-haproxy, ... }: {
    nixosConfigurations.my-nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          # Use the default HAProxy package from the flake.
          environment.systemPackages = with pkgs; [
            ocp-haproxy.defaultPackage.x86_64-linux
          ];

          # Additional configuration options go here...
        })
      ];
    };
  };
}
```

## Accessing Packages and Overlays

- Access specific HAProxy builds directly via the package set, e.g., `ocp_haproxy_2_8_5`.
- Utilize overlays to integrate the package set with your Nixpkgs.

## Default Packages

Each supported system (`aarch64-linux`, `x86_64-linux`) has a default package set, making it easier to use the flake in various environments.

## Development Shells

Development shells are available for supported systems, providing a clean environment for development and testing.

## OCP-HAProxy Nix Package

### Install Phase

The `installPhase` handles multiple aspects of setting up HAProxy for different versions:

1. **Directory Structure Creation**: Creates necessary directories for binaries and source files specific to each version of HAProxy.
2. **Binary Installation**: Installs the HAProxy binary with a version-specific name (`ocp-haproxy-${version}-g`) in the `bin` directory.
3. **Source Code Management**: Extracts the source code for each version into a version-specific directory under `share`.
4. **GDB Initialization File**: Creates a `gdbinit` file for each version, specifying the directory of the source code, facilitating debugging with GDB.
5. **GDB Wrapper Script**: Generates a wrapper script for GDB for each version. This script invokes GDB with the corresponding `gdbinit` file.
6. **Clangd Configuration**: Uses Perl to generate `.clangd` configuration files for each version, ensuring proper settings for Clangd, including the inclusion of version-specific headers.
7. **Compile Commands JSON**: Installs the `compile_commands.json` file in the appropriate source directory for each version, aiding in source code analysis and other tooling.
8. **Emacs Project Recognition**: Adds a sentinel file (.project) in each version-specific directory, allowing Emacs' project.el to recognize these directories as individual projects. This is particularly useful when the directories are not part of a version control system and assists developers in using Emacs tooling effectively with each HAProxy version.

This setup ensures that each version of HAProxy is isolated and configured with its appropriate debugging and development tools.

## Customising and Extending

You can extend or customise this flake by:

- Adding new HAProxy versions or patches in `packages.nix`.
- Modifying the build process in `package.nix`.
- Adjusting the systems supported or the default packages.
