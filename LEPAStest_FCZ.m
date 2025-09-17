restoredefaultpath
clearvars; close all


if ispc
%     eeglab_path = 'C:\Users\u0097877\Documents\MATLAB\eeglab2019_0';
%     addpath(genpath ('C:\Users\u0097877\Documents\MATLAB\eigene_functionen'));
%     addpath(genpath ('C:\Users\u0097877\Documents\MATLAB\matlab_scripts'));
else
    eeglab_path = ('/Users/jac277/Documents/MATLAB/eeglab2022.1'); 
%     addpath('/path/to/yourownfunctions'); % you may need a directory where you store random functions
    addpath('/path/to/youranalysisscripts');% change this to your directory where your analysis script sits
end
cd(eeglab_path)
eeglab




% define starting directory
start_path = fullfile('/path/to/layoutinfo'); % path to folder with layout info
data_path = fullfile('/path/to/currentdata'); % this is where your data is currently, you can change it to a different directory once this is set up for your data collection

chan_locations = [start_path filesep 'acquisition_layout_information' filesep 'CACS-96_REF.bvef'];  

%% load the data

% Get a list of all files and folders in this folder.
subjFolders = dir(data_path);
directoryNames = {subjFolders([subjFolders.isdir]).name};
directoryNames = directoryNames(~ismember(directoryNames,{'.','..'}));

% loop through the subj's folders - for now you can run it step by step
% ignoring the for loop
for s = 1:length(directoryNames)
    currentFolder =directoryNames{s};
    fprintf('Processing folder %s\n', currentFolder)
    
    basedir = ([data_path filesep currentFolder]);

    cd(basedir)
    ls


     out_dir = ([basedir filesep 'eeglab_processed']);
    if ~exist (out_dir, 'dir')
        mkdir(out_dir);
    end


cd('raw_eeg')
    file_ext = '.vhdr';
    
    FileNames=dir(['*' file_ext]);
    FileNames ={FileNames.name};
    FileNames =FileNames(~contains(FileNames,{'._'}));
    
    for ff =1 %:size(FileNames, 2) %uncomment to cycle through other .vhdr files
    currentFile = extractBefore(FileNames{1,ff}, '.vhdr');

    EEGloaded = pop_loadbv(pwd, FileNames{1,ff}, [], 1:64); % load the BP file
    events=EEGloaded.event;
    complete_event_info=EEGloaded.urevent;
    EEGloaded.setname='rawEEG';
    EEGloaded = eeg_checkset(EEGloaded);


    EEGloaded=pop_chanedit(EEGloaded,'settype',{[1:64] 'EEG'});
    EEG = pop_select( EEGloaded,'channel', [1:64]);
    EEG.setname='EEGraw_s';
    %     EEG = eeg_checkset( EEG );
    EEG = eeg_checkset( EEG );


 %% detrending --> highpass filter at 1Hz the data to remove baseline drift
    
    EEG = pop_eegfiltnew(EEG, 'locutoff',1,'plotfreqz',1);
    
    EEG.setname='EEGraw_sf';
    EEG = eeg_checkset( EEG );


   %% plot the raw
   figure; pop_spectopo(EEG, 1, [0  3115636], 'EEG' , 'percent', 15, 'freq', [6 10 22 35 60], 'freqrange',[2 70],'electrodes','off');
   title('rawEEG')
    saveas(gcf,[out_dir filesep [currentFile, '_rawEEG.png']]) % to do: change file naminging to account for S/M
    close(gcf)

%% REMOVE LINE NOISE WITH BANDSTOP FILTER
 [EEG, com, b] = pop_firws(EEG, 'forder', 16500, 'fcutoff', [59.9 60.1], 'ftype', 'bandstop', 'wtype', 'hamming', 'minphase', 1);

 %% epoch data data based on new trigger information

    EEG = pop_epoch( EEG, {  'T  1' }, [-0.5 1], 'newname', 'EEGraw_sfln_seg', 'epochinfo', 'yes');
    EEG = eeg_checkset( EEG );

     % to do: remove everything irrelevant before 'real test'

     %% plot the filtered
   figure; pop_spectopo(EEG, 1, [0  3115636], 'EEG' , 'percent', 15, 'freq', [6 10 22 35 60], 'freqrange',[2 70],'electrodes','off');
   title('rawEEG_sfln_seg')
   saveas(gcf,[out_dir filesep [currentFile, '_filtEEG.png']])
   close(gcf)

   %% we can consider downsampling but this might not even be necessary
%     EEG = pop_resample( EEG, 250);
%     EEG = eeg_checkset( EEG );

   %% re-reference to average reference after cleaning is done - I omitted this step for now
    % EEG = pop_reref( EEG, []);
   % EEG = eeg_checkset( EEG );

   %% take a first look at the ERPs timelocked to teh sensory stimulus at time 0 (i.e., your SEPs)

    figure; pop_timtopo(EEG, [-500  999], [NaN], 'ERP data and scalp maps of filtered and epoched EEG data');
    saveas(gcf,[out_dir filesep [currentFile, '_SEP_topo.png']])
    close(gcf)


    figure; pop_plottopo(EEG, [1:64] , 'filtered and epoched EEG', 0, 'ydir',1);
    saveas(gcf,[out_dir filesep [currentFile, '_SEP_chans.png']])
    close(gcf)

    %% run the ERP analysis with TESA - this is originally a toolbox for TMS-evoked potentials (TEPs) 
    % but it may actually be very convenient for your purposes. If you want
    % to take a look at what the functions are doing you can read the
    % annotation by typing 'open pop_tesa_functionname' in the command
    % window, for example open pop_tesa_peakanalysis


%     **********
%     The regions of interest (ROI) or rather electrodes of interest can be changed, same for
%     the latencies youn are interested in)

%  define electrode(s), i.e.,  ROI and name it - the channel layout plot you
%  just saved out may be of help to define where (in which electrodes) the SEPs are best visible
%  I just made a rough decision to look at left/right SM1
    EEG = pop_tesa_tepextract( EEG, 'GMFA');
    
    
    %     define latencies of interest and the time windows you are looking
    %     at to find the (positive/negative) deflections of interest - you
    %     can use fewer or more latencies and you need to make a decision
    %     about the width of the time window.
    %     What needs to be decided is how you define the evoked potential, here
    %     called 'method', we use the default here that searches for the
    %     'largest' deflection in the time window
    EEG = pop_tesa_peakanalysis( EEG, 'GMFA', 'positive', [40 200 300], [30 50;180 220; 250 350], 'method', 'largest', 'samples', 5 );
    EEG = pop_tesa_peakanalysis( EEG, 'GMFA', 'negative', [30 60 300], [20 40;50 70; 250 350], 'method', 'largest', 'samples', 5 );

    % prepare the information for output
    output = pop_tesa_peakoutput( EEG, ...
        'calcType', 'amplitude', 'winType', 'individual', 'averageWin', 5, ...
        'fixedPeak', [], 'tablePlot', 'on' );
    
 
    % plot the results
    pop_tesa_plot( EEG, 'tepType', 'GMFA', 'xlim', [-100 500], 'ylim', [], 'CI','off','plotPeak','on' );



    end

end
