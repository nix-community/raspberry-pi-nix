# raspberry-pi-nix

NixOS modules that make building images for raspberry-pi products
easier. Most of the work in this repository is based on work in
[nixos-hardware](https://github.com/NixOS/nixos-hardware) and
[nixpkgs](https://github.com/NixOS/nixpkgs). Additionally, be aware
that I am no expert and this repo is the product of me fooling around
with some pis.

This flake provides nixos modules that correspond to different
raspberry-pi products. These modules can be included in nixos
configurations and aim to deliver the following benefits:

1. Configure the kernel, device tree, and u-boot in a way that is
   compatible with the hardware.
2. Provide a nix interface to device tree configuration that will be
   familiar to those who have used raspberry-pi's config.txt based
   configuration.
3. Make it easy to build an image suitable for flashing to an sd-card,
   without a need to first go through an installation media.
   
The important modules are `overlay/default.nix`, `rpi/default.nix`,
and `rpi/device-tree.nix`. The other modules for i2c, i2s, etc are
mostly wrappers that set common device tree settings for you.

## Example

```nix
{
  description = "raspberry-pi-nix example";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.11";
    raspberry-pi-nix = {
      url = "github:tstat/raspberry-pi-nix";
    };
  };

  outputs = { self, nixpkgs, raspberry-pi-nix }:
    let
      inherit (nixpkgs.lib) nixosSystem;
      basic-config = { pkgs, lib, ... }: {
        time.timeZone = "America/New_York";
        users.users.root.initialPassword = "root";
        networking = {
          hostName = "basic-example";
          useDHCP = false;
          interfaces = { wlan0.useDHCP = true; };
        };
        hardware.raspberry-pi = {
          i2c.enable = true;
          audio.enable = true;
          fkms-3d.enable = true;
          deviceTree = {
            dt-overlays = [{
              overlay = "imx477"; # add the overlay for the HQ camera
              args = [ ];
            }];
          };
        };
      };
    in {
      nixosConfigurations = {
        rpi-zero-2-w-example = nixosSystem {
          system = "aarch64-linux";
          modules = [ raspberry-pi-nix.rpi-zero-2-w basic-config ];
        };
        rpi-4b-example = nixosSystem {
          system = "aarch64-linux";
          modules = [ raspberry-pi-nix.rpi-4b basic-config ];
        };
      };
    };
}
```

## Building an sd-card image

An image suitable for flashing to an sd-card can be found at the
attribute `config.system.build.sdImage`. For example, if you wanted to
build an image for `rpi-zero-2-w-example` in the above configuration
example you could run:

```
nix build '.#nixosConfigurations.rpi-zero-2-w-example.config.system.build.sdImage'
```

## Other notes

The sd-image built is partitioned in the same way as the aarch64
installation media from nixpkgs: There is a firmware partition that
contains necessary firmware, u-boot, and config.txt. Then there is
another partition that contains everything else. After the sd-image is
built, nixos system updates will not change anything in the firmware
partition ever again. New kernels and device tree configurations will
remain on the nixos partition and be booted by u-boot in the firmware
partition.

So, while you can control device tree params and overlays through your
nixos system configuration, if you want to modify other config.txt
variables this must be done manually by mounting the partition and
modifying the config.txt file.
