function Licking_Training % name of the file and function must be the same. Put the file in the Protocol folder that also has the same name.
% This script is for training animals to lick
% A water reward is delivered every 10 seconds along with an auditory cue
% This script was repurposed from the optogenetic stimulation paradigm and may contain some unnecessary lines.

global BpodSystem % One Matlab can only run one paradigm. If two or more paradigms needed, start additional Matlab.
%% Resolve HiFi USB port
if (isfield(BpodSystem.ModuleUSB, 'HiFi1'))
    HiFiUSB =  BpodSystem.ModuleUSB.HiFi1;
else
    error('Error: To run this protocol, you must first pair the HiFi1 module with its USB port. Click the USB config button on the Bpod console.')
end 

% Create an instance of the HiFi module
H = BpodHiFi(BpodSystem.ModuleUSB.HiFi1); % The argument is the name of the HiFi module's USB serial port (e.g. COM3)

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))   % If settings file was an empty struct, populate struct with default settings
    S.GUI.RewardAmount = 5; %ul. With 3 µl. Animal can perform ~ 250 trials if it it very thirsty.
%    S.GUI.CueDuration = 1;  %s LED on (seconds)
%    S.GUI.RewardDelay = 1;  %s 
    S.GUI.ITIDuration = 0;  %s
    S.GUI.CueDuration = 0.2; % Auditory cue duration in seconds
    S.GUI.SinWaveFreq_Cue = 8000; % Frequency of auditory cue. 8k is the most salient for mice, accoding to Ke.
    S.GUI.SinWaveFreq_Reward = 12000; % Frequency of auditory reward cue.
    S.GUI.SoundIntensity = 0.2; % Intensity of the sound, range between 0 1. 70db is good. 
end
%% Define trials
% nReward = 5; % reward without cue. The first 5 trials. To make sure if everything working fine.
% nCueReward = 0; % reward with cue. 
nRandomTrials = 250; % either case 1 or 2. See below.
MaxTrials = nRandomTrials; % number of total trials
mixTrials = rand(1,nRandomTrials); % trick to generate case 1 or 2. This generate random number between 0 to 1 (Uniform distribution). 
mixTrials(mixTrials>=0.3) = 1; % 70% of trials - no laser
mixTrials(mixTrials< 0.3) = 1; % 20% of trials - laser

