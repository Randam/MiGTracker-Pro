#!/usr/bin/env python
import sys
import copy
from array import *

#
# MTP2MWM converts files from MiGTracker Pro (MTP) format to Moonblaster for Moonsound Wave (MWM) format.
# Moonblaster for Moonsound Wave is a tracker program for the MSX2 computer with Moonsound (OPl4) software synthesizer cartridge
# 
# To execute this python script, make sure python is installed, then use: python mtp2mwm.py songname.mtp
# The resulting mwm file will be saved in the same directory, with the same name but with the .mwm extension
#
# The template.mwm file is required for the converter to run and is used as a base file to which the converted MTP file is written.
#
# The conversion is not perfect. Some instruments need to be set manually. 
# Unsupported events are: program changes (Ixx -> Wxx) and the transpose command. 
#
# Freeware
#
# Created by Jeroen Derwort in 2019
#

def bytes_from_file(filename, chunksize=8192):
	with open(filename, "rb") as f:
		while True:
			chunk = f.read(chunksize)
			if chunk:
				for b in chunk:
					yield b
			else:
				break
				
def read_mwm_template(filename):
	all_bytes = []
	for b in bytes_from_file(filename):
		all_bytes.append(b)
  
	return all_bytes

def read_mtp(filename):
 
	file = open(filename, "r")
  
	# read patterns and transform the data so it is more easily converted to MWM
	patterns = []
	for t1 in range (0, 60):       # pattern
		channels = []
		endofpattern = 0
		for t2 in range (0, 28):     # channel
			steps = []
			for t3 in range(0, 16):    # step
				if (t2 == 0):
					steps.append(0)					   	   		# first channel in MB is not used	
				if (t2 == 1 or t2 == 2 or t2 == 3):		   		# 2nd, 3rd and 4th channels contain FF
					steps.append(255)
					
				if (t2 > 3 and t2 < 21):				   		# 5th channel until 20th channel contain music data
					step = int(file.readline())
					if (step > 170 and step < 181):
						step += 9								# stereo setting
					elif (step > 96 and step < 161):
						if (t2 == 19 or t2 == 20):		   		# volume percussion channels
							step = 146 + ((int(step) - 96) * 2)
						else:
							step = int((step - 97) / 2) + 146  	# volume melodic channels
					elif (step > 160 and step < 171):
						step = int((int(step) - 160) / 2) + 246 # modulation/vibration - tuned back 50%
					elif (step > 0 and step < 97):
						step += 1 	                     		# notes
						if (t2 != 19 and t2 != 20 and step != 97 and step > 12):
							step -= 12							# drop an octave, only for notes 
					elif (step == 191):
						endofpattern = t3
					if (t2 < 21):
						steps.append(step)
					else:								   
						steps.append(0)
						
				if (t2 == 27):							   		# command channel 
					if ((endofpattern - 1) == t3):
						steps.append(24)				   		# end of pattern
					else:
						steps.append(0) 
				if (t2 > 20 and t2 < 28 and t2 != 27):     		# empty channels that are not in use by MiGTracker
					steps.append(0)
			
			channels.append(steps)
		patterns.append(channels)


	# reorder the data to pattern, step, channel in a single list
	data = []
	for t1 in range (0, 60):       # pattern
		for t3 in range(0, 16):      # step
			for t2 in range (0, 28):   # channel
				data.append(str(patterns[t1][t2][t3]).encode())
		
	# read the positions
	positions = []
	for t in range (0, 200):
		position = int(file.readline())
		positions.append(position - 1)
	
	# read the variables
	looppos = int(file.readline())
	if (looppos == 0):
		looppos = 255
	else:
		looppos -= 1

	lastpos = int(file.readline()) - 1
	startspeed = int(file.readline())
	songname = file.readline()

	print('MiGTracker Pro (MTP) to Moonblaster for Moonsound Wave (MWM) converter v0.7.')
	print('(c) 2019 Jer Der of MSX is Good (MiG)')
	print('')
	print('Loop Pos: ' + str(looppos))
	print('Last Pos: ' + str(lastpos))
	print('Start Speed: ' + str(startspeed))
	print('Song name: ' + songname)
	
	#start voices
	startvoices = []
	startvolume = []
	for t in range (1, 16):
		voice = int(file.readline())
		if (voice == 1):
			voice = 0
		else:	
			voice += 6
		startvoices.append(voice)
		file.readline() 						# startmode 1 true or 0 false, not implemented
		startvolume.append(int(file.readline()))

	# program changes
	voices = []
	for t in range(1, 20):
		voice = file.readline()
		voices.append(voice)
	
	file.close()
	
	# prepare output
	mtp = dict()
	mtp['patterns'] = data
	mtp['positions'] = positions
	mtp['looppos'] = looppos
	mtp['lastpos'] = lastpos
	mtp['startspeed'] = startspeed
	mtp['songname'] = songname
	mtp['startvoices'] = startvoices
	mtp['startvolume'] = startvolume
	mtp['voices'] = voices

	return mtp
  
