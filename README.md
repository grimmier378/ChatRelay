# ChatRelay

By Grimmier

## Description: 

This script creates a Window on the Driver to monitor Chat from other Characters on the same PC over Actors.

The script came about from a question in Discord about being able to see guild chat from other characters that were in different guilds without alt-tabbing.
You can relay Guild Chat and / or Tells settings in the Config Window.

## Features

* Tabs for Guild Chat and Tells will show if enabled.
* Tabs for GuildNames will show for each unique guild name as they receive messages, to relay that guilds chat into.
* Tabs for each Character will show for each Character as they receive tells, otherwise you will always see yourself (driver)
* /chatrelay commands bindings
* Send and Replay to tells from GUI.
  * Message format( who|message ) will have the character whose tab you are on send a message who = who to send it to message = your message.
  * example tab(Char1) soandso|testing 123 will have character1 issue /tell soandso testing 123
  
## Run

* ```/lua run chatrelay driver``` will run in driver mode with the GUI displayed
* ```/lua run chatrelay client``` will run in client mode without a GUI

## Commands

* ```/chatrelay tells``` 	Toggles tell monitoring on|off
* ```/chatrelay guild``` 	Toggles guild monitoring on|off
* ```/chatrelay gui``` 		Toggles the GUI
* ```/chatrelay exit```		Closes the script