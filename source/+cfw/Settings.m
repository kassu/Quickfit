% Storage mechanism for settings
% Settings can be added at runtime, and nested to create a settings tree.
% Implemented with dynamic properties
classdef Settings < dynamicprops
    properties (Access = private)
        m_metadata = struct([]);
    end
    events
        SettingChanged
    end
    methods
        function obj = Settings(varargin)
            % Accept name/value pairs for new settings
            for i=1:2:(2*fix(nargin/2))
                obj.addSetting(varargin{i}, varargin{i+1});
            end
        end 
        function delete(obj)
            % Make sure any child objects are deleted
            p = properties(obj);
            for i=1:length(p)
                if isa(obj.(p{i}),'cfw.Settings')
                    delete(obj.(p{i}))
                end
            end
        end
        % Add a new setting
        function addSetting(obj, name, initialvalue, varargin)
            if isempty(obj.findprop(name))
                p = addprop(obj, name);
                meta = struct('settingname',name,'callbacks',{{}},'allowload',true,'showinoptions',true,'editinoptions',true,'editverifyfcn',[],'editparsefcn',[],'editclass',[],'showfcn',[],'description','');
                if isempty(obj.m_metadata)
                    obj.m_metadata = meta;
                else
                    obj.m_metadata(end+1) = meta;
                end
                obj.(name) = initialvalue;
                p.SetMethod = @setSetting;
                p.SetObservable = true; % Allow PreSet/PostSet events
                p.GetObservable = true; % Allow PreGet/PostGet events
                p.AbortSet = true; % Only update value (call listeners) when the value actually changes
                if nargin>3
                    obj.setSettingMeta(name,varargin{:});
                end
            else
                throw(MException('Settings:addSetting','Setting already exists'));
            end
            function setSetting(obj, val)
                oldval = obj.(name);
                obj.(name) = val; 
                
                % Notify any listeners for SettingChanged
                e = cfw.SettingChangedEvent(obj,name,oldval,val);
                notify(obj,'SettingChanged',e);
               
                % Find all callback functions defined for this setting
                m = find(arrayfun(@(x)strcmp(x.settingname,name),obj.m_metadata));
                if ~isempty(m)
                    for i=1:length(obj.m_metadata(m(1)).callbacks)
                        feval(obj.m_metadata(m(1)).callbacks{i},obj,e);
                    end
                end
            end
        end
        
        function removeSetting(obj, name)
             p = obj.findprop(name);
             if ~isempty(p)
                 delete(p);
             end
             % Remove also from metadata
             obj.m_metadata = obj.m_metadata(~cellfun(@(x)strcmp(x,name), cat(2,{obj.m_metadata.settingname})));
        end
        
        function setSettingMeta(obj, name, varargin)
            v = varargin;
            m = find(arrayfun(@(x)strcmp(x.settingname,name),obj.m_metadata));
            if ~isempty(m)
                while length(v) >= 2
                    if ischar(v{1})
                        switch(lower(v{1}))
                            case {'allowload','showinoptions','editinoptions'}
                                if islogical(v{2}) && isscalar(v{2})
                                    obj.m_metadata(m(1)).(lower(v{1})) = v{2};
                                else
                                    throw(MException('Settings:setSettingMeta','%s must be true or false',v{1}));
                                end
                            case {'editverifyfcn','editparsefcn','showfcn'}
                                if isa(v{2},'function_handle') && isscalar(v{2})
                                    obj.m_metadata(m(1)).(lower(v{1})) = v{2};
                                else
                                    throw(MException('Settings:setSettingMeta','%s must be a function handle',v{1}));
                                end
                            case {'description', 'editclass'}
                                if ischar(v{2})
                                    obj.m_metadata(m(1)).(lower(v{1})) = v{2};
                                else
                                    throw(MException('Settings:setSettingMeta','%s must be a string',v{1}));
                                end
                            otherwise 
                                throw(MException('Settings:setSettingMeta','%s is not a valid setting meta property',v{1}));
                        end
                    else
                        throw(MException('Settings:setSettingMeta','Setting meta data must be given as key/value pairs'));
                    end
                    v = v(3:end);
                end
            end
        end
        
        function varargout = getSettingMeta(obj, name, varargin)
            varargout = {};
            v = varargin;
            m = find(arrayfun(@(x)strcmp(x.settingname,name),obj.m_metadata));
            if ~isempty(m)
                for i=1:length(varargin)
                    if ischar(varargin{i})
                        if isfield(obj.m_metadata(m(1)),lower(varargin{i}))
                            varargout{i} = obj.m_metadata(m(1)).(varargin{i});
                        else
                            throw(MException('Settings:setSettingMeta','%s is not a valid setting meta property',v{1}));
                        end
                    else
                        throw(MException('Settings:setSettingMeta','Setting names must be char'));
                    end
                end
            end
        end
        
        function addListener(obj, name, callback)
            if isa(callback,'function_handle')
                m = find(arrayfun(@(x)strcmp(x.settingname,name),obj.m_metadata));
                if ~isempty(m)
                    if isempty(obj.m_metadata(m(1)).callbacks)
                        obj.m_metadata(m(1)).callbacks = {callback};
                    else
                        obj.m_metadata(m(1)).callbacks(end+1) = {callback};
                    end
                else
                    throw(MException('Settings:addListener','Setting not found'));
                end
            end
        end
        
        % Get a struct containing all settings in this object. Only
        % name/value pairs are saved, meta data is not saved.
        % Settings whos value is a Settings object are converted by
        % calling their getSaveData method.
        % Note that this mechanism does not support settings that have a
        % struct as value.
        function s = getStructData(obj)
            fields = properties(obj);
            for i = 1:length(fields)
                if isa(obj.(fields{i}), 'cfw.Settings')
                    s.(fields{i}) = obj.(fields{i}).getStructData();
                else
                    s.(fields{i}) = obj.(fields{i});
                end
            end
        end
        
        % 
        function putStructData(obj, s, forceload, createnew)
            if nargin<3, forceload = false; end;
            if nargin<4, createnew = false; end;
            
            props = properties(obj);
            fields = fieldnames(s);
            for i = 1:length(fields)
                e = ismember(fields{i},props);
                if ~e && createnew
                    if isstruct(s.(fields{i}))
                        m = cfw.Settings;
                        m.putStructData(s.(fields{i}), forceload, createnew);
                        obj.addSetting(fields{i},m);
                    else
                        obj.addSetting(fields{i},s.(fields{i}));
                    end
                elseif e
                    if forceload || obj.getSettingMeta(fields{i},'allowload')
                        if isstruct(s.(fields{i}))
                            if isa(obj.(fields{i}),'cfw.Settings')
                                obj.(fields{i}).putStructData(s.(fields{i}), forceload, createnew);
                            else
                                obj.(fields{i}) = s.(fields{i});
                            end
                        else
                            obj.(fields{i}) = s.(fields{i});
                        end
                    end
                end
            end
        end
        
        % Just an alternative notation
        function set(obj,name,val)
            obj.(name) = val;
        end
    end
    methods (Static)
        function c = allMetaNames
            c = {'callbacks','allowload','showinoptions','editinoptions','editverifyfcn','editparsefcn','editclass','showfcn','description'};
        end
    end
end