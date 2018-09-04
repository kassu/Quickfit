classdef UI < handle
    properties
        quickfit %#ok<*PROP>
        mainwindow
        fitoptionswindow 
        settingseditor
    end
    properties (Access = private)
        tbbImages = {};
        exportfigurehandle;
        fitoptionslisteners = [];
    end
    methods
        function obj = UI(theInstance)
            obj.quickfit = theInstance;
            obj.buildMainWindow();
            obj.updateFunctionList();
        end 
        function delete(obj)           
            if ~isempty(obj.mainwindow) && isvalid(obj.mainwindow), delete(obj.mainwindow); end
            if ~isempty(obj.fitoptionswindow) && isvalid(obj.fitoptionswindow), delete(obj.fitoptionswindow); end
            if ~isempty(obj.settingseditor) && isvalid(obj.settingseditor), delete(obj.settingseditor); end
            obj.quickfit = [];
        end
        
        % Callback functions for controls
        function cb_closemainwindow(obj,source,event)
            if ~isempty(obj.quickfit) && isvalid(obj.quickfit)
                % It seems to be a bit tricky to make sure all objects
                % (both classes and handle graphics objects) are removed
                % properly. The strategy now is to call
                % Instance.beforeClose, which will save settings and
                % then delete the quickfit instance. Then all decontsructor (delete)
                % functions are written to delete all children, so the
                % complete hierarchy should get deleted this way
                obj.quickfit.beforeClose()
            else
                % At least delete ourselves and all corresponding windows
                delete(obj);
            end
        end
        
        % %%%%%%%%%%%%%%%%%%%%%%%%% TOOLBAR BUTTONS %%%%%%%%%%%%%%%%%%%%%%
        function cb_tbbSettings(obj,source,event)
            if ~isempty(obj.settingseditor) && isvalid(obj.settingseditor), delete(obj.settingseditor); end
            obj.settingseditor = cfw.SettingsEditor(obj.quickfit.settings);
        end
        function cb_tbbLoad(obj,source,event)
            % Load session
            [filename, pathname] = uigetfile({'*.mat';'*.*'}, 'Load session');
            if (filename==0), return; end
            
            file = fullfile(pathname,filename);
            
            if exist(file,'file')
                saved = load(file);
                if isfield(saved,'info') && isstruct(saved.info) && isfield(saved.info, 'type') && ...
                        strcmp(saved.info.type,'QuickfitSession') && isfield(saved,'settings') && isfield(saved.settings, 'session')
                    
                    % Restore function, so the UI can handle the upcoming
                    % changes
                    obj.functionRestore(saved.settings.session.function);
                    
                    % Import into settings
                    obj.quickfit.settings.session.putStructData(saved.settings.session, false, false);
                    
                    % Update plots
                    obj.updatePlots();
                else
                    msgbox('The selected file is not a saved session.');
                end
            else
                msgbox('File not found.');
            end
            
        end
        function cb_tbbSave(obj,source,event)
            % Save session
            [filename, pathname] = uiputfile({'*.mat';'*.*'}, 'Save session');
            if (filename==0), return; end
            
            file = fullfile(pathname,filename);
            
            tosave.info = struct('type','QuickfitSession','version',1);
            tosave.settings.session = obj.quickfit.settings.session.getStructData(); %#ok<STRNU>
            save(file,'-struct','tosave');
        end
        
        function cb_plottools_callback(obj,source,event)
            % Treat toggling off one button as toggling off everything
            zoom(obj.mainwindow.hfigure,'off');
            pan(obj.mainwindow.hfigure,'off');
            datacursormode(obj.mainwindow.hfigure,'off');
            v = source.get('Value');
            obj.mainwindow.controls.tbbZoomIn.set('Value',0);
            obj.mainwindow.controls.tbbZoomOut.set('Value',0);
            obj.mainwindow.controls.tbbPan.set('Value',0);
            obj.mainwindow.controls.tbbDataCursor.set('Value',0);
            if v
                % Turn on respective button
                if source==obj.mainwindow.controls.tbbZoomIn
                    set(zoom(obj.mainwindow.hfigure),'enable','on','direction','in');
                elseif source==obj.mainwindow.controls.tbbZoomOut
                    set(zoom(obj.mainwindow.hfigure),'enable','on','direction','out');
                elseif source==obj.mainwindow.controls.tbbPan
                    pan(obj.mainwindow.hfigure,'on');
                elseif source==obj.mainwindow.controls.tbbDataCursor
                    datacursormode(obj.mainwindow.hfigure,'on');
                end
                source.set('Value',1);
            end  
        end
        
        % %%%%%%%%%%%%%%%%%%% TAB CHANGES %%%%%%%%%%%%%%%%%%%%%%%%%%%
        function cb_tabchanged(obj,source,event)
            switch event.newtab
                case 1  % Data
                    
                case 2  % Function
                    
                case 3  % Fit
                    
                    % If the fit function changed, update the fit table
                    if obj.quickfit.settings.session.state.functionchanged
                        obj.quickfit.settings.session.state.functionchanged = false;
                        obj.functionApply();
                    end 
                case 4  % Export
                    
            end
        end
        
        % %%%%%%%%%%%%%%%%%%% DATA TAB %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function cb_pbDataRemovePoints(obj,source,event)
            data = obj.quickfit.settings.session.data;
            
            if isempty(data.x) || isempty(data.y); return; end;
    
            hdlg = dialog('Name','Remove data points...','Position',[1 1 400 300],'Resize','Off','Visible','on','Toolbar','figure');
            movegui(hdlg,'center');

            ha = axes('Units','Pixels','Position',[1 40 399 241],'XTickLabel',[],'YTickLabel',[],'box','on');
            uicontrol(hdlg,'Style','pushbutton','Units','Pixels','Position',[138 5 60 30],'String','Ok','Callback',@okbtn);
            uicontrol(hdlg,'Style','pushbutton','Units','Pixels','Position',[202 5 60 30],'String','Cancel','Callback',@cancelbtn);
            hold(ha,'on');
            set(ha,'ButtonDownFcn',@clickaxes);

            % First plot only blue lines
            plot(ha,data.x,data.y,'-','Color',[0 0 1],'ButtonDownFcn',@clickaxes);
            % Plot all points in red. Then plot not-removed-points on top of it in blue, hiding the red squares. 
            % When the user clicks a blue squares, it is removed. When the user clicks a red square, the corresponding blue square is put back.
            ynotremoved = data.y; ynotremoved(logical(data.removedpoints)) = NaN;
            plot(ha,data.x,data.y,'s','MarkerFaceColor',[1 0 0],'MarkerEdgeColor',[1 0 0],'ButtonDownFcn',@clickaxes);
            pblue = plot(ha,data.x,ynotremoved,'s','MarkerFaceColor',[0 0 1],'MarkerEdgeColor',[0 0 1],'ButtonDownFcn',@clickaxes);

            
            % Temporary list of removed points
            removedpoints = data.removedpoints;

            drawnow;
            
            % Wait until dialog is closed.
            uiwait(hdlg);

            function okbtn(h,e)
                data.removedpoints = removedpoints;
                obj.quickfit.plotData();
                delete(hdlg);
            end
            
            function cancelbtn(h,e)
                delete(hdlg);
            end

            function clickaxes(h,e)
                point = get(ha,'CurrentPoint');
                ar = get(ha,'DataAspectRatio');
                
                dx = data.x;
                dy = data.y;
                
                % Calculate the distance of the clicked piont to each data
                % point, taking the aspect ratio of the plot into account
                distance = ((point(1,1)-dx)/ar(1)).^2 + ((point(1,2)-dy)/ar(2)).^2;
                [a,idx] = min(distance);
                
                if ~removedpoints(idx);
                    removedpoints(idx) = true;

                    % Remove point from blue plot
                    dy = get(pblue,'YData');
                    dy(idx) = NaN;
                    set(pblue,'YData',dy);
                else
                    removedpoints(idx) = false;

                    % Restore point in blue plot
                    ddy = get(pblue,'YData');
                    ddy(idx) = data.y(idx);
                    set(pblue,'YData',ddy);
                end
            end
        end
        
        function cb_pbDataFromPlot(obj,source,event)
            % Find any object that has x and y data (line, area, stem, errorbar, ...)
            obs = findobj('-property','XData','-property','YData');

            % Check if they have equal vector data, and make list of
            % descritpions
            S = {}; O = [];
            for i=1:length(obs)
                if isvector(obs(i).XData) && isequal(size(obs(i).XData),size(obs(i).YData))
                    % Find common style properties to help selection
                    ss='';
                    if isprop(obs(i), 'Marker'), ss = [ss, obs(i).Marker]; end
                    if isprop(obs(i), 'LineStyle'), ss = [ss, obs(i).LineStyle]; end

                    S{end+1} = sprintf('Figure %g, %s ''%s'', %.0f points', get(ancestor(obs(i),'Figure'),'Number'), obs(i).Type, ss,  length(obs(i).XData));
                    O(end+1) = obs(i);
                end
            end

            % Show list to user, and if user chooses one set data
            % programmatically
            if ~isempty(S)
                s = listdlg('ListString',S,'SelectionMode','single','ListSize',[300 400],'Name','Available plots');
                if ~isempty(s)
                    % Todo: figure out which properties to return and in which
                    % order
                    x = get(O(s),'XData');
                    y = get(O(s),'YData');
                    % Get also error bounds from errorbar object:
                    if isprop(O(s),'LData') && isequal(size(get(O(s),'LData')),size(get(O(s),'XData')))
                        e = get(O(s),'LData');
                    else
                        e = [];
                    end
                    obj.quickfit.setData(x,y,e);
                end
            end
        end
        
        function cb_pbDataApply(obj,source,event)
            obj.quickfit.dataApply();
        end
        
        % %%%%%%%%%%%%%%%%%%% FUNCTION TAB %%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function updateFunctionList(obj, selectstring)
            s = obj.quickfit.settings.functions;
            fnames = properties(s);
            
            if nargin<2
                curlist = obj.mainwindow.controls.pmFunction.get('String');
                curnum = obj.mainwindow.controls.pmFunction.get('Value');
                if ~isempty(curnum) && ~isempty(curlist) && curnum<=length(curlist)
                    selectstring = curlist{curnum};
                else
                    selectstring = '';
                end
            end
                
            % Try to find the current setting in the new list
            listidx = 0;
            if ~isempty(selectstring)
                idx = find(strcmp(fnames,selectstring));
                if ~isempty(idx)
                    listidx = idx;
                end
            end
            
            % Update list data
            obj.mainwindow.controls.pmFunction.set('String',[{'<Custom>'}; fnames]);
            obj.mainwindow.controls.pmFunction.set('Value',listidx+1);
            
            obj.cb_pmFunction(obj.mainwindow.controls.pmFunction);
        end 
        function functionChangedNow(obj,source,event)
            obj.quickfit.settings.session.state.functionchanged = true;
        end
        function cb_pmFunction(obj,source,~)
            names = source.get('string');
            name = names{source.get('value')};
            
            % Does function exist?
            if strcmp('<Custom>',name)
                obj.quickfit.settings.session.function.name = name;
            elseif isprop(obj.quickfit.settings.functions,name)
                % Set function to current (use StructData to make a copy
                % and not a reference)
                obj.quickfit.settings.session.function.putStructData(obj.quickfit.settings.functions.(name).getStructData, true);
                obj.quickfit.settings.session.state.functionchanged=true;
            end
        end
        
        function cb_tbbFunctionNew(obj,source,event)
            newname = inputdlg('Name:','New function');
            if ~isempty(newname) && ~isempty(newname{1})
                newname = genvarname(newname{1});
                
                % Already exists?
                if any(strcmp(properties(obj.quickfit.settings.functions),newname))
                    dialog('A function with that name already exists.','New function');
                    return
                end
                
                % Create new function
                newfun = quickfit.Engine.getDefaultFunction();
                newfun.name = newname;
                
                % Add to settings
                obj.quickfit.settings.functions.addSetting(newname,newfun);
                
                % Update list
                obj.updateFunctionList(newname);
            end
        end
        function cb_tbbFunctionSave(obj,source,event)
            name = obj.quickfit.settings.session.function.name;
            
            % Does function exist?
            if strcmp('<Custom>',name)
                obj.cb_tbbFunctionSaveAs(source,event);
            elseif isprop(obj.quickfit.settings.functions,name)
                % Copy function (use StructData to make a copy and not a reference)
                obj.quickfit.settings.functions.(name).putStructData(obj.quickfit.settings.session.function.getStructData, true);
                
                % To make sure we select the right function now
                obj.updateFunctionList(name);
            end
        end
        function cb_tbbFunctionSaveAs(obj,source,event)
            newname = inputdlg('Name:','Save function as');
            if ~isempty(newname) && ~isempty(newname{1})
                newname = genvarname(newname{1});
                
                % Already exists?
                if any(strcmp(properties(obj.quickfit.settings.functions),newname))
                    dialog('A function with that name already exists.','Save function as');
                    return
                end
                
                % Create new function
                newfun = quickfit.Engine.getDefaultFunction();
                % Copy function data (use StructData to make a copy and not a reference)
                newfun.putStructData(obj.quickfit.settings.session.function.getStructData, true);
                % Assign name
                newfun.name = newname;
                
                % Add to settings
                obj.quickfit.settings.functions.addSetting(newname,newfun);
                
                % Update list
                obj.updateFunctionList(newname)
            end
        end
        function cb_tbbFunctionDelete(obj,source,event)
            % This gets dubious, its possible to manually change the name
            name = obj.quickfit.settings.session.function.name;
            if strcmp('<Custom>',name), return; end
            
            if isprop(obj.quickfit.settings.functions,name)
                answ = questdlg(sprintf('Are you sure you want to delete the function ''%s''?',name),'Delete function','Delete','Cancel','Cancel');
                if strcmp(answ,'Delete')
                    obj.quickfit.settings.functions.removeSetting(name);
                    obj.updateFunctionList();
                end
            end
        end
        function cb_pbFunctionImport(obj,source,event)
            % Load functions from settings or function file
            [filename, pathname] = uigetfile({'*.mat';'*.*'}, 'Import functions');
            if (filename==0), return; end
            
            file = fullfile(pathname,filename);
            
            if exist(file,'file')
                saved = load(file);
                if isfield(saved,'info') && isstruct(saved.info) && isfield(saved.info, 'type') && ...
                        (strcmp(saved.info.type,'QuickfitFunctions') || strcmp(saved.info.type,'QuickfitSettings') ) && ...
                        isfield(saved,'settings') && isfield(saved.settings, 'functions')
                    
                    % Names of functions in file and in the current
                    % settings
                    newfunctions = fieldnames(saved.settings.functions);
                    oldfunctions = properties(obj.quickfit.settings.functions);
                    
                    % Find duplicates
                    [~, newindex] = intersect(newfunctions,oldfunctions);
                    
                    % Add * to duplicate functions
                    newfunctionlist = newfunctions; 
                    newfunctionlist(newindex) = strcat(newfunctionlist(newindex),' *');
                    selected = 1:length(newfunctionlist); selected(newindex) = [];
                    
                    % Ask which functions to import
                    toimport = listdlg('liststring',newfunctionlist,'initialvalue',selected,'promptstring',sprintf('Select functions to import:\n* = function already exists'),'listsize',[240 300],'name','Export functions');
                                        
                    % Import into settings
                    if ~isempty(toimport)
                        importdata = struct();
                        for i=toimport
                            importdata.(newfunctions{i}) = saved.settings.functions.(newfunctions{i});
                        end
                        obj.quickfit.settings.functions.putStructData(importdata, false, true);
                        
                        obj.updateFunctionList();
                    end
                    
                else
                    msgbox('The selected file does not appear to contain quickfit functions.');
                end
            else
                msgbox('File not found.');
            end
        end
        
        function cb_pbFunctionExport(obj,source,event)
            % Get all functions
            functions = properties(obj.quickfit.settings.functions);
            
            % Ask which ones to export
            toexport = listdlg('liststring',functions,'initialvalue',1:length(functions),'promptstring','Select functions to export:','listsize',[240 300],'name','Export functions');
            
            if ~isempty(toexport)

                % Get file name
                [filename, pathname] = uiputfile({'*.mat';'*.*'}, 'Export functions');
                if ~(filename==0)

                    file = fullfile(pathname,filename);

                    % Build export structure
                    tosave.info = struct('type','QuickfitFunctions','version',1);
                    for i = toexport
                        tosave.settings.functions.(functions{i}) = obj.quickfit.settings.functions.(functions{i}).getStructData();
                    end
                    
                    % Save
                    save(file,'-struct','tosave');
                end
            end
        end
        function cb_pbFunctionTest(obj,source,event)
            if quickfit.Engine.testFunction(obj.quickfit.settings.session.function)
                msgbox('The function evaluates without errors.');
            end
        end
        
        % %%%%%%%%%%%%%%%%%%% FIT TAB %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function cb_pbFitInitialsFromFit(obj,source,event)
            obj.quickfit.settings.session.fit.initials = obj.quickfit.settings.session.fit.results;
        end
        function cb_pbFitNew(obj,source,event)
        end
        function cb_pbFitClear(obj,source,event)
            obj.quickfit.clearTraces('initials','fit','fitconfidence');
            obj.updatePlots();
        end
        function cb_pbFitOptions(obj,source,event)
            % Note: Opening the "Fit Options" closes the settings editor,
            % and vice versa. They are the same thing anyway (except for
            % which settings object they edit).
