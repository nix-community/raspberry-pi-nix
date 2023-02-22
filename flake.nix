{
  description = "raspberry-pi nixos configuration";

  inputs = { };

  outputs = { self }: {
    overlay = import ./overlay;
    rpi = import ./rpi { overlay = self.overlay; };
  };
}
