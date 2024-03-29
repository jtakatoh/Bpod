function LickToGetReward_Training
%%
% This behavior paradigm is for training animals.
% To motivate the animal, water reward is delivered regardless of licking performance every 10th trials. 

% In the regular trials, the animal needs to lick x times (x is defined by
% S.GUI.LickThreshold) to get water reward.
% 
% Updata: 2023-04-11
% ITI is changed to the random distribution between 5 to 10 sec
% Reward volume is decreased from 3 to 2 µl
% The auditory signal concurrently delivered with a water reward is removed

% Update: 2023-05-03
% Reward volume: 5 µl
% Sound intensity: 0.2
% Reward amount update 

% Update: 2023-06-21
% Add "BNC2 output" in Reward and Unconditioned Reward for timestamping in the Intan recording system  
%%
global BpodSystem

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
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.RewardAmount = 5; %ul. With 3 µl. Animal can perform ~ 250 trials if it it very thirsty.
    S.GUI.InterTrialIntervalMin = 5; % Minimum inter-trial interval in seconds
    S.GUI.InterTrialIntervalMax = 10; % Maximum inter-trial interval in seconds
    S.GUI.CueDuration = 0.2; % Auditory cue duration in seconds
    S.GUI.SinWaveFreq_Cue = 8000; % Frequency of auditory cue. 8k is the most salient for mice, accoding to Ke.
    % S.GUI.SinWaveFreq_Reward = 12000; % Frequency of auditory reward cue. Remove it for now (2023-04-11)   
    S.GUI.SoundIntensity = 0.2; % Intensity of the sound, range between 0 1. 70db is good. 
    S.GUI.ResponseWindow = 10; % Response time window in seconds
    S.GUI.LickThreshold = 2; % Number of licks required to deliver reward
    S.GUI.DrinkTime = 5; % Drinking time in seconds
    S.GUI.MaxTrials = 200; % Maximum number of trials
    
    % setup these later
    % S.GUIMeta.DifficultyLevel.Style = 'popupmenu';
    % S.GUIMeta.DifficultyLevel.String = {'Easy', 'Difficult','Impossible'};    
    % S.GUIPanels.Shaping = {'DifficultyLevel'};
end

%% Define trials
TrialTypes = ones(1,S.GUI.MaxTrials);
% TrialTypes will become 2 in every 10 times
for idx = 10:10:S.GUI.MaxTrials
    TrialTypes(idx) = 2;
