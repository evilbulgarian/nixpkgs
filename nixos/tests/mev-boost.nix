{ lib, pkgs, ... }:
{
  name = "mev-boost";
  meta.maintainers = with lib.maintainers; [ evilbulgarian ];

  nodes.machine = {
    environment.systemPackages = [ pkgs.curl ];

    services.mev-boost = {
      enable = true;
      metrics.enable = true;
      # Not contacted at startup: relayCheck is off by default, which keeps
      # the test hermetic.
      relays = [
        "https://0xa15b52576bcbf1072f4a011c0f99f9fb6c66f3e1ff321f11f461d15e31b1cb359caa092c71bbded0bae5b5ea401aab7e@aestus.live"
      ];
    };
  };

  testScript = ''
    start_all()

    machine.wait_for_unit("mev-boost.service")
    machine.wait_for_open_port(18550)
    machine.wait_for_open_port(18551)

    machine.succeed("curl -sf http://127.0.0.1:18550/eth/v1/builder/status")
    machine.succeed("curl -sf http://127.0.0.1:18551/metrics")
  '';
}
