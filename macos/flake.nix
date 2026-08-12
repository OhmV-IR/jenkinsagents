{
  description = "Macbook System Configuration Flake";

  inputs = {
    # Pinned to 26.05-darwin because 26.11+ dropped x86_64-darwin support
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    }; # Added missing semicolon
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, rust-overlay }:
  let
    configuration = { pkgs, ... }: {
      # Allow unfree packages (required for VS Code)
      nixpkgs.config.allowUnfree = true;
      nixpkgs.overlays = [ (import rust-overlay) ];

      # Packages managed natively by Nix
      environment.systemPackages = with pkgs; [
        git
        vim
        vscode
        jdk
        gh
        python3
        clang-tools
        cppcheck
        sqlfluff
        codespell
        cmake
        gcc
        buf
        protoc-gen-prost
        nodejs
        curl
        (rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" "clippy" ];
          targets = [
            "aarch64-linux-android"
            "x86_64-pc-windows-gnu"
            "x86_64-linux-android"
            "aarch64-apple-ios"
            "armv7-linux-androideabi"
            "i686-linux-android"
            "aarch64-apple-darwin"
            "x86_64-apple-darwin"
            "x86_64-unknown-linux-gnu"
          ];
        })
      ];

      # System Defaults & Preferences
      system.defaults = {
        dock.autohide = true;
        finder.AppleShowAllExtensions = true;
        NSGlobalDomain.AppleInterfaceStyle = "Dark";
      };

      # Homebrew Integration for Xcode and macOS Casks
      homebrew = {
        enable = true;
        onActivation.cleanup = "zap"; # Removes Homebrew formula/casks not listed here

        masApps = {
          "Xcode" = 497799835;
        };
      };

      # Platform configuration for Intel Mac
      nixpkgs.hostPlatform = "x86_64-darwin";

      # Enable Nix daemon service
      services.nix-daemon.enable = true;
      nix.settings.experimental-features = "nix-command flakes";

      # Compatibility state version
      system.stateVersion = 5;
    };
  in
  {
    darwinConfigurations."Ohms-iMac" = nix-darwin.lib.darwinSystem {
      modules = [ configuration ];
    };
  };
}