% BCI workshop 2015
% Exercise 2: A Basic BCI
% 
% Description:
% In this second exercise, we will learn how to use an automatic algorithm to 
% recognize somebody's mental states from their EEG. We will use a classifier: 
% a classifier is an algorithm that, provided some data, learns to recognize 
% patterns, and can then classify similar unseen information.
% 

clear;
close all;

addpath('bci_workshop_tools\');

% MuLES connection parameters    
mules_ip = '127.0.0.1';
muse_port = 30000;

% Creates a mules_client
mules_client = MulesClient(mules_ip, muse_port);
params = mules_client.getparams();

% Device parameters
name_of_channels   = params{6};
sampling_frequency = params{3};

%% Set the experiment parameters

training_secs = 20;
win_test_secs = 1;     % Length of the Test Window in seconds
overlap_secs = 0.7;    % Overlap between two consecutive Test Windows
shift_secs = win_test_secs - overlap_secs;   
eeg_buffer_secs = 30;  % Size of the EEG data buffer (duration of Testing section) 

%% Record training data

% Record data for mental activity 0
tone(500,500); % Beep sound
eeg_data0 = mules_client.getdata(training_secs);

% Record data for mental activity 1
tone(500,500); % Beep sound
eeg_data1 = mules_client.getdata(training_secs);    

% Divide data into epochs
eeg_epochs0 = epoching(eeg_data0, win_test_secs * sampling_frequency, ... 
                                        overlap_secs * sampling_frequency);
eeg_epochs1 = epoching(eeg_data1, win_test_secs * sampling_frequency, ...    
                                        overlap_secs * sampling_frequency);

%% Compute features

feat_matrix0 = compute_feature_matrix(eeg_epochs0, sampling_frequency);
feat_matrix1 = compute_feature_matrix(eeg_epochs1, sampling_frequency);

%% Train classifier    

[classifier, mu_ft, std_ft] = classifier_train(feat_matrix0, feat_matrix1, 'SVM');
tone(500,300)

%% Initialize the buffers for storing raw EEG and decisions
    
eeg_buffer = zeros(sampling_frequency * eeg_buffer_secs , numel(name_of_channels)); 
decision_buffer = zeros(30,1);

% Initialize the plots
h_yhat  = figure();

mules_client.flushdata()  % Flushes old data from MuLES

%% Start pulling data
tone(500,500); % Beep sound
             
disp(' Press ESC in the decision figure window to break the While Loop');

while true
    % 1- ACQUIRE DATA 
    eeg_data = mules_client.getdata(shift_secs, false); % Obtain EEG data from MuLES  
    eeg_buffer = updatebuffer(eeg_buffer, eeg_data); % Update EEG buffer
    % Get newest "testing samples" from the buffer 
    test_data = getlastdata(eeg_buffer, win_test_secs * sampling_frequency);

    % 2- COMPUTE FEATURES and CLASSIFY 
    % Compute features on "test_data"
    feat_vector = compute_feature_vector(test_data, sampling_frequency);
    y_hat = classifier_test(classifier, feat_vector, mu_ft, std_ft);
            
    decision_buffer = updatebuffer(decision_buffer, y_hat);
    
    % 3- VISUALIZE THE DECISIONS
    disp(y_hat);
    figure(h_yhat);
    plot_channels(decision_buffer, shift_secs, [], 'y-hat');
    
    pause(0.00001);
    
    commandKey = get(h_yhat,'CurrentCharacter');        
    if commandKey == char(27) %If the CurrentCharacter is ESC, end program
        break
    else
        set(h_yhat,'currentch',char(0));
    end    
end

% Close connection with MuLES
mules_client.disconnect(); % Close connection