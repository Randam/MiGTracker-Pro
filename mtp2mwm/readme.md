MTP2MWM converts files from MiGTracker Pro (MTP) format to Moonblaster for Moonsound Wave (MWM) format.
Moonblaster for Moonsound Wave is a tracker program for the MSX2 computer with Moonsound (OPl4) software synthesizer cartridge
 
To execute this python script, make sure python is installed, then use: python mtp2mwm.py songname.mtp
The resulting mwm file will be saved in the same directory, with the same name but with the .mwm extension

The template.mwm file is required for the converter to run and is used as a base file to which the converted MTP file is written.

The conversion is not perfect. Some instruments need to be set manually. 
Unsupported events are: program changes (Ixx -> Wxx) and the transpose command. 

Freeware

Created by Jeroen Derwort in 2019