%            if ~isempty(obj.settingseditor) && isvalid(obj.settingseditor), delete(obj.settingseditor); end
%            obj.settingseditor = cfw.SettingsEditor(obj.quickfit.settings.session.fitting);
            obj.showFitOptions();
        end
        function cb_pbFitPlotInitials(obj,source,event)
            obj.quickfit.plotInitials();
        end
        function cb_pbFitFit(obj,source,event)
            obj.quickfit.doFit();
        end
        
        % %%%%% Code for Fit table, wich is directly linked to
        % obj.quickfit.settings.session.fit
        function setupFitTable(obj)
            tFit = obj.mainwindow.controls.tableFit;
            
            % Names of the settings in session.fit corresponding to each
            % column
            settings = {'','fixedparams','initials','lb','ub','results','confidence'};
            
            % Set column names and properties
            tFit.columnnames = {'Name','Fixed','Initial value','Lower bound','Upper bound','Fit result','68% Confidence'};
            tFit.set('ColumnWidth',{120 50 100 100 100 100 100});
            tFit.set('ColumnEditable',[false true true true true false false])
            tFit.set('RowName',[])

            % Add event listener to table
            addlistener(tFit, 'DataChanged', @obj.cb_tableFitDataChanged);
            
            % Add event listener to each setting
            for i = 2:length(settings)
                % Set up listener
                obj.quickfit.settings.session.fit.addListener(settings{i}, @obj.cb_tableFitSettingChanged);
            end
            
            % Fill table
            obj.mainwindow.controls.tableFit.tag = settings;
            obj.mainwindow.controls.tableFit.data = [];
        end
        function cb_pbFitReset(obj,source,event)
            obj.functionApply(true);
        end
        
        % This sets the current function, like the apply button in the old
        % quickfit, but in stead it happens only automatically when the tab
        % changes
        % This function changes both the fit table and the settings under
        % session.fit
        function functionApply(obj,reset)   
            if nargin<2, reset=false; end;
            f = obj.quickfit.settings.session.function;
            
            % Get current table content
            olddata = obj.mainwindow.controls.tableFit.data;
            if isempty(olddata), pnames = {}; else pnames = olddata(:,1); end

            % Save current variables
            oldfixedparams = obj.quickfit.settings.session.fit.fixedparams;
            oldinitials = obj.quickfit.settings.session.fit.initials;
            oldlb = obj.quickfit.settings.session.fit.lb;
            oldub = obj.quickfit.settings.session.fit.ub;
            oldresults = obj.quickfit.settings.session.fit.results;
            oldconfidence = obj.quickfit.settings.session.fit.confidence;
            
            np = length(f.parameters);
            
            % Set new table data to correct size, and insert parameter names
            newdata = cell(np,7);
            newdata(:,1) = f.parameters;
            obj.mainwindow.controls.tableFit.data = newdata;
            
            % Evaluate initial values
            data = obj.quickfit.settings.session.data;
            initials = quickfit.Engine.evalXY(data.x,data.y,data.ystd,1:length(data.x), f.initials);
            
            % Reset all variables, to make sure they actually change value
            % and the events get triggered
            obj.quickfit.settings.session.fit.results = [];
            obj.quickfit.settings.session.fit.confidence = [];
            obj.quickfit.settings.session.fit.fixedparams = [];
            obj.quickfit.settings.session.fit.initials = [];
            obj.quickfit.settings.session.fit.lb = [];
            obj.quickfit.settings.session.fit.ub = [];
            
            % Set default input variables
            obj.quickfit.settings.session.fit.fixedparams = false(1,np);
            obj.quickfit.settings.session.fit.initials = initials;
            obj.quickfit.settings.session.fit.lb = -inf(1,np);
            obj.quickfit.settings.session.fit.ub = inf(1,np);
                        
            if ~reset
                % Loop over parameters to see if some have the same name as
                % before, and keep settings for those
                for i = 1:np;
                    % Already in old table?
                    old = cellfun(@(x)strcmp(x,f.parameters{i}),pnames);
                    if any(old)
                        % Keep old data
                        o = find(old,1);
                        obj.quickfit.settings.session.fit.fixedparams(i) = oldfixedparams(o);
                        obj.quickfit.settings.session.fit.initials(i) = oldinitials(o);
                        obj.quickfit.settings.session.fit.lb(i) = oldlb(o);
                        obj.quickfit.settings.session.fit.ub(i) = oldub(o);
                    end
                end
            end
            
            obj.mainwindow.controls.txtFitFunction.set('String',['y = ',f.equation]);
        end
        
        function functionRestore(obj, fstruct)
            % Apply function to the table when loading a session. In this
            % case, all the variables are kept
            np = length(fstruct.parameters);
            
            % Set new table data to correct size, and insert parameter names
            newdata = cell(np,7);
            newdata(:,1) = fstruct.parameters;
            obj.mainwindow.controls.tableFit.data = newdata;
            
            % Make sure the function will not be reset when next changing
            % tab to Fit
            obj.quickfit.settings.session.state.functionchanged = false;
            
            % Loading the data will automaticall fill the rest of the table
        end
        
        % Executed when the user changes one of the quick settings
        function cb_tableFitDataChanged(obj,source,event)
            sname = source.tag{event.column};
            if ~isempty(sname)
                if ischar(event.newvalue)
                    try
                        val = evalin('base',event.newvalue);
                        if ~isnumeric(val) && ~islogical(val)
                            val = nan;
                        end 
                    catch
                        val = nan;
                    end
                else
                    val = event.newvalue;
                end 
                try
                    obj.quickfit.settings.session.fit.(sname)(event.row) = val;
                catch
                    obj.quickfit.settings.session.fit.(sname)(event.row) = nan;
                end
            end
        end
        % Executed when a setting is changed in code: update table
        % note: source = the setting
        function cb_tableFitSettingChanged(obj,source,event)
             cols = cellfun(@(x)strcmp(x,event.name), obj.mainwindow.controls.tableFit.tag);
             col = find(cols, 1,'first');

             if ~isempty(col)
                 try
                    if isnumeric(event.newvalue)
                        celldata = arrayfun(@(x)num2str(x,6), event.newvalue,'uniformoutput',false);
                    else
                        celldata = num2cell(event.newvalue); 
                    end
                    obj.mainwindow.controls.tableFit.data(:,col) = celldata;
                 catch
                 end
             end
        end

        function updatePlots(obj,style,haxes,showlegend)
            if ~exist('style','var'), style = 'main'; end
            if ~exist('haxes','var'), haxes = obj.mainwindow.controls.axesMain.handle; end
            if ~exist('showlegend','var'), showlegend = false; end
            traces = obj.quickfit.settings.session.traces;
            
            cla(haxes);
            hold(haxes,'on');
            
            legendhandles = [];
            legendstrings = {};
            
            % Loop over all traces
            for i=1:length(traces)
                ts = traces(i);
                
                % Loop over all traces (there might be multiple)
                if ts.enabled.(style)
                    % Plot the trace
                    tplot = plot(haxes,ts.x, ts.y);

                    % Loop over all specified plotstyles and apply tot
                    % he plot
                    fn = fieldnames(ts.plotstyle);
                    for k = 1:length(fn)
                        set(tplot, fn{k}, ts.plotstyle.(fn{k}));
                    end
                    
                    if showlegend && ts.enabled.legend
                        legendhandles(end+1) = tplot;
                        legendstrings{end+1} = ts.legendname;
                    end
                end
            end
            
            if showlegend && ~isempty(legendhandles)
                legend(haxes, legendhandles, legendstrings);
            end
            
            % Call resize handler to make sure the axes tick marks fit in
            % the window
            obj.mainwindow.cb_ResizeFcn();
        end
        
        % Functions for linksetting between trace table and traces
        function cb_tableExportSettingChanged(obj,source,event)            
            traces = event.newvalue;
            tdata = {};
            
            % Loop over all traces
            for i=1:length(traces)
                ts = traces(i);
                
                % Loop over all traces (there might be multiple)
                tdata(end+1,:) = {ts.enabled.export, ts.type, ts.enabled.legend, ts.legendname};
            end
            obj.mainwindow.controls.tableExportTraces.data = tdata;
        end
        
        function cb_tableExportDataChanged(obj,source,event)
            session = obj.quickfit.settings.session;
            tdata = source.data;
            
            if length(session.traces) == size(tdata,1)
                for i=1:length(session.traces)
                    session.traces(i).enabled.export = tdata{i,1};
                    session.traces(i).enabled.legend = tdata{i,3};
                    session.traces(i).legendname = tdata{i,4};
                end
            end
        end
        
        function cb_pbExportApply(obj,source,event)
            export = obj.quickfit.settings.session.export;
            
            if isempty(obj.exportfigurehandle) || ~ishandle(obj.exportfigurehandle)
                obj.exportfigurehandle = figure('integerhandle','off','name','Quickfit export','units','centimeters','paperunits','centimeters','paperpositionmode','auto');
                p = get(obj.exportfigurehandle, 'position');
                set(obj.exportfigurehandle,'position', [p(1:2), 12, 10]);
            end
            
            figure(obj.exportfigurehandle);
            clf(obj.exportfigurehandle);
