# Time, locale, console, and the keyboard layout outside Sway.
{ config, lib, pkgs, ... }:

{
  time.timeZone = "Europe/Copenhagen";

  i18n.defaultLocale = "en_US.UTF-8";
  # Danish/Norwegian formatting for the things that actually benefit (paper
  # sizes, week numbers starting Monday — `ukenr`/`cal` aliases assume this).
  i18n.extraLocaleSettings = {
    LC_TIME = "en_DK.UTF-8";
    LC_PAPER = "nb_NO.UTF-8";
    LC_MEASUREMENT = "nb_NO.UTF-8";
  };

  # Sway sets its own input config (sway/config: `input type:keyboard`), but GDM
  # and the VT consoles read this. Kept identical so the layout doesn't change
  # depending on where you're typing.
  services.xserver.xkb = {
    layout = "us,no";
    variant = ",nodeadkeys";
    options = "ctrl:nocaps,grp:alt_shift_toggle,compose:ralt";
  };

  console.useXkbConfig = true;
}