end
%% Initialize plots
% TrialTypes = ones(1, S.GUI.MaxTrials);
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.
BpodSystem.ProtocolFigures.OutcomePlotFig = figure('Position', [50 540 1000 250],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.OutcomePlot = axes('Position', [.075 .3 .89 .6]);
TrialTypeOutcomePlot(BpodSystem.GUIHandles.OutcomePlot,'init',TrialTypes);

BpodParameterGUI('init', S); % Initialize parameter GUI plugin
TotalRewardDisplay('init'); % Total Reward display (online display of the total amount of liquid reward earned)
%% Define stimuli and send to analog module
SF = 192000; % Use max supported sampling rate
H.SamplingRate = SF;

% Auditory cue
Sound_Cue = GenerateSineWave(SF, S.GUI.SinWaveFreq_Cue, S.GUI.CueDuration)*S.GUI.SoundIntensity; % Sampling freq (hz), Sine frequency (hz), duration (s) * Sound
H.load(1, Sound_Cue);

Envelope = 1/(SF*0.001):1/(SF*0.001):1; % Define 1ms linear ramp envelope of amplitude coefficients, to apply at sound onset + in reverse at sound offset
%Envelope = [];
H.AMenvelope = Envelope;
H.push(); % Send the sound data and envelope to the HiFi module
LoadSerialMessages('HiFi1', {['P' 0]});

%% Main trial loop
for currentTrial = 1:S.GUI.MaxTrials
    
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    R = GetValveTimes(S.GUI.RewardAmount, 1); 
    ValveTime = R; % Update reward amounts
    
    % ITI duration. Random distribution between 5 to 10 sec 
    ITI_duration = S.GUI.InterTrialIntervalMin + (S.GUI.InterTrialIntervalMax - S.GUI.InterTrialIntervalMin) * rand; 
    
    switch TrialTypes(currentTrial) % Determine trial-specific state matrix fields
        case 1
            StartState = 'ITI'; WaitForLick = 'WaitForLick';
        case 2
            StartState = 'ITI'; WaitForLick ='UnconditionedReward';
    end
    
    sma = NewStateMachine(); % Initialize new state machine description
    
    % Set GlobalTimer 1 for BNC1-out constant ON for lickometer
    sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', 1, 'OnsetDelay', 0,...
        'Channel', 'BNC1', 'OnLevel', 1, 'OffLevel', 0, ...
        'Loop', 1, 'SendGlobalTimerEvents', 0, 'LoopInterval', 0);
    
    % start GlobalTimer 1 
    sma = AddState(sma, 'Name', 'TimerTrig', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'TrialStart'},...
        'OutputActions', {'GlobalTimerTrig', '1'});  
    
    % Set GlobalCounter 1. Reset the counter right before use.  
    sma = SetGlobalCounter(sma, 1, 'BNC1High', S.GUI.LickThreshold);
    
    % Trial starts
    sma = AddState(sma, 'Name', 'TrialStart', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', StartState},...
        'OutputActions', {}); % StartState 1 or 2
    
    % ITI 
    sma = AddState(sma, 'Name', 'ITI', ...
        'Timer', ITI_duration, ...
        'StateChangeConditions', {'Tup', 'Cue'}, ...
        'OutputActions', {});
    
    % Auditory cue. Play the auditory cue using HiFi module
    sma = AddState(sma, 'Name', 'Cue', ...
        'Timer', S.GUI.CueDuration, ...
        'StateChangeConditions', {'Tup', 'CounterReset'}, ...
        'OutputActions', {'HiFi1', 1});
    
    % This state resets the global counter
    sma = AddState(sma, 'Name', 'CounterReset', ... 
        'Timer', 0,'StateChangeConditions', {'Tup', WaitForLick},...
        'OutputActions', {'GlobalCounterReset', 1});
    
    % Response Window: If no licking occurs during the response window, 
    % the state machine proceeds to ITI. 
    % If the licking threshold defined in S.GUI.LickThreshold is reached, 
    % the state machine proceeds to the Reward state.
    % 'exit' state is necessary 
    sma = AddState(sma, 'Name', 'WaitForLick', ...
        'Timer', S.GUI.ResponseWindow, ...
        'StateChangeConditions', {'Tup', 'exit', 'GlobalCounter1_End', 'Reward'}, ...
        'OutputActions', {});

    % Unconditioned Reward delivery
    sma = AddState(sma, 'Name', 'UnconditionedReward', ...
        'Timer', ValveTime, ...
        'StateChangeConditions', {'Tup', 'Drinking'}, ...
        'OutputActions', {'ValveState', 1, 'BNC2', 1});
    
    % Reward delivery
    sma = AddState(sma, 'Name', 'Reward', ...
        'Timer', ValveTime, ...
        'StateChangeConditions', {'Tup', 'Drinking'}, ...
        'OutputActions', {'ValveState', 1, 'BNC2', 1});

    % exit
    sma = AddState(sma, 'Name', 'Drinking', ...
        'Timer', S.GUI.DrinkTime, ...
        'StateChangeConditions', {'Tup', 'exit'}, ...
        'OutputActions', {});
    
    SendStateMachine(sma); % Send the state matrix to the Bpod device
    RawEvents = RunStateMatrix; % Run the trial and return events
    
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        % BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data); % Sync with Bpod notebook plugin
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        UpdateSideOutcomePlot(TrialTypes, BpodSystem.Data)
        UpdateTotalRewardDisplay(S.GUI.RewardAmount, currentTrial)
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end

    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0 % If protocol was stopped, exit the loop
        return
    end

end

end

% Plot behavior outcomes. 
% Outcome1: green - reward delivered. 
% Outcome0: red - rewad not delivered
% Outcome2: unfilled green - Unconditioned reward delivered.

function UpdateSideOutcomePlot(TrialTypes,Data)
    global BpodSystem
    Outcomes = zeros(1, Data.nTrials);
    
    for x = 1:Data.nTrials
        if TrialTypes(x) == 2 % UnconditionedReward
            Outcomes(x) = 2;
        elseif isfield(Data.RawEvents.Trial{x}.Events, 'GlobalCounter1_End') && ~isempty(Data.RawEvents.Trial{x}.Events.GlobalCounter1_End)
            Outcomes(x) = 1; % reward delivered
        else
            Outcomes(x) = 0; % reward not delivered
        end
    end

    TrialTypeOutcomePlot(BpodSystem.GUIHandles.OutcomePlot, 'update', Data.nTrials + 1, TrialTypes, Outcomes);
end
function UpdateTotalRewardDisplay(RewardAmount, currentTrial)
% If rewarded based on the state data, update the TotalRewardDisplay
global BpodSystem
    if ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Reward(1)) || ...
       ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.UnconditionedReward(1))
       TotalRewardDisplay('add', RewardAmount);
    end
end