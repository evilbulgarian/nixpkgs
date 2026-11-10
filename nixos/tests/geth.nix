{ pkgs, ... }:
{
  name = "geth";
  meta = {
    maintainers = with pkgs.lib.maintainers; [ bachp ];
  };

  nodes.machine =
    { ... }:
    {
      services.geth."mainnet" = {
        enable = true;
        http = {
          enable = true;
        };
      };

      services.geth."holesky" = {
        enable = true;
        port = 30304;
        network = "holesky";
        http = {
          enable = true;
          port = 18545;
        };
        authrpc = {
          enable = true;
          port = 18551;
        };
      };

      # A root-owned 0400 secret, as sops-nix and agenix produce by default, is
      # only readable by the DynamicUser service when loaded as a credential.
      environment.etc."geth-jwtsecret" = {
        text = "0x7365637265747365637265747365637265747365637265747365637265747365";
        mode = "0400";
      };

      services.geth."credentials" = {
        enable = true;
        port = 30306;
        authrpc = {
          enable = true;
          port = 38551;
          jwtsecret = "/etc/geth-jwtsecret";
        };
      };

      services.geth."sepolia" = {
        enable = true;
        port = 30305;
        network = "sepolia";
        http = {
          enable = true;
          port = 28545;
        };
        authrpc = {
          enable = true;
          port = 28551;
        };
      };
    };

  testScript = ''
    start_all()

    machine.wait_for_unit("geth-mainnet.service")
    machine.wait_for_unit("geth-holesky.service")
    machine.wait_for_unit("geth-sepolia.service")
    machine.wait_for_unit("geth-credentials.service")
    machine.wait_for_open_port(8545)
    machine.wait_for_open_port(18545)
    machine.wait_for_open_port(28545)

    # Fails if geth could not read the JWT secret: it exits, and Restart=always
    # flaps the unit instead of ever listening on the authrpc port.
    machine.wait_for_open_port(38551)
    machine.succeed(
        "[ \"$(systemctl show -p NRestarts --value geth-credentials.service)\" = 0 ]"
    )

    machine.succeed(
        'geth attach --exec "eth.blockNumber" http://localhost:8545 | grep \'^0$\' '
    )

    machine.succeed(
        'geth attach --exec "eth.blockNumber" http://localhost:18545 | grep \'^0$\' '
    )

    machine.succeed(
        'geth attach --exec "eth.blockNumber" http://localhost:28545 | grep \'^0$\' '
    )
  '';
}