TrialTypes = [mixTrials]; % ones(1,nReward) = [1 1 1 1 1], ones(1,nCueReward)*2 = [2 2 2 2 2]
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.
%% Define stimuli and send to analog module
SF = 192000; % Use max supported sampling rate
H.SamplingRate = SF;
Sound_Cue = GenerateSineWave(SF, S.GUI.SinWaveFreq_Cue, S.GUI.CueDuration)*S.GUI.SoundIntensity; % Sampling freq (hz), Sine frequency (hz), duration (s) * Sound
H.load(1, Sound_Cue);
Sound_Reward = GenerateSineWave(SF, S.GUI.SinWaveFreq_Reward, S.GUI.CueDuration)*S.GUI.SoundIntensity; % Sampling freq (hz), Sine frequency (hz), duration (s) * Sound
H.load(2, Sound_Reward);
Envelope = 1/(SF*0.001):1/(SF*0.001):1; % Define 1ms linear ramp envelope of amplitude coefficients, to apply at sound onset + in reverse at sound offset
%Envelope = [];
H.AMenvelope = Envelope;
H.push(); % Send the sound data and envelope to the HiFi module
LoadSerialMessages('HiFi1', {['P' 0],['P' 1]});
%% Initialize plots
BpodSystem.ProtocolFigures.OutcomePlotFig = figure('Position', [50 540 1000 250],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.OutcomePlot = axes('Position', [.075 .3 .89 .6]);
TrialTypeOutcomePlot(BpodSystem.GUIHandles.OutcomePlot,'init',TrialTypes);
BpodNotebook('init'); % Initialize Bpod notebook (for manual data annotation)
BpodParameterGUI('init', S); % Initialize parameter GUI plugin
TotalRewardDisplay('init'); % Total Reward display (online display of the total amount of liquid reward earned)
%% Main trial loop
% [vid1, src1] = BpodVideoRecording(vid1, src1);
for currentTrial = 1:MaxTrials
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    R = GetValveTimes(S.GUI.RewardAmount, 1); ValveTime = R; % Update reward amounts
    ITI_duration =     S.GUI.ITIDuration + round(4 *(rand(1)-0.5),1); % 5 +/- 2 s
    
    switch TrialTypes(currentTrial) % Determine trial-specific state matrix fields
        case 1
            StartState = 'Cue'; Reward = 'Reward';   % Reward 
        case 2
            StartState = 'Cue'; Reward = 'Laser';    % Reward + Laser
    end
    
    sma = NewStateMachine(); % Initialize new state machine description
    
    sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', 1, 'OnsetDelay', 0,...
        'Channel', 'BNC1', 'OnLevel', 1, 'OffLevel', 0, ...
        'Loop', 1, 'SendGlobalTimerEvents', 0, 'LoopInterval', 0); % BNC1-out constant ON for lickometer
    
    sma = SetGlobalTimer(sma, 'TimerID', 2, 'Duration', 0.1, 'OnsetDelay', 0,... % 0.1 sec
        'Channel', 'BNC2', 'OnLevel', 1, 'OffLevel', 0);
    
    sma = SetGlobalTimer(sma, 'TimerID', 3, 'Duration', 1, 'OnsetDelay', 0,...
        'Channel', 'PWM1', 'OnLevel', 10, 'OffLevel', 0);
    
    
    sma = AddState(sma, 'Name', 'TimerTrig', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'TrialStart'},...
        'OutputActions', {'GlobalTimerTrig', '001'}); % start timers 1 = ON. To start timer 1 but not 2, it has to be '01'. It has to be flipped somehow.
    
    % ^ Setting up
    % Trial starts
    
    sma = AddState(sma, 'Name', 'TrialStart', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', StartState},...
        'OutputActions', {}); % StartState 1 or 2
    
        sma = AddState(sma, 'Name', 'Cue', ...
        'Timer', 5,...
        'StateChangeConditions', {'Tup', Reward},...
        'OutputActions', {}); % 5 sec wait after the trial starts 

    % reward
    sma = AddState(sma, 'Name', 'Reward', ...
        'Timer', ValveTime,...
        'StateChangeConditions', {'Tup', 'Drinking'},...
        'OutputActions', {'ValveState', 1,'GlobalTimerTrig', '110','HiFi1', 1});  % Water delivery

    
    % reward + laser
    sma = AddState(sma, 'Name', 'Laser', ...
        'Timer', ValveTime,...
        'StateChangeConditions', {'Tup', 'Drinking'},...
        'OutputActions', {'ValveState', 1, 'GlobalTimerTrig', '110'}); % trigger BNC2 for 5 sec
    
    sma = AddState(sma, 'Name', 'Drinking', ...
        'Timer', 5,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {}); % 5 sec drinking time after water delivery    
    
    SendStateMatrix(sma);
    RawEvents = RunStateMatrix;
    if BpodSystem.Status.BeingUsed == 0
%         stoppreview(vid1);
%         stop(vid1);
%         delete(vid1);
%         clear vid1
        return
        
    end
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data); % Sync with Bpod notebook plugin
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        UpdateOutcomePlot(TrialTypes, BpodSystem.Data);
%         BpodSystem.Data.Rotary{currentTrial} = Rotary.readUSBStream();
%         Rotary.stopUSBStream()
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
        UpdateTotalRewardDisplay(S.GUI.RewardAmount, currentTrial)
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        return
    end
end

function UpdateOutcomePlot(TrialTypes, Data)
global BpodSystem
Outcomes = zeros(1,Data.nTrials);
for x = 1:Data.nTrials
    if isfield(Data.RawEvents.Trial{x}.Events, 'Port1In')
        Outcomes(x) = 1;
    else
        Outcomes(x) = 0;
    end
end
TrialTypeOutcomePlot(BpodSystem.GUIHandles.OutcomePlot,'update',Data.nTrials+1,TrialTypes,Outcomes);
function UpdateTotalRewardDisplay(RewardAmount, currentTrial)
% If rewarded based on the state data, update the TotalRewardDisplay
global BpodSystem
    if ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Reward(1))
        TotalRewardDisplay('add', RewardAmount);
    end


