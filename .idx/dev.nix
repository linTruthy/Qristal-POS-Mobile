{ pkgs, ... }: {
  # Which nixpkgs channel to use.
  channel = "stable-24.05"; 
  
  # Use https://search.nixos.org/packages to find packages
  packages = [
    pkgs.docker
    pkgs.docker-compose # Added for convenience
    pkgs.openssl
    pkgs.nodejs_20
    pkgs.flutter
  ];

  # Enable the Docker daemon service
  services.docker.enable = true;

  # Sets environment variables in the workspace
  env = {};
  
  idx = {
    extensions = [
      "google.gemini-cli-vscode-ide-companion"
    ];
    previews = {
      enable = true;
      previews = {
        # web = {
        #   command = ["npm" "run" "dev"];
        #   manager = "web";
        #   env = {
        #     PORT = "$PORT";
        #   };
        # };
      };
    };
    workspace = {
      onCreate = {
        default.openFiles = [ ".idx/dev.nix" "README.md" ];
      };
      onStart = {
      };
    };
  };
}