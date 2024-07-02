{ config, lib, options, pkgs, ... }:

let
  cfg = config.hardware;
  hardwareOpengl = if options.hardware?graphics then "graphics" else "opengl";
in
{
  options.hardware = {
    intelGPU = lib.mkEnableOption "" // { description = "Whether to add and configure drivers for intel hardware acceleration."; };
  };

  config = lib.mkIf cfg.intelGPU {
    environment.sessionVariables = {
      # source https://github.com/elFarto/nvidia-vaapi-driver#firefox
      LIBVA_DRIVER_NAME = "intel";

      # source https://discourse.nixos.org/t/nvk-error-when-using-prop-nvidia-drivers/43300/4
      VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json";
    };

    hardware.${hardwareOpengl} = {
      extraPackages = with pkgs; [
        intel-compute-runtime # OpenCL library for iGPU
        # video encoding/decoding hardware acceleration
        intel-media-driver # broadwell or newer
        intel-vaapi-driver # older hardware like haswell
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [
        # video encoding/decoding hardware acceleration
        intel-media-driver # broadwell or newer
        intel-vaapi-driver # older hardware like haswell
      ];
    };

    programs.firefox.hardwareAcceleration = true;

    system.checks = let
      openglDriver = config.systemd.tmpfiles.settings.opengl."/run/opengl-driver"."L+".argument;
    in [
      (pkgs.runCommand "check-that-intel-driver-json-files-exist" {} /* bash */ ''
        set -eoux pipefail

        # the cut drops /run/opengl-driver/
        [[ -e ${openglDriver}/$(echo ${config.environment.sessionVariables.VK_DRIVER_FILES} | cut -d'/' -f4-) ]]
        touch $out
      '')
    ];
  };
}