%            set(obj.exportfigurehandle,'resizefcn',@export_resize);
            
            % Define axes
            margins = [0.11 0.13 0.02 0.09]; % left bottom right top
            sep = 0.032;
            mainheight = 1-margins(4)-margins(2); 
            mainpos = margins(2);
            if export.showfitresults
                htext = annotation('textbox',[margins(1) 1-margins(4) 0 0],...
                    'string',obj.quickfit.settings.session.fit.resulttext,...
                    'BackgroundColor','white','linestyle','-','margin',4,'fitboxToText','on');
                drawnow;
                textpos = get(htext,'position');
                if textpos(3) < 1-margins(3)-margins(1)
                    textpos = textpos.*[1 1 0 1] + [0 0 1-margins(3)-margins(1) 0];
                end
                %textpos = textpos + [0 0.02 0 -0.02]; % Fix the margins
                set(htext,'position',textpos);
                mainheight = mainheight - textpos(4) - sep;
            end
            if export.showresiduals
                resheight = mainheight*0.35;
                mainheight = mainheight - resheight;
                mainpos = mainpos + resheight;
                hresid = axes('position',[margins(1) margins(2) 1-margins(3)-margins(1) resheight-sep]);
            end            
            hmain = axes('position',[margins(1) mainpos 1-margins(3)-margins(1) mainheight]);
            
            % Plot data
            obj.updatePlots('export',hmain,export.showlegend);
            
            % Set title and labels
            if export.showresiduals
                obj.updatePlots('residual',hresid)
                xlabel(hresid, export.xlabel);
                ylabel(hresid, 'Residual');
                set(hresid,'box','on');
                set(hmain,'box','on','xticklabel',[]);
                
                linkaxes([hmain, hresid],'x');
            else
                xlabel(hmain, export.xlabel);
            end
            ylabel(hmain, export.ylabel);
            title(hmain, export.title);
            set(hmain,'box','on');
            if export.showfitresults
                % Move title to be above the fit result table.
                % note: title position is in normalized _axes_ units, so we scale from normalized figure units.
                htitle = get(hmain,'title');
                set(htitle,'units','normalized');
                titlepos = get(htitle,'position');
                set(htitle,'position',titlepos + [0 (textpos(4)+sep)/mainheight 0]);
            end
        end
    end 
    
    methods (Access = protected)
        function buildMainWindow(obj)
            % Make window and set its properties
            w = cfw.CWindow();
            obj.mainwindow = w;
            
            w.set('Name',['Quickfit']);
            w.set('Position',[1 1 700 600]);
            movegui(w.hfigure,'center');
            
            % Get the figure's datacursormode, and set the update function
            hdcm = datacursormode(w.hfigure);
            set(hdcm,'UpdateFcn',@obj.datacursorupdatefcn)

            addlistener(w,'Close',@obj.cb_closemainwindow);
            
            % Main grid (toolbar, axes, controls)
            maingrid = cfw.CGridLayout();
            w.control = maingrid;
            maingrid.setRows({'pixels','pixels','normalized'},[220 31 1]);
            maingrid.setColumns({'normalized'},[1]);
            
            % Add axes
            w.addNamedControl('axesMain',maingrid.addChild(cfw.CAxes([],'box','on'),[3 1]));
            w.controls.axesMain.positionmode= 'tightinset';
            %w.controls.axesMain.set('ButtonDownFcn', @obj.cb_axesmainbuttondown);
           
            % Add toolbar grid
            tbimgs = load(fullfile(fileparts(mfilename('fullpath')), 'toolbarimgs.mat'));
            tbgrid = maingrid.addChild(cfw.CGridLayout([]),[2 1]);
            bx = 28;
            tbgrid.setColumns({'normalized','pixels','pixels','pixels','pixels','pixels','pixels','pixels','pixels','pixels','pixels'},[1 bx bx bx 8 bx 8 bx bx bx bx]);
            tbgrid.margin = [-1 -1 -1 -1]*0.5;
            
            % Session tools
           % w.addNamedControl('tbbNew', tbgrid.addChild(cfw.CUIControl([],'style','pushbutton','CData',tbimgs.new),[1 2]));
            w.addNamedControl('tbbLoad', tbgrid.addChild(cfw.CUIControl([],'style','pushbutton','CData',tbimgs.open),[1 3]));
            addlistener(w.controls.tbbLoad, 'Callback', @obj.cb_tbbLoad);
            w.addNamedControl('tbbSave', tbgrid.addChild(cfw.CUIControl([],'style','pushbutton','CData',tbimgs.save),[1 4]));
            addlistener(w.controls.tbbSave, 'Callback', @obj.cb_tbbSave);
            
            % Settings
            w.addNamedControl('tbbSettings', tbgrid.addChild(cfw.CUIControl([],'style','pushbutton','CData',tbimgs.settings),[1 6]));
            addlistener(w.controls.tbbSettings, 'Callback', @obj.cb_tbbSettings);
            
            % Zoom etc tools
            w.addNamedControl('tbbZoomIn', tbgrid.addChild(cfw.CUIControl([],'style','togglebutton','CData',tbimgs.zplus),[1 8]));
            w.addNamedControl('tbbZoomOut', tbgrid.addChild(cfw.CUIControl([],'style','togglebutton','CData',tbimgs.zmin),[1 9]));
            w.addNamedControl('tbbPan', tbgrid.addChild(cfw.CUIControl([],'style','togglebutton','CData',tbimgs.pan),[1 10]));
            w.addNamedControl('tbbDataCursor', tbgrid.addChild(cfw.CUIControl([],'style','togglebutton','CData',tbimgs.datacursor),[1 11]));
            addlistener(w.controls.tbbZoomIn, 'Callback', @obj.cb_plottools_callback);
            addlistener(w.controls.tbbZoomOut, 'Callback', @obj.cb_plottools_callback);
            addlistener(w.controls.tbbPan, 'Callback', @obj.cb_plottools_callback);
            addlistener(w.controls.tbbDataCursor, 'Callback', @obj.cb_plottools_callback);
            
            % Tab control
            w.addNamedControl('tab', maingrid.addChild(cfw.CTabbedDialog([],'Data','Function','Fit','Export'),[1 1],[2 1]));
            addlistener(w.controls.tab, 'TabChanged', @obj.cb_tabchanged);
            
            % %%%% Data tab %%%%
            tab = w.controls.tab.tabs(1);
            grid = tab.addChild(cfw.CGridLayout([]));
            grid.setRows({'pixels' , 'normalized',  'pixels', 'pixels', 'pixels', 'pixels', 'pixels', 'pixels'},[35 1 28 28 28 28 28 22]);
            grid.setColumns({'pixels',  'pixels', 'pixels', 'pixels','normalized','pixels', 'pixels'}, [80 100 100 100 1 83 17]);
            grid.margin = [3 3 3 3];
            grid.addChild(cfw.CUIControl([], 'style','text','string','Enter Matlab expressions for x and y data and click Apply:','horizontalalignment','left'),[8 1],[1 7]);
            
            % x, y, std(y)
            grid.addChild(cfw.CUIControl([0 0 1 0.8],'style','text','string','x = ','horizontalalignment','right'),[7 1]);
            w.addNamedControl('pmDataX',  grid.addChild(cfw.CUIControl([],'style','popupmenu','string',{'...'},'horizontalalignment','left'),[7 2],[1 6]));
            w.addNamedControl('txtDataX', grid.addChild(cfw.CUIControl([],'style','edit','string','','horizontalalignment','left'),[7 2],[1 5]));
            obj.linkSetting(w.controls.txtDataX, 'String', obj.quickfit.settings.session.data, 'xname',@(s)s,@(s)s);
            addlistener(w.controls.pmDataX,'Callback',@(s,e)set(obj.quickfit.settings.session.data,'xname',obj.celltake(s.get('String'),s.get('Value'))));
            
            grid.addChild(cfw.CUIControl([0 0 1 0.8],'style','text','string','y = ','horizontalalignment','right'),[6 1]);
            w.addNamedControl('pmDataY',  grid.addChild(cfw.CUIControl([],'style','popupmenu','string',{'...'},'horizontalalignment','left'),[6 2],[1 6]));
            w.addNamedControl('txtDataY', grid.addChild(cfw.CUIControl([],'style','edit','string','','horizontalalignment','left'),[6 2],[1 5]));
            obj.linkSetting(w.controls.txtDataY, 'String', obj.quickfit.settings.session.data, 'yname',@(s)s,@(s)s);
            addlistener(w.controls.pmDataY,'Callback',@(s,e)set(obj.quickfit.settings.session.data,'yname',obj.celltake(s.get('String'),s.get('Value'))));

            grid.addChild(cfw.CUIControl([0 0 1 0.8],'style','text','string','std(y) = ','horizontalalignment','right'),[5 1]);
            w.addNamedControl('pmDataYStd',  grid.addChild(cfw.CUIControl([],'style','popupmenu','string',{'...'},'horizontalalignment','left'),[5 2],[1 6]));
            w.addNamedControl('txtDataYStd', grid.addChild(cfw.CUIControl([],'style','edit','string','','horizontalalignment','left'),[5 2],[1 5]));
            obj.linkSetting(w.controls.txtDataYStd, 'String', obj.quickfit.settings.session.data, 'ystdname',@(s)s,@(s)s);
            addlistener(w.controls.pmDataYStd,'Callback',@(s,e)set(obj.quickfit.settings.session.data,'ystdname',obj.celltake(s.get('String'),s.get('Value'))));
            
            % Fill x,y,std(y) popupmenus with all available variables
            % List numeric arrays in base workspace    
            s = evalin('base','whos');
            vars = {};
            for i=1:length(s)
                switch s(i).class
                    case {'double','single','int8','int16','int32','int64','uint8','uint16','uint32','uint64'}
                        if prod(s(i).size)~=1
                            vars = [vars,s(i).name];    
                        end
                end
            end
            if ~isempty(vars)
                w.controls.pmDataX.set('String',vars);
                w.controls.pmDataY.set('String',vars);
                w.controls.pmDataYStd.set('String',vars);
            end
 
            % Fit range
            grid.addChild(cfw.CUIControl([0 0 1 0.8],'style','text','string','Fit range: ','horizontalalignment','left'),[4 1]);
            %w.addNamedControl('pmFitRangeMode', grid.addChild(cfw.CUIControl([],'style','popupmenu','string',{'x','index'}),[4 2],[1 1]));
            %obj.linkSetting(w.controls.pmFitRangeMode, 'Value', obj.quickfit.settings.session.data, 'fitrangemode',@(s)int32(s));

            w.addNamedControl('txtFitRange', grid.addChild(cfw.CUIControl([],'style','edit','string','','horizontalalignment','left'),[4 2],[1 3]));
            obj.linkSetting(w.controls.txtFitRange, 'String', obj.quickfit.settings.session.data, 'fitrangename',@(s)s,@(s)s);            
            grid.addChild(cfw.CUIControl([0 0 1 0.8],'style','text','string','Condition as function of x, y, ystd and index.','horizontalalignment','left'),[4 5],[1 2]);
            
            % X model
            grid.addChild(cfw.CUIControl([0 0 1 0.8],'style','text','string','x for plot: ','horizontalalignment','left'),[3 1]);
            w.addNamedControl('txtXModel', grid.addChild(cfw.CUIControl([],'style','edit','string','linspace(min(x), max(x), 1000)','horizontalalignment','left'),[3 2],[1 3]));
            obj.linkSetting(w.controls.txtXModel, 'String', obj.quickfit.settings.session.data, 'xmodelname', @(s)s,@(s)s);

            % Buttons on the bottom
            w.addNamedControl('pbDataRemovePoints', grid.addChild(cfw.CUIControl([],'style','pushbutton','string','Remove points'), [1 2]));
            w.addNamedControl('pbDataFromPlot', grid.addChild(cfw.CUIControl([],'style','pushbutton','string','Get from plot'), [1 3]));
            %w.addNamedControl('pbData...', grid.addChild(cfw.CUIControl([],'style','pushbutton','string','...'), [1 4]));
            w.addNamedControl('pbDataApply', grid.addChild(cfw.CUIControl([],'style','pushbutton','string','Apply'), [1 6],[1 2]));
            addlistener(w.controls.pbDataRemovePoints, 'Callback', @obj.cb_pbDataRemovePoints);
            addlistener(w.controls.pbDataFromPlot, 'Callback', @obj.cb_pbDataFromPlot);
            addlistener(w.controls.pbDataApply, 'Callback', @obj.cb_pbDataApply);
            
            % %%%% Function tab %%%%
            tab = w.controls.tab.tabs(2);
            grid = tab.addChild(cfw.CGridLayout([]));
            grid.setRows({'pixels' , 'normalized',  'pixels', 'pixels', 'pixels', 'pixels', 'pixels', 'pixels'},[35 1 28 28 28 28 28 22]);
            grid.setColumns({'pixels', 'normalized', 'pixels', 'pixels'}, [80 1 140 100]);
            grid.margin = [3 3 3 3];
            grid.addChild(cfw.CUIControl([], 'style','text','string','Select the fit function to use.','horizontalalignment','left'),[8 1],[1 4]);
            
            grid.addChild(cfw.CUIControl([0 0 1 0.8],'style','text','string','Function:','horizontalalignment','left'),[7 1]);
            w.addNamedControl('pmFunction',  grid.addChild(cfw.CUIControl([],'style','popupmenu','string',{'<Custom>'},'horizontalalignment','left'),[7 2],[1 1]));
            addlistener(w.controls.pmFunction,'Callback',@obj.cb_pmFunction);
            
            % Add grid for library new/save/etc buttons
            tbgrid = grid.addChild(cfw.CGridLayout([0 0 1 1.1]),[7 3],[1 2]);
            tbgrid.setColumns({'pixels','pixels','pixels','pixels','normalized','normalized'},[bx bx bx bx 1 1]);
            tbgrid.margin = [-1 -1 -1 -1]*0.5;
            
            % Function new/save/etc buttons
            w.addNamedControl('tbbFunctionNew', tbgrid.addChild(cfw.CUIControl([],'style','pushbutton','CData',tbimgs.new,'TooltipString','New function'),[1 1]));
            w.addNamedControl('tbbFunctionSave', tbgrid.addChild(cfw.CUIControl([],'style','pushbutton','CData',tbimgs.save,'TooltipString','Save function'),[1 2]));
            w.addNamedControl('tbbFunctionSaveAs', tbgrid.addChild(cfw.CUIControl([],'style','pushbutton','CData',tbimgs.saveas,'TooltipString','Save function as...'),[1 3]));
            w.addNamedControl('tbbFunctionDelete', tbgrid.addChild(cfw.CUIControl([],'style','pushbutton','CData',tbimgs.delete,'TooltipString','Delete function'),[1 4]));
            addlistener(w.controls.tbbFunctionNew,'Callback',@obj.cb_tbbFunctionNew);
            addlistener(w.controls.tbbFunctionSave,'Callback',@obj.cb_tbbFunctionSave);
            addlistener(w.controls.tbbFunctionSaveAs,'Callback',@obj.cb_tbbFunctionSaveAs);
            addlistener(w.controls.tbbFunctionDelete,'Callback',@obj.cb_tbbFunctionDelete);
            
            w.addNamedControl('pbFunctionImport', tbgrid.addChild(cfw.CUIControl([],'style','pushbutton','String','Import'),[1 5]));
            w.addNamedControl('pbFunctionExport', tbgrid.addChild(cfw.CUIControl([],'style','pushbutton','String','Export'),[1 6]));
            addlistener(w.controls.pbFunctionImport,'Callback',@obj.cb_pbFunctionImport);
            addlistener(w.controls.pbFunctionExport,'Callback',@obj.cb_pbFunctionExport);
            
            grid.addChild(cfw.CUIControl([0 0 1 0.8],'style','text','string','Description:','horizontalalignment','left'),[6 1]);
            w.addNamedControl('txtFunctionDescription', grid.addChild(cfw.CUIControl([],'style','edit','string','','horizontalalignment','left'),[6 2],[1 3]));
            obj.linkSetting(w.controls.txtFunctionDescription, 'String', obj.quickfit.settings.session.function, 'description', @(s)s,@(s)s);
            addlistener(w.controls.txtFunctionDescription, 'Callback', @obj.functionChangedNow);
            
            grid.addChild(cfw.CUIControl([0 0 1 0.8],'style','text','string','Parameters:','horizontalalignment','left'),[5 1]);
            w.addNamedControl('txtFunctionParameters',  grid.addChild(cfw.CUIControl([],'style','edit','string','a,b','horizontalalignment','left'),[5 2],[1 1]));
            grid.addChild(cfw.CUIControl([0 0 1 0.8],'style','text','string','Comma-separated list of variable names.','horizontalalignment','left'),[5 3],[1 2]);
            obj.linkSetting(w.controls.txtFunctionParameters, 'String', obj.quickfit.settings.session.function, 'parameters', @(s)obj.join(', ',s), @(s)obj.split(',',s));
            addlistener(w.controls.txtFunctionParameters, 'Callback', @obj.functionChangedNow);
            
            grid.addChild(cfw.CUIControl([0 0 1 0.8],'style','text','string','Equation: y =','horizontalalignment','left'),[4 1]);
            w.addNamedControl('txtFunctionEquation', grid.addChild(cfw.CUIControl([],'style','edit','string','a*x + b','horizontalalignment','left'),[4 2],[1 3]));
            obj.linkSetting(w.controls.txtFunctionEquation, 'String', obj.quickfit.settings.session.function, 'equation', @(s)s,@(s)s);
            addlistener(w.controls.txtFunctionEquation, 'Callback', @obj.functionChangedNow);
            
            grid.addChild(cfw.CUIControl([0 0 1 0.8],'style','text','string','Initial values:','horizontalalignment','left'),[3 1]);
            w.addNamedControl('txtFunctionInitials',  grid.addChild(cfw.CUIControl([],'style','edit','string','[1 0]','horizontalalignment','left'),[3 2],[1 1]));
            grid.addChild(cfw.CUIControl([0 0 1 0.8],'style','text','string','Matlab expression that evaluates to a list','horizontalalignment','left'),[3 3],[1 2]);
            obj.linkSetting(w.controls.txtFunctionInitials, 'String', obj.quickfit.settings.session.function, 'initials', @(s)s,@(s)s);
            addlistener(w.controls.txtFunctionInitials, 'Callback', @obj.functionChangedNow);
            
            % Buttons on the bottom
            w.addNamedControl('pbFunctionTest', grid.addChild(cfw.CUIControl([],'style','pushbutton','string','Test'), [1 1],[1 1]));
            addlistener(w.controls.pbFunctionTest, 'Callback', @obj.cb_pbFunctionTest);
            
            % %%%% Fit tab %%%%
            tab = w.controls.tab.tabs(3);
            grid = tab.addChild(cfw.CGridLayout([]));
            grid.setRows({'pixels', 'normalized',  'pixels'},[35 1 22]);
            grid.setColumns({'pixels','pixels','pixels','pixels','normalized', 'pixels','pixels'}, [100 100 100 100 1 100 100]);
            grid.margin = [3 3 3 3];
            
            % Fit result table
            w.addNamedControl('txtFitFunction', grid.addChild(cfw.CUIControl([],'style','text','string','y = a*x + b','horizontalalignment','left'),[3 1],[1 7]));
            w.addNamedControl('tableFit', grid.addChild(cfw.CUITable([]),[2 1],[1 7]));
            obj.setupFitTable();
            
            % Buttons on the bottom
            w.addNamedControl('pbFitInitialsFromFit', grid.addChild(cfw.CUIControl([],'style','pushbutton','string','Initials <== Fit'), [1 1]));
            %w.addNamedControl('pbFitNew', grid.addChild(cfw.CUIControl([],'style','pushbutton','string','New fit'), [1 2]));
            w.addNamedControl('pbFitClear', grid.addChild(cfw.CUIControl([],'style','pushbutton','string','Clear plot'), [1 3]));
            w.addNamedControl('pbFitOptions', grid.addChild(cfw.CUIControl([],'style','pushbutton','string','Options'), [1 4]));
            w.addNamedControl('pbFitPlotInitials', grid.addChild(cfw.CUIControl([],'style','pushbutton','string','Plot initials'), [1 6]));
            w.addNamedControl('pbFitFit', grid.addChild(cfw.CUIControl([],'style','pushbutton','string','Fit'), [1 7]))
            addlistener(w.controls.pbFitInitialsFromFit,'Callback',@obj.cb_pbFitInitialsFromFit);
            %addlistener(w.controls.pbFitNew,'Callback',@obj.cb_pbFitNew);
            addlistener(w.controls.pbFitClear,'Callback',@obj.cb_pbFitClear);
            addlistener(w.controls.pbFitOptions,'Callback',@obj.cb_pbFitOptions);
            addlistener(w.controls.pbFitPlotInitials,'Callback',@obj.cb_pbFitPlotInitials);
            addlistener(w.controls.pbFitFit,'Callback',@obj.cb_pbFitFit);
            
            w.addNamedControl('pbFitReset', grid.addChild(cfw.CUIControl([],'style','pushbutton','string','Reset'), [1 2],[1 1]));
            addlistener(w.controls.pbFitReset, 'Callback', @obj.cb_pbFitReset);
                        
            % %%%% Export tab %%%%
            tab = w.controls.tab.tabs(4);
            grid = tab.addChild(cfw.CGridLayout([]));
            grid.setRows({'pixels' , 'normalized',  'pixels', 'pixels', 'pixels', 'pixels', 'pixels', 'pixels','pixels'},[35 1 22 22 22 28 28 28 22]);
            grid.setColumns({'pixels','normalized','normalized','pixels'}, [80 1.2 0.8 100]);
            grid.margin = [3 3 3 3];
            grid.addChild(cfw.CUIControl([], 'style','text','string','Export data and fit to a matlab figure:','horizontalalignment','left'),[9 1],[1 2]);
            grid.addChild(cfw.CUIControl([], 'style','text','string','Select traces to include in plot:','horizontalalignment','left'),[9 3],[1 2]);
            
            % title, labels
            grid.addChild(cfw.CUIControl([0 0 1 0.8],'style','text','string','Title: ','horizontalalignment','left'),[8 1]);
            w.addNamedControl('txtExportTitle', grid.addChild(cfw.CUIControl([],'style','edit','string','','horizontalalignment','left'),[8 2],[1 1]));
            obj.linkSetting(w.controls.txtExportTitle, 'String', obj.quickfit.settings.session.export, 'title',@(s)s,@(s)s);
            
            grid.addChild(cfw.CUIControl([0 0 1 0.8],'style','text','string','x label: ','horizontalalignment','left'),[7 1]);
            w.addNamedControl('txtExportXLabel', grid.addChild(cfw.CUIControl([],'style','edit','string','','horizontalalignment','left'),[7 2],[1 1]));
            obj.linkSetting(w.controls.txtExportXLabel, 'String', obj.quickfit.settings.session.export, 'xlabel',@(s)s,@(s)s);
            
            grid.addChild(cfw.CUIControl([0 0 1 0.8],'style','text','string','y label: ','horizontalalignment','left'),[6 1]);
            w.addNamedControl('txtExportYLabel', grid.addChild(cfw.CUIControl([],'style','edit','string','','horizontalalignment','left'),[6 2],[1 1]));
            obj.linkSetting(w.controls.txtExportYLabel, 'String', obj.quickfit.settings.session.export, 'ylabel',@(s)s,@(s)s);
                        
            w.addNamedControl('chkExportFitResults', grid.addChild(cfw.CUIControl([0 0 1 1],'style','checkbox','string','Show table of fit results','value',1,'horizontalalignment','left'),[5 2],[1 1]));
            obj.linkSetting(w.controls.chkExportFitResults, 'Value', obj.quickfit.settings.session.export, 'showfitresults',@(s)s,@(s)logical(s));
            
            w.addNamedControl('chkExportLegend', grid.addChild(cfw.CUIControl([0 0 1 1],'style','checkbox','string','Show legend','horizontalalignment','left'),[4 2],[1 1]));
            obj.linkSetting(w.controls.chkExportLegend, 'Value', obj.quickfit.settings.session.export, 'showlegend',@(s)s,@(s)logical(s));
            
            w.addNamedControl('chkExportResiduals', grid.addChild(cfw.CUIControl([0 0 1 1],'style','checkbox','string','Plot residuals','horizontalalignment','left'),[3 2],[1 1]));
            obj.linkSetting(w.controls.chkExportResiduals, 'Value', obj.quickfit.settings.session.export, 'showresiduals',@(s)s,@(s)logical(s));
            
            % Export traces table
            t = grid.addChild(cfw.CUITable([]),[2 3],[7 2]);
            w.addNamedControl('tableExportTraces', t);
                        
            % Set column names and properties
            t.columnnames = {'Plot','Type','Legend','Legend name'};
            t.set('ColumnWidth',{40 80 50 110});
            t.set('ColumnEditable',[true false true false])
            t.set('RowName',[])
            
            % Connect to data
            addlistener(t, 'DataChanged', @obj.cb_tableExportDataChanged);
            obj.quickfit.settings.session.addListener('traces', @obj.cb_tableExportSettingChanged);
            
            % Buttons on the bottom
            w.addNamedControl('pbExportApply', grid.addChild(cfw.CUIControl([],'style','pushbutton','string','Export'), [1 4]))
            addlistener(w.controls.pbExportApply,'Callback',@obj.cb_pbExportApply);
            
            w.show;
        end
               
        function showFitOptions(obj)
            % Close window if already open
            fitoptionslisteners = [];
            cb_closefitoptions();
                        
            % Make window and set its properties
            w = cfw.CWindow();
            obj.fitoptionswindow = w;
            addlistener(w,'Close',@cb_closefitoptions);
            addlistener(w,'Delete',@cb_closefitoptions);
            
            w.set('Name','Fit options');
            w.set('Position',[1 1 450 300]);
            movegui(w.hfigure,'center');

            %addlistener(w,'Close',@obj.cb_closemainwindow);

            % Main grid (toolbar, axes, controls)
            grid = cfw.CGridLayout();
            w.control = grid;
            grid.setRows({'pixels','normalized','pixels','pixels','pixels','pixels','pixels'},[28 1 22 22 22 22 22]);
            grid.setColumns({'pixels','normalized','pixels'},[120 1 100]);

            % Algorithm
            grid.addChild(cfw.CUIControl([0 0 1 0.8],'style','text','string','Algorithm: ','horizontalalignment','left'),[7 1]);
            w.addNamedControl('pmAlgorithm',  grid.addChild(cfw.CUIControl([],'style','popupmenu','string',obj.quickfit.availableAlgorithms,'horizontalalignment','left'),[7 2],[1 2]));
            j = find(strcmp(obj.quickfit.availableAlgorithms, obj.quickfit.settings.session.fitting.algorithm),1);
            if ~isempty(j)
                w.controls.pmAlgorithm.set('Value',j);
            end
            fitoptionslisteners = addlistener(w.controls.pmAlgorithm,'Callback',@(s,e)set(obj.quickfit.settings.session.fitting,'algorithm',obj.celltake(s.get('String'),s.get('Value'))));
            fitoptionslisteners(2) = event.listener(obj.quickfit.settings.session.fitting,'SettingChanged',@settingFittingChanged);
            
            % Scale
            w.addNamedControl('chkScaleParams',grid.addChild(cfw.CUIControl([0 0 1 0.8],'style','checkbox','string','Scale parameters by initial values','horizontalalignment','right'),[6 2],[1 2]));
            fitoptionslisteners(3:4) = obj.linkSetting(w.controls.chkScaleParams, 'Value', obj.quickfit.settings.session.fitting, 'scaleparameters',@(s)s,@(s)logical(s));
            set(w.controls.chkScaleParams.handle,'Value',obj.quickfit.settings.session.fitting.scaleparameters);

            % Get parameter confidence bounds?
            w.addNamedControl('chkParamConf',grid.addChild(cfw.CUIControl([0 0 1 0.8],'style','checkbox','string','Calculate parameter confidence bounds','horizontalalignment','right'),[5 2],[1 2]));
            fitoptionslisteners(5:6) = obj.linkSetting(w.controls.chkParamConf, 'Value', obj.quickfit.settings.session.fitting, 'paramconfidence',@(s)s,@(s)logical(s));
            set(w.controls.chkParamConf.handle,'Value',obj.quickfit.settings.session.fitting.paramconfidence);
            
            % Get value confidence bounds?
            w.addNamedControl('chkPredConf',grid.addChild(cfw.CUIControl([0 0 1 0.8],'style','checkbox','string','Calculate prediction confidence bounds','horizontalalignment','right'),[4 2],[1 2]));
            fitoptionslisteners(7:8) = obj.linkSetting(w.controls.chkPredConf, 'Value', obj.quickfit.settings.session.fitting, 'predconfidence',@(s)s,@(s)logical(s));
            set(w.controls.chkPredConf.handle,'Value',obj.quickfit.settings.session.fitting.predconfidence);
            
            % Other settings
            grid.addChild(cfw.CUIControl([0 0 1 0.8],'style','text','string','Fit options: ','horizontalalignment','left'),[3 1],[1 3]);
            tOpt = grid.addChild(cfw.CUITable([]),[2 1],[1 3]);
            w.addNamedControl('tableFit', tOpt);

            % Set column names and properties
            tOpt.columnnames = {'Option','Value','Description'};
            tOpt.set('ColumnWidth',{120 80 220});
            tOpt.set('ColumnEditable',[false true false])
            tOpt.set('RowName',[])

            % Fill table
            sobj = obj.quickfit.settings.session.fitting.options;
            names = sort(properties(sobj));
            data = cell(length(names),3);
            for s = 1:length(names)
                tdesc = sobj.getSettingMeta(names{s},'description');
                val = cfw.SettingsEditor.formatSetting(sobj,names{s});
                data(s,:) = {names{s}, val, tdesc};
            end
            tOpt.data = data;
            
            % Add event listener to table
            fitoptionslisteners(9) = addlistener(tOpt, 'DataChanged', @cb_tableChanged);
            fitoptionslisteners(10) = event.listener(obj.quickfit.settings.session.fitting.options,'SettingChanged',@cb_settingChanged);
            
            
            w.addNamedControl('pbClose', grid.addChild(cfw.CUIControl([],'style','pushbutton','string','Close'), [1 3]))
            addlistener(w.controls.pbClose,'Callback',@(s,e)delete(w));
              
            w.show;
            
            function settingFittingChanged(s,e)
                if strcmp(e.name,'algorithm')
                    strs = w.controls.pmAlgorithm.get('String');
                    i = find(strcmp(strs, e.newvalue),1);
                    if ~isempty(i)
                        w.controls.pmAlgorithm.set('Value',i);
                    end
                end
            end
            function cb_tableChanged(source,event)
                source.data{event.row,event.column} = event.oldvalue; 
                if event.column == 2
                    cfw.SettingsEditor.parseEdit(sobj, source.data{event.row,1}, event.newvalue);
                end
            end
            function cb_settingChanged(source,event)
                r = find(cellfun(@(x)strcmp(x,event.name), tOpt.data(:,1)));
                if ~isempty(r)
                    tOpt.data{r(1),2} = cfw.SettingsEditor.formatSetting(event.source, event.name);
                end
            end
            function cb_closefitoptions(~,~)
                % Delete all event listeners
                for i=1:length(fitoptionslisteners)
                    if isvalid(fitoptionslisteners(i))
                        delete(fitoptionslisteners(i));
                    end
                end
                
                % Delete window
                if ~isempty(obj.fitoptionswindow) && isvalid(obj.fitoptionswindow)
                    delete(obj.fitoptionswindow)
                    obj.fitoptionswindow = [];
                end
            end
        end
        
        % Setup a link between a CUIControl parameter (e.g., edit
        % box) and a setting.
        % parsefun and showfun can be used to alter the behaviour of
        % editing. If not supplied, the corresponding functiones of the
        % settingseditor are used.
        function listeners = linkSetting(obj, uiobj, uiparam, sobj, sparam, showfun, parsefun)
            % Default parse and show function
            if nargin<6 || isempty(showfun)
                showfun = @(v)cfw.SettingsEditor.formatSetting(sobj,sparam,v);
            end
            if nargin<7
                parsefun = [];
            end
            
            % Set up link from setting to control. SettingChanged is only
            % available for all settings within a category (sobj).
            % Therefore, we set up another function, that
            % compares the name of the setting. (sparam)
            l1 = addlistener(sobj,'SettingChanged', @(s,e) obj.linkSettingChangedCallback(s,e,sobj,sparam,showfun,uiobj,uiparam));
            
            % Set up link from control to setting.
            l2 = addlistener(uiobj, 'Callback', @(s,e) obj.linkControlChangedCallback(sobj,sparam,parsefun,uiobj,uiparam,showfun));
            
            listeners = [l1, l2];
        end
    end
    methods (Static)
        function linkSettingChangedCallback(s,e,sobj,sparam,showfun,uiobj,uiparam)
            if strcmp(sparam, e.name)
                uiobj.set(uiparam, showfun(sobj.(sparam)));
            end
        end
        function linkControlChangedCallback(sobj,sparam,parsefun,uiobj,uiparam,showfun)
            if isempty(parsefun)
                baccept = cfw.SettingsEditor.parseEdit(sobj,sparam,uiobj.get(uiparam));
            else
                baccept = true;
                try
                    sobj.(sparam) = parsefun(uiobj.get(uiparam));
                catch e
                    disp('Parse error: '); disp(e.message);
                    baccept = false;
                end
            end
            if ~baccept
                % If something failed, set the uicontrol back to the actual
                % value to indicate failure.
                uiobj.set(uiparam, showfun(sobj.(sparam)));
            end
        end
        % The actual update function
        function txt = datacursorupdatefcn(source,event)
            pos = get(event,'Position');
            txt = {['X: ',num2str(pos(1),10)],...
                ['Y: ',num2str(pos(2),10)]};

            % If there is a Z-coordinate in the position, display it as well
            if length(pos) > 2
                txt{end+1} = ['Z: ',num2str(pos(3),10)];
            end

            % If a DataIndex is available, show that also:
            info = getCursorInfo(datacursormode(ancestor(event.Target, 'figure')));
            if isfield(info,'DataIndex')
                txt{end+1} = ['Index: ', num2str(info.DataIndex)];
            end
        end
        function s = join(d,varargin)
        
            if (isempty(varargin)), 
                s = '';
            else
                if (iscell(varargin{1}))
                    s = quickfit.UI.join(d, varargin{1}{:});
                else
                    s = varargin{1};
                end

                for ss = 2:length(varargin)
                    s = [s d quickfit.UI.join(d, varargin{ss})];
                end
            end
        end
        function c = split(d, s)
            if isempty(s)
                c = {};
            else
                c = textscan(s,'%s','delimiter',d);
                if ~isempty(c),c = c{1};end
            end
        end
        function el = take(x,varargin)
            % el = take(m,index1,index2,...)
            %   Matrix indexing on matrix m.
            %
            %   take(m,index1,index2,...) = m(index1,index2,...)
            %
            %   Each index can either be a list (e.g. 1:10) or the string ':'
            s.type = '()';      % Use matrix indexing
            s.subs = varargin;

            el = subsref(x,s);
        end
        function el = celltake(x,varargin)
            s.type = '{}';      % Use cell  indexing
            s.subs = varargin;

            el = subsref(x,s);
        end
    end
end