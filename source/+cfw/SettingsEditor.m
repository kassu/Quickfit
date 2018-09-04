classdef SettingsEditor < handle
    properties
        mainwindow
        settings
    end
    properties (Access=protected)
        sections = struct([])
        activesection = []
        activeSettingChangedListener = [];
    end
    methods
        function obj = SettingsEditor(settings)            
            obj.settings = settings;
            
            % make a flat list of sections
            obj.sections = struct('name', 'Settings', 'level', 0, 'object', settings,'button',[]);
            obj.createTreeList(settings, 0)
            obj.mainwindow = obj.buildMainWindow();  
            obj.loadsection(1);
        end 
        function delete(obj)
            if ~isempty(obj.activeSettingChangedListener) && isvalid(obj.activeSettingChangedListener), delete(obj.activeSettingChangedListener); end
            if ~isempty(obj.mainwindow) && isvalid(obj.mainwindow), delete(obj.mainwindow); end
            obj.settings = []; % Don't delete this, it would just clear the settings
        end
    end
    methods (Access = protected)
        function createTreeList(obj, settingsobj, level)
            props = sort(properties(settingsobj));
            for i=1:length(props)
                if isa(settingsobj.(props{i}),'cfw.Settings')
                    obj.sections(end+1) = struct('name',props{i},'level',level+1,'object',settingsobj.(props{i}),'button',[]);
                    obj.createTreeList(settingsobj.(props{i}), level+1);
                end
            end
        end
        function w = buildMainWindow(obj)
            % Make window and set its properties
            w = cfw.CWindow();
            w.set('Name','Settings Editor');
            w.set('Position',[1 1 800 600]);
            movegui(w.hfigure,'center');
            addlistener(w,'Close',@(s,e)delete(obj));
            
            % Divide the window in main sections
            maingrid = cfw.CGridLayout();
            w.control = maingrid;
            maingrid.setRows({'pixels','normalized'},[35 1]);
            maingrid.setColumns({'pixels','normalized'},[200 1]);
            
            % Bottom bar with close/import/export buttons
            buttongrid = cfw.CGridLayout();
            buttongrid.setColumns({'pixels','pixels','normalized','pixels'},[100 100 1 60]);
            maingrid.addChild(buttongrid,[1 2],[1 1]);
            w.addNamedControl('btnExport',buttongrid.addChild(cfw.CUIControl([],'style','pushbutton','string','Export section'),[1,1],[1 1]));
            w.addNamedControl('btnImport',buttongrid.addChild(cfw.CUIControl([],'style','pushbutton','string','Import section'),[1,2],[1 1]));
            w.addNamedControl('btnClose',buttongrid.addChild(cfw.CUIControl([],'style','pushbutton','string','Close'),[1,4],[1 1]));
            
            addlistener(w.controls.btnClose, 'Callback', @(s,e)delete(s.getWindow));
            
            % Left panel with buttons for each section
            w.addNamedControl('ubgSections',maingrid.addChild(cfw.CUIButtonGroup([]),[2 1],[1 1]));            
            ubggrid = w.controls.ubgSections.addChild(cfw.CGridLayout());
            un = cell(1,length(obj.sections)+1);
            un(2:end) = {'pixels'};
            un{1} = 'normalized';
            ubggrid.setRows(un,[1 30*ones(1,length(obj.sections))]);
            
            for i=1:length(obj.sections)
                btn = cfw.CUIControl([0.1*obj.sections(i).level 0 1-0.1*obj.sections(i).level 1],'style','togglebutton','string',obj.sections(i).name);
                ubggrid.addChild(btn,[length(obj.sections)-i+2,1]);
                obj.sections(i).button = btn;
            end
            addlistener(w.controls.ubgSections,'SelectionChanged',@obj.cb_sectionSelectionChanged);
            
            % Table for the settings
            w.addNamedControl('tableSettings',maingrid.addChild(cfw.CUITable(),[2 2]));
            w.controls.tableSettings.columnnames = {'Name','Value','Description'};
            addlistener(w.controls.tableSettings, 'DataChanged', @obj.cb_tableSettingsDataChanged);
            w.controls.tableSettings.set('ColumnWidth',{150 150 250});
            w.controls.tableSettings.set('ColumnEditable',[false true false])
            w.controls.tableSettings.set('RowName',[]);
            
            w.show;
        end
        function cb_sectionSelectionChanged(obj,source,event)
            % Clicked on a different section button
            if ~isempty(event.newvalue)
                s = find(arrayfun(@(x)x.button==event.newvalue,obj.sections), 1);
                if ~isempty(s)
                    obj.loadsection(s)
                end
            end
        end
        function loadsection(obj,s)
            % Load properties and meta data from the section object
            data = cell(0,3);
            if s>0 && s<=length(obj.sections)
                sobj = obj.sections(s).object;
                obj.activesection = s;
                if ~isempty(obj.activeSettingChangedListener) && isvalid(obj.activeSettingChangedListener), delete(obj.activeSettingChangedListener); end
                obj.activeSettingChangedListener = event.listener(sobj,'SettingChanged',@obj.cb_settingChanged);
                names = sort(properties(sobj));
                for i = 1:length(names)
                    [tshow,tdesc] = sobj.getSettingMeta(names{i},'showinoptions','description');
                    if tshow && ~isa(sobj.(names{i}), 'cfw.Settings')
                        val = obj.formatSetting(sobj,names{i});
                        if isempty(data)
                            data = {names{i}, val, tdesc};
                        else
                            data = [data; {names{i}, val, tdesc}];
                        end
                    end
                end
            end
            obj.mainwindow.controls.tableSettings.data = data;
        end
        function cb_tableSettingsDataChanged(obj,source,event)
            % Only allow editing of the second column
            % Default: keep current value in the table. Updating of the
            % table data will be done automatically after the setting is
            % updated through cb_settingChanged
            source.data{event.row,event.column} = event.oldvalue; 
            if event.column == 2
                obj.parseEdit(obj.sections(obj.activesection).object, source.data{event.row,1}, event.newvalue);
            end
        end
        function cb_settingChanged(obj,source,event)
            r = find(cellfun(@(x)strcmp(x,event.name), obj.mainwindow.controls.tableSettings.data(:,1)));
            if ~isempty(r)
                obj.mainwindow.controls.tableSettings.data{r(1),2} = obj.formatSetting(event.source, event.name);
            end
        end
    end
    methods(Static)
        function val1 = formatSetting(sobj,name,value)
            tshowfcn = sobj.getSettingMeta(name,'showfcn'); 
            if nargin<3,
                value = sobj.(name);
            end
            if ~isempty(tshowfcn)
                val1 = feval(tshowfcn, value);
            else
                val1 = defaultshowfcn(value);
            end
            function val = defaultshowfcn(value)
                % Default behaviour: try to be a little bit
                % clever in interpreting the value
                val = sprintf('%dx%d %s',size(value,1), size(value,2), class(value));
                try
                    if ischar(value)
                        val = ['''',value,''''];
                    elseif isnumeric(value) || islogical(value) || iscell(value)
                        if isscalar(value) && ~iscell(value) % Cells always need to be in {}
                            if islogical(value)
                                val = value;
                            else
                                % Explicitly make it a string (Wether or
                                % not we should depends on what we want the
                                % table to do. If we don't make it a
                                % string, it is possible to accidentally
                                % change a string field into double, but
                                % not back.)
                                val = num2str(value);
                            end
                        elseif isvector(value)
                            % Deal with column vectors by transposing them
                            % (nicer than lots of semicolons)
                            tr =''; 
                            if size(value,1)>1, tr=''''; end; 
                            if iscell(value)
                                br = {'{','}'}; 
                                % Recurse to format the contents of the cell
                                tval = cellfun(@defaultshowfcn, value(:), 'uniformoutput',false);
                                tval2 = cell(1,length(tval)*2-1);
                                tval2(1:2:end) = tval;
                                tval2(2:2:end) = {' '};
                                innerval = horzcat(tval2{:});
                            else
                                br = {'[',']'};
                                innerval = num2str(value(:)');
                            end
                            val = [br{1},innerval,br{2},tr];
                        end  
                    end
                catch
                end
            end
        end
        function baccept = parseEdit(sobj, name, newvalue)
            baccept = false;
            [tedit,tverifyfcn, tparsefcn, tclass] = sobj.getSettingMeta(name,'editinoptions','editverifyfcn','editparsefcn','editclass');
            if tedit
                % Only accept change if editinoptions=true

                if ~isempty(tparsefcn)
                    % Parse with user defined function
                    newval = tparsefcn(newvalue);
                else
                    % Try to evaluate as an expression, so the user can
                    % do calculations in the box
                    try
                        newval = evalin('base',newvalue);
                    catch e
                        % Just take it as a string
                        newval = newvalue;
                    end
                end
                if ~isempty(tclass)
                    % Convert to the desired class if defined
                    try
                        newval = cast(newval,tclass);
                        baccept = true;
                    catch e
                        baccept = false;
                    end
                else
                    baccept = true;
                end
                if baccept && (isempty(tverifyfcn) || ~feval(tverifyfcn,newvalue))
                    % All is ok now
                    sobj.(name) = newval;
                end
            end
        end
    end
end
