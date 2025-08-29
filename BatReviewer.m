function BatReviewer()
% WAV File Browser with Copy, Heterodyne Listening (with Volume), and Spectrogram Controls
    % --- Ensure 'src' (and its subfolders) is on path, once ---
    rootDir = fileparts(mfilename('fullpath'));
    srcDir  = fullfile(rootDir, 'src');

    if exist(srcDir, 'dir')
        % exact-path membership test (robust vs contains/partial matches)
        pcell = strsplit(path, pathsep);
        onPath = any(strcmpi(pcell, srcDir));
        if ~onPath
            addpath(genpath(srcDir));  % use addpath(srcDir) if you don't want subfolders
        end
    end

    % --- Window ---
    f = figure('Name','Bat Reviewer V1.0','NumberTitle','off', ...
        'Position',[100 100 1200 600], 'MenuBar','figure','Toolbar','figure', ...
        'Color',[0.94 0.94 0.94], 'Resize', 'off', 'CloseRequestFcn',@onClose);

    % ===== LEFT: file list + nav =====
    listbox = uicontrol(f,'Style','listbox','Position',[20 180 200 400], ...
        'FontSize',10,'Callback',@fileSelected);

    uicontrol(f,'Style','pushbutton','String','Load Folder', ...
        'Position',[20 140 80 30],'FontSize',10, 'FontWeight', 'bold', 'Callback',@loadFolder);
    uicontrol(f,'Style','pushbutton','String','< Prev', ...
        'Position',[120 140 50 30],'FontSize',10,'Callback',@prevFile);
    uicontrol(f,'Style','pushbutton','String','Next >', ...
        'Position',[170 140 50 30],'FontSize',10,'Callback',@nextFile);

    infoText = uicontrol(f,'Style','text','Position',[25 5 500 25], ...
        'HorizontalAlignment','left','FontSize',10, 'FontWeight', 'bold', 'String','');

    % Export panel (compact; bottom-left)
    exportPanel = uipanel('Parent',f,'Title','Export','FontWeight', 'bold','Position',[0.02 0.05 0.30 0.15]);
    uicontrol(exportPanel,'Style','text','String','Destination:', ...
        'HorizontalAlignment','center','Position',[2 50 80 20]);
    destEdit = uicontrol(exportPanel,'Style','edit','String','', ...
        'HorizontalAlignment','left','Position',[80 50 150 23],'BackgroundColor','w');
    uicontrol(exportPanel,'Style','pushbutton','String','Browse…', ...
        'Position',[247 50 80 20],'Callback',@pickDest);
    uicontrol(exportPanel,'Style','text','String','If exists:', ...
        'HorizontalAlignment','center','Position',[2 20 80 20]);
    policyPopup = uicontrol(exportPanel,'Style','popupmenu', ...
        'String',{'Ask','Overwrite','Auto-rename'},'Position',[80 20 120 20],'Value',1);
    uicontrol(exportPanel,'Style','pushbutton','String','Copy Current', ...
        'Position',[247 20 80 20],'Callback',@copyCurrent);

    % ===== RIGHT: drawing + controls in dedicated panels =====
    rightPanel = uipanel('Parent',f,'Position',[0.2 0.20 0.8 0.80], 'BorderType','none');

    % Waveform (top)
    axWave = axes('Parent',rightPanel,'Position',[0.08 0.58 0.86 0.37], ...
        'Box','on','PositionConstraint','innerposition');
    ylabel(axWave,'Amplitude'); grid(axWave,'on');

    % Spectrogram (bottom)
    axSpec = axes('Parent',rightPanel,'Position',[0.08 0.12 0.86 0.36], ...
        'Box','on','PositionConstraint','innerposition');
    xlabel(axSpec,'Time (s)'); ylabel(axSpec,'Frequency (kHz)'); grid(axSpec,'on');
    % title(axSpec,'Spectrogram');

    % Controls (bottom-right, own panel)
    ctrlPanel = uipanel('Parent',f,'Title','Listening & Spectrogram Controls', ...
        'FontWeight', 'bold', 'Position',[0.33 0.05 0.66 0.15]);

    % Channel
    uicontrol(ctrlPanel,'Style','text','String','Channel:', ...
        'HorizontalAlignment','center','Position',[2 50 60 20]);
    chanPopup = uicontrol(ctrlPanel,'Style','popupmenu','String',{'Left (1)','Right (2)'}, ...
        'HorizontalAlignment', 'center', 'Position',[50 50 80 20],'Value',1,'Callback',@onChannelChange);

    % Carrier slider + edit
    uicontrol(ctrlPanel,'Style','text','String','Carrier (Hz):', ...
        'HorizontalAlignment','center','Position',[130 50 60 20]);
    cfSlider = uicontrol(ctrlPanel,'Style','slider','Min',15000,'Max',85000,'Value',40000, ...
        'Position',[190 50 150 20], 'HorizontalAlignment', 'center', 'Callback',@syncCFEdit);
    cfEdit = uicontrol(ctrlPanel,'Style','edit','String','40000', ...
        'Position',[350 50 70 20], 'HorizontalAlignment', 'center', 'BackgroundColor','w','Callback',@syncCFSlider);

    % Volume (linear multiplier 0–300%)
    uicontrol(ctrlPanel,'Style','text','String','Volume:', ...
        'HorizontalAlignment','center','Position',[475 50 40 20]);
    volSlider = uicontrol(ctrlPanel,'Style','slider','Min',0,'Max',3,'Value',1, ...
        'Position',[520 50 120 20], 'HorizontalAlignment', 'center', 'Callback',@syncVolEdit);
    volEdit = uicontrol(ctrlPanel,'Style','edit','String','1.00', ...
        'Position',[655 50 30 20], 'HorizontalAlignment', 'center', 'BackgroundColor','w','Callback',@syncVolSlider);

    % Listen / Update buttons
    listenBtn = uicontrol(ctrlPanel,'Style','togglebutton','String','Listen', ...
        'Position',[715 5 70 70],'Callback',@toggleListen);

    % Spectrogram params
    uicontrol(ctrlPanel,'Style','text','String','FFT:', ...
        'HorizontalAlignment','center','Position',[2 20 60 20]);
    nfftPopup = uicontrol(ctrlPanel,'Style','popupmenu','String',{'256','512','1024','2048'}, ...
        'Position',[50 20 70 20],'Value',2);
    uicontrol(ctrlPanel,'Style','text','String','Window:', ...
        'HorizontalAlignment','center','Position',[130 20 60 20]);
    winPopup = uicontrol(ctrlPanel,'Style','popupmenu','String',{'Hann','Hamming','Blackman'}, ...
        'Position',[190 20 120 20],'Value',1);
    uicontrol(ctrlPanel,'Style','text','String','Overlap:', ...
        'HorizontalAlignment','center', 'Position',[300 20 60 20]);
    ovlPopup = uicontrol(ctrlPanel,'Style','popupmenu','String',{'50%','75%'}, ...
        'Position',[350 20 80 20],'Value',2);
    uicontrol(ctrlPanel,'Style','pushbutton','String','Update Spectrogram', ...
        'Position',[475 5 220 40], 'HorizontalAlignment','center', 'Callback',@updateSpectrogram);

    % Status (single line, safe area)
    statusText = uicontrol(f,'Style','text','String','', ...
        'HorizontalAlignment','left','Position',[320 140 800 22]);

    % ===== DATA / STATE =====
    fileList = {}; folderPath = ''; currentIndex = 1;
    player = []; isListening = false;

    % Context menu
    cm = uicontextmenu(f); uimenu(cm,'Label','Copy This File','Callback',@copyCurrent);
    set(listbox,'UIContextMenu',cm);

    % ===== Callbacks =====
    function loadFolder(~,~)
        p = uigetdir(pwd,'Select folder with .wav files'); if isequal(p,0),return,end
        folderPath = p; d = dir(fullfile(folderPath,'*.wav')); fileList = {d.name};
        if isempty(fileList)
            errordlg('No .wav files found in folder.'); set(listbox,'String',{},'Value',1);
            cla(axWave); cla(axSpec); set(infoText,'String',''); return;
        end
        set(listbox,'String',fileList,'Value',1); currentIndex = 1;
        plotCurrentFile(); setStatus(sprintf('Loaded %d files.',numel(fileList)));
    end

    function fileSelected(src,~)
        if isempty(fileList),return,end
        currentIndex = max(1,min(numel(fileList),src.Value)); plotCurrentFile();
    end
    function prevFile(~,~)
        if isempty(fileList),return,end
        currentIndex = max(1,currentIndex-1); set(listbox,'Value',currentIndex); plotCurrentFile();
    end
    function nextFile(~,~)
        if isempty(fileList),return,end
        currentIndex = min(numel(fileList),currentIndex+1); set(listbox,'Value',currentIndex); plotCurrentFile();
    end

   function plotCurrentFile()
    stopListeningIfActive();
    if isempty(fileList), return; end

    filename = fileList{currentIndex};
    filepath = fullfile(folderPath, filename);

    try
        [y, fs] = audioread(filepath);
        t = (0:size(y,1)-1)/fs;
        nCh = size(y,2);

        % --- preserve current channel selection (if any)
        prevVal = get(chanPopup,'Value');

        if nCh == 1
            % Mono file: lock to channel 1
            set(chanPopup,'String',{'Mono (1)'}, ...
                          'Value',1, ...
                          'Enable','off');
            ch = 1;
        else
            % Multi-channel: build labels dynamically
            if nCh == 2
                labels = {'Left (1)','Right (2)'}; % stereo labels
            else
                labels = arrayfun(@(k) sprintf('Channel %d',k),1:nCh,'UniformOutput',false);
            end
            % Clamp restored selection
            ch = max(1, min(prevVal, nCh));
            set(chanPopup,'String',labels, ...
                          'Value',ch, ...
                          'Enable','on');
        end

        % --- plot waveform
        cla(axWave);
        plot(axWave, t, y(:,ch), 'k');
        grid(axWave,'on');
        xlabel(axWave,'Time (s)');
        ylabel(axWave,'Amplitude');
        title(axWave, sprintf('File: %s (ch %d)', filename, ch), 'Interpreter','none');

        % --- update info
        set(infoText,'String', ...
            sprintf('Fs: %d Hz | Duration: %.2f s | Samples: %d | Channels: %d', ...
                    fs, size(y,1)/fs, size(y,1), nCh));

        % --- update spectrogram (uses current popup value)
        updateSpectrogram();

    catch ME
        errordlg(['Failed to read file: ' filepath newline ME.message], 'Read Error');
    end
