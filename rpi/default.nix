{ overlay }:
{ lib, pkgs, config, ... }:

{
  imports = [
    ../sd-image
    ./device-tree.nix
    ./audio.nix
    ./i2c.nix
    ./i2s.nix
    ./modesetting.nix
  ];

  nixpkgs = { overlays = [ overlay ]; };
  boot = {
    initrd.availableKernelModules = [
      "usbhid"
      "usb_storage"
      "vc4"
      "pcie_brcmstb" # required for the pcie bus to work
      "reset-raspberrypi" # required for vl805 firmware to load
    ];
    kernelPackages = pkgs.linuxPackagesFor (pkgs.rpi-kernels.v5_15_87.kernel);

    loader = {
      grub.enable = lib.mkDefault false;
      generic-extlinux-compatible = {
        enable = lib.mkDefault true;
        # We want to use the device tree provided by firmware, so don't
        # add FDTDIR to the extlinux conf file.
        useGenerationDeviceTree = false;
      };
    };
  };
  hardware.enableRedistributableFirmware = true;

}
