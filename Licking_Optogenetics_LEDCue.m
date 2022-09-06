%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2019 Sanworks LLC, Stony Brook, New York, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%}
function Licking_Optogenetics_LEDCue % name of the file and function must be the same. Put the file in the Protocol folder that also has the same name.
% This protocol introduces Light cue > Delay period > reward or no reward >
% Drinking period > ITI
% 
% SETUP
% - Valve 1 > water reward
% - BNC1 > electric lickometer. Lick > high, No Lick > low 

global BpodSystem % One Matlab can only run one paradigm. If two or more paradigms needed, start additional Matlab.
%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))   % If settings file was an empty struct, populate struct with default settings
    S.GUI.RewardAmount = 3; %ul. With 3 µl. Animal can perform ~ 250 trials if it it very thirsty.
%     S.GUI.CueDuration = 1;  %s LED on (seconds)
%     S.GUI.RewardDelay = 1;  %s 
    S.GUI.ITIDuration = 0;  %s
end
%% Start preview the video
% [vid1, src1] = BpodPreviewVideo;
%% Define trials
% nReward = 5; % reward without cue. The first 5 trials. To make sure if everything working fine.
% nCueReward = 0; % reward with cue. 
nRandomTrials = 250; % either case 1 or 2. See below.
MaxTrials = nRandomTrials; % number of total trials
mixTrials = rand(1,nRandomTrials); % trick to generate case 1 or 2. This generate random number between 0 to 1 (Uniform distribution). 
mixTrials(mixTrials>=0.3) = 2; % 70% of trials - no laser
mixTrials(mixTrials< 0.3) = 2; % 20% of trials - laser

TrialTypes = [mixTrials]; % ones(1,nReward) = [1 1 1 1 1], ones(1,nCueReward)*2 = [2 2 2 2 2]
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.
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
        'Timer', 10,...
        'StateChangeConditions', {'Tup', Reward},...
        'OutputActions', {}); % 10 sec wait after the trial starts 

    % reward
    sma = AddState(sma, 'Name', 'Reward', ...
        'Timer', ValveTime,...
        'StateChangeConditions', {'Tup', 'Drinking'},...
        'OutputActions', {'ValveState', 1,'GlobalTimerTrig', '110'});  % Water delivery

    
    % reward + laser
    sma = AddState(sma, 'Name', 'Laser', ...
        'Timer', ValveTime,...
        'StateChangeConditions', {'Tup', 'Drinking'},...
        'OutputActions', {'ValveState', 1, 'GlobalTimerTrig', '110'}); % trigger BNC2 for 5 sec
    
    sma = AddState(sma, 'Name', 'Drinking', ...
        'Timer', 10,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {}); % 10 sec drinking time after water delivery    
    
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


