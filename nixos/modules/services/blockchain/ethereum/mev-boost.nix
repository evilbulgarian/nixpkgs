{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.mev-boost;
in
{
  options.services.mev-boost = {
    enable = lib.mkEnableOption "MEV-Boost, block-building middleware for Ethereum validators";

    package = lib.mkPackageOption pkgs "mev-boost" { };

    network = lib.mkOption {
      type = lib.types.enum [
        "mainnet"
        "sepolia"
        "holesky"
        "hoodi"
      ];
      default = "mainnet";
      description = "The network to connect to.";
    };

    address = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Listen address of the MEV-Boost server. The beacon node connects to this
        endpoint, so it is usually left on localhost.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 18550;
      description = "Port number of the MEV-Boost server.";
    };

    relays = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Relays to request blocks from, as `scheme://pubkey@host`. At least one
        relay is required. See <https://github.com/flashbots/mev-boost#relays>.
      '';
      example = [
        "https://0xa15b52576bcbf1072f4a011c0f99f9fb6c66f3e1ff321f11f461d15e31b1cb359caa092c71bbded0bae5b5ea401aab7e@aestus.live"
      ];
    };

    relayCheck = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Check relay status on startup and on the status API call.";
    };

    minBid = lib.mkOption {
      type = lib.types.numbers.nonnegative;
      default = 0;
      description = ''
        Minimum bid in ETH to accept from a relay. Blocks below this value are
        built locally by the validator instead.
      '';
    };

    metrics = {
      enable = lib.mkEnableOption "the MEV-Boost prometheus metrics server";

      address = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Listen address of the MEV-Boost metrics server.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 18551;
        description = "Port number of the MEV-Boost metrics server.";
      };
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional arguments passed to MEV-Boost.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.relays != [ ];
        message = "services.mev-boost.relays must contain at least one relay.";
      }
    ];

    systemd.services.mev-boost = {
      description = "MEV-Boost block-building middleware";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart =
          let
            args = lib.cli.toCommandLineShellGNU { } {
              ${cfg.network} = true;
              addr = "${cfg.address}:${toString cfg.port}";
              relays = lib.concatStringsSep "," cfg.relays;
              relay-check = cfg.relayCheck;
              min-bid = if cfg.minBid > 0 then cfg.minBid else null;
              metrics = cfg.metrics.enable;
              metrics-addr =
                if cfg.metrics.enable then "${cfg.metrics.address}:${toString cfg.metrics.port}" else null;
            };
          in
          "${lib.getExe cfg.package} ${args} ${lib.escapeShellArgs cfg.extraArgs}";

        DynamicUser = true;
        Restart = "on-failure";
        StateDirectory = "mev-boost";

        # Hardening measures
        CapabilityBoundingSet = "";
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "noaccess";
        ProcSubset = "pid";
        RemoveIPC = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
        ];
      };
    };
  };

  meta.maintainers = with lib.maintainers; [ evilbulgarian ];
}
