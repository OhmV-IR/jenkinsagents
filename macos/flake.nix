{
  description = "Macbook System Configuration Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    }
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, rust-overlay }:
  let
    configuration = { pkgs, ... }: {
      # Allow unfree packages (required for VS Code)
      nixpkgs.config.allowUnfree = true;
      nixpkgs.overlays = [ (import rust-overlay) ];

      # Packages managed natively by Nix
      environment.systemPackages = with pkgs; [
        pkgs.git
        pkgs.vim
        pkgs.vscode
        pkgs.jdk # Installs the current default stable OpenJDK build
        pkgs.gh
        pkgs.python314
        pkgs.clang-tools
        pkgs.cppcheck
        pkgs.sqlfluff
        pkgs.codespell
        pkgs.cmake
        pkgs.gcc
        pkgs.buf
        pkgs.protoc-gen-prost
        pkgs.nodejs_26
        pkgs.curl
        (pkgs.rust-bin.stable.latest.default.override {
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
            "x86_64-unknown-linux-gnu"  # Linux x86_64
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

        # Install Xcode from the Mac App Store via the 'mas' engine
        # Note: Requires being logged into the Mac App Store once manually
        masApps = {
          "Xcode" = 497799835;
        };
      };

      # Platform configuration (Use "aarch64-darwin" for Apple Silicon M1/M2/M3/M4, or "x86_64-darwin" for Intel)
      nixpkgs.hostPlatform = "x86_64-darwin";

      # Enable Nix daemon service
      services.nix-daemon.enable = true;
      nix.settings.experimental-features = "nix-command flakes";

      # Compatibility state version
      system.stateVersion = 5;
    };
  in
  {
    # Replace "YOUR-HOSTNAME" with the output of `scutil --get LocalHostName`
    darwinConfigurations."Ohms-iMac" = nix-darwin.lib.darwinSystem {
      modules = [ configuration ];
    };
  };
}