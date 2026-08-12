{
  description = "Macbook System Configuration Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs }:
  let
    configuration = { pkgs, ... }: {
      # Allow unfree packages (required for VS Code)
      nixpkgs.config.allowUnfree = true;

      # Packages managed natively by Nix
      environment.systemPackages = with pkgs; [
        git
        vim
        vscode
        jdk # Installs the current default stable OpenJDK build
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