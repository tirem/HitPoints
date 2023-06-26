# HitPoints

An Ashita v4 addon for displaying your target and any enemies you are currently engaged with.

## Show Your Support ##
If you would like to show your support for my addon creation consider buying me a coffee! 

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/A0A6JC40H)

## Overview

This addon has two parts:
1) Shows your targets HP alongside its HP%, distance, server ID, and any status effects. It will also show your target's target if one is available.
2) Shows a list of enemies you are currently "engaged" with alongside their HP% and any status effects on them.

Hovering over any status icon will popup a help text explaining the buff or debuff if a description is available.

**NOTE:** Buffs, debuffs, and target of target are all approximations based on packets and available data. Accuracy may vary.

![Screenshot](https://user-images.githubusercontent.com/7691562/248598451-a3f9a6b7-3302-4bf2-becd-e94dd388bc77.png)


## Installation
* Download the latest release of HitPoints from the panel on the right and extract it.
* Open up the extracted folder and inside of it will be a directory called `addons`.
* Copy the addons folder to your `Ashita` folder, merging it with your current `Ashita/addons` folder.
* To load HitPoints, type `/addon load HitPoints` in your chatbox.
* If you want to load this addon by default:
    * Open up the file `default.txt` in the `Ashita/scripts` folder.
    * Add the following line: `/addon load HitPoints`
* **NOTE:** You must follow these steps to install the addon. Downloading the code directly will not work without source control software as this repository makes use of git submodules!

## Config

To configure any settings simply type `/hitpoints`, `/hpoints`, or `/hp` into the chatbox and a config menu will pop up.

All elements can be dragged around or locked in place. This location is stored in the imgui config in the `Ashita/config` directory. If elements stop rendering correctly, close your game, delete your imgui config, and reopen the game. This will reset all positions.
