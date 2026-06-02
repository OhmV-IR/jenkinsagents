{
    description = "Mac-OS Jenkins runner flake";
    inputs = {
	nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
	nix-darwin.url = "github:LnL7/nix-darwin";
	nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    };
    outputs = inputs@{ self, nixpkgs, nix-darwin}: {
	darwinConfiguration."MacPro2008" = nix-darwin.lib.darwinSystem {
		modules = [
		./configuration.nix
		];
	};
    };
}
