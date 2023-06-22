# Bpod
Behavior protocol files in Bpod  
The original beavior protocol files are stored in this repository.  
The directory of behavior protocol files in te behavior computer is  
"/usr/local/MATLAB/R2018b/Bpod Local/Protocols/"

# Running behavior paradigm and Recording   
Updated: 2023-06-21

Connection
Digital-in 1: High-speed camera TTL from the function generator
Digital-in 2: Lickometer
Digital-in 3: Auditory cue from the HiFi module
Digital-in 4: Reward delivery from Bpod BNC2

1. Start the Intan program from Terminal (cd Programs/IntanRHX > ./IntanRHX)
2. Create a new file and name it for recording.
3. Start CameraViewr from Terminal (cd Programs/build-CameraViewer-Clang-Release > ./CameraViewer)
4. Rescan and Connect cameras
5. Put an animal in the rig
6. Turn IR light on
7. Hit "Trigger" on CameraViewr to start the cameras
8. Adjust the position of the lick port (2cm, 2cm on the computer monitor)
9. Create a new video file and name it
10. Hit "Record" on CameraViewr (CameraViewr is ready to record)
11. Hit "output" on the function generator to start camera acquisition
12. Start behavior paradigm from Bpod
13. -- Behavior recording --
14. Stop the behavior paradigm from Bpod
15. Hit "output" on the function generator to stop camera acquisition
16. Hit "Record" on CameraViewr
17. Stop recording in the Intan program.

## Licking_Optogenetics_LEDCue.m: 
delivers a water reward every 20 seconds. Upon activating the "mixTrials" section, the code triggers BNC2 for 5 seconds during 20% of the total trials. BNC2 is currently not active with the current settings.

## LickToGetReward_5.m: 
delivers a water reward when the animal licks 5 times within a 10-second response window after an auditory cue. After a successful trial, the animal is allowed to drink for 5 seconds. If the animal fails to meet the licking requirement, the trial proceeds to the inter-trial interval (ITI). 

## LickToGetReward_Training.m: 
delivers a water reward when the animal licks 3 times within a 10-second response window after an auditory cue. After a successful trial, the animal is allowed to drink for 5 seconds. If the animal fails to meet the licking requirement, the trial proceeds to the inter-trial interval (ITI). To encourage the animal an unconditioned water reward is delivered every 10th trials. Additionally, an auditory signal is delivered simultaneously with the reward. 