end

    function onChannelChange(~,~), if isempty(fileList),return,end, plotCurrentFile(); end

    function pickDest(~,~)
        d = uigetdir(pwd,'Select export destination'); if isequal(d,0),return,end
        set(destEdit,'String',d); setStatus(['Destination set: ' d]);
    end

    function copyCurrent(~,~)
        if isempty(fileList), setStatus('No file loaded.'); return; end
        dest = strtrim(get(destEdit,'String'));
        if isempty(dest) || ~isfolder(dest)
            choice = questdlg('Destination not set/invalid. Create/select one?', ...
                'Destination Needed','Browse…','Cancel','Browse…');
            if ~strcmp(choice,'Browse…'), return; end
            pickDest(); dest = strtrim(get(destEdit,'String'));
            if isempty(dest) || ~isfolder(dest), return; end
        end
        srcName = fileList{currentIndex}; srcPath = fullfile(folderPath,srcName);
        tgtPath = fullfile(dest,srcName);
        policy = get(policyPopup,'Value'); % 1 Ask, 2 Overwrite, 3 Auto-rename
        if exist(tgtPath,'file')
            switch policy
                case 1
                    answ = questdlg(sprintf('"%s" exists. Overwrite?',srcName), ...
                        'File Exists','Overwrite','Auto-rename','Cancel','Auto-rename');
                    if strcmp(answ,'Cancel')||isempty(answ), setStatus('Copy cancelled.'); return; end
                    if strcmp(answ,'Auto-rename'), tgtPath = nextAvailableName(dest,srcName); end
                case 3
                    tgtPath = nextAvailableName(dest,srcName);
            end
        end
        try
            [ok,msg,msgid] = copyfile(srcPath,tgtPath); if ~ok, error(msgid,'%s',msg); end
            setStatus(sprintf('Copied to: %s',tgtPath));
        catch ME
            errordlg(sprintf('Copy failed:\n%s',ME.message),'Copy Error'); setStatus('Copy failed.');
        end
    end

    function outPath = nextAvailableName(destDir,baseName)
        [~,nm,ext] = fileparts(baseName); k=1; outPath = fullfile(destDir,baseName);
        while exist(outPath,'file'), outPath = fullfile(destDir,sprintf('%s_%02d%s',nm,k,ext)); k=k+1; end
    end

    function setStatus(msg), set(statusText,'String',msg); drawnow limitrate; end

    % ===== Heterodyne + Volume =====
    function syncCFEdit(~,~)
        v = round(get(cfSlider,'Value')); set(cfEdit,'String',num2str(v));
        if isListening, restartListening(); end
    end
    function syncCFSlider(~,~)
        v = str2double(get(cfEdit,'String')); if isnan(v), v=get(cfSlider,'Value'); end
        v = max(15000,min(85000,round(v))); set(cfSlider,'Value',v); set(cfEdit,'String',num2str(v));
        if isListening, restartListening(); end
    end
    function syncVolEdit(~,~)
        v = get(volSlider,'Value'); set(volEdit,'String',sprintf('%.2f',v));
        if isListening, restartListening(); end
    end
    function syncVolSlider(~,~)
        v = str2double(get(volEdit,'String')); if isnan(v), v=get(volSlider,'Value'); end
        v = max(0,min(3,v)); set(volSlider,'Value',v); set(volEdit,'String',sprintf('%.2f',v));
        if isListening, restartListening(); end
    end

    function toggleListen(src,~)
        if isListening
            stopListeningIfActive(); set(src,'String','Listen','Value',0); setStatus('Stopped listening.');
        else
            if startListening(), isListening=true; set(src,'String','Stop','Value',1); setStatus('Listening…'); end
        end
    end

    function ok = startListening()
        ok = false; if isempty(fileList), setStatus('No file loaded.'); return; end
        try
            filename = fileList{currentIndex}; filepath = fullfile(folderPath,filename);
            cf = round(get(cfSlider,'Value')); ch = max(1,get(chanPopup,'Value'));
            [het, fsIn] = heterodyneAudio(filepath, cf, ch);
            % Apply volume (linear multiplier)
            vol = get(volSlider,'Value'); het = het .* vol;
            % Resample to 44.1 kHz
            targetFs = 44100; het_r = tryAudioResample(het, fsIn, targetFs);
            stopListeningIfActive();
            player = audioplayer(het_r, targetFs);
            player.StopFcn = @(~,~) listenStopped(); play(player); ok = true;
        catch ME
            errordlg(['Listen failed: ' ME.message],'Heterodyne Error'); setStatus('Listen failed.');
        end
    end

    function het_r = tryAudioResample(x, fsIn, fsOut)
        try
            het_r = audioresample(x, "InputRate", fsIn, "OutputRate", fsOut);
        catch
            [p,q] = rat(fsOut/fsIn, 1e-6); het_r = resample(x,p,q);
        end
    end

    function restartListening(), wasOn = isListening; stopListeningIfActive(); if wasOn, startListening(); end, end
    function listenStopped(), isListening=false; if isgraphics(listenBtn), set(listenBtn,'String','Listen','Value',0); end; setStatus('Playback finished.'); end
    function stopListeningIfActive(), if ~isempty(player), try, stop(player); end, end, isListening=false; if isgraphics(listenBtn), set(listenBtn,'String','Listen','Value',0); end, end

    % ===== Spectrogram =====
    function updateSpectrogram(~,~)
        if isempty(fileList), return; end
        filename = fileList{currentIndex}; filepath = fullfile(folderPath,filename);
        try
            [y, fs] = audioread(filepath); ch = min(get(chanPopup,'Value'),size(y,2)); x = y(:,ch);
            nfft = str2double(extractPopupString(nfftPopup));
            ovlPctStr = extractPopupString(ovlPopup); ovlPct = contains(ovlPctStr,'75')*0.25 + 0.50; % 0.75 or 0.50
            winName = extractPopupString(winPopup); w = makeWindow(winName,nfft); nover = floor(ovlPct*numel(w));
            cla(axSpec);
            [S,F,T] = spectrogram(x, w, nover, nfft, fs, 'yaxis'); P = 20*log10(abs(S)+1e-12);
            imagesc(axSpec, T, F/1000, P); axis(axSpec,'xy'); xlabel(axSpec,'Time (s)'); ylabel(axSpec,'Frequency (kHz)');
            title(axSpec, sprintf('Spectrogram (NFFT=%d, %s, %d%% overlap)', nfft, winName, round(ovlPct*100)));
            cb = colorbar(axSpec); cb.Label.String = 'Magnitude (dB)';
        catch ME
            errordlg(['Spectrogram failed: ' ME.message],'Spectrogram Error');
        end
    end

    function s = extractPopupString(h)
        strs = get(h,'String'); if iscell(strs), s = strs{get(h,'Value')}; else, s = strtrim(strs(get(h,'Value'),:)); end
    end
    function w = makeWindow(name,N)
        switch lower(name), case 'hann', w=hann(N,'periodic'); case 'hamming', w=hamming(N,'periodic'); case 'blackman', w=blackman(N,'periodic'); otherwise, w=hann(N,'periodic'); end
    end

    % ===== Housekeeping =====
    function onClose(~,~)
        % Optional: remove the paths we added
        if exist('srcDir','var') && exist(srcDir,'dir')
            rmpath(genpath(srcDir));   % or rmpath(srcDir) if you didn't use genpath
        end
        stopListeningIfActive();
        delete(f);
    end
end