def convert_mtp_mwm(mwm_template, mtp):
	pattern_start = 667
	pattern_length = 448
	position_start = 6
	voice_start = 350
	volume_start = 398
	songname_start = 446
	
	mwm_converted = mwm_template.copy() 

	# patterns
	counter = pattern_start
	for mtp_data in mtp['patterns']:
		if (int(mtp_data) < 98 or 								# notes, empty, commands
			int(mtp_data) == 255 or 							# FF filler
			(int(mtp_data) >= 246 and int(mtp_data) <= 254) or	# volume
			(int(mtp_data) >= 146 and int(mtp_data) <= 177) or	# vibrato
			(int(mtp_data) >= 178 and int(mtp_data) <= 192)		# stereo
		):
			mwm_converted[counter] = int(mtp_data)
		else:
			mwm_converted[counter] = int(0)
		counter += 1
		if counter == (35 * pattern_length + pattern_start): 
			counter += 3										# skip a mysterious 3 byte pair in the middle of the song

	# nullify the remaining patterns
	#while (counter < 35553):
	#	if (mwm_converted[counter] == 97 or mwm_converted[counter] == 19):
	#		mwm_converted[counter] = int(0)
	#	counter += 1
			
	# speed mappings
	if (mtp['startspeed'] == 9): tempo = 3  # MB tempo 22
	if (mtp['startspeed'] == 8): tempo = 6  # MB tempo 19
	if (mtp['startspeed'] == 7): tempo = 9  # MB tempo 16
	if (mtp['startspeed'] == 6): tempo = 11 # MB tempo 14
	if (mtp['startspeed'] == 5): tempo = 13 # MB tempo 12
	if (mtp['startspeed'] == 4): tempo = 15 # MB tempo 10
	if (mtp['startspeed'] == 3): tempo = 17 # MB tempo  8
	if (mtp['startspeed'] == 2): tempo = 19 # MB tempo  6
	if (mtp['startspeed'] == 1): tempo = 21 # MB tempo  4

	# variables
	mwm_converted[326] = 2 # start instruments
	mwm_converted[226] = mtp['lastpos']
	mwm_converted[227] = mtp['looppos']
	mwm_converted[position_start] = 10
	mwm_converted[252] = tempo
		
	# set start voices
	counter = voice_start
	for voice in mtp['startvoices']:
		mwm_converted[counter] = voice
		counter += 1
		
	# set volume for start voices	
	counter = volume_start
	for volume in mtp['startvolume']:
		mwm_converted[counter] = 33 - int((volume / 2))
		counter += 1
	
	# position table
	counter = 0
	for mtp_data in mtp['positions']:
		if (counter < 79):
			mwm_converted[position_start + counter] = mtp_data
		counter += 1
	
	# song name
	counter = songname_start	
	for c in mtp['songname']:
		if (counter < 496):
			if ord(c) != 10:
				mwm_converted[counter] = ord(c)
		counter += 1
		
	return mwm_converted
  
def main():
	# read the mtp file to convert
	mtp = read_mtp(sys.argv[1])

	# read the mwm template
	mwm_template = read_mwm_template('template.mwm')

	# perform the conversion
	mwm_converted = convert_mtp_mwm(mwm_template, mtp)
	
	counter = 0
	for c in mwm_converted:
		if (c > 255 or c < 0):
			print(str(counter) + ':' + str(c))
		counter += 1	

	# write the converted mwm file
	filename = sys.argv[1].replace('.mtp','.mwm')
	file = open(filename, "wb")
	file.write(bytearray(mwm_converted))
	file.close()
	print('Conversion completed. "' + filename + '" created.')
	
	return 0

if __name__ == "__main__":
	sys.exit(main())