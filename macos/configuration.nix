{ pkgs, ... }: {
  
  # List packages installed in system profile. To search by name, run: $ nix search nixpkgs
  environment.systemPackages = with pkgs; [
    neovim
    git
    tmux
    curl
  ];

  # Enable the Nix daemon service and configure experimental features for Flakes
  services.nix-daemon.enable = true;
  nix.settings.experimental-features = "nix-command flakes";

  # Configure your default system shell integration
  programs.zsh.enable = true;

  # Fully reproducible macOS system preferences customization
  system.defaults = {
    dock = {
      autohide = true;
      show-recents = false;
      # Sets tile size layout parameters
      tilesize = 48;
    };
    finder = {
      AppleShowAllExtensions = true;
      FXPreferredViewStyle = "clmv"; # Column view layout configuration
      QuitMenuItem = true;
    };
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark"; # Enforce Dark Mode system-wide
      "com.apple.keyboard.fnState" = true; # Use F1, F2 keys as standard functional keys
    };
  };

  # Set your specific hostname configuration profile match
  networking.hostName = "MacPro2008";

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;
}
