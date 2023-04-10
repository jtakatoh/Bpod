# Bpod
Behavior protocol files in Bpod  
The original beavior protocol files are stored in this repository.  
The directory of behavior protocol files in te behavior computer is  
"/usr/local/MATLAB/R2018b/Bpod Local/Protocols/"

• Licking_Optogenetics_LEDCue.m: delivers a water reward every 20 seconds. Upon activation of the "mixTrials" section, the code triggers BNC2 for 5 seconds during 20% of the total trials. BNC2 is currently not active with the current settings.

• LickToGetReward_5.m: delivers a water reward when the animal licks 5 times within a 10-second response window after an auditory cue. After a successful trial, the animal is allowed to drink for 5 seconds. If the animal fails to meet the licking requirement, the trial proceeds to the inter-trial interval (ITI). 

