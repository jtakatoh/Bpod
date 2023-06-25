function Laser_Stim_Continuous
%%
% This script delivers continuous laser stim (100ms, 500ms, and 100ms)
% Each stim repeats 10 times.
%%
global BpodSystem
%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.InterTrialInterval = 5;
    S.GUI.MaxTrials = 1; % Maximum number of trials
end
%% Main trial loop
for currentTrial = 1
    
    % S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    sma = NewStateMachine(); % Initialize new state machine description
    
    % Set GlobalTimer 1 for BNC1-out constant ON for lickometer
    sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', 1, 'OnsetDelay', 0,...
        'Channel', 'BNC1', 'OnLevel', 1, 'OffLevel', 0, ...
        'Loop', 1, 'SendGlobalTimerEvents', 0, 'LoopInterval', 0);
    
    % Set GlobalTimer 2 for Flex1DO. 100ms x10, 5 sec interval  
    sma = SetGlobalTimer(sma, 'TimerID', 2, 'Duration', 0.1, 'OnsetDelay', 0,...
        'Channel', 'Flex1DO', 'OnLevel', 1, 'OffLevel', 0, ...
        'Loop', 10, 'SendGlobalTimerEvents', 1, 'LoopInterval', 5);

    % Set GlobalTimer 3 for Flex1DO. 500 ms x10, 5 sec interval
    sma = SetGlobalTimer(sma, 'TimerID', 3, 'Duration', 0.5, 'OnsetDelay', 0,...
        'Channel', 'Flex1DO', 'OnLevel', 1, 'OffLevel', 0, ...
        'Loop', 10, 'SendGlobalTimerEvents', 0, 'LoopInterval', 5);

    % Set GlobalTimer 4 for Flex1DO. 500 ms x10, 5 sec interval
    sma = SetGlobalTimer(sma, 'TimerID', 4, 'Duration', 1, 'OnsetDelay', 0,...
        'Channel', 'Flex1DO', 'OnLevel', 1, 'OffLevel', 0, ...
        'Loop', 10, 'SendGlobalTimerEvents', 0, 'LoopInterval', 5);
    
    
    % Set GlobalCounter 1 for GlobalTimer 2
    sma = SetGlobalCounter(sma, 1, 'GlobalTimer2_End', 10);
    
    % Set GlobalCounter 2 for GlobalTimer 3
    sma = SetGlobalCounter(sma, 2, 'GlobalTimer3_End', 10);
    
    % Set GlobalCounter 3 for GlobalTimer 4
    sma = SetGlobalCounter(sma, 3, 'GlobalTimer4_End', 10);
    
    
    % start GlobalTimer 1 
    sma = AddState(sma, 'Name', 'TimerTrig', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'TrialStart'},...
        'OutputActions', {'GlobalTimerTrig', 1});  
    
    % Trial starts
    sma = AddState(sma, 'Name', 'TrialStart', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'CounterReset_1'},...
        'OutputActions', {});
    %% 100 ms stim
    % This state resets the global counter
    sma = AddState(sma, 'Name', 'CounterReset_1', ... 
        'Timer', 0,'StateChangeConditions', {'Tup', 'ShortStimTrig'},...
        'OutputActions', {'GlobalCounterReset', 1});
    
    % 100 ms stim trigger 
    sma = AddState(sma, 'Name', 'ShortStimTrig', ...
        'Timer', 0, ...
        'StateChangeConditions', {'Tup', 'ShortStim'}, ...
        'OutputActions', {'GlobalTimerTrig', 2});

    % 100 ms stim  
    sma = AddState(sma, 'Name', 'ShortStim', ...
        'Timer', Inf, ...
        'StateChangeConditions', {'GlobalCounter1_End', 'ITI_1'}, ...
        'OutputActions', {});
    
    % ITI
    sma = AddState(sma, 'Name', 'ITI_1', ...
        'Timer', S.GUI.InterTrialInterval, ...
        'StateChangeConditions', {'Tup', 'CounterReset_2'}, ...
        'OutputActions', {});

    %% 500 ms Stim
    % This state resets the global counter
    sma = AddState(sma, 'Name', 'CounterReset_2', ... 
        'Timer', 0,'StateChangeConditions', {'Tup', 'MediumStimTrig'},...
        'OutputActions', {'GlobalCounterReset', 2});

    % 500 ms stim trigger 
    sma = AddState(sma, 'Name', 'MediumStimTrig', ...
        'Timer', 0, ...
        'StateChangeConditions', {'Tup', 'MediumStim'}, ...
        'OutputActions', {'GlobalTimerTrig', 3});

    % 500 ms stim
    sma = AddState(sma, 'Name', 'MediumStim', ...
        'Timer', Inf, ...
        'StateChangeConditions', {'GlobalCounter2_End', 'ITI_2'}, ...
        'OutputActions', {});
    
    % ITI
    sma = AddState(sma, 'Name', 'ITI_2', ...
        'Timer', S.GUI.InterTrialInterval, ...
        'StateChangeConditions', {'Tup', 'CounterReset_3'}, ...
        'OutputActions', {});
    
    %% 1000 ms stim
    % This state resets the global counter
    sma = AddState(sma, 'Name', 'CounterReset_3', ... 
        'Timer', 0,'StateChangeConditions', {'Tup', 'LongStimTrig'},...
        'OutputActions', {'GlobalCounterReset', 3});
    
    % 1000 ms stim trigger 
    sma = AddState(sma, 'Name', 'LongStimTrig', ...
        'Timer', 0, ...
        'StateChangeConditions', {'Tup', 'LongStim'}, ...
        'OutputActions', {'GlobalTimerTrig', 4});

    % 1000 ms stim  
    sma = AddState(sma, 'Name', 'LongStim', ...
        'Timer', Inf, ...
        'StateChangeConditions', {'GlobalCounter3_End', '>exit'}, ...
        'OutputActions', {});
    
    %%
    SendStateMachine(sma); % Send the state matrix to the Bpod device
    RawEvents = RunStateMatrix; % Run the trial and return events
    
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        % BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data); % Sync with Bpod notebook plugin
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        % BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        % UpdateSideOutcomePlot(TrialTypes, BpodSystem.Data)
        % UpdateTotalRewardDisplay(S.GUI.RewardAmount, currentTrial)
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end

    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0 % If protocol was stopped, exit the loop
        return
    end

end